// supabase/functions/delete-account/index.ts
//
// Soft-deletes the calling user's account: wipes PII/media (photos, voice
// intro, NIC/selfie files, about text, display name) but deliberately keeps
// the `users`/`profiles` rows and everything in `reports`,
// `connection_ratings`, `trust_score`, `report_count`, and
// `verification_submissions` status history intact. This is intentional —
// a true cascading delete would let a reported/bad-actor user erase their
// moderation trail and re-register clean. See CLAUDE.md "Account deletion".
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const BUCKETS = ['profile-photos', 'audio-intros', 'nic-documents']

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const authHeader = req.headers.get('Authorization')!
  const { data: { user } } = await supabase.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (!user) return new Response('Unauthorized', { status: 401 })

  // Remove every stored file under this user's folder in each private
  // bucket (profile photo, audio intro, selfie, NIC front/back — whatever
  // extension they were uploaded with).
  for (const bucket of BUCKETS) {
    const { data: files } = await supabase.storage.from(bucket).list(user.id)
    if (files && files.length > 0) {
      const paths = files.map((f) => `${user.id}/${f.name}`)
      await supabase.storage.from(bucket).remove(paths)
    }
  }

  // Wipe identifying/media fields on the profile, hide it from matching.
  // Deliberately NOT touched: date_of_birth, gender, seeking, seeking_age_*,
  // trait_*, relationship_intent, partner_values, music_genres, avatar_id,
  // country_code — none of these are individually identifying, and it
  // doesn't matter what's left since is_profile_active=false hides the row
  // from `public_profiles` regardless.
  await supabase
    .from('profiles')
    .update({
      display_name: 'Deleted user',
      about_text: '',
      avatar_config: null,
      profile_photo_url: null,
      audio_intro_url: null,
      region_name: null,
      is_profile_active: false,
      is_photo_public: false,
      hide_from_contacts: true,
    })
    .eq('user_id', user.id)

  // Clear the actual document/photo paths from verification history, but
  // keep status/tier/rejection_reason/reviewed_at/reviewed_by — the review
  // outcome itself is part of the moderation trail, not PII.
  await supabase
    .from('verification_submissions')
    .update({ nic_front_path: null, nic_back_path: null, selfie_path: null })
    .eq('user_id', user.id)

  // Mark the account deleted and block future logins. `trust_score`,
  // `report_count`, `phone`, and `verification_tier` are left untouched —
  // the phone number stays tied to this now-unusable identity so deleting
  // and re-registering can't be used to launder a bad trust score.
  await supabase
    .from('users')
    .update({ is_active: false, deleted_at: new Date().toISOString() })
    .eq('id', user.id)

  return new Response(JSON.stringify({ deleted: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
