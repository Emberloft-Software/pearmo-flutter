# Pearmo — backend notes

Flutter dating app on Supabase (auth, Postgres + RLS, storage, edge functions,
realtime). **The schema, RLS policies, and edge function source are NOT in
this repo** — they live only in the Supabase dashboard for project
`akodhmnaykaifzxxvher`. Everything below was reverse-engineered from runtime
errors during manual testing, not read from source. Update this file whenever
a new table/policy/enum/edge-function behavior is discovered.

## How to investigate this backend (do this before guessing)

Schema and RLS policies are invisible from this repo, but both are directly
queryable from the Supabase SQL Editor — use these instead of inferring
behavior from trial-and-error `42501`/`23503`/`23505` errors:

```sql
-- exact column types for a table (catches enum vs text[] mismatches before writing inserts)
select column_name, data_type, udt_name
from information_schema.columns
where table_schema = 'public' and table_name = '<table>'
order by ordinal_position;

-- exact RLS policy logic for a table (catches missing policies, wrong assumptions about what's checked)
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = '<table>';
```

Edge function source still isn't visible this way (not in `pg_catalog`), so
their behavior is still inferred from runtime effects only.

## Auth & account chain

`auth.users` (Supabase Auth, phone OTP via `signInWithOtp`/`verifyOTP`)
  → `public.users.id` (FK to `auth.users.id` — confirmed via `users_id_fkey`
    violation when inserting a `users` row with a UUID that has no matching
    `auth.users` row)
  → `public.profiles.user_id` (FK to `public.users.id`, also UNIQUE —
    constraint `profiles_user_id_key`)

So a `profiles` row can only exist for a UUID that already has both an
`auth.users` row and a `public.users` row. To create fake/test accounts for
seeding, you must first create a real `auth.users` row (Dashboard →
Authentication → Users → Add user, with "Auto Confirm User" on; email-only
works fine, no phone needed) — there is no way to fake this with plain SQL
inserts into `public.users`.

`AuthRepository.ensureUserRow()` ([lib/data/repositories/auth_repository.dart](lib/data/repositories/auth_repository.dart))
creates the `public.users` row idempotently using
`upsert(..., ignoreDuplicates: true)` (→ `INSERT ... ON CONFLICT DO NOTHING`).
**Correction (confirmed via `pg_policies` 2026-06-22):** the original `42501`
here was simply a *missing* `INSERT` policy on `users` (fixed by adding
`Users can insert their own row`, `with check (auth.uid() = id)`) — `users`
already had `users_update_own` (`UPDATE`, `auth.uid() = id`) and
`users_select_own` (`SELECT`) the whole time, so the earlier theory about a
missing `UPDATE` policy was wrong. `ignoreDuplicates: true` is still the
right call (avoids an unnecessary write on every login), just not for the
reason originally written here. `users` currently also has a redundant
second `SELECT` policy (`Users can read their own row`, identical
condition to `users_select_own`) from when we were debugging — harmless
(permissive policies OR together) but worth dropping for tidiness:
`drop policy "Users can read their own row" on public.users;`

`OnboardingController.submit()` ([lib/features/onboarding/providers/onboarding_controller.dart](lib/features/onboarding/providers/onboarding_controller.dart))
calls `ensureUserRow()` right before saving the profile — needed because the
router can send an already-authenticated user (restored session) straight to
`/onboarding` without ever passing through `OtpScreen` (the only other place
that calls `ensureUserRow()`).

`ProfileRepository.saveOnboarding()` upserts on `user_id` (not a plain
insert) — onboarding can be resubmitted if a later step (audio upload,
`analyse-profile` call) fails after the profile insert already succeeded,
and a plain insert would then hit `profiles_user_id_key`.

## `public.profiles` columns (confirmed via `information_schema.columns`)

| column | type |
|---|---|
| id | uuid |
| user_id | uuid (unique, FK → users.id) |
| display_name | text |
| date_of_birth | date |
| gender | **enum** `gender_option` |
| seeking | **enum array** `_gender_option` |
| relationship_intent | **enum** `relationship_intent` |
| life_stage | **enum** `life_stage` |
| energy_type | **enum** `energy_type` |
| conflict_style | **enum** `conflict_style` |
| lifestyle_pace | **enum** `lifestyle_pace` |
| partner_values | plain `_text` (check-constrained, not a real enum) |
| music_genres | plain `_text` (check-constrained, not a real enum) |
| about_text, avatar_id, audio_intro_url, profile_photo_url | text |
| avatar_config | jsonb |
| is_photo_public, is_profile_active, hide_from_contacts, onboarding_complete | boolean |
| active_hours_start, active_hours_end | time without time zone |
| country_code, region_name | text |
| lat_bucket, lng_bucket | numeric |
| created_at, updated_at | timestamptz |

**Gotcha:** `gender`/`relationship_intent`/etc. are real Postgres ENUM types,
but only `gender_option` is shared across two columns (`gender` + `seeking`),
so it's the only one with an array variant (`_gender_option`). When
hand-writing SQL inserts, a scalar literal like `'woman'` implicitly casts
fine, but `ARRAY['man']` resolves to `text[]` by default and needs an
explicit cast: `array['man']::gender_option[]`. `partner_values`/
`music_genres` are plain `text[]`, no cast needed.

Dart enum `dbValue`s in [lib/core/constants/enums.dart](lib/core/constants/enums.dart)
match the Postgres value strings exactly (snake_case).

## Full schema confirmed (via `information_schema` + `pg_policies` + `pg_constraint`, 2026-06-22)

Ran the schema/FK/policy introspection queries from the section above across
*every* `public` table in one pass — see git history of this file for the
raw JSON if needed. Replaces all the "inferred from repo code" guessing
below with ground truth. Full table list: `users`, `profiles`, `avatars`,
`prompts`, `reports`, `messages`, `payments`, `connections`, `boost_credits`,
`daily_matches`, `date_checkins`, `message_counts`, `consent_records`,
`profile_vectors`, `connection_ratings`, `ice_breaker_sessions`,
`verification_submissions` (+ the `active_consents`/`public_profiles` views,
and PostGIS system tables we can ignore).

**FK relationships** (`table.column → references_table.id`), all pointing at
`users.id` unless noted: `profiles.user_id`, `connections.initiator_id`,
`connections.receiver_id`, `connections.ended_by`, `daily_matches.user_id`,
`daily_matches.candidate_id`, `payments.user_id`, `reports.reporter_id`,
`reports.reported_id`, `messages.sender_id`, `message_counts.sender_id`,
`connection_ratings.rater_id`, `connection_ratings.rated_id`,
`verification_submissions.user_id`, `profile_vectors.user_id`,
`boost_credits.user_id`, `date_checkins.user_id`,
`consent_records.requested_by`, `consent_records.revoked_by`. Pointing at
`connections.id` instead: `messages.connection_id`,
`message_counts.connection_id`, `ice_breaker_sessions.connection_id`,
`date_checkins.connection_id`, `reports.connection_id`,
`consent_records.connection_id`, `connection_ratings.connection_id`. So
**every feature table hangs off either `users` or `connections`** — there's
no deeper FK chain than that.

**`users` (full columns):** `id`, `phone`, `created_at`, `last_active_at`,
`is_active` (default `true`), `is_banned` (default `false`), `ban_reason`,
`verification_tier` (default `'unverified'`), `subscription_plan` (enum
`subscription_plan`: `free`/`premium`, default `'free'` — **not modeled in
Dart at all yet, and payments/subscriptions are intentionally not
implemented in the app yet — leave this alone for now**),
`subscription_expires_at`, `trust_score` (numeric, default `5.00`),
`daily_match_count` (default `5`), `report_count` (default `0`),
`is_shadow_suppressed` (default `false`). `AppUser` (Dart model) only maps
`id`/`phone`/`verification_tier` — the rest aren't surfaced in the app yet.

**`connections` (full columns):** `id`, `initiator_id`, `receiver_id`,
`status` (enum `connection_status`), `initiated_at`, `accepted_at`,
`ended_at`, `ended_by`, `end_reason`, `ice_breaker_score`. `Connection`
(Dart model) doesn't map `accepted_at`/`ice_breaker_score` yet.

**Bug found + fixed 2026-06-22:** the real `connection_status` enum is
`pending → accepted → ice_breaking → limited_chat → open_chat →
media_unlocked → date_planned`, or `ended` — there's an `accepted` value
between `pending` and `ice_breaking` that the Dart `ConnectionStatus` enum
([lib/core/constants/enums.dart](lib/core/constants/enums.dart)) didn't
know about. `ConnectionStatus.fromDb()`'s `orElse` silently mapped any
unrecognized value (i.e. `'accepted'`) back to `pending`, so an accepted-
but-not-yet-icebreaking connection displayed "Waiting for response" instead
of being recognized as accepted, and the "Play a game" button in
[chat_screen.dart](lib/features/chat/screens/chat_screen.dart) only
appeared once status reached `ice_breaking`, not as soon as it was
`accepted` — even though the `ice_breaker_sessions` RLS policies don't
actually restrict by status at all (any participant of any connection can
create/update a session regardless of status), so there was no backend
reason to hide that button during `accepted`. Fixed by adding `accepted` to
the enum (`dbValue`/`label`) and updating `chat_screen.dart`'s game-button
condition to include it. `Connection.isActive` ([connection.dart](lib/data/models/connection.dart))
was unaffected in practice (not currently used anywhere), but would have
had the same mismapping bug — worth double-checking if it's ever wired up.

**`connections` RLS:** `INSERT` only by `initiator_id = auth.uid()`;
`SELECT`/`UPDATE` by either participant. The `UPDATE` policy has no
`WITH CHECK` beyond the participant check — i.e. **either participant can
write any column, including `status`, to any value** via the client RLS
layer (not just through `respond-to-connection`/edge functions). Not
necessarily a bug (might be intentional, with the edge functions just being
the *app's* sanctioned path), but worth knowing if status integrity ever
becomes a concern.

**`daily_matches` (full columns):** `id`, `user_id`, `candidate_id`,
`score`, `score_breakdown` (jsonb), `generated_at`, `expires_at`,
`was_shown`, `user_action`. RLS: `SELECT`/`UPDATE` own (`user_id =
auth.uid()`) only — no client `INSERT`/`DELETE` policy, consistent with
rows only ever being created by `generate_daily_matches()` (a
`SECURITY DEFINER` function, bypasses RLS).
- `ice_breaker_sessions`: `id`, `connection_id`, `game_type`, `state` (flexible jsonb).
  **Bug found 2026-06-22:** confirmed via `pg_policies` that this table had only ONE RLS policy total — `icb_select_participant` (`SELECT`, checks `connection_id` belongs to a connection where `auth.uid()` is `initiator_id`/`receiver_id`). No `INSERT` or `UPDATE` policy existed, so `GamesRepository.createSession()`/`updateState()` ([lib/data/repositories/games_repository.dart](lib/data/repositories/games_repository.dart)) were unusable for *any* user, not just test accounts — `42501` on every insert. Fixed by adding `icb_insert_participant` / `icb_update_participant` policies mirroring the same participant check (no extra status/consent restriction, consistent with the existing SELECT policy). If ice-breaker games still don't unlock as expected after this, check `pg_policies` again rather than assuming — don't trust this section's "fixed" status without re-confirming, since RLS for this app has repeatedly had gaps the app code assumes are filled.
- `consent_records` (confirmed via `information_schema`): **one row per `(connection_id, consent_type)`**, not one row per user. Columns: `id`, `connection_id`, `consent_type` (enum `consent_type`), `requested_by`, `requested_at`, `user_a_consented` (bool), `user_b_consented` (bool), `user_a_consented_at`, `user_b_consented_at`, `is_active` (bool), `revoked_by`, `revoked_at`. **No column says which participant is "a" vs "b"** — that mapping isn't derivable from the schema alone (probably `initiator_id`/`receiver_id` order, or `least(uuid)`, decided inside the `update-consent` edge function). When faking this via SQL, just set both `user_a_consented`/`user_b_consented` true to sidestep the ambiguity.
- `active_consents`: read-only view, true (`is_granted`) only once **both** participants have granted a given `ConsentType` — presumably reads off `consent_records.is_active` plus both `_consented` flags.

**Remaining tables (confirmed columns + RLS, not yet exercised by app testing):**
- `messages`: `id`, `connection_id`, `sender_id`, `content`, `content_type` (default `'text'`, **check-constrained to `text`/`image`/`audio`/`system`**), `media_url`, `sent_at`, `is_flagged`, `flag_reason`, `harassment_score`, `is_deleted`. RLS `INSERT` requires `sender_id = auth.uid()` **and** the connection's `status` to be one of `limited_chat`/`open_chat`/`media_unlocked`/`date_planned` — matches `ConnectionStatus.canChat` in Dart exactly. RLS `SELECT` is looser: visible once status is anything except `pending`/`ended` (so `accepted`/`ice_breaking` can view — presumably empty — message history before they can send). No `UPDATE`/`DELETE` policy — messages are immutable from the client.
- `message_counts`: `connection_id`, `sender_id`, `count` — composite PK, no RLS policies at all. Backs the "5-message cap" mentioned in [error_mapper.dart](lib/core/utils/error_mapper.dart) comments; presumably only written by a trigger, never queried directly by the client.
- `reports`: `id`, `reporter_id`, `reported_id`, `connection_id`, `category` (enum `report_category`), `description`, `evidence_urls` (`_text`), `submitted_at`, `status` (plain text, default `'open'`, **check-constrained to `open`/`reviewing`/`resolved`/`dismissed`**), `resolved_at`, `resolved_by`, `action_taken`. RLS: `INSERT`/`SELECT` own (`reporter_id = auth.uid()`) only — no `UPDATE`, so a submitted report can't be edited/withdrawn by the reporter (moderation-only).
- `connection_ratings`: `id`, `connection_id`, `rater_id`, `rated_id`, `respectfulness`, `communication`, `ghosting_behaviour`, `overall` (all int4, **each check-constrained 1–5**), `created_at`. RLS `SELECT`/`INSERT` checks `rater_id = auth.uid()` only — **you can't query ratings made about you (`rated_id`)**, only ones you made. `update_trust_score()` (SECURITY DEFINER) is the only thing that aggregates the `rated_id` side.
- `verification_submissions` (full columns confirmed 2026-06-24 via a full schema dump, correcting the earlier "cut off" note): `id`, `user_id` (FK → `users.id`), `submitted_at`, `reviewed_at`, `reviewed_by`, `status` (default `'pending'`, check-constrained to `pending`/`approved`/`rejected`), `rejection_reason`, `nic_front_path` (nullable — see tiered-verification section below), `nic_back_path`, `selfie_path` (nullable, same reason), `liveness_clip_path` (unused — see below), `face_match_score` (unused), `nic_data_extracted` (jsonb, unused), `nic_number_hash` (unused), `tier` (`'selfie'`/`'id'`, added 2026-06-24), `liveliness_passed` (added 2026-06-24). RLS: `INSERT`/`SELECT` own only (`verif_insert_own`/`verif_select_own`, both `auth.uid() = user_id`) — **no `UPDATE` policy**, confirming `status`/`reviewed_at`/`reviewed_by` are only ever written by the Next.js reviewer via its service-role key, never by the client.
- `profile_vectors`: `user_id`, `onboarding_vector`, `sentiment_vector`, `combined_vector` (all pgvector `vector` type), `last_computed_at`. RLS: **`SELECT` only** — no `INSERT`/`UPDATE` policy for any role, confirming these are written exclusively by a `SECURITY DEFINER` function or the `analyse-profile` edge function via service role, never directly by the client.
- `avatars`, `prompts`: static reference data (`avatars`: `id`, `name`, `svg_url`, `is_active`, `sort_order`; `prompts`: `id`, `text`, `category`, `is_active`). Neither has any RLS policy in our dump and neither is queried by the app (avatars are generated client-side in [avatar_catalog.dart](lib/shared/avatars/avatar_catalog.dart); `prompts` isn't referenced in `lib/` at all yet — possibly an unused/future feature table).
- `boost_credits`: `user_id`, `credits`, `last_updated_at`. RLS: `SELECT` own only, no `INSERT`/`UPDATE` — credits are server-managed (ties into payments, see below).
- `date_checkins`: `id`, `user_id`, `connection_id`, `scheduled_for`, `check_in_interval` (default `30 min`), `emergency_contact`, `last_checked_in_at`, `status` (default `'active'`, **check-constrained to `active`/`checked_in`/`escalated`/`cancelled`**), `escalated_at`, `created_at`. RLS: single `ALL` policy, owner-only (`auth.uid() = user_id`).
- **`payments`** (`id`, `user_id`, `provider` (**check-constrained to `payhere`/`stripe`**), `provider_payment_id`, `amount_lkr`, `amount_usd`, `currency`, `plan` (enum `subscription_plan`), `status` default `'pending'` (**check-constrained to `pending`/`completed`/`failed`/`refunded`**), `created_at`, `completed_at`, `webhook_payload`): RLS is `SELECT` own only, no client `INSERT`/`UPDATE` — by design, since this is meant to be written server-side by the (not-yet-built) `create-payhere-order` flow. **Payments/subscriptions are intentionally out of scope for now — don't build against this table yet.**
- `daily_matches.user_action` (not previously documented): check-constrained to `request_sent`/`passed`, or `null`.

## Edge functions (source not visible from this repo — behavior inferred only)

Names from [lib/core/config/supabase_config.dart](lib/core/config/supabase_config.dart):
`analyse-profile`, `send-connection-request`, `respond-to-connection`,
`update-consent`, `submit-verification`, `date-checkin`, (planned, not yet
built) `create-payhere-order`.

**Important:** these functions almost certainly do more than the single
column update their name suggests. E.g. `respond-to-connection` likely does
more than set `connections.status = 'ice_breaking'` — manually flipping that
column via SQL was *not* sufficient to let an `ice_breaker_sessions` insert
through RLS (got `42501`), implying acceptance also requires something else
(probably a `chat_unlock` consent record from both sides via
`active_consents`). When faking backend state via raw SQL for testing,
expect to hit RLS walls like this one layer at a time, since we can't read
the actual function source.

## Matching algorithm (confirmed via `pg_proc` — not a guess)

This is NOT an edge function — it's plain Postgres functions, fully visible
via `select pg_get_functiondef(oid) from pg_proc where proname = '<name>'`.
`MatchesRepository` just reads whatever's already in `daily_matches`; it has
no scoring logic of its own. Any `daily_matches` rows inserted by hand (like
our test seed data) bypass all of this and show up regardless of actual
compatibility.

**`public.score_compatibility(user_a uuid, user_b uuid) returns numeric`**
Hard gate first: returns `0` if `pa.gender` isn't in `pb.seeking` AND
vice versa (mutual gender/seeking compatibility required). Otherwise:

```
final_score =
    cosine_score   * 0.40   -- 1 - (va <=> vb) on profile_vectors.combined_vector (pgvector, dim 12); 0.5 if either side has no vector yet
  + intent_match    * 0.25  -- 1.0 same relationship_intent; 0.2 if either is 'serious' and they don't match; else 0.7
  + music_score     * 0.15  -- Jaccard similarity (intersection/union) of music_genres
  + location_score  * 0.10  -- 1.0 same country_code+region_name; 0.5 same country_code only; 0.1 otherwise
  + trust_mult      * 0.10  -- candidate's (user_b's) users.trust_score / 10
```
rounded to 4 decimals. Note `lat_bucket`/`lng_bucket` on `profiles` are
**not** used here — location scoring is exact-string country/region match,
not geographic distance, despite those columns existing (possibly a planned
but unwired feature).

`profile_vectors.combined_vector` is a separate table we haven't introspected
— likely populated by the `analyse-profile` edge function after onboarding
(the "sentiment pass" `ProfileRepository.runSentimentAnalysis()` triggers).
Hand-seeded fake profiles have no `profile_vectors` row, so they'd get a
neutral `cosine_score` of `0.5` if real matching ran on them — they never do,
since we wrote `daily_matches` rows directly instead.



**`public.generate_daily_matches(for_user_id uuid) returns void`**
Populates `daily_matches` for one user. Deletes their expired rows first,
then **no-ops entirely if unexpired matches already exist** — so re-running
it does nothing until the existing batch expires (24h after generation,
matching `expires_at`) or you manually delete the unexpired rows first.
Candidate pool filters: `is_active`, not banned, not `is_shadow_suppressed`,
profile `is_profile_active` + `onboarding_complete`, verification-tier
visibility (`unverified` only sees `unverified`; `id_verified` sees
`id_verified`+`paid_verified`; `paid_verified` sees everyone), excludes
anyone already in a non-`ended` connection, and respects the candidate's
`active_hours_start/end` window. Calls `score_compatibility` per candidate
(capped at 100 candidates), inserts if score `> 0`. `score_breakdown` is
currently just `{"composite": score}` — despite the column name, it does
**not** store the per-component breakdown.

**`public.update_trust_score(target_user_id uuid) returns void`**
`trust_score` lives on `public.users` (0–10 scale), not `profiles`. Computed
as `(avg of last 20 connection_ratings' (respectfulness+communication+
ghosting_behaviour+overall)/4, scaled to /5.0*8.0) - report_penalty`, where
`report_penalty = least(report_count * 0.5, 4.0)`. New accounts with no
ratings fall back to `5.0 - report_penalty` (so `5.0` for a clean new
account — this is a reputation default, not related to compatibility
scoring). Also sets `users.is_shadow_suppressed = true` if the new score
drops below `2.5`, which then excludes them from `generate_daily_matches`'s
candidate pool entirely.

Both `score_compatibility` and `generate_daily_matches` can be called
directly from the SQL editor for debugging:
```sql
select public.score_compatibility('<user_a>', '<user_b>');
select public.generate_daily_matches('<user_id>'); -- no-ops if unexpired matches already exist
```

## Tiered verification (2026-06-24)

Verification was split into two independently-submittable tiers instead of
one flat NIC+selfie form, and the manual review side moved to a separate
Next.js admin app that reads/writes this same Supabase project directly
(service-role key on that side, no new API surface needed in this repo):

1. **`selfie_verified`** (new enum value, inserted between `unverified` and
   `id_verified`) — an on-device liveliness gesture check (center face →
   blink → turn head, via `google_mlkit_face_detection` + `camera` in
   [liveness_check_screen.dart](lib/features/verification/widgets/liveness_check_screen.dart))
   followed by a selfie, manually reviewed. Confirms the user is a real
   person. This is a client-side gate only — final acceptance is still
   manual review on the Next.js side, same as before.
2. **`id_verified`** (existing enum value, **repurposed**: previously meant
   "passed the old single-step NIC+selfie review", now means "also submitted
   a NIC on top of `selfie_verified`, manually compared against the
   profile's displayed age"). Only reachable after `selfie_verified`.

**Migration confirmed applied to the live database (2026-06-24)** — run by
hand in the SQL Editor (no DB execution access from this coding session, so
schema/enum/RLS dumps were pulled by the user and the exact statements below
were handed back rather than guessed):

```sql
-- enum: selfie_verified inserted between unverified and id_verified
alter type verification_tier add value if not exists 'selfie_verified' after 'unverified';

-- verification_submissions: the old single-step flow had nic_front_path AND
-- selfie_path NOT NULL (every row needed both). Relaxed since a tier-1 row
-- has no NIC and a tier-2 row has no fresh selfie.
alter table public.verification_submissions
  alter column nic_front_path drop not null,
  alter column selfie_path drop not null;

alter table public.verification_submissions
  add column if not exists tier text not null default 'selfie',
  add column if not exists liveliness_passed boolean not null default false;

alter table public.verification_submissions
  add constraint verification_submissions_tier_check check (tier in ('selfie', 'id')),
  add constraint verification_submissions_tier_fields_check check (
    (tier = 'selfie' and selfie_path is not null)
    or
    (tier = 'id' and nic_front_path is not null)
  );
```

(`status` and `rejection_reason` already existed pre-migration — CLAUDE.md's
older "cut off" note about this table undersold what was actually there; see
the corrected full column list below.)

One pre-existing row (the old combined NIC+selfie submission for the
`c1bf1153-7a87-4be0-ac43-ea99eb5672b7` test account, already `approved`) got
backfilled to `tier = 'id'` rather than nulling out its `selfie_path` —
hence the constraint checks "the right path is present" per tier rather than
"the other path is absent", so legacy combined rows stay valid.

`generate_daily_matches()` has been replaced with `selfie_verified` slotted
into the visibility pyramid: `unverified` sees `unverified` only;
`selfie_verified` and `id_verified` both see
`selfie_verified`+`id_verified`+`paid_verified`; `paid_verified` sees
everyone (unchanged). Confirmed via
`pg_get_functiondef`/`pg_proc` after the replace — everything else in that
function (candidate filters, `score_compatibility` call, the
24h-expiry/no-op-if-unexpired guard) is untouched.

**Still outside this repo, not yet done:** `submit-verification`'s edge
function source needs updating to accept `{tier, selfie_path,
liveliness_passed}` or `{tier, nic_front_path, nic_back_path}` and write
these columns; on approval the Next.js reviewer should set
`users.verification_tier` to `'selfie_verified'` or `'id_verified'`
accordingly.

**Confirmed unused, left alone:** `liveness_clip_path`, `face_match_score`,
`nic_data_extracted`, `nic_number_hash` already existed on
`verification_submissions` before this change — clearly earmarked by
whoever designed the table for a richer pipeline (a recorded liveness video
+ automated face-match/OCR) than what's built today (live on-device
ML-Kit-gated gesture check + a single still selfie, judged manually). Left
null/unpopulated; revisit if that automation ever gets built.

**Two bugs found and fixed while wiring this up:**
- `StorageRepository.uploadProfilePhoto` / `ProfileRepository.updateProfilePhotoPath`
  existed but were never called from anywhere — Settings only ever had a
  toggle for `profiles.is_photo_public`, with no UI that could ever set
  `profile_photo_url` in the first place. Settings' "Add picture" action
  (gated behind `selfie_verified` via `VerifyToUnlockDialog`) now actually
  calls both.
- `profile.profilePhotoUrl` (a path in the private `profile-photos` bucket)
  was being passed straight into `AvatarDisplay`'s `photoUrl` in both
  [my_profile_screen.dart](lib/features/profile/screens/my_profile_screen.dart)
  and [candidate_detail_screen.dart](lib/features/matches/screens/candidate_detail_screen.dart)
  instead of being resolved through the existing (already correctly used
  for audio intros) `signedProfilePhotoUrlProvider` — so it would never have
  rendered even once a photo existed. Fixed via a new
  [signed_avatar_display.dart](lib/shared/widgets/signed_avatar_display.dart)
  wrapper used in both places.

## Fake test accounts seeded for matching/connections UI testing

Created via Dashboard → Authentication → Add user (email + "Auto Confirm"),
then seeded `public.users` + `public.profiles` + `public.daily_matches` rows
by hand. Real test account used as the "viewer": `c1bf1153-7a87-4be0-ac43-ea99eb5672b7`.

| id | role |
|---|---|
| da1dc596-b2a7-49d4-9103-3c2622c5370f | fake woman seeking men |
| 03db2c19-08ae-4c45-92f5-decd3a27b8f4 | fake man seeking women |
| c52d0a19-e344-4a16-9d17-bae58e467d43 | fake woman seeking everyone |
| 7820db01-626b-42e6-88e3-6d676006f27c | fake non-binary seeking everyone |
| ec50f6b3-f432-4da0-822f-460c327607f1 | fake man seeking men |

Cleanup when done testing:
```sql
delete from public.daily_matches where candidate_id in (
  'da1dc596-b2a7-49d4-9103-3c2622c5370f','03db2c19-08ae-4c45-92f5-decd3a27b8f4',
  'c52d0a19-e344-4a16-9d17-bae58e467d43','7820db01-626b-42e6-88e3-6d676006f27c',
  'ec50f6b3-f432-4da0-822f-460c327607f1');
delete from public.profiles where user_id in (...same five ids...);
delete from public.users where id in (...same five ids...);
-- then delete the 5 auth users from the Dashboard too.
```

