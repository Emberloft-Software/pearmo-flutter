// supabase/functions/submit-verification/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )


  // Non-null assertion here meant a request with no Authorization header
  // threw a TypeError and returned 500 instead of 401.
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return new Response('Unauthorized', { status: 401 })

  const { data: { user } } = await supabase.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (!user) return new Response('Unauthorized', { status: 401 })

  const { tier, nic_front_path, nic_back_path, selfie_path, liveliness_passed } = await req.json()

  if (tier !== 'selfie' && tier !== 'id') {
    return new Response(
      JSON.stringify({ error: "tier must be 'selfie' or 'id'" }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }
  if (tier === 'selfie' && !selfie_path) {
    return new Response(
      JSON.stringify({ error: 'selfie_path is required for tier "selfie"' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }
  if (tier === 'id' && !nic_front_path) {
    return new Response(
      JSON.stringify({ error: 'nic_front_path is required for tier "id"' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Tier 'id' builds on tier 'selfie' — the client only shows this form once
  // `selfie_verified`, but that was never enforced here, so a direct call
  // could submit an ID before ever passing (or being reviewed for) tier 1.
  if (tier === 'id') {
    const { data: userRow } = await supabase
      .from('users')
      .select('verification_tier')
      .eq('id', user.id)
      .single()

    if (!userRow || userRow.verification_tier === 'unverified') {
      return new Response(
        JSON.stringify({ error: 'Complete selfie verification before submitting an ID.' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
  }

  // Check no pending submission already exists for this tier — scoped per
  // tier (not globally) so a pending tier-1 review can't block a tier-2
  // submission or vice versa.
  const { data: existing } = await supabase
    .from('verification_submissions')
    .select('id, status')
    .eq('user_id', user.id)
    .eq('tier', tier)
    .eq('status', 'pending')
    .maybeSingle()

  if (existing) {
    return new Response(
      JSON.stringify({ error: 'You already have a pending verification submission' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const insertPayload: Record<string, unknown> = {
    user_id: user.id,
    tier,
    status: 'pending'
  }
  if (tier === 'selfie') {
    insertPayload.selfie_path = selfie_path
    insertPayload.liveliness_passed = liveliness_passed ?? false
  } else {
    insertPayload.nic_front_path = nic_front_path
    if (nic_back_path) insertPayload.nic_back_path = nic_back_path
  }

  const { data, error } = await supabase
    .from('verification_submissions')
    .insert(insertPayload)
    .select()
    .single()

  if (error) {
    return new Response(JSON.stringify({ error }), { status: 500 })
  }

  // TODO: trigger ML face match service here once Python service is ready

  return new Response(JSON.stringify({ submission: data }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
