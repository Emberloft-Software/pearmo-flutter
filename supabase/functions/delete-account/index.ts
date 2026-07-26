// supabase/functions/delete-account/index.ts
//
// Soft-deletes the calling user's account: wipes PII/media (photos, voice
// intro, NIC/selfie files, about text, display name) but deliberately keeps
// the `users`/`profiles` rows and everything in `reports`,
// `connection_ratings`, `trust_score`, `report_count`, and
// `verification_submissions` status history intact. This is intentional —
// a true cascading delete would let a reported/bad-actor user erase their
// moderation trail and re-register clean. See CLAUDE.md "Account deletion".
//
// `users.verification_tier` is the one exception — reset to 'unverified'
// since the actual reviewed evidence (NIC/selfie files) is deleted below,
// so the badge shouldn't survive onto a re-onboarded, never-reviewed
// profile. Re-verification is required again after deletion.
//
// This does NOT permanently block the phone number from signing in again —
// the same identity (same `users.id`) can re-onboard from scratch. What
// persists across a delete+recreate cycle is `trust_score`/`report_count`/
// `reports`/`connection_ratings` (untouched, tied to the same id) plus
// `last_deleted_at`/`deletion_count` (bumped here) as a permanent safety
// record a moderator could look at — deletion is tracked, not blocked.
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

  // Wipe identifying/media fields on the profile and force it back through
  // onboarding (onboarding_complete=false) — the router sends anyone with
  // an incomplete profile to /onboarding, so signing back in with the same
  // phone lands them in a fresh setup flow rather than a blocked screen.
  // Deliberately NOT touched: date_of_birth, gender, seeking, seeking_age_*,
  // trait_*, relationship_intent, partner_values, music_genres, avatar_id,
  // country_code — none of these are individually identifying, and it
  // doesn't matter what's left since onboarding_complete=false hides the
  // row from `public_profiles` (and re-onboarding overwrites all of it
  // anyway).
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
      onboarding_complete: false,
    })
    .eq('user_id', user.id)

  // Clear the actual document/photo paths from verification history, but
  // keep status/tier/rejection_reason/reviewed_at/reviewed_by — the review
  // outcome itself is part of the moderation trail, not PII.
  await supabase
    .from('verification_submissions')
    .update({ nic_front_path: null, nic_back_path: null, selfie_path: null })
    .eq('user_id', user.id)

  // Record the deletion for safety visibility, but do NOT block future
  // logins (no `is_active` change) — `trust_score`/`report_count`/`phone`
  // are left untouched, so a delete+recreate cycle can't be used to
  // launder a bad trust score onto a "fresh" identity; it's the same
  // identity, just re-onboarded.
  //
  // `verification_tier` IS reset to 'unverified' here, unlike those —
  // the actual NIC/selfie evidence backing that tier was just deleted
  // above, so keeping the badge would mean it no longer corresponds to
  // any reviewed evidence of the (now different) re-onboarded profile.
  // `verification_submissions` history rows (status/tier/rejection_reason/
  // reviewed_at/reviewed_by) are untouched — only the paths were cleared
  // above — so the moderation trail of past reviews still exists.
  const { data: existing } = await supabase
    .from('users')
    .select('deletion_count')
    .eq('id', user.id)
    .single()

  await supabase
    .from('users')
    .update({
      last_deleted_at: new Date().toISOString(),
      deletion_count: (existing?.deletion_count ?? 0) + 1,
      verification_tier: 'unverified',
    })
    .eq('id', user.id)

  return new Response(JSON.stringify({ deleted: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
