// supabase/functions/cleanup-verification-media/index.ts
//
// Deletes NIC front/back images from storage once a submission has been
// reviewed (approved or rejected) — there's no reason to keep a government
// ID photo around after a human has already looked at it. Keeps the
// verification_submissions row itself (status/tier/rejection_reason/
// reviewed_at/reviewed_by) as the permanent moderation record; only the
// actual image files + their path columns are cleared.
//
// Not triggered by client action — this is meant to be invoked on a
// schedule by pg_cron via pg_net (see CLAUDE.md for the cron.schedule call),
// since the actual review/approval happens in the separate Next.js admin
// app, not this repo. Authenticated via a shared secret header rather than
// a user JWT, since there's no user session behind a cron-triggered call.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  const secret = req.headers.get('x-cron-secret')
  if (!secret || secret !== Deno.env.get('CRON_SECRET')) {
    return new Response('Unauthorized', { status: 401 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const { data: submissions, error } = await supabase
    .from('verification_submissions')
    .select('id, user_id, nic_front_path, nic_back_path')
    .in('status', ['approved', 'rejected'])
    .or('nic_front_path.not.is.null,nic_back_path.not.is.null')

  if (error) {
    return new Response(JSON.stringify({ error }), { status: 500 })
  }

  let cleaned = 0
  for (const submission of submissions ?? []) {
    const paths = [submission.nic_front_path, submission.nic_back_path].filter(
      (p): p is string => typeof p === 'string' && p.length > 0
    )
    if (paths.length === 0) continue

    await supabase.storage.from('nic-documents').remove(paths)
    await supabase
      .from('verification_submissions')
      .update({ nic_front_path: null, nic_back_path: null })
      .eq('id', submission.id)
    cleaned++
  }

  return new Response(JSON.stringify({ cleaned, checked: submissions?.length ?? 0 }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
