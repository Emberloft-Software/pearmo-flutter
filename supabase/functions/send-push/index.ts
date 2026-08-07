// supabase/functions/send-push/index.ts
//
// Sends a real FCM push for the three events the old client-side
// `NotificationWatcher` used to fake with Supabase Realtime: a new chat
// message, a new incoming connection request, and a new ice-breaker game
// session. See CLAUDE.md "Push notifications".
//
// Not called by the app — invoked by three Supabase Database Webhooks
// (Dashboard → Database → Webhooks), one per table, each configured for
// INSERT only and POSTing here with a shared secret header (there's no user
// session behind a webhook call, same reasoning as `cleanup-verification-
// media`'s `x-cron-secret`). Database Webhooks send the row as-is in
// `{type, table, record}` — see the `WebhookPayload` shape below.
//
// FCM's HTTP v1 API (unlike the deprecated legacy API) needs a short-lived
// OAuth2 access token, not a static server key — obtained here by signing a
// JWT with the Firebase service account's private key and exchanging it at
// Google's token endpoint. `jose` (not a Node/npm-only lib — works in Deno)
// handles the RS256 signing.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5'

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: Record<string, unknown>
}

interface PushTarget {
  title: string
  body: string
  data: Record<string, string>
  userIds: string[]
}

const GAME_LABELS: Record<string, string> = {
  would_you_rather: 'Would You Rather',
  draw_together: 'Draw Together',
  trivia: 'Trivia',
  prompts: '20 Questions',
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null

async function getAccessToken(): Promise<string> {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 30_000) {
    return cachedAccessToken.token
  }

  const serviceAccount = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!)
  const privateKey = await importPKCS8(serviceAccount.private_key, 'RS256')

  const jwt = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuedAt()
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setExpirationTime('1h')
    .sign(privateKey)

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const data = await res.json()
  if (!res.ok) throw new Error(`Token exchange failed: ${JSON.stringify(data)}`)

  cachedAccessToken = { token: data.access_token, expiresAt: Date.now() + data.expires_in * 1000 }
  return data.access_token
}

async function connectionParticipants(
  supabase: ReturnType<typeof createClient>,
  connectionId: string
): Promise<{ initiator_id: string; receiver_id: string } | null> {
  const { data } = await supabase
    .from('connections')
    .select('initiator_id, receiver_id')
    .eq('id', connectionId)
    .maybeSingle()
  return data as { initiator_id: string; receiver_id: string } | null
}

async function buildTarget(
  supabase: ReturnType<typeof createClient>,
  payload: WebhookPayload
): Promise<PushTarget | null> {
  const record = payload.record

  if (payload.table === 'messages') {
    const connectionId = record.connection_id as string
    const senderId = record.sender_id as string
    const participants = await connectionParticipants(supabase, connectionId)
    if (!participants) return null
    const recipient = participants.initiator_id === senderId
      ? participants.receiver_id
      : participants.initiator_id
    if (recipient === senderId) return null

    const contentType = record.content_type as string
    const body =
      contentType === 'image' ? 'Sent a photo' :
      contentType === 'video' ? 'Sent a video' :
      (record.content as string) ?? ''

    return {
      title: 'New message',
      body,
      data: { type: 'message', connection_id: connectionId },
      userIds: [recipient],
    }
  }

  if (payload.table === 'connections') {
    if (record.status !== 'pending') return null
    return {
      title: 'New connection request',
      body: 'Someone wants to connect with you!',
      data: { type: 'connection_request', connection_id: record.id as string },
      userIds: [record.receiver_id as string],
    }
  }

  if (payload.table === 'ice_breaker_sessions') {
    const connectionId = record.connection_id as string
    const participants = await connectionParticipants(supabase, connectionId)
    if (!participants) return null
    const gameLabel = GAME_LABELS[record.game_type as string] ?? 'a game'
    return {
      title: 'Game invite',
      body: `Your connection wants to play ${gameLabel}!`,
      data: { type: 'game_invite', connection_id: connectionId },
      // No `created_by` column on ice_breaker_sessions (see CLAUDE.md), so
      // there's no way to exclude whoever started it — both participants
      // (including the creator) get notified, same accepted redundancy the
      // old client-side watcher had.
      userIds: [participants.initiator_id, participants.receiver_id],
    }
  }

  return null
}

async function sendToUser(
  supabase: ReturnType<typeof createClient>,
  accessToken: string,
  projectId: string,
  userId: string,
  target: PushTarget
) {
  const { data: tokens } = await supabase
    .from('push_tokens')
    .select('id, token')
    .eq('user_id', userId)

  for (const row of tokens ?? []) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: row.token,
            notification: { title: target.title, body: target.body },
            data: target.data,
          },
        }),
      }
    )

    if (!res.ok) {
      const error = await res.json().catch(() => null)
      const status = error?.error?.status
      // Token no longer valid (app uninstalled, token rotated without a
      // fresh upsert reaching us, etc.) — drop it rather than retry forever.
      if (status === 'UNREGISTERED' || status === 'NOT_FOUND' || status === 'INVALID_ARGUMENT') {
        await supabase.from('push_tokens').delete().eq('id', row.id)
      }
    }
  }
}

Deno.serve(async (req) => {
  const secret = req.headers.get('x-webhook-secret')
  if (!secret || secret !== Deno.env.get('PUSH_WEBHOOK_SECRET')) {
    return new Response('Unauthorized', { status: 401 })
  }

  const payload = (await req.json()) as WebhookPayload
  if (payload.type !== 'INSERT') {
    return new Response(JSON.stringify({ skipped: 'not an insert' }), { status: 200 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const target = await buildTarget(supabase, payload)
  if (!target) {
    return new Response(JSON.stringify({ skipped: 'no target' }), { status: 200 })
  }

  const serviceAccount = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!)
  const accessToken = await getAccessToken()

  for (const userId of target.userIds) {
    await sendToUser(supabase, accessToken, serviceAccount.project_id, userId, target)
  }

  return new Response(JSON.stringify({ sent: true, recipients: target.userIds.length }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
