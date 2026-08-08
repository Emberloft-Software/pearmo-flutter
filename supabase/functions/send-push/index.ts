// supabase/functions/send-push/index.ts
//
// Sends a real FCM push for chat/connection/consent events. Originally
// covered only the three events the old client-side `NotificationWatcher`
// used to fake with Supabase Realtime (new chat message, new incoming
// connection request, new ice-breaker game session) — extended to also
// cover connection responses (accept/decline), pause/resume, end, and
// chat/media consent changes (request/grant/revoke). See CLAUDE.md "Push
// notifications" and the connection-notifications follow-up section.
//
// Not called by the app — invoked by plain Postgres triggers calling
// `net.http_post` (see the trigger SQL handed to the user; Database
// Webhooks aren't usable on this project, see CLAUDE.md), POSTing here with
// a shared secret header (there's no user session behind a trigger-driven
// call, same reasoning as `cleanup-verification-media`'s `x-cron-secret`).
//
// Two payload shapes:
// - Table-native (`messages`, `connections` INSERT, `ice_breaker_sessions`):
//   `{type, table, record}` — `buildTarget` derives the recipient(s) and
//   copy itself, same as originally built.
// - Event-driven (connection UPDATE, consent_records INSERT/UPDATE): the
//   trigger already has the relational context (participant ids, who acted)
//   that would otherwise need a second query here, so it computes
//   `target_user_id` and a specific `event` label in SQL and passes them
//   directly — `buildFromEvent` just picks the copy for that `event`.
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
  old_record?: Record<string, unknown>
  /** Event-driven payloads only — see file header. */
  event?: string
  target_user_id?: string
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

// Mirrors ConsentType.label in lib/core/constants/enums.dart — keep in sync
// if that changes.
const CONSENT_LABELS: Record<string, string> = {
  chat_unlock: 'Open chat',
  media_share: 'Share photos & videos',
}

/**
 * Copy for event-driven payloads (see file header) — the trigger already
 * resolved `target_user_id`, so this only picks title/body/data.
 */
function buildFromEvent(payload: WebhookPayload): PushTarget | null {
  const record = payload.record
  const targetUserId = payload.target_user_id!
  const connectionId = (record.connection_id as string) ?? (record.id as string)

  switch (payload.event) {
    case 'connection_accepted':
      return {
        title: 'Request accepted!',
        body: "They said yes — break the ice together to unlock chat.",
        data: { type: 'connection_accepted', connection_id: connectionId },
        userIds: [targetUserId],
      }
    // ASSUMPTION, not confirmed against `respond-to-connection`'s actual
    // source (not visible from this repo — see CLAUDE.md's standing rule on
    // guessing edge function behavior): a decline is inferred as a
    // `pending -> ended` transition that never passed through `accepted`.
    // If `respond-to-connection` instead sets some other status on decline,
    // this event never fires — verify against a real decline before
    // relying on it.
    case 'connection_declined':
      return {
        title: 'Connection update',
        body: "Your connection request wasn't accepted this time.",
        data: { type: 'connection_declined', connection_id: connectionId },
        userIds: [targetUserId],
      }
    case 'connection_ended':
      return {
        title: 'Connection ended',
        body: 'Your connection has ended.',
        data: { type: 'connection_ended', connection_id: connectionId },
        userIds: [targetUserId],
      }
    case 'connection_paused':
      return {
        title: 'Chat paused',
        body: 'The other person paused this chat for now.',
        data: { type: 'connection_paused', connection_id: connectionId },
        userIds: [targetUserId],
      }
    case 'connection_resumed':
      return {
        title: 'Chat resumed',
        body: 'The chat you paused has been resumed.',
        data: { type: 'connection_resumed', connection_id: connectionId },
        userIds: [targetUserId],
      }
    case 'consent_requested': {
      const label = CONSENT_LABELS[record.consent_type as string] ?? 'A shared unlock'
      return {
        title: 'New request',
        body: `They'd like to turn on "${label}" — open the app to respond.`,
        data: { type: 'consent_requested', connection_id: connectionId },
        userIds: [targetUserId],
      }
    }
    case 'consent_granted': {
      const label = CONSENT_LABELS[record.consent_type as string] ?? 'A shared unlock'
      return {
        title: `${label} unlocked`,
        body: "You both agreed — it's unlocked now.",
        data: { type: 'consent_granted', connection_id: connectionId },
        userIds: [targetUserId],
      }
    }
    case 'consent_revoked': {
      const label = CONSENT_LABELS[record.consent_type as string] ?? 'A shared unlock'
      return {
        title: 'Consent update',
        body: `They turned off "${label}".`,
        data: { type: 'consent_revoked', connection_id: connectionId },
        userIds: [targetUserId],
      }
    }
    default:
      return null
  }
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

  // Event-driven payloads (connection UPDATE, consent_records) already
  // carry their recipient and a specific event label — no DB lookup needed.
  if (payload.target_user_id && payload.event) {
    return buildFromEvent(payload)
  }

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
  // Event-driven UPDATE payloads (connection responses/pause/end, consent
  // changes) are handled below via `target_user_id`/`event`. Every other
  // UPDATE (and any DELETE) is still a no-op, same as before — table-native
  // handling in `buildTarget` only exists for INSERTs.
  if (payload.type !== 'INSERT' && !(payload.type === 'UPDATE' && payload.target_user_id)) {
    return new Response(JSON.stringify({ skipped: `not handled: ${payload.type}` }), {
      status: 200,
    })
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
