# Matching pipeline + verification tiers

**Status (2026-08-02):** app changes done and analysed clean. SQL sections
1–3 **applied and verified against the live database**. Sections 4 (tier
trigger) and 5 (chat-media storage policy) are **not yet run**.

Written 2026-08-02. Companion to `CLAUDE.md`, which stays the source of
truth for schema/RLS ground truth; this file covers one feature end to end.

---

## The problem this fixes

`generate_daily_matches(uuid)` is the only writer of `public.daily_matches`.
Before this change **nothing called it**: no client RPC (`.rpc(` appeared
nowhere in `lib/`), and `cron.job` was empty. A user's match list was
whatever happened to be in the table, which for a genuinely new account was
nothing, forever. The "no matches" symptom during testing was this, not a
scoring problem.

Three things were layered on top of the fix:

1. Unverified users get a real, populated first session — from their own
   pool, with the pool rule explained honestly.
2. Chat photo/video sharing requires **both** participants at
   `selfie_verified` or higher. It previously required nothing at all.
3. A tier change mid-connection updates both people's matches and is
   announced in-thread.

---

## Decisions and why

**Pool rule: bootstrap, then strict.** Unverified users only ever see
unverified users. Verified users see other verified users *plus* unverified
users **only while the verified pool is thin** (< 20 active verified
profiles), after which it tightens to verified-only automatically.

The pure strict split was rejected for launch because it inverts the
incentive at the worst possible moment: on day one everyone is unverified,
so the first person to verify would leave a populated pool for an empty one
and be punished for verifying. The bootstrap window closes itself — no
manual flip, no follow-up migration.

**Media gate: both sides, at `selfie_verified`.** Selfie verification is
exactly the check that confirms a face belongs to the person sending it,
and it already gates the profile photo. Requiring `id_verified` would have
meant media sharing was effectively off for the whole beta.

**Copy is symmetric, never comparative.** The unverified banner says
"everyone here — including you". The badge now renders for *every* tier
including unverified, on your own profile too. A one-sided warning would
imply Pearmo has vouched for the viewer and not the person on the card;
both are in identical unchecked states.

**No "remind them to verify" action exists anywhere.** When media is
blocked because the *other* person hasn't verified, the dialog says so and
offers only "Got it". Nudging someone to submit a selfie or a national ID
because of who they happen to be talking to is coercion, and NIC images are
the most sensitive data this app touches.

**Unverified badge is grey, never red.** It's a factual state that usually
describes the viewer too, not a danger signal. A red badge on half the app
gets ignored within days.

---

## App changes (done)

| File | Change |
|---|---|
| `lib/shared/widgets/tier_chip.dart` | **New.** Verification pill rendered for every tier including unverified. Tappable into the existing claim dialog. |
| `lib/shared/widgets/verify_to_unlock_dialog.dart` | Parameterised by `VerifyUnlockReason` — profile picture / self unverified / other unverified / both. Drops "Verify now" when the block is on the other person. |
| `lib/data/repositories/matches_repository.dart` | `refreshMyMatches()` (calls the `refresh_my_matches` RPC) and `getCurrentBatchExpiry()`. |
| `lib/providers/matches_providers.dart` | Generation call before reading, non-fatal on failure; `nextBatchExpiryProvider`. |
| `lib/features/onboarding/providers/onboarding_controller.dart` | Generates the first batch at the end of `submit()`, outside the best-effort block. |
| `lib/features/matches/screens/matches_screen.dart` | `_UnverifiedPoolBanner`; `_EmptyMatches` with a real "next matches in Xh" instead of "check back tomorrow". |
| `lib/features/matches/widgets/match_card.dart` | Tier chip for all tiers (was verified-only). |
| `lib/features/profile/screens/my_profile_screen.dart` | Same, on your own header. |
| `lib/features/chat/screens/chat_screen.dart` | Media gate on both participants' tiers, fail-closed; `_SystemNotice` renderer. |
| `lib/data/models/message.dart` | `isSystem` getter. |

`HeroProfileCard` and `candidate_detail_screen.dart` already rendered a
muted badge for unverified — no change needed there.

---

## SQL to run

Run in order, in the Supabase SQL Editor.

### 1. Client entry point

```sql
create or replace function public.refresh_my_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  perform public.generate_daily_matches(auth.uid());
end;
$$;

revoke all on function public.refresh_my_matches() from public;
grant execute on function public.refresh_my_matches() to authenticated;
```

Never grant `generate_daily_matches(uuid)` itself to `authenticated` — it
takes an arbitrary user id, so any client could burn another user's daily
generation.

### 2. Bootstrap threshold helper

```sql
create or replace function public.verified_pool_is_thin()
returns boolean
language sql
stable
set search_path = public
as $$
  select count(*) < 20
  from public.users u
  join public.profiles p on p.user_id = u.id
  where u.verification_tier in ('selfie_verified', 'id_verified')
    and u.is_active and not u.is_banned and not u.is_shadow_suppressed
    and p.is_profile_active and p.onboarding_complete;
$$;
```

Tune the `20`, or force strict mode early by replacing the body with
`select false;`.

### 3. `generate_daily_matches` replacement — APPLIED

Three behavioural changes, everything else copied verbatim from the real
source (pulled via `pg_get_functiondef`, never reconstructed):

**(a) Tier visibility → bootstrap-then-strict.** The pre-existing function
already had the strict 3-way split live (contrary to `CLAUDE.md`, which had
the 2026-07-29 change recorded as unconfirmed — it *was* run). Replaced
with the bootstrap rule via `verified_pool_is_thin()`.

**(b) Daily cap enforced — this was a real bug.** The function scored up to
100 candidates and inserted **every one** with `score > 0`. It never read
`users.daily_match_count`, and no trigger enforced it either. "Up to 5
matches" was true in the app copy and in `AppConstants.dailyMatchCount`,
but the database would have inserted 60+ rows once the user base grew. Now
scores the candidate pool, orders by score descending, and takes
`coalesce(daily_match_count, 5)`.

**(c) `active_hours_end is null` guard added.** The original only guarded
`active_hours_start is null`, so a profile with a start but no end would
vanish from every pool.

**Correction to an earlier theory in this file and in `CLAUDE.md`:** the
active-hours clause was *not* the cause of "new accounts never see each
other". The real source already read
`p.active_hours_start is null or current_time between ...`, which handles
the all-NULL case every fresh profile has. The sole cause was that nothing
ever called `generate_daily_matches`. The `end is null` addition above is a
genuine but unrelated edge-case fix.

Also added `set search_path to 'public'` — `SECURITY DEFINER` without a
fixed search_path is a privilege-escalation vector that Supabase's own
advisor flags, and the sibling `score_compatibility` already had it.

**Verified live:** four unverified test profiles (2 men seeking women, 2
women seeking men, all age 24, overlapping age ranges) each generated
exactly 2 matches with symmetric scores in both directions.

### 4. Tier-change trigger

```sql
create or replace function public.on_verification_tier_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  other_id uuid;
  both_verified boolean;
begin
  if new.verification_tier is not distinct from old.verification_tier then
    return new;
  end if;

  -- 1. Their own batch now points at the wrong pool.
  delete from public.daily_matches where user_id = new.id;

  -- 2. They've moved above unverified, so drop them from unverified
  --    users' pending cards. Scoped narrowly on purpose: selfie and id
  --    share a pool, so a selfie -> id change must NOT wipe them from
  --    other verified users' batches.
  if new.verification_tier <> 'unverified' then
    delete from public.daily_matches dm
    using public.users u
    where dm.candidate_id = new.id
      and dm.user_id = u.id
      and u.verification_tier = 'unverified';
  end if;

  -- 3. Regenerate. MUST follow the delete — generate_daily_matches
  --    no-ops while an unexpired batch exists.
  perform public.generate_daily_matches(new.id);

  -- 4. Announce in any live connection. Copy is subject-neutral because
  --    both participants read the same row.
  for other_id in
    select case when c.initiator_id = new.id then c.receiver_id else c.initiator_id end
    from public.connections c
    where (c.initiator_id = new.id or c.receiver_id = new.id)
      and c.status <> 'ended'
  loop
    select u.verification_tier <> 'unverified' into both_verified
    from public.users u where u.id = other_id;

    insert into public.messages (connection_id, sender_id, content, content_type)
    select c.id, new.id,
           case
             when new.verification_tier = 'unverified'
               then 'A verification status in this chat changed.'
             when both_verified
               then 'Both of you are now verified — photos and videos are unlocked.'
             else 'One of you completed a verification check. Photos and videos unlock once both of you have.'
           end,
           'system'
    from public.connections c
    where (c.initiator_id = new.id or c.receiver_id = new.id)
      and c.status <> 'ended'
      and (c.initiator_id = other_id or c.receiver_id = other_id);
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_verification_tier_change on public.users;
create trigger trg_verification_tier_change
after update of verification_tier on public.users
for each row execute function public.on_verification_tier_change();
```

### 5. Chat media storage — check first

Per `CLAUDE.md` the `chat-media` bucket and its policies were written but
never confirmed created. Check before assuming:

```sql
select id, public from storage.buckets where id = 'chat-media';
select policyname, cmd, qual, with_check
from pg_policies where schemaname = 'storage' and tablename = 'objects';
select conname, pg_get_constraintdef(oid) from pg_constraint
where conrelid = 'public.messages'::regclass;
```

If the bucket is missing, create it **private**, then apply the policies
below. If it already exists with a permissive INSERT policy, replace that
policy — the tier requirement is what actually enforces the media gate; the
Dart check is UI only and a modified client can bypass it.

```sql
-- Upload: must be a participant, and BOTH participants verified.
drop policy if exists "chat media insert participant" on storage.objects;
create policy "chat media insert both verified"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chat-media'
  and exists (
    select 1
    from public.connections c
    join public.users me   on me.id = auth.uid()
    join public.users them on them.id = case
           when c.initiator_id = auth.uid() then c.receiver_id else c.initiator_id end
    where c.id::text = (storage.foldername(name))[1]
      and (c.initiator_id = auth.uid() or c.receiver_id = auth.uid())
      and me.verification_tier   <> 'unverified'
      and them.verification_tier <> 'unverified'
  )
);

-- Read: participants only, no tier requirement (media already sent stays
-- visible even if someone's tier later changes).
create policy "chat media select participant"
on storage.objects for select to authenticated
using (
  bucket_id = 'chat-media'
  and exists (
    select 1 from public.connections c
    where c.id::text = (storage.foldername(name))[1]
      and (c.initiator_id = auth.uid() or c.receiver_id = auth.uid())
  )
);
```

No UPDATE policy is needed — chat media paths are unique per message and
upload with `upsert: false`, unlike the deterministic per-user paths that
caused the `nic-documents` bug.

If `'video'` is missing from the `messages.content_type` check constraint,
add it (and keep `'system'`, which the trigger above depends on).

---

## Rollout order

1. Run SQL 1–4. The app tolerates their absence (`refreshMyMatches` failures
   are swallowed), but nothing works until they exist.
2. Verify with the test queries below **before** shipping the app build.
3. Ship the app build.
4. SQL 5 whenever chat media is being enabled — the Dart gate is already
   live and fails closed, so shipping ahead of it is safe.

---

## Test plan

Two accounts per tier. Clear blockers first — `generate_daily_matches`
no-ops while an unexpired batch exists, and any non-`ended` connection
removes both parties from the pool:

```sql
delete from public.daily_matches where user_id in ('<a>', '<b>');
delete from public.connections
 where initiator_id in ('<a>', '<b>') or receiver_id in ('<a>', '<b>');
```

- Two unverified accounts see each other; both cards show the grey chip and
  the pool banner.
- Verify one. Their batch regenerates against the verified pool; they
  disappear from the other's cards; the live connection survives; the system
  notice appears centred in the thread for both.
- Media stays locked until both are verified, with the right dialog copy in
  each of the three blocked states.
- A rejected submission shows its reason and allows resubmission.
- Delete account → re-onboard yields a clean unverified profile with a fresh
  batch.
- Sanity-check the hard gates directly:
  `select public.score_compatibility('<a>', '<b>'), public.score_compatibility('<b>', '<a>');`
  `0` means the mutual gender/seeking or mutual age-range gate rejected them,
  not that generation is broken.

---

## Designed but deliberately not built

**Bounded unverified window.** Unverified users would keep matching for 7
days or one connection, then need `selfie_verified` to continue. Two
reasons it matters: it caps how long a self-declared age goes unchecked, and
it flushes non-verifiers out of the entry pool — otherwise the unverified
pool fills over time with people who refused to verify, which is what every
new user then meets first.

Shape if it gets built: `users.unverified_since timestamptz`, a check in
`generate_daily_matches`, a pause while a `verification_submissions` row is
`pending` (manual review latency must not burn the user's window), plus
countdown and expired-state UI.

**Push notification on tier change.** The in-thread system notice is the
durable record and needs no infrastructure. A push on top requires FCM,
`device_tokens`, and a `send-push` edge function.

---

## Known gaps

- **Client media gating is not enforcement.** Until SQL 5 lands, a modified
  client can still upload. The Dart change is UX.
- **A client can still insert a `content_type = 'image'` message row with a
  bogus `media_url`** even with the storage policy in place. Low harm (it
  renders as a broken image), but it exists.
- **Existing conversations lose media access** the moment SQL 5 lands if
  either participant is unverified. The dialog explains it; no in-app
  announcement is sent.
- **`_SystemNotice` shows for both participants including the one who
  verified.** Intentional — the copy is subject-neutral so it reads
  correctly either way.
- **The 24h reciprocity lag.** A newly onboarded user sees 5 cards
  immediately, but existing users' batches are already generated and no-op
  for up to 24h, so nobody sees the newcomer for up to a day. Mitigation
  (not built): delete a user's unexpired rows once they've actioned every
  card, so the next refresh regenerates against the current pool.
- **Undeployed items elsewhere** — per `CLAUDE.md`, still unconfirmed: the
  `connections` restrictive UPDATE policy, storage UPDATE policies for
  `profile-photos`/`audio-intros`, the check-in escalation cron,
  `submit-verification`'s tier-order fix, and `cleanup-verification-media`
  (deploy + `CRON_SECRET` + schedule). The last one matters most — it's the
  only thing that deletes NIC images after review.
