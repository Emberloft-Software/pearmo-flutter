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

**Update 2026-07-01:** `submit-verification`'s edge function source has now
been updated (outside this repo, in the Supabase dashboard) to accept
`{tier, selfie_path, liveliness_passed}` or `{tier, nic_front_path,
nic_back_path}` and write only the columns relevant to that tier. On
approval the Next.js reviewer still needs to set `users.verification_tier`
to `'selfie_verified'` or `'id_verified'` accordingly (unchanged, still
outside this repo).

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

**Bug found + fixed 2026-07-01 (storage RLS, not `public` schema this
time):** submitting an ID (`tier: 'id'`) verification failed with a `42501`
on `storage.objects` — `new row violates row-level security policy (USING
expression)`, on an `INSERT ... ON CONFLICT (name, bucket_id) DO UPDATE`
query. Root cause: `StorageRepository._upload()`
([storage_repository.dart:35-42](lib/data/repositories/storage_repository.dart#L35-L42))
always uploads with `FileOptions(upsert: true)`, and NIC/selfie/profile-photo
paths are all deterministic (`$userId/nic_front.jpg` etc.) — so any *second*
upload to the same path (retaking a photo, resubmitting after rejection)
becomes an UPDATE on `storage.objects`, which is checked against the
`USING` clause of an UPDATE policy. Confirmed via `pg_policies` (schemaname
`storage`, tablename `objects`) that the `nic-documents` bucket only had
`SELECT` (`users read own files r4fnlf_0`) and `INSERT`
(`users upload own files r4fnlf_0`) policies — no `UPDATE`. Fixed by adding
a matching `UPDATE` policy (`users update own files r4fnlf_0`) with the
same `bucket_id = 'nic-documents' and auth.uid()::text =
(storage.foldername(name))[1]` condition on both `using` and `with check`.
**Not yet checked:** `profile-photos` and `audio-intros` likely have the
same gap, since `uploadProfilePhoto`/`uploadAudioIntro` use the same
`_upload()` helper with `upsert: true` — re-query `pg_policies` for those
bucket ids before assuming a second upload to either will work.
**Update 2026-07-01:** handed the user matching `create policy ... for
update` statements for both buckets (mirroring the `nic-documents` fix) to
run after confirming via `pg_policies` — not yet confirmed applied.

## App-flow audit and fixes (2026-07-01)

Did a full sweep of every feature flow (auth/router/onboarding,
verification, matches/connections/consent, chat/icebreakers,
safety/reports/ratings/checkins, payments) via parallel deep-read agents,
each cross-checking client code against this file's documented RLS ground
truth rather than re-deriving it. Fixed everything fixable from this repo;
three items need action in the Supabase dashboard directly (SQL/edge
function source aren't in this repo).

**Fixed in this repo:**
- **`connections.status` was writable to any value by either participant**
  — `ConnectionsRepository.endConnection()`
  ([connections_repository.dart:74-85](lib/data/repositories/connections_repository.dart#L74-L85))
  does a direct `.update()`, proving the pattern works, and since the
  `UPDATE` RLS policy has no `WITH CHECK` on the value (documented above),
  the same pattern could set `status` to `open_chat`/`media_unlocked`/etc.
  directly, skipping `respond-to-connection`'s consent/business logic
  entirely. **Not a Dart fix** — needs the restrictive RLS policy below,
  run by the user.
- **Banned/deactivated accounts (`users.is_banned`/`is_active`) were never
  checked anywhere client-side** — a still-valid Supabase Auth session had
  no gate at all. Added `isBlocked` to `AppUser`
  ([app_user.dart](lib/data/models/app_user.dart)), a `myAppUserProvider`
  ([auth_providers.dart](lib/providers/auth_providers.dart)), a new
  `/blocked` route + `BlockedScreen`
  ([blocked_screen.dart](lib/features/auth/screens/blocked_screen.dart)),
  and a router redirect check
  ([app_router.dart](lib/core/router/app_router.dart)) that routes blocked
  users there (only exit is signing out) before the onboarding/home checks
  run. `AuthRepository.getCurrentAppUser()` was dead code before this (zero
  call sites) — now used, and switched from `.single()` to `.maybeSingle()`
  since it can be queried in the window between session creation and
  `ensureUserRow()` completing.
- **Onboarding marked `onboarding_complete: true` before the audio
  upload/`analyse-profile` pass ran** — if either failed, the profile row
  was already "complete" in the DB but `myProfileProvider` was never
  invalidated (the throw happened first), so the router kept the user
  stuck on the onboarding screen with no way to distinguish "required
  onboarding failed" from "an optional follow-up step failed," and no way
  to add the audio intro later (no such option exists in Settings).
  `OnboardingController.submit()`
  ([onboarding_controller.dart](lib/features/onboarding/providers/onboarding_controller.dart))
  now treats the audio upload + sentiment pass as best-effort — a failure
  there returns a warning string instead of throwing, and the router still
  moves the user to `/home` since the required fields are genuinely saved.
- **Double-tap race on "Send Request"** —
  [candidate_detail_screen.dart](lib/features/matches/screens/candidate_detail_screen.dart)
  set `_isActing` only *after* an `await`, so two fast taps could both pass
  the `canSendRequestProvider` check and both invoke
  `send-connection-request`. Now set before the first await.
- **No re-submission guard on connection ratings** — a user could
  navigate to `/connection/:id/rate` repeatedly and insert multiple rows
  (no unique constraint confirmed on `(connection_id, rater_id)`), each one
  factored into `update_trust_score()`'s last-20-ratings average.
  `RatingsRepository.hasRated()`
  ([ratings_repository.dart](lib/data/repositories/ratings_repository.dart))
  checks for a prior rating (RLS already permits selecting your own), and
  [rating_screen.dart](lib/features/ratings/screens/rating_screen.dart)
  shows "You've already rated this connection" instead of the form when
  one exists. Client-side only — still worth adding a DB unique constraint
  on `(connection_id, rater_id)` if this needs a hard backstop.
- **No verification rejection/resubmission feedback** —
  `verification_submissions.status`/`rejection_reason` were never read
  anywhere client-side; a rejected user just saw a blank form with no
  explanation, and the "submitted" state was purely local widget state
  (reset on navigation), not backed by the actual row. Added
  `VerificationRepository.getLatestSubmission()` and wired both tier cards
  in [verification_screen.dart](lib/features/verification/screens/verification_screen.dart)
  to show the real `pending`/`rejected` state (with `rejection_reason`)
  instead of a transient local flag.
- **Ice-breaker game state had no defensive parsing of *inner* shape** —
  `IceBreakerSession.fromJson` already guards the outer `state` shape, but
  a malformed entry (e.g. a `qa` item missing `question`, or a stroke point
  that isn't `[num, num]`) would throw uncaught mid-render, since RLS
  allows any participant to write arbitrary jsonb here with no shape
  validation (documented above). Hardened
  `PromptsGame._qa` ([prompts_game.dart](lib/features/icebreakers/widgets/prompts_game.dart))
  to drop non-conforming entries, and
  `DrawTogetherGame._strokes`/`_DrawingPainter.paint()`
  ([draw_together_game.dart](lib/features/icebreakers/widgets/draw_together_game.dart))
  to skip malformed strokes per-stroke instead of crashing the whole
  canvas. `WouldYouRatherGame` already used safe casts throughout — no
  change needed there.
- **No `23514` (check-constraint violation) mapping** in
  [error_mapper.dart](lib/core/utils/error_mapper.dart) — latent gap, not
  currently reachable since rating UI clamps to 1-5, but now mapped to a
  friendly message instead of raw Postgres text.
- **OTP resend had no client-side cooldown** —
  [otp_screen.dart](lib/features/auth/screens/otp_screen.dart) now disables
  the resend button for 30s after each send (Supabase's own rate limit was
  always the real backstop; this is just UX).

**Needs action outside this repo (SQL Editor / edge function dashboard):**
- `connections.status` write-anything gap: add a restrictive UPDATE policy
  requiring `status = 'ended'` for any client-side write (service-role edge
  functions bypass RLS entirely, so `respond-to-connection` etc. are
  unaffected) — exact `create policy` handed to the user, not yet run.
- Same storage-RLS gap as `nic-documents` (missing `UPDATE` policy) likely
  also affects `profile-photos` and `audio-intros` — SQL handed to the
  user, not yet confirmed/run.
- `submit-verification`
  ([supabase/functions/submit-verification/index.ts](supabase/functions/submit-verification/index.ts))
  updated in-repo to (a) reject a `tier: 'id'` submission unless
  `users.verification_tier` is already past `unverified`, closing the gap
  where tier ordering was only enforced by hiding the UI card, and (b) scope
  the "one pending submission" check to the same tier instead of blocking
  across tiers. **CONFIRMED DEPLOYED 2026-08-02** — the live function source
  was read from Dashboard → Edge Functions → Code and contains both changes.
  This entry previously said it still needed deploying; that was stale.
  The only remaining repo-vs-live difference is the missing-`Authorization`-
  header guard (returns 401 instead of a 500 from a TypeError), which is
  robustness, not a security gap.
- **Date check-in escalation has no confirmed trigger anywhere — confirmed
  2026-07-01.** `select jobid, schedule, command, active from cron.job;`
  ran successfully (so `pg_cron` is installed) but returned **zero rows** —
  there is no scheduled job of any kind, let alone one that escalates
  overdue check-ins. A missed check-in currently does nothing at all: no
  status change, no alert to anyone. Handed the user a `cron.schedule(...)`
  job (runs every 5 minutes) that does the escalation directly in SQL
  rather than routing through the `date-checkin` edge function (which
  isn't built for being invoked on a schedule):
  ```sql
  select cron.schedule(
    'escalate-overdue-checkins',
    '*/5 * * * *',
    $$
    update public.date_checkins
    set status = 'escalated', escalated_at = now()
    where status = 'active'
      and now() > coalesce(last_checked_in_at, scheduled_for) + check_in_interval;
    $$
  );
  ```
  **This only flips `status`/`escalated_at` in the database — it does not
  contact the `emergency_contact` number or notify anyone.** That remains
  a real gap (see the excluded item below) but at least an overdue
  check-in becomes an observable, queryable state instead of silently
  never happening. **Not yet confirmed run by the user.**
- **Bug found + fixed 2026-07-01: `DateCheckin.fromJson` didn't match the
  real `date_checkins` schema at all, and would crash the moment any
  check-in row existed.** The model
  ([date_checkin.dart](lib/data/models/date_checkin.dart)) read
  `json['created_by']` and `json['acknowledged_at']`, and compared
  `status` against `'scheduled'`/`'acknowledged'`/`'missed'` — none of
  which exist in the real schema (`user_id`, no `acknowledged_at` column,
  status check-constrained to `active`/`checked_in`/`escalated`/
  `cancelled`, confirmed above). Casting the missing `created_by` key
  (`null as String`) threw immediately inside `fromJson`, so
  `CheckinRepository.getCheckins()` — and therefore the whole
  `CheckinPanel` — crashed to an error banner as soon as one check-in
  existed for a connection; before that, `canAct`/`needsAcknowledgement`
  compared against status values the DB never produces, so the
  Acknowledge/Cancel buttons could never have appeared regardless. Fixed
  the model's fields/status values to match reality, and updated
  [checkin_panel.dart](lib/features/safety/widgets/checkin_panel.dart)'s
  `_CheckinTile` icon/color logic to use `active`/`checked_in`/
  `cancelled`/`escalated` (added a distinct icon+color for `escalated`,
  which the old code had no branch for at all). This was missed by the
  first pass of this audit — the safety-flow review agent read the model
  but didn't cross-check its field names against this file's schema
  section the way other agents did for `ConnectionStatus`; found only
  while manually designing the escalation cron job above.
- **Not in scope this pass (explicitly excluded by the user):**
  `emergency_contact` on `date_checkins` is a free-text field with no
  format validation and no SMS/call integration anywhere in the app —
  likely misleading given the name, since nothing actually contacts that
  number automatically today.

## Personality questionnaire + matching algorithm rewrite (2026-07-09)

Replaced the 4 placeholder single-choice onboarding questions
(`life_stage`/`energy_type`/`conflict_style`/`lifestyle_pace` — always
labeled as placeholders in this file) with a real personality instrument
("PEARMO" doc, provided by the user) and rewired `score_compatibility` to
use it. Also added an age-range match preference alongside gender.

**Schema changes (migration run 2026-07-09):**
- Dropped `profiles.life_stage`/`energy_type`/`conflict_style`/
  `lifestyle_pace` (+ their enum types) — confirmed no other reads of these
  columns anywhere before dropping.
- Added `profiles.seeking_age_min`/`seeking_age_max` (int, default
  18/99, check `seeking_age_min >= 18 and seeking_age_max >= seeking_age_min`).
- Added 6 new numeric(3,2) columns, `profiles.trait_extraversion`/
  `trait_agreeableness`/`trait_conscientiousness`/`trait_emotional_stability`/
  `trait_openness`/`trait_attachment_security`, each check-constrained
  1-5, default 3.0 — the averaged Likert scores from onboarding. **Private
  matching data, never exposed via `public_profiles`** (same treatment as
  `profile_vectors`).
- `public_profiles` view recreated without `life_stage`/`energy_type`/
  `lifestyle_pace` (had to `drop view` + recreate rather than
  `create or replace`, since Postgres won't let `create or replace view`
  remove/reorder existing columns) — otherwise unchanged, still same
  banned/inactive/`is_profile_active`/`onboarding_complete` filters.

**Onboarding (client):** collects 12 Likert questions (2 per trait — 1
direct + 1 reverse-scored, cut down from the source doc's 30/5-per-trait
per the user's request to keep onboarding shorter; averaging still works
identically with fewer items, just lower precision) via
[personality_questions.dart](lib/features/onboarding/data/personality_questions.dart)
and a reusable [likert_scale.dart](lib/features/onboarding/widgets/likert_scale.dart)
widget. `OnboardingController.submit()` reverse-scores (`6 - answer`) then
averages each trait client-side before saving — the 6 `trait_*` columns
store final scores, not raw answers (raw Likert answers aren't persisted
anywhere). New age-range step uses a `RangeSlider` (18-70), defaulting to
`[ownAge-8, ownAge+10]` clamped to that range. Onboarding grew from 15 to
18 steps (-4 old placeholder steps, +1 age range, +6 trait screens).

**`score_compatibility` rewrite:** per explicit user decision, the
`profile_vectors`-based `cosine_score` term (weight 0.40) was **replaced**
with a new `trait_compat` term at the same weight — `intent_match`/
`music_score`/`location_score`/`trust_mult` are untouched, copied verbatim
from the pre-existing function source. `trait_compat` implements the
PDF's formula directly: per-trait compatibility = `1 - |diff|/4` (i.e.
`100 - diff/range*100` scaled to 0-1), weighted Agreeableness 25% /
Attachment Security 20% / Emotional Stability 20% / Conscientiousness 15% /
Openness 10% / Extraversion 10%. Also added a **mutual age-range hard
gate** (return 0 if either person's age falls outside the other's
`seeking_age_min`/`seeking_age_max`), right alongside the existing
gender/seeking hard gate, at the user's explicit request (age preference
excludes candidates entirely rather than just scoring them lower).

**Consequence: `profile_vectors`/`analyse-profile`'s sentiment pass is now
vestigial for matching.** Onboarding still calls
`ProfileRepository.runSentimentAnalysis()` (unchanged), and
`profile_vectors` still gets populated, but nothing in
`score_compatibility` reads it anymore. Not removed since the client call
wasn't in scope of this change and it may still be useful for something
else later — just worth knowing the vector it computes has no effect on
matches today.

**Fake test accounts (see below) now all share default trait scores
(3.0/3.0/...) and the default age range (18-99)** post-migration, since
`ADD COLUMN ... DEFAULT` backfills existing rows — they'll all score as
maximally trait-compatible with each other. Harmless for UI testing, just
not meaningful signal if testing the scoring math specifically.

**Avatar suggestion wired to real personality data (2026-07-10).** A
friend's UI redesign (separate from this backend work) replaced the old
generated-circle avatars with 20 anthro-animal characters
([avatar_catalog.dart](lib/shared/avatars/avatar_catalog.dart), each with a
male/female art variant) and added a "Suggested for you" vs "All
characters" toggle in the onboarding avatar step — but that toggle only
ever filtered by gender, the personality-flavored taglines (e.g. Fox:
"Clever · Flirtatious · Quick-witted", Owl: "Introspective · Observant ·
Quietly wise") weren't connected to anything. Added a hand-derived 6-trait
profile (1-5 scale, same scale as `profiles.trait_*`) to each character —
read off its existing tagline/description, not from any new source of
truth — and `AvatarCatalog.suggestCharacter()` picks whichever character's
profile is closest to the user's actual PEARMO answers (same
`1 - |diff|/4` per-trait similarity `score_compatibility` uses, just
comparing a person to a character instead of two people). Works because
the avatar step in onboarding comes *after* all 6 personality trait
screens, so `draft.personalityAnswers` is fully populated by the time
`AvatarPicker` needs it — `PersonalityQuestions.computeTraitScores()` was
pulled out of `OnboardingController` into a shared static method for this
reason (both the picker and final `submit()` needed the same computation).
`AvatarPicker` auto-selects the suggested character on first visit only if
the selection is still at the untouched default (never overrides a real
choice), and reorders the gender-filtered grid to put the suggestion
first — tapping any other character still overrides it freely either way,
same as the gender-only filtering already worked.

## Account deletion (2026-07-09)

Added a real "Delete account" flow (Settings → Danger zone), plus a
"Pause my profile" toggle — a deliberate two-tier design discussed with
the user before building:

- **Pause** (`profiles.is_profile_active`, already existed in the schema
  but was never surfaced in Settings until now) — fully reversible, hides
  the profile from `public_profiles`/matching, doesn't touch any data.
  Persists through the existing `ProfileRepository.updateSettings()` /
  "Save settings" flow like the other toggles.
- **Delete** — irreversible from the user's side, but implemented as a
  **soft delete/anonymize, not a cascading SQL delete**. Reasoning
  (discussed with the user first): a true cascading delete would let a
  reported/bad-actor user erase their `reports`/`connection_ratings`/
  `trust_score` moderation trail and re-register clean — this app's
  entire trust-score/report system depends on that history surviving.
  It's also close to an App Store hard requirement (guideline 5.1.1(v):
  apps with account creation must offer in-app account deletion, not just
  deactivation), so this needed building regardless.

**New edge function `delete-account`**
([supabase/functions/delete-account/index.ts](supabase/functions/delete-account/index.ts)) —
service-role, authenticated via bearer token like `submit-verification`.
On call:
- Lists and removes every storage object under `{userId}/` in all three
  buckets (`profile-photos`, `audio-intros`, `nic-documents`) — actual
  files, not just DB rows.
- Wipes `profiles`: `display_name` → `'Deleted user'`, `about_text` → `''`,
  `avatar_config`/`profile_photo_url`/`audio_intro_url`/`region_name` →
  `null`, `is_profile_active`/`is_photo_public` → `false`,
  `hide_from_contacts` → `true`, **`onboarding_complete` → `false`**.
  **Deliberately untouched:** `date_of_birth`/`gender`/`seeking`/
  `seeking_age_*`/`trait_*`/`relationship_intent`/`partner_values`/
  `music_genres`/`avatar_id`/`country_code` — none of these are
  individually identifying, and it doesn't matter what's left since
  `onboarding_complete = false` already hides the row from
  `public_profiles` (and gets overwritten by re-onboarding anyway — see
  below).
- Clears `verification_submissions.nic_front_path`/`nic_back_path`/
  `selfie_path` (the actual files, already removed from storage above) but
  **keeps `status`/`tier`/`rejection_reason`/`reviewed_at`/`reviewed_by`**
  — the review outcome is part of the moderation trail, not PII.
- Sets `users.last_deleted_at = now()` and increments
  `users.deletion_count` — **does not touch `is_active`, `phone`,
  `trust_score`, `report_count`, or `verification_tier`.**
- **`messages`/`connections`/`daily_matches`/`reports`/
  `connection_ratings`/`date_checkins`/`consent_records`/
  `ice_breaker_sessions` are completely untouched** — deleting a user's
  chat history would also delete the *other* participant's side of the
  conversation, which this design explicitly avoids. A deleted user's old
  messages remain visible to whoever they talked to (mainstream dating-app
  behavior — matches how Tinder/Bumble/Hinge handle this).

**Revised 2026-07-10 — same phone can re-onboard after deletion, by user
decision.** The first version of this feature also set `users.is_active =
false`, permanently blocking that phone number from ever signing in again
(enforced via the pre-existing ban/inactive router gate). The user decided
this was too strict: deleting your account should let you start fresh with
the same number, not lock you out forever — the anti-abuse goal (can't
launder a bad reputation by deleting and re-registering) is already fully
satisfied without a login block, since `trust_score`/`report_count`/
`reports`/`connection_ratings` all stay tied to the same `users.id`
regardless of whether the profile gets rebuilt. So:
- `users.deleted_at` was **renamed to `last_deleted_at`** (a repeatable
  historical timestamp, not a "currently deleted" flag) and a new
  `users.deletion_count int not null default 0` column tracks how many
  times this identity has gone through delete-and-recreate — a safety
  signal for future moderation tooling to look at, never acted on
  automatically today.
- `delete-account` no longer touches `is_active` at all. Instead it sets
  `profiles.onboarding_complete = false`, so signing back in with the same
  phone hits the router's ordinary onboarding-incomplete redirect and
  lands the user in a fresh onboarding flow — same `id`, same trust/report
  history, brand new profile data.
- `Profile.toInsertJson()` ([profile.dart](lib/data/models/profile.dart))
  now explicitly writes `is_profile_active: true` and
  `hide_from_contacts: false` on every onboarding submission (previously
  these two columns were entirely Settings-only, never touched by
  onboarding) — needed so a re-onboarded profile doesn't stay invisible
  from the earlier deletion's `is_profile_active = false` until the user
  manually flips it back on in Settings.
- `BlockedScreen`'s `isDeleted` branch was removed (reverted to
  ban-only copy) — with `is_active` no longer touched by deletion, that
  branch became unreachable in practice, and leaving it would have
  misled a future reader into thinking deletion still routes there.

**Bug found + fixed 2026-07-10: brand-new edge functions need an explicit
deploy step, not just committing the source.** After building this
feature, `delete-account` failed with "Requested function was not found"
the first time the user actually clicked the button — and no log entry
appeared anywhere in Supabase, which was the giveaway: a nonexistent
function name gets rejected by the Functions gateway before there's any
function context to log against. Root cause was purely process, not code:
`submit-verification` was an *existing* function so "paste the updated
source into the dashboard" was enough, but `delete-account` was brand new
and writing the file into this repo's `supabase/functions/delete-account/`
folder never deploys it anywhere — that requires either the Supabase CLI
(`supabase functions deploy`) or manually creating the function in
Dashboard → Edge Functions first. Worth remembering for any *future* new
edge function added this way: committing the file in this repo is
necessary but not sufficient, unlike SQL (always run directly in the SQL
Editor, so this gap doesn't happen there).

**Two more fixes, 2026-07-10, found via actual end-to-end testing of a
delete → re-onboard cycle:**
- **Bug: re-onboarding didn't clear the "Deleted user" placeholder.** A
  friend's separate UI redesign added `profiles.display_name` as a real
  field ([profile.dart](lib/data/models/profile.dart), read by the new
  profile header) on the assumption that "no app flow writes it yet" —
  true until `delete-account` started setting it to `'Deleted user'`.
  `saveOnboarding()`'s upsert never included `display_name` at all, so
  that placeholder silently survived a full re-onboarding and showed as
  "Deleted, 24" (etc.) in the profile header forever after. Fixed by
  having `Profile.toInsertJson()` always explicitly write
  `display_name: null` — no onboarding step collects a real display name
  yet, so this just restores the pre-deletion fallback behavior (profile
  header falls back to the avatar character's name) for both fresh and
  re-onboarded profiles.
- **Design change: `verification_tier` now resets to `'unverified'` on
  deletion,** at the user's explicit request. The rest of `delete-account`
  deliberately preserves `trust_score`/`report_count`/`phone` etc. so a
  delete+recreate can't launder reputation — but verification is
  different: its whole purpose is a human reviewer confirming a specific
  submitted photo/ID, and that evidence is deleted by this same function.
  Keeping the tier would let a "verified" badge point at nothing a
  reviewer ever actually saw on the new profile. `verification_submissions`
  history rows (status/tier/rejection_reason/reviewed_at/reviewed_by) are
  still untouched — only the tier badge itself resets, not the audit
  trail — so re-verification is simply required again after any deletion.

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

## Chat realtime bugs + typing indicator (2026-07-10)

Three reported issues in one pass, two confirmed root-caused against the
installed package source rather than guessed:

- **Bug found + fixed: newest message rendered at the top instead of the
  bottom.** `MessagesRepository.watchMessages()`
  ([messages_repository.dart](lib/data/repositories/messages_repository.dart))
  called `.order('sent_at')` with no `ascending` argument. Checked the
  installed `supabase` package source directly
  (`supabase-2.12.2/lib/src/supabase_stream_builder.dart`) —
  `SupabaseStreamBuilder.order()` defaults to **`ascending: false`**
  (confirmed in source, not assumed), so messages arrived newest-first and
  a plain non-reversed `ListView.builder` put the newest bubble at index 0
  — the top. Fixed with an explicit `ascending: true`. The same
  `.stream()` call elsewhere (`connections`, `consent_records`,
  `ice_breaker_sessions`, `users` for verification tier) all filter to a
  single row or don't render list position, so none of them were affected
  by this same default.
- **Likely cause of "chat doesn't update live, needs a refresh to receive
  a message":** `.stream()` subscribes via Postgres Changes, which only
  fires for tables added to the `supabase_realtime` publication — a
  project-level Dashboard/SQL setting, invisible from this repo (same
  category of gotcha as the SMS-hook/Text.lk and edge-function-deploy
  issues earlier). Asked the user to run
  `select schemaname, tablename from pg_publication_tables where pubname = 'supabase_realtime';`
  to check whether `messages` (and the other 4 tables above, while
  checking) are actually in it — if a table's missing, the fix is
  `alter publication supabase_realtime add table <name>;`. **Not yet
  confirmed which tables were missing or whether this was applied.**
- **New feature: typing indicator.** Didn't exist anywhere in the
  codebase before this — not a bug, net-new. Built with Realtime
  **Broadcast** (`MessagesRepository.typingChannel()`), not Postgres
  Changes — purely ephemeral, no table, no migration, no RLS involved.
  One channel per connection, topic `typing:{connectionId}`; `ChatScreen`
  ([chat_screen.dart](lib/features/chat/screens/chat_screen.dart))
  subscribes in `initState`, broadcasts a `typing` event (throttled to
  once per 2s) whenever the composer's text changes, and on receiving the
  other participant's event shows a pulsing-dots `_TypingIndicator` that
  clears itself 3s after the last event (a `Timer` reset on every new
  event) — no explicit "stopped typing" signal is sent, just a timeout.
  Channel is torn down via `SupabaseClient.removeChannel()` in `dispose()`.

**Follow-up confirmed 2026-07-10:** the `pg_publication_tables` check came
back empty on the first try purely because of a typo in the query
(`supabase_realtime` misspelled) — once corrected, all 5 relevant tables
(`messages`, `connections`, `consent_records`, `ice_breaker_sessions`,
`users`) were already properly in the publication. **So the realtime
publication was never actually the problem** — the user re-ran the
`alter publication ... add table ...` fix anyway, which is a safe no-op
for tables already present. If "needs a refresh" ever recurs, the actual
cause is somewhere in the client subscription lifecycle
(`messagesStreamProvider`/`ChatScreen`), not a missing-publication config
gap — don't re-reach for that explanation without re-checking first.

## Matches screen + ice-breaker games availability (2026-07-10)

- **Added a "Current connection" card to the Matches screen**
  ([matches_screen.dart](lib/features/matches/screens/matches_screen.dart)),
  pinned above today's match list whenever `activeConnectionProvider` is
  non-null — reuses the existing `getActiveConnection`/`StatusPill`/
  `AvatarCatalog` patterns already used in `connection_detail_screen.dart`,
  tapping it navigates to `/connection/:id`. No new provider or backend
  query needed, `activeConnectionProvider` already existed.
- **Ice-breaker games are now available for the whole lifetime of a
  connection, not just before chat unlocks.** Previously
  `connection_detail_screen.dart`'s games tile was gated on `!canChat`
  (hidden the moment `limited_chat`+ was reached) — per the user's
  explicit request, changed to show whenever `status != ended`, with the
  copy switching from "...to unlock chat" to "...together" once chat is
  already open (no functional gating changed, `ice_breaker_sessions` RLS
  already had no status restriction — see earlier entries in this file).
  Also added a persistent games icon to `ChatScreen`'s AppBar (same
  `status != ended` condition) so games are reachable from inside an
  already-open chat too, not only from the connection detail screen.

## UI/feature batch (2026-07-11)

Eight requested changes in one pass; one (live "seen"/presence in games) was
deliberately **not built** — see reasoning below. One (20 Questions
answer/question order) I could not reproduce from source — see note below.

- **Matches screen connection card made prominent, with its own header.**
  `_CurrentConnectionCard` (added 2026-07-10) now reuses the gradient
  `HeroProfileCard` treatment (same component `my_profile_screen.dart`
  uses) instead of a plain bordered row, under a `SectionHeader('Your
  Connection')`. The in-body `"Today's Matches"` heading is now only shown
  (below the connection section) when a connection exists — otherwise the
  AppBar title alone is enough, matching how it looked before this pass.
- **Removed voice/video call, location-share, and gift-address consent
  types**, at the user's request (calling judged more complex than worth
  building now; the other two weren't wired to any real feature).
  `ConsentType` ([enums.dart](lib/core/constants/enums.dart)) now only has
  `chatUnlock`/`mediaShare` — `ConsentType.values` is what
  `connection_detail_screen.dart`'s "Shared unlocks" section iterates, so
  removing the enum members was enough to remove the UI; the underlying
  Postgres `consent_type` enum still has the old values (can't cheaply drop
  enum values), just nothing client-side offers them anymore.
- **Chat photo/video sharing — genuinely built, not a fix.** There was no
  attachment UI or upload path in `chat_screen.dart` at all before this
  (same category as the typing indicator earlier — reported as broken, but
  actually never built). Added:
  - New private storage bucket `chat-media` (SQL below — **not yet
    confirmed run**), with per-connection-participant RLS (checks
    `(storage.foldername(name))[1]` against `connections.initiator_id`/
    `receiver_id`, not against a user id like the other buckets, since the
    folder here is the connection, not the uploader).
  - Paths are unique per message (`{connectionId}/{timestamp}_{senderId}.
    {ext}`), unlike the deterministic per-user paths `profile-photos`/
    `nic-documents` use — so this never needs an `UPDATE` storage policy,
    sidestepping that whole earlier bug class entirely.
  - `messages.content_type` needs `'video'` added to its check constraint
    (previously `text`/`image`/`audio`/`system` only) — SQL below, **not
    yet confirmed run**.
  - `Message` model gained `mediaUrl` (from `media_url`) and
    `isImage`/`isVideo` getters. `_MessageBubble` renders a signed-URL
    thumbnail for images (tap for a zoomable full-screen view) and an
    inline `video_player`-backed bubble for videos (tap to play/pause) —
    new `video_player` dependency added to `pubspec.yaml`.
  - Composer got an attachment button (`Icons.add_photo_alternate_outlined`)
    opening a bottom sheet to choose Photo/Video, picked via `image_picker`
    (already a dependency).
- **"Would You Rather" bank expanded from 15 to 100 prompts**
  ([icebreaker_content.dart](lib/features/icebreakers/data/icebreaker_content.dart)),
  split roughly evenly across goofy/fun, serious/intellectual, and
  romantic-but-tasteful (dating-app-appropriate, nothing explicit — kept
  brand-safe for App Store review) themes, so two people playing
  repeatedly don't loop back to the same ~15 within a few sessions.
- **"20 Questions" answer/question order — could not reproduce from
  source.** Read `prompts_game.dart` in full: each turn already renders
  the question bubble before the answer bubble in the same `Column`
  (question first = higher up the screen), and the `qa` array is appended
  to (not prepended), so oldest-to-newest should render top-to-bottom
  correctly. Did not change anything here rather than guess a fix for a
  bug I couldn't locate — flagged back to the user for a screenshot/repro
  steps if it's still happening.
- **Draw Together: fixed the "screen shakes and doesn't draw correctly"
  bug.** Root cause: the whole game body was a scrollable `ListView` with
  the drawing `GestureDetector` nested inside it — the canvas's pan
  gesture was competing with the list's scroll gesture in Flutter's
  gesture arena, which is exactly what caused janky/incorrect stroke
  tracking. Changed the outer container to a plain non-scrolling `Column`
  (content fits without scrolling: instructions, toolbar, square canvas,
  clear button), removing the competing recognizer entirely. Also added a
  color-swatch picker (8 brand-palette colors, free choice per stroke
  rather than one fixed color per player) and a 3-size stroke-width picker
  — both stored per-stroke in `state['strokes'][n]['color'/'width']`, with
  `_DrawingPainter` reading `width` with a `?? 4.0` fallback for
  strokes drawn before this change.
- **In-app/local notifications** — user chose this over real OS push
  (which would need a Firebase project + APNs cert + server-side sender,
  none of which exist). Built with `flutter_local_notifications` (already
  an unused dependency in `pubspec.yaml` before this — someone had
  apparently anticipated this feature already):
  - [notification_service.dart](lib/core/notifications/notification_service.dart) —
    thin init/show wrapper, initialized once in `main.dart`. Added
    `POST_NOTIFICATIONS` to `AndroidManifest.xml` (required at runtime on
    Android 13+, the plugin's permission request has nothing to grant
    without it).
  - [notification_watcher.dart](lib/features/home/notification_watcher.dart) —
    invisible widget wrapping `HomeShell`, using `ref.listen` on three
    Realtime-backed providers to fire notifications: new chat messages
    (suppressed if that chat is the one currently open — tracked via new
    `currentlyOpenChatConnectionIdProvider`, set/cleared by `ChatScreen`
    itself), new incoming connection requests, and new ice-breaker game
    sessions ("game invite"). The latter two needed new stream-based
    providers (`incomingRequestsStreamProvider`,
    `gameSessionsStreamProvider`) since the existing ones were one-shot
    `FutureProvider`s that wouldn't notice new arrivals without an
    explicit refetch.
  - Known limitation: `ice_breaker_sessions` has no `created_by` column
    (confirmed via CLAUDE.md's schema dump), so there's no way to tell who
    started a game session — the creator will also see their own "game
    invite" notification fire once. Left as a minor accepted redundancy
    rather than guessing at schema changes to track it.
  - This is local-only, not push: notifications only fire while the app
    process is alive (foreground or backgrounded), never when fully
    killed, since there's no server-side sender or device-token
    infrastructure. That's a deliberate, discussed scope choice, not a
    limitation anyone should be surprised by later.
- **Live "online"/presence indicator for games — deliberately not
  built.** The user was explicitly on the fence and asked for a judgment
  call. Recommended against it: "is this person active right now" is a
  known dating-app safety anti-pattern (lets someone correlate online
  status with real-world routines — Hinge/Bumble/Tinder all deliberately
  omit it), and cuts directly against this app's existing safety-first
  design choices elsewhere (anonymous avatars until photo consent, hide-
  from-contacts, no exact location, careful verification gating). Nothing
  was implemented for this.

**SQL not yet confirmed run** (needed for chat media sharing to work
end-to-end — see git history of this file for the exact statements handed
to the user): create the `chat-media` storage bucket + its two RLS
policies, and add `'video'` to `messages.content_type`'s check constraint.

## Legal/safety review follow-up (2026-07-29)

User pasted an external legal/safety security-review document (PDPA No. 9
of 2022 special-category data, Penal Code 365/365A risk around
`seeking`/orientation-revealing data, "verified" badge misrepresentation,
date-checkin emergency-contact false promise, NIC image retention) and
asked for a plan before any changes; after presenting the plan, the user
made 4 explicit decisions in one message. Three are implemented below;
the 4th (strict same-tier matching) is blocked on the user supplying
`generate_daily_matches()`'s current source — per this file's standing
practice, its SQL is never hand-reconstructed from memory, always
requested verbatim first.

**1. Check-in reframed as a personal alarm, not an emergency-contact
system.** The original "date check-in" feature implied Pearmo would
contact `emergency_contact` (or someone) if a user missed a check-in — it
never did (see the 2026-07-01 entry above: no trigger existed at all
until a `pg_cron` escalation job was added, and even that only flips a
`status` column, it doesn't call/text anyone). That gap was itself the
false promise the review flagged. Rather than building real SMS/call
infra, the feature is now honestly scoped down to what a phone can
actually do unassisted: a **local, on-device alarm**.
- [checkin_panel.dart](lib/features/safety/widgets/checkin_panel.dart) —
  renamed throughout to "check-in alarm" (`SectionHeader`, button label,
  card title), with a persistent disclaimer box stating plainly: *"This
  alarm only sounds on your own phone. Pearmo does not call, text, or
  notify anyone — including the contact below — automatically. If you
  don't check in, your check-in is simply marked missed in the app."* The
  `emergencyContact` text field itself is kept (per the user's explicit
  "alarm route with clear disclaimers" decision — not removed), but
  relabeled "Optional — a personal note of who you'd call" with a caption
  reiterating Pearmo never contacts that number — the field is now
  honestly just a personal note-to-self, not a system integration.
- Uses `NotificationService.instance.scheduleAlarm()` (already built
  2026-07-x for the notifications batch —
  [notification_service.dart](lib/core/notifications/notification_service.dart),
  `AndroidScheduleMode.alarmClock` + `fullScreenIntent` + iOS
  `InterruptionLevel.timeSensitive`) against `checkin.nextDeadline`. A
  stable local alarm id is derived per check-in via `_alarmIdFor()`
  (`checkinId.hashCode & 0x7FFFFFFF` — `flutter_local_notifications` needs
  an int, not the uuid string). Rescheduled on `_acknowledge()` (extends to
  the next interval) and cancelled on `_cancel()`.
- `_CheckinTile` now shows "Missed check-in" instead of the raw
  `'escalated'` enum string for that status.
- **Known limitation, stated deliberately, not hidden:** this alarm only
  fires while the app process is alive (same local-notification
  constraint as the rest of the notification system, see the 2026-07-x
  entry above) — killing the app kills the alarm too. Acceptable for this
  feature's actual purpose (a personal reminder), unlike the old framing
  which implied a safety-net guarantee.

**2. Age-gating → strict same-tier-only matching — SQL handed to user
2026-07-29, not yet confirmed run.** Decision: `unverified` should only
match `unverified`, `selfie_verified` only `selfie_verified`,
`id_verified` only `id_verified` (replacing the pyramid where higher
tiers saw everyone below them — see the "Tiered verification" section
above for the visibility logic being replaced). User provided the
function's real source via
`select pg_get_functiondef(oid) from pg_proc where proname = 'generate_daily_matches';`
per this file's established rule (never guess at a Postgres function's
current source) — only the tier `case` block changed, everything else
(24h-expiry/no-op-if-unexpired guard, active-hours/banned/shadow-
suppressed/already-connected filters, `score_compatibility` call) is
untouched:
```sql
and case
  when user_tier = 'unverified'      then u.verification_tier = 'unverified'
  when user_tier = 'selfie_verified' then u.verification_tier = 'selfie_verified'
  when user_tier = 'id_verified'     then u.verification_tier = 'id_verified'
  when user_tier = 'paid_verified'   then true
  else false
end
```
`paid_verified` was **not** specified by the user's instruction (only the
three tiers above were named as strict pairs) — kept seeing everyone
(`then true`) as a stated assumption, not yet explicitly confirmed.
Existing `daily_matches` rows for test accounts won't reflect this until
they expire (24h) or are deleted manually
(`delete from public.daily_matches where expires_at > now();`), since the
function no-ops while unexpired rows exist.

**3. NIC image cleanup — new scheduled edge function, built in this
repo.** New function
[supabase/functions/cleanup-verification-media/index.ts](supabase/functions/cleanup-verification-media/index.ts):
for every `verification_submissions` row with `status` in
(`approved`, `rejected`) that still has a `nic_front_path`/`nic_back_path`,
deletes those files from the `nic-documents` storage bucket and nulls both
columns. Deliberately **keeps the row itself** (`status`/`tier`/
`rejection_reason`/`reviewed_at`/`reviewed_by`) as the permanent moderation
record — only the actual government-ID image files + their path columns
are cleared, same "keep the audit trail, drop the sensitive payload"
pattern as `delete-account`'s handling of `verification_submissions`
(2026-07-09 section above). Authenticated via a shared `x-cron-secret`
header checked against a `CRON_SECRET` function secret, not a user JWT,
since a `pg_cron`/`pg_net` scheduled call has no user session behind it.
**Not yet done, required before this works:**
- This is a **brand-new** edge function — per the standing lesson in this
  file (first hit with `delete-account`), writing the file in this repo
  does not deploy it. Must be created via Supabase CLI
  (`supabase functions deploy cleanup-verification-media`) or manually in
  Dashboard → Edge Functions.
- Set the `CRON_SECRET` secret on the deployed function (any random
  string, matched against the header the cron job sends).
- Schedule it via `pg_cron`/`pg_net`, e.g. daily:
  ```sql
  select cron.schedule(
    'cleanup-verification-media',
    '0 3 * * *',
    $$
    select net.http_post(
      url := 'https://akodhmnaykaifzxxvher.supabase.co/functions/v1/cleanup-verification-media',
      headers := jsonb_build_object('x-cron-secret', '<same value as CRON_SECRET>')
    );
    $$
  );
  ```
- None of this has been confirmed run/deployed by the user yet.

**4. Verification-copy disclaimers — "verified" is terminology, not a
claim of a background check.** New shared module
[verification_disclaimer.dart](lib/shared/widgets/verification_disclaimer.dart):
`verificationClaimFor(VerificationTier)` returns an exact, narrow claim
per tier (e.g. `idVerified` → *"We've confirmed a live selfie check, and
that a submitted national ID matches their selfie and stated age."*), and
a constant `verificationSafetyDisclaimer` states plainly that Pearmo runs
no criminal background checks and verification isn't a guarantee of
anyone's safety/character/intentions. Two presentations built on top:
`VerificationDisclaimer` (persistent inline box) and
`showVerificationInfoDialog()` (tap-triggered dialog) — same copy, chosen
per surface based on whether permanent screen space is warranted.
Wired to every surface that shows a tier/verified badge:
- [verification_screen.dart](lib/features/verification/screens/verification_screen.dart) —
  persistent `VerificationDisclaimer` below the existing `_TierBanner`.
- [hero_profile_card.dart](lib/shared/widgets/hero_profile_card.dart) —
  new optional `tier` param; the centered-layout tier badge is wrapped in
  a `GestureDetector` opening `showVerificationInfoDialog()` when tapped
  (only the centered layout renders tier badges at all — the editorial
  layout used on `my_profile_screen.dart` doesn't render a badge
  regardless of `tier`, so passing `tier` there is inert but kept for
  consistency/future use). Wired through from
  [candidate_detail_screen.dart](lib/features/matches/screens/candidate_detail_screen.dart)'s
  `HeroProfileCard` call.
- **Bug found + fixed in the same pass:**
  [my_profile_screen.dart](lib/features/profile/screens/my_profile_screen.dart)'s
  `_HeaderTitle` (the compact app-bar identity row, a separate inline
  badge that doesn't go through `HeroProfileCard` at all) hardcoded the
  literal text `'ID'` on its badge for *any* verified tier — so a
  `selfie_verified` user's app-bar badge claimed "ID" just as confidently
  as an actual `id_verified` user's, which is precisely the kind of
  imprecise verification language the review flagged. Fixed to render the
  real `tier.label` (`"Selfie verified"` / `"Age verified"` / `"Verified
  Plus"`) and made tappable via `showVerificationInfoDialog()`. Left the
  badge's visibility condition unchanged (`isVerified` only — still hidden
  entirely for `unverified`, not shown as a muted "Unverified" pill) since
  that would be a layout change beyond what this review asked for.
- `matches_screen.dart`'s `_CurrentConnectionCard` `HeroProfileCard` call
  doesn't pass `tierLabel` at all, so no badge/disclaimer gap exists there
  — left untouched.

## Matching pipeline had no trigger at all (2026-08-02)

**Root cause of "we created test accounts and still get no matches":
`generate_daily_matches()` was never called by anything.** Confirmed by
grepping `lib/` for `.rpc(` (zero hits anywhere) and by this file's own
2026-07-01 note that `cron.job` returned zero rows. `MatchesRepository`
only ever *read* `daily_matches`. Whatever rows existed came from
hand-seeding or (unconfirmed, source not visible) a possible call inside
`analyse-profile` at onboarding — either way nothing regenerated on day 2.
All the earlier debugging of scoring/gates was downstream of this.

**A second theory — that NULL `active_hours` excluded every new profile —
was investigated and is WRONG.** `Profile.toInsertJson()` does only write
those columns via Settings, so every fresh profile really does have both
NULL, but the real function source (pulled via `pg_get_functiondef`
2026-08-02) already reads
`p.active_hours_start is null or current_time between ...`, which handles
exactly that case. Missing caller was the *only* cause. Don't re-reach for
the active-hours explanation.

**Bug found in the live function 2026-08-02: there was no cap on matches
per day.** It scored up to 100 candidates and inserted every one with
`score > 0` — `users.daily_match_count` was never read, and no trigger
enforced it (confirmed against the full `pg_proc` list). "Up to 5" was true
only in `AppConstants.dailyMatchCount` and the UI copy; the DB would have
inserted 60+ rows per user once the pool grew. Fixed in the replacement
function by ordering the scored pool by score desc and taking
`coalesce(daily_match_count, 5)`.

**Also confirmed 2026-08-02:** the strict same-tier `case` block handed
over on 2026-07-29 *was* actually run — this file had it recorded as
unconfirmed. It has now been replaced by the bootstrap rule below.

Full design, all SQL, rollout order and test plan live in
[docs/matching-and-verification-tiers.md](docs/matching-and-verification-tiers.md).
Summary of what changed and what's still owed:

**Client (done, `flutter analyze` clean):** new
`refresh_my_matches` RPC wrapper called at the end of
`OnboardingController.submit()` (so a new user's first screen is populated
rather than "check back tomorrow") and again in `dailyMatchCardsProvider`
(so day 2+ works); `MatchesRepository.getCurrentBatchExpiry()` +
`nextBatchExpiryProvider` backing honest "next matches in Xh" copy; new
`TierChip` shown for **every** tier including `unverified` (match cards and
`_HeaderTitle` previously hid the badge unless verified, so an unverified
profile looked like it had no verification state at all); an unverified-pool
explainer banner on the matches screen; `VerifyToUnlockDialog`
parameterised by `VerifyUnlockReason`; `Message.isSystem` + a `_SystemNotice`
renderer in `chat_screen.dart` for `content_type = 'system'`.

**Bug found + fixed: chat media had no verification gate whatsoever.**
`_pickAndSendMedia()` checked nothing — not the sender's tier, not the
recipient's, not even the `media_share` consent record — so any user in a
chattable connection could send photos/videos. `VerifyToUnlockDialog` was
wired only to Settings' "Add picture" ([settings_screen.dart](lib/features/settings/screens/settings_screen.dart)),
never to chat. Now gated on **both** participants being
`isAtLeastSelfieVerified`, failing closed when either tier can't be
resolved (e.g. the other participant paused their profile, so
`public_profiles` returns no row). **This is UI gating only** — the real
enforcement is a storage RLS policy on `chat-media` that hasn't been
applied yet.

**Pool rule decided: bootstrap, then strict.** `unverified` sees only
`unverified`; `selfie_verified`/`id_verified` see each other *plus*
`unverified` while a new `verified_pool_is_thin()` helper says the verified
pool has < 20 active profiles, then tighten automatically. Chosen over the
pure 3-way strict split handed over on 2026-07-29 (still unrun) because
strict-at-launch inverts the incentive: on day one everyone is unverified,
so the first person to verify would leave a populated pool for an empty one.
The window closes itself — no manual flip needed.

**APPLIED AND VERIFIED 2026-08-02:** `refresh_my_matches()` wrapper +
grant, `verified_pool_is_thin()`, and the `generate_daily_matches`
replacement (bootstrap tier rule + daily cap + `active_hours_end` guard +
`set search_path`). Verified live: four unverified test profiles each
generated exactly 2 matches with symmetric scores. Note
`generate_daily_matches` no-ops while an unexpired batch exists, so any
rule change needs `delete from public.daily_matches where user_id = ...`
before it takes effect — `daily_matches` is derived data, always safe to
delete, and unrelated to accounts/SMS credits.

**STILL NOT RUN:** an `after update of verification_tier on users` trigger
that deletes the user's stale batch, drops them from unverified users'
pending cards, regenerates (delete **before** generate — the function
no-ops while unexpired rows exist), and inserts a subject-neutral
`content_type='system'` message into every non-ended connection; and the
`chat-media` bucket + both-participants-verified storage policies. Until
this runs the client changes are inert — `refreshMyMatches()` failures are
deliberately swallowed so a missing RPC degrades to the old behaviour
rather than an error screen.

**Deliberately not built, documented instead:** the bounded unverified
window (7 days / 1 connection, then verification required). It's what caps
how long a self-declared age goes unchecked *and* what stops the unverified
pool silting up with people who refuse to verify — which is the cohort every
new user would then meet first. Design + schema shape are in the doc.

**Known reciprocity lag worth remembering:** a newly onboarded user gets 5
cards immediately, but existing users' batches are already generated and
no-op for up to 24h, so **nobody sees the newcomer for up to a day**. In a
small beta that's asymmetric enough to matter. Untackled mitigation: delete
a user's unexpired rows once they've actioned every card.

## `public_profiles` was silently returning zero rows (2026-08-02)

**After the matching pipeline was fixed and verified generating rows in the
database, the app still showed "No new matches today" on every device.**
Root cause: `public_profiles` had been defined with `security_invoker=true`,
which applies *the querying user's* RLS to every table the view reads. The
view is `from profiles p join users u on u.id = p.user_id`. `profiles` was
fine (`profiles_select_any`, `auth.uid() is not null`), but **`users` only
has an own-row SELECT policy**, so for any candidate the `users` side of
that join was invisible, the join produced nothing, and the view returned
rows **only for yourself**. Every candidate lookup in
`dailyMatchCardsProvider` failed.

Almost certainly introduced by someone clearing a Supabase advisor warning
— the linter flags views *without* `security_invoker` as "Security Definer
View", so enabling it looks like a fix. **It is not, for this view.** Fixed
with:

```sql
alter view public.public_profiles set (security_invoker = off);
revoke all on public.public_profiles from anon;
grant select on public.public_profiles to authenticated;
```

A "public profiles" view exists precisely to bypass RLS in a controlled
way: its own `where` clause (`is_active`, not banned, `is_profile_active`,
`onboarding_complete`) is the access control, and its column list is a
narrow projection — no phone, no `date_of_birth` (only a computed `age`),
no `seeking`, no `trait_*`, no lat/lng, and `profile_photo_url` only when
`is_photo_public`. With `security_invoker` off, access must be controlled
by GRANT instead of RLS, hence the explicit revoke from `anon`. **The
advisor will flag this view again — that warning is expected and should
not be "fixed".** (It does expose `trust_score` to other users, which is
pre-existing and worth revisiting separately.)

**Second-order lesson, fixed in the same pass:**
`dailyMatchCardsProvider` ([matches_providers.dart](lib/providers/matches_providers.dart))
wrapped each candidate lookup in `catch (_) { continue; }` — legitimate for
tolerating one candidate who got banned/paused between generation and
display, but it made *total* failure render identically to a genuine empty
result, with no error anywhere. Now tracks the last error and rethrows if
every lookup failed while match rows existed.

## Match repetition + permanent exclusion rules (2026-08-03)

Four changes to `generate_daily_matches`, all backend-only — the client
just reads `daily_matches` and has no idea how rows are chosen, so no Dart
change was needed for any of this.

**1. Ended connections are now excluded permanently.** The candidate filter
was `and status != 'ended'`, so once a connection ended both people went
back into each other's pool the next day. The status check is gone: anyone
you have *ever* had a `connections` row with is excluded forever. **Note
this includes a `pending` request that was declined or expired via the
`expire-pending-connections` cron** — one decline removes that person
permanently. Deliberate, per user decision, but expensive in a small pool;
if it needs relaxing, scope the `not in` to connections that reached
`accepted` or beyond.

**2. Reports exclude bidirectionally.** `reports` was never referenced by
the matching function at all — you could report someone for harassment and
have them back on your cards the next day. Now `not exists (... reporter_id
/ reported_id ...)` in both directions. Side effect worth knowing:
**reporting is now a de-facto block**, and each report still increments the
reported user's `report_count`, which feeds `update_trust_score` and can
shadow-suppress them. **There is still no plain user-to-user block feature
anywhere in the app** — every "block" in `lib/` refers to account-level
`is_banned`/`BlockedScreen`. Worth building before public launch; a user's
only options today are "report them" (an accusation) or "end the
connection".

**3. Repeat suppression, ranked not filtered.** A `seen_rank` is computed
per candidate — `0` never shown, `1` shown but never actioned, `2`
explicitly passed on — and the batch is ordered `seen_rank asc, score
desc`. So with a healthy pool a skipped person never returns; with a thin
pool the user still gets a full batch instead of an empty screen. No
threshold to tune: it's just sort order, and it adapts as the pool grows.

**4. `daily_matches` is now a permanent history table.** The
`delete ... where expires_at < now()` at the top of the function was
removed — those rows *are* the "already shown" record that `seen_rank`
reads. The client only ever queries `expires_at > now()`, so old rows stay
invisible in the app. Two consequences: the insert became
`on conflict (user_id, candidate_id) do update` (it was `do nothing`, which
silently dropped every repeat because of the unique constraint), and
`on_verification_tier_change` now **expires** rows (`set expires_at = now()`)
instead of deleting them, so a tier change no longer wipes history. The
table grows but is bounded by the unique pair constraint; a retention job
dropping rows older than a few months is worth adding at scale.

## Project hygiene findings (2026-08-02)

Full audit of the live project while wiring up the matching fix. Three
things worth remembering:

**Another app's (`Trio`) objects were created in this project by mistake.**
Five `pg_cron` jobs (`lock-gigs`, `complete-gigs`, `recompute-bands`,
`expire-friend-requests`, `expire-verifications`) and four storage buckets
(`venues` — the only *public* bucket in the project — `shared-media`,
`avatars`, `verification`). **No Trio data ever existed here:** every table
in `public` is Pearmo's, every FK is Pearmo→Pearmo, all five job functions
were missing from every schema, all four buckets were empty, and the jobs
never appeared in `cron.job_run_details` (scheduled but never executing).
The five cron jobs have been unscheduled; the buckets were still pending
deletion at time of writing (must go through the dashboard/Storage API —
`delete from storage.buckets` is blocked by a `storage.protect_delete()`
trigger). Note the `avatars` bucket is *not* Pearmo's: avatars are bundled
PNGs under `assets/avatars/` (40 files, 12 MB) and `public.avatars` is
unused, per [avatar_catalog.dart](lib/shared/avatars/avatar_catalog.dart).

**`CRON_SECRET` is stored in plaintext inside `cron.job.command`** for the
`cleanup-verification-media` job, so anyone who can read `cron.job` can
read it. It was exposed during this audit and needs rotating. Future
scheduled functions should avoid embedding secrets in the job command.

**Phone numbers had no normalisation, and it had already created a
duplicate account.** `auth.users` contained one tester's number twice —
once with the `94` country code and once as a bare local number. The old
`Validators.phone` accepted any syntactically valid E.164 string, so the
country-code-less form passed as a legitimate *foreign* number (a bare
Sri Lankan mobile happens to parse as a valid `+7…` number) and minted a
separate identity.

**Fixed 2026-08-02, Sri Lanka only by explicit user decision.** New
`Validators.normalizeSriLankanMobile()` / `sriLankanMobile()`
([validators.dart](lib/core/utils/validators.dart)) collapse `0771234567`,
`771234567`, `94771234567` and `+94771234567` to one canonical
`+94771234567`, and `LoginScreen` now sends the **normalised** string to
`signInWithOtp`, never the raw field text — that's the part that actually
prevents duplicates, since Supabase Auth keys accounts by the exact string
it receives. The field is digits-only behind a fixed `🇱🇰 +94` prefix.
Landline prefixes (`011`, `081`, …) are rejected: every SL mobile is `07x`,
and a landline can't receive an SMS OTP. The generic `Validators.phone`
still exists and is still used by `emergencyContact`, which is a free-text
note-to-self and shouldn't be country-restricted. Widening beyond Sri Lanka
later means relaxing `normalizeSriLankanMobile` alone.

**`escalate-overdue-checkins` is live and genuinely working** (every 5 min;
it's pure SQL, no HTTP call, so `cron.job_run_details` telling the truth
about it is meaningful).

**`cleanup-verification-media` was scheduled but had NEVER once run —
found 2026-08-02.** `cron.job_run_details` showed `succeeded` on every
invocation, which was misleading: `net.http_post` is asynchronous and
returns a request id immediately, so "succeeded" only ever meant *the SQL
ran*, never that the HTTP call was accepted. The real outcome lives in
`net._http_response`, and every row there was **401
`UNAUTHORIZED_NO_AUTH_HEADER` / "Missing authorization header"** going back
as far as the table retains.

Root cause: **Supabase Edge Functions enforce JWT verification by
default.** The cron job sends only `x-cron-secret` and no
`Authorization: Bearer <jwt>`, so the platform gateway rejected it before
the function body executed — the `CRON_SECRET` check inside it was never
reached. Consequence: **no NIC image has ever been deleted**, despite the
whole function existing to close exactly that PDPA exposure.

Fix: turn off "Verify JWT with legacy secret" in Dashboard → Edge Functions
→ `cleanup-verification-media` → Settings. Correct for this function, since
a scheduled call has no user session and `x-cron-secret` *is* its
authentication (Supabase's own hint on that toggle says the same:
"Recommended: OFF with JWT and custom auth logic in your function code").
Do **not** instead put the `service_role` key in the `Authorization` header
— that would sit in `cron.job.command` in plaintext and reads the entire
database. Leave the toggle ON for `submit-verification` and
`delete-account`, which are called by real user sessions.

**RESOLVED 2026-08-03.** JWT verification turned off and `CRON_SECRET`
re-set so the dashboard secret and `cron.job.command` finally hold the same
string (they had diverged, which is why the first rotation attempt still
401'd). First-ever successful run returned
`200 {"cleaned":1,"checked":1}`.

Second lesson from the same incident: **Supabase cannot display a saved
function secret** ("Secrets can't be retrieved once saved"), so there is no
way to compare it against what's in the cron job. When they disagree the
only fix is to overwrite both from one known value — keep it in a password
manager, never retype it.

**Standing lesson for any future `pg_net`-invoked function: `cron.job_run_details`
tells you nothing about whether the HTTP request worked. Always verify via
`net._http_response.status_code`, and disable JWT verification on any
function invoked by a scheduler rather than a user.**

**RESOLVED 2026-08-05 (partially) — Auth SMS rate limits.** Every SMS the
app sends is the phone OTP from `AuthRepository.sendOtp()` →
`signInWithOtp()`, called from exactly two places
([login_screen.dart](lib/features/auth/screens/login_screen.dart) "Send
code" and [otp_screen.dart](lib/features/auth/screens/otp_screen.dart)
"Resend"). Login and signup are the same code path, so one limit governs
both. **No custom edge function is involved in sending OTP SMS at all** —
confirmed by grepping `lib/` and `supabase/functions/` for any SMS/Text.lk
reference: the three edge functions that exist (`delete-account`,
`submit-verification`, `cleanup-verification-media`) don't touch SMS.
Text.lk is wired in purely as Supabase Auth's configured phone SMS
provider (Dashboard → Authentication → Providers → Phone), so every lever
here is Dashboard-only, no app code change, no APK rebuild required.

**This section previously said the live "Sending SMS messages" limit was
150/hour — that was stale/wrong.** A dashboard screenshot on 2026-08-05
showed it was already **30/hour** (someone had already tightened it at
some point without updating this file). Current confirmed dashboard
settings (Authentication → Rate Limits):
- **Sending SMS messages: 30/hour** — left as-is. Already tighter than the
  70/hour this file was about to recommend before the screenshot caught
  the stale baseline; lowering it further risks blocking real users during
  an unpredictable demo/marketing spike for no added abuse protection.
- **Sign-ups and sign-ins: 10 per 5 min per IP** (changed 2026-08-05, was
  30/5min = 360/hour) — this is the one that actually targets abuse without
  risking legitimate traffic, since it's scoped per-IP: a viral spike comes
  from many different IPs and sails through unaffected, while a single
  script/bot hammering the endpoint from one IP gets throttled.
- Email/anonymous/Web3 limits are irrelevant — the app uses phone OTP only
  (every `auth.users` row has no email) and never anonymous sign-in.
- **"Enable IP address forwarding" confirmed OFF, left untouched.** It lets
  clients declare their own IP, which is only safe behind a proxy you
  control; the app talks to Supabase directly from devices, so enabling it
  would let anyone claim a fresh IP per request and defeat the per-IP limit
  above.

**Still open / not done here:** a prepaid balance cap on the Text.lk
account itself, which is the actual bounded-worst-case backstop (money, not
a request-count that has to guess future traffic correctly) — this lives
outside Supabase entirely, on Text.lk's own dashboard, and wasn't
accessible from this session. Also still open: Supabase's native CAPTCHA
protection toggle (Authentication → Settings) would be a stronger gate on
`signInWithOtp` itself, but requires the client to pass a `captchaToken`
(an hCaptcha/Turnstile widget on the login screen) — that's an app code
change and would need a new APK build, so deliberately deferred while the
current demo APK is in distribution. Client-side there is still just a 60s
cooldown on the login send button (UX only — the anon key ships in the app
binary, so the endpoint can be called directly, bypassing that cooldown;
server-side limits above are the only real control).


## Push notifications (2026-08-07)

Replaced the local-only notification system (`flutter_local_notifications`
firing off client-side `ref.listen`s on Supabase Realtime — only worked
while the app process was alive) with real FCM push for the three events it
covered: new chat message, new incoming connection request, new ice-breaker
game invite. **Android is fully wired in this repo; iOS is not started**
(no `GoogleService-Info.plist`/Apple APNs key supplied yet, and pushing an
iOS Xcode capability change isn't possible from this Windows session
regardless — needs a Mac).

**Firebase project:** `pearmo-ce752` (Android app `com.pearmo.pearmo`).
`android/app/google-services.json` is committed (normal for Flutter/Android
Firebase apps — its API key isn't a secret, Firebase's actual security
boundary is Auth + Firestore/Storage rules, neither of which this project
uses). **The Firebase service-account JSON (`firebase-adminsdk-fbsvc@pearmo-ce752...`)
is a real admin credential and was never committed** — it's Supabase
Edge Function secret `FCM_SERVICE_ACCOUNT_JSON` only. It was pasted in
plaintext into a chat session to hand it over, so **it should be rotated**
(Firebase console → Project settings → Service accounts → Generate new
private key, then delete the old `b5e2a18812cc...` key) — re-set the
`FCM_SERVICE_ACCOUNT_JSON` secret to the new value afterward. Not yet done
at time of writing.

**Client (done, Android):**
- `google-services.json` + the `com.google.gms.google-services` Gradle
  plugin wired into [android/settings.gradle.kts](android/settings.gradle.kts)
  / [android/app/build.gradle.kts](android/app/build.gradle.kts).
  `firebase_core`/`firebase_messaging` added to `pubspec.yaml`.
- **Bug found + fixed in the same pass, unrelated to push itself:** the
  main [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) had
  no `INTERNET` permission at all — only the debug/profile manifest
  variants did. A release build would have had every network call
  (Supabase, and now FCM token registration) silently fail. Added to the
  main manifest.
- [push_token_repository.dart](lib/data/repositories/push_token_repository.dart) —
  upserts `{user_id, token, platform}` into a new `push_tokens` table,
  `onConflict: 'token'` (so a device that logs into a different account
  re-homes its token instead of creating a duplicate row).
- [push_notification_listener.dart](lib/features/home/push_notification_listener.dart) —
  replaces `NotificationWatcher` at the same mount point
  ([home_shell.dart](lib/features/home/home_shell.dart)). On login: requests
  notification permission, registers the FCM token, listens for
  `onTokenRefresh`. Also listens to `FirebaseMessaging.onMessage`
  (foreground-only — FCM delivers those silently on both platforms) and
  shows a local banner via the existing `NotificationService`, suppressed
  if `data.connection_id` matches `currentlyOpenChatConnectionIdProvider`
  (same suppression the old watcher did, now driven by the push payload
  instead of a Realtime row). Background/terminated delivery needs no Dart
  code — the OS renders the FCM `notification` payload directly.
- `main.dart` calls `Firebase.initializeApp()` and registers a (currently
  empty) `FirebaseMessaging.onBackgroundMessage` handler, required to exist
  even though it does nothing yet.
- `NotificationWatcher` and the two stream providers that existed only for
  it (`incomingRequestsStreamProvider`, `gameSessionsStreamProvider`) were
  deleted outright rather than left dead. `NotificationService` itself
  (the `flutter_local_notifications` wrapper) **was not removed** — it's
  still used for the check-in alarm
  ([checkin_panel.dart](lib/features/safety/widgets/checkin_panel.dart))
  and for displaying push while foregrounded (above). The check-in alarm is
  a scheduled on-device alarm, not a reaction to a Realtime event — push
  doesn't replace it, don't reach for that later.

**Server-side — new edge function, NOT YET DEPLOYED (brand new function,
same standing lesson as `delete-account`: writing the file here doesn't
deploy it):**
[supabase/functions/send-push/index.ts](supabase/functions/send-push/index.ts).
Auth via a shared `x-webhook-secret` header (function secret
`PUSH_WEBHOOK_SECRET`) — no user session behind a Database Webhook call,
same pattern as `cleanup-verification-media`'s `x-cron-secret`. Exchanges
the Firebase service-account JSON for a short-lived OAuth2 token (cached
per warm instance) via `jose`'s RS256 JWT signing, then calls FCM's HTTP v1
send endpoint per registered device token. Deletes a `push_tokens` row if
FCM reports it `UNREGISTERED`/`NOT_FOUND`/`INVALID_ARGUMENT`.

**Not yet run — needed before any of this actually delivers a push:**

1. **`push_tokens` table** (SQL editor):
   ```sql
   create table public.push_tokens (
     id uuid primary key default gen_random_uuid(),
     user_id uuid not null references public.users(id) on delete cascade,
     token text not null unique,
     platform text not null check (platform in ('android', 'ios')),
     created_at timestamptz not null default now(),
     updated_at timestamptz not null default now()
   );
   create index push_tokens_user_id_idx on public.push_tokens(user_id);
   alter table public.push_tokens enable row level security;
   create policy "push_tokens_select_own" on public.push_tokens
     for select using (auth.uid() = user_id);
   create policy "push_tokens_insert_own" on public.push_tokens
     for insert with check (auth.uid() = user_id);
   create policy "push_tokens_update_own" on public.push_tokens
     for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
   create policy "push_tokens_delete_own" on public.push_tokens
     for delete using (auth.uid() = user_id);
   ```
2. **Deploy `send-push`** (Supabase CLI `supabase functions deploy send-push`
   or create it manually in Dashboard → Edge Functions first).
3. **Set two function secrets** on `send-push`: `FCM_SERVICE_ACCOUNT_JSON`
   (the full service-account JSON, ideally the *rotated* key, as one
   string) and `PUSH_WEBHOOK_SECRET` (any random string — reused in step 5).
4. **Turn off "Verify JWT with legacy secret"** for `send-push` (Dashboard →
   Edge Functions → send-push → Settings) — a Database Webhook call has no
   user JWT, only the `x-webhook-secret` header, same reasoning as
   `cleanup-verification-media`'s toggle.
5. **Wire the trigger — NOT via Dashboard → Database → Webhooks.** That UI
   depends on an internal `supabase_functions` schema Supabase provisions
   per-project, and on this project it's missing:
   `Failed to create webhook: ... schema "supabase_functions" does not
   exist` (confirmed 2026-08-07 trying to create the `messages` webhook).
   This is a known Supabase-side bootstrap bug with no self-service SQL
   fix — see
   [supabase/supabase#20056](https://github.com/supabase/supabase/issues/20056),
   where Supabase support told a reporter the same schema was simply
   missing its functions on their project too. Rather than file a support
   ticket and wait, skip that feature entirely and reuse the mechanism
   that's already proven working in this project —
   `cleanup-verification-media`'s cron job already calls `net.http_post`
   (the `pg_net` extension) directly, so `pg_net` is confirmed installed
   and enabled. A plain trigger calling it does exactly what a Database
   Webhook would have, with the identical `{type, table, record}` JSON
   shape `send-push`'s `WebhookPayload` already expects — no function code
   changes needed:
   ```sql
   create or replace function public.notify_push()
   returns trigger
   language plpgsql
   security definer
   set search_path = public
   as $$
   begin
     perform net.http_post(
       url := 'https://akodhmnaykaifzxxvher.supabase.co/functions/v1/send-push',
       headers := jsonb_build_object(
         'Content-Type', 'application/json',
         'x-webhook-secret', '<same value as PUSH_WEBHOOK_SECRET>'
       ),
       body := jsonb_build_object(
         'type', 'INSERT',
         'table', TG_TABLE_NAME,
         'record', to_jsonb(NEW)
       )
     );
     return NEW;
   end;
   $$;

   create trigger messages_push_trigger
     after insert on public.messages
     for each row execute function public.notify_push();

   create trigger connections_push_trigger
     after insert on public.connections
     for each row execute function public.notify_push();

   create trigger ice_breaker_sessions_push_trigger
     after insert on public.ice_breaker_sessions
     for each row execute function public.notify_push();
   ```
   **Same plaintext-secret caveat as `cron.job.command`** (documented
   above under "Project hygiene findings"): the secret literal sits in
   `pg_proc`/`information_schema.routines` in plain text, readable by
   anyone with SQL Editor access. Accepted for the same reason the cron
   secret was — this project's threat model already treats SQL Editor
   access as trusted (owner-only), and there's no parameterized-secret
   mechanism available to a plain trigger function.
6. **Rotate the Firebase service-account key** (see above — it was pasted
   into a chat transcript) and update the `FCM_SERVICE_ACCOUNT_JSON` secret
   to match.

None of steps 1–6 have been confirmed run as of this entry. If Supabase
support later fixes the missing `supabase_functions` schema and the
Dashboard webhook feature starts working, the trigger-based approach above
still works fine left in place — no need to migrate back to Dashboard
webhooks, they'd just be redundant.

**iOS: not started.** Needs `ios/Runner/GoogleServiceInfo.plist` from the
Firebase console's iOS app registration, an APNs Auth Key from Apple
Developer uploaded to Firebase Cloud Messaging settings, and enabling the
"Push Notifications" + "Background Modes → Remote notifications"
capabilities in Xcode (which also touches `Runner.entitlements` and the
`.pbxproj` — not something to hand-edit blind without Xcode to verify it,
and this session has no Mac to run it on regardless).

## Connection request/response, pause, and consent state + notifications (2026-08-08)

User-reported gap: sending a connection request had no visible "waiting"
state, decline/accept never notified the sender, ending/pausing a chat
never notified the other participant, and toggling photo/video consent
(`ConsentDialog`) claimed "the other person will get a notification" when
nothing anywhere actually sent one. Audited the full connection/consent/
chat flow (see git history of this file for the raw agent report) and
found: `send-push` (still undeployed — see "Push notifications" above)
only ever fires on `connections` INSERT (a new pending request), explicitly
skips every UPDATE — so accept/decline/end were never going to notify
anyone even once deployed; there was no "pause" feature at all, only
irreversible `endConnection`; consent state only had two visual states
(granted vs not), unable to distinguish "nobody asked" from "I asked,
waiting" from "they turned it off."

**Client-side, done (`flutter analyze` clean):**
- `Connection` gained `isPaused`/`pausedBy`/`pausedAt` + a `canChatNow`
  getter (`status.canChat && !isPaused`) — pause is orthogonal to the
  status pipeline (freezes sending only, doesn't move/reset progress),
  unlike `endConnection`.
- `ConnectionsRepository.pauseConnection()`/`resumeConnection()` — direct
  client `UPDATE`s, same pattern as the pre-existing `endConnection` (the
  `connections` UPDATE RLS policy already permits either participant to
  write any column — see the "Full schema confirmed" section above — so no
  RLS change was needed for these two columns to work). **By design, only
  the person who paused can resume** — enforced client-side only (the
  Resume button is hidden from the other participant in both
  `connection_detail_screen.dart` and `chat_screen.dart`), not by RLS.
- `ConnectionsRepository.getOutgoingPendingRequest()` +
  `outgoingPendingRequestProvider` — `getActiveConnection` deliberately
  excludes `pending` rows, so a sent request previously had zero visible
  state until accepted. `connection_hub_screen.dart` now shows a "Waiting
  for response" card in that gap.
- New `ConsentRecord` model (raw `consent_records` row) +
  `resolveConsentState()` in
  [consent_record.dart](lib/data/models/consent_record.dart) — a 6-state
  enum (`none`/`waitingOnThem`/`needsYourResponse`/`granted`/
  `revokedByMe`/`revokedByThem`) derived from `active_consents.is_granted`
  plus `consent_records.requested_by`/`is_active`/`revoked_by`. **Sidesteps
  the documented `user_a`/`user_b` mapping ambiguity entirely** — those two
  boolean columns are never read; `requested_by`/`revoked_by` are real
  user ids, directly comparable against the current user's id, which is
  enough to derive all 6 states. `connectionConsentsProvider` replaces the
  old `activeConsentsProvider`, fetching both `active_consents` and raw
  `consent_records` off one shared realtime subscription (the old
  `activeConsentsProvider` would otherwise become two independent
  subscriptions to the same table once records were needed too).
  `ConsentTile` now renders distinct copy/button label per state (e.g.
  "Cancel" while waiting on your own request vs "Agree" when responding to
  theirs) instead of a flat granted/not-granted toggle.
- `ConsentDialog`'s copy no longer promises a notification that doesn't
  exist — now describes what's actually true today (visible to the other
  participant next time they open the connection).

**Server-side — SQL not yet run, code not yet deployed:**

`send-push`'s `WebhookPayload`
([supabase/functions/send-push/index.ts](supabase/functions/send-push/index.ts))
gained `event`/`target_user_id`/`old_record` fields. When a trigger
supplies `target_user_id` + `event`, `buildFromEvent()` picks copy for it
directly — no DB lookup needed, since the trigger already has the
relational context (a join is easy in SQL, awkward to redo in the function
for every event). The three original INSERT-only paths (`messages`,
`connections` new-request, `ice_breaker_sessions`) are untouched. New
events: `connection_accepted`/`connection_declined`/`connection_ended`/
`connection_paused`/`connection_resumed`/`consent_requested`/
`consent_granted`/`consent_revoked`.

**Flagged, not verified:** `connection_declined` is inferred as a
`pending -> ended` transition that never passed through `accepted` — this
is a guess, not read from `respond-to-connection`'s source (still not
visible from this repo). If a real decline doesn't actually produce that
exact transition, this notification silently never fires. Confirm with a
real decline (`select status from connections where id = '<test row>'`
right after declining) before trusting it.

This entire section is additive to the still-undeployed pipeline described
above — none of it does anything until `send-push` is actually deployed
(step 2 in the "Push notifications" section). SQL to run, in order:

```sql
-- 1. Pause columns (client code above already assumes these exist)
alter table public.connections
  add column if not exists is_paused boolean not null default false,
  add column if not exists paused_by uuid references public.users(id),
  add column if not exists paused_at timestamptz;

-- 2. Replace notify_push() to also handle connections UPDATE
--    (accept/decline/pause/resume/end). Falls through to the original
--    INSERT-only body — unchanged — for every other case.
create or replace function public.notify_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target uuid;
  v_event text;
begin
  if TG_TABLE_NAME = 'connections' and TG_OP = 'UPDATE' then
    if NEW.status = 'accepted' and OLD.status = 'pending' then
      v_target := NEW.initiator_id;
      v_event := 'connection_accepted';
    elsif NEW.status = 'ended' and OLD.status = 'pending' then
      -- ASSUMPTION, unconfirmed — see CLAUDE.md note above.
      v_target := NEW.initiator_id;
      v_event := 'connection_declined';
    elsif NEW.status = 'ended' and OLD.status <> 'ended' then
      v_target := case when NEW.ended_by = NEW.initiator_id
                        then NEW.receiver_id else NEW.initiator_id end;
      v_event := 'connection_ended';
    elsif NEW.is_paused = true and OLD.is_paused = false then
      v_target := case when NEW.paused_by = NEW.initiator_id
                        then NEW.receiver_id else NEW.initiator_id end;
      v_event := 'connection_paused';
    elsif NEW.is_paused = false and OLD.is_paused = true then
      v_target := case when OLD.paused_by = NEW.initiator_id
                        then NEW.receiver_id else NEW.initiator_id end;
      v_event := 'connection_resumed';
    else
      return NEW; -- no notification-worthy change
    end if;

    perform net.http_post(
      url := 'https://akodhmnaykaifzxxvher.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', '<same value as PUSH_WEBHOOK_SECRET>'
      ),
      body := jsonb_build_object(
        'type', 'UPDATE', 'table', 'connections', 'event', v_event,
        'target_user_id', v_target, 'record', to_jsonb(NEW), 'old_record', to_jsonb(OLD)
      )
    );
    return NEW;
  end if;

  -- Original behavior, unchanged.
  perform net.http_post(
    url := 'https://akodhmnaykaifzxxvher.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', '<same value as PUSH_WEBHOOK_SECRET>'
    ),
    body := jsonb_build_object('type', 'INSERT', 'table', TG_TABLE_NAME, 'record', to_jsonb(NEW))
  );
  return NEW;
end;
$$;

-- Re-run the 3 existing INSERT triggers if not already applied (unchanged):
create trigger messages_push_trigger
  after insert on public.messages
  for each row execute function public.notify_push();

create trigger connections_push_trigger
  after insert on public.connections
  for each row execute function public.notify_push();

create trigger ice_breaker_sessions_push_trigger
  after insert on public.ice_breaker_sessions
  for each row execute function public.notify_push();

-- New: connections UPDATE trigger (accept/decline/pause/resume/end)
create trigger connections_update_push_trigger
  after update on public.connections
  for each row execute function public.notify_push();

-- 3. consent_records needs its own function — it requires a join to
--    connections to find both participant ids, which `notify_push()`
--    doesn't have.
create or replace function public.notify_push_consent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conn record;
  v_target uuid;
  v_actor uuid;
  v_event text;
begin
  select initiator_id, receiver_id into v_conn
  from public.connections where id = NEW.connection_id;
  if v_conn is null then return NEW; end if;

  if TG_OP = 'INSERT' then
    v_actor := NEW.requested_by;
    v_event := 'consent_requested';
  elsif NEW.is_active = true and NEW.user_a_consented = true and NEW.user_b_consented = true
        and (OLD.user_a_consented = false or OLD.user_b_consented = false) then
    v_event := 'consent_granted';
  elsif NEW.is_active = false and OLD.is_active = true then
    v_actor := NEW.revoked_by;
    v_event := 'consent_revoked';
  else
    return NEW;
  end if;

  if v_event = 'consent_granted' then
    -- both participants get notified; no single "actor" to exclude
    perform net.http_post(
      url := 'https://akodhmnaykaifzxxvher.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object('Content-Type', 'application/json',
        'x-webhook-secret', '<same value as PUSH_WEBHOOK_SECRET>'),
      body := jsonb_build_object('type', 'UPDATE', 'table', 'consent_records',
        'event', v_event, 'target_user_id', v_conn.initiator_id, 'record', to_jsonb(NEW))
    );
    perform net.http_post(
      url := 'https://akodhmnaykaifzxxvher.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object('Content-Type', 'application/json',
        'x-webhook-secret', '<same value as PUSH_WEBHOOK_SECRET>'),
      body := jsonb_build_object('type', 'UPDATE', 'table', 'consent_records',
        'event', v_event, 'target_user_id', v_conn.receiver_id, 'record', to_jsonb(NEW))
    );
    return NEW;
  end if;

  v_target := case when v_actor = v_conn.initiator_id
                    then v_conn.receiver_id else v_conn.initiator_id end;

  perform net.http_post(
    url := 'https://akodhmnaykaifzxxvher.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-webhook-secret', '<same value as PUSH_WEBHOOK_SECRET>'),
    body := jsonb_build_object('type', TG_OP, 'table', 'consent_records',
      'event', v_event, 'target_user_id', v_target, 'record', to_jsonb(NEW))
  );
  return NEW;
end;
$$;

create trigger consent_records_insert_push_trigger
  after insert on public.consent_records
  for each row execute function public.notify_push_consent();

create trigger consent_records_update_push_trigger
  after update on public.consent_records
  for each row execute function public.notify_push_consent();
```

None of this has been confirmed run. Same plaintext-secret caveat as the
rest of this pipeline (documented under "Project hygiene findings").

**Deployed 2026-08-08.** `push_tokens` table, the trigger SQL above, and
the updated `send-push` function were all applied by the user — confirmed
via a successful SQL Editor run and a redeployed function.

## Shared Unlocks was cosmetic — didn't actually gate chat or media (2026-08-08)

User-reported: after building the pause/consent-notification work above,
locking "Open chat" or "Share photos & videos" again in Shared Unlocks
didn't actually stop the other person from chatting/sharing. Root cause,
confirmed by reading the code rather than guessing: `chat_screen.dart`'s
`canChat` was derived **only** from `connection.status` (the
`pending → accepted → ice_breaking → limited_chat → open_chat → ...`
pipeline, which is what `messages` RLS actually checks), and `canShareMedia`
was derived **only** from both participants' verification tier. Neither
ever read `consent_records`/`active_consents` — the `chat_unlock`/
`media_share` `ConsentType`s existed, rendered in the UI, updated the
database via `update-consent`, and (as of the section above) sent
notifications, but had **zero effect on whether chat or media sharing
actually worked.** Toggling them was pure theater.

**Confirmed desired behavior (from the user, verbatim scenario check):**
ice-breaker games still happen first as before; chat stays locked until
one person requests "Open chat" and the other explicitly agrees; **either
person can re-lock it at any time**, which immediately closes chat for
*both* (not just the locker) and notifies the other person; re-opening
after a lock needs a fresh request + fresh agreement, not an automatic
reopen. Same independent mutual-agreement model for "Share photos &
videos".

**Fix, in `chat_screen.dart`:** `canChat` is now
`connection.canChatNow && chatUnlockGranted`, and `canShareMedia` is now
`iAmVerified && theyAreVerified && mediaShareGranted`, reading
`connectionConsentsProvider` (already built for the Shared Unlocks panel
in the section above) directly in the chat screen for the first time.
This is purely additive — AND'd onto the existing requirements, never
replacing them — so it can only make sending *more* restricted than
before, never grant something the old code wouldn't have; safe regardless
of whatever `update-consent`'s actual internals turn out to be. Fails
closed while consents are still loading, same pattern the tier check
already used. A third notice-banner state was added between "ice-breaker
not done" and "fully open": status is chat-eligible but `chat_unlock`
isn't granted yet → "Chat is locked. Both of you need to agree to open
it." with a button into the connection-detail screen's Shared Unlocks
panel, where the actual request/agree happens.

**New: explicit Decline, not just silent non-response.** Previously
`ConsentTile` only had one button per state, so responding to someone
else's request meant either tapping "Agree" or doing nothing. Added a
second button (`onDecline`) shown only in the `needsYourResponse` state —
calls `ConsentRepository.setConsent(consenting: false)` directly, skipping
`ConsentDialog`'s granting/revoking confirmation copy since declining
someone else's ask isn't "revoking my own grant" (same "no confirmation
needed to say no" choice already made for connection-request decline).

**New `consent_declined` push event, distinct from `consent_revoked`.**
Both are an `is_active: true → false` transition on `consent_records`, so
telling apart "they declined my still-pending request" from "they turned
off something we'd both already agreed to" needs to know whether it was
ever actually granted — not derivable from the current row alone.
`notify_push_consent()`'s trigger now checks `OLD.user_a_consented`/
`OLD.user_b_consented`: both true beforehand → `consent_revoked`
("They turned off ..."); otherwise → `consent_declined`
("They declined your request..."). Only the function body changed
(`create or replace`, safe to re-run) — no trigger/table changes needed:

```sql
create or replace function public.notify_push_consent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conn record;
  v_target uuid;
  v_actor uuid;
  v_event text;
begin
  select initiator_id, receiver_id into v_conn
  from public.connections where id = NEW.connection_id;
  if v_conn is null then return NEW; end if;

  if TG_OP = 'INSERT' then
    v_actor := NEW.requested_by;
    v_event := 'consent_requested';
  elsif NEW.is_active = true and NEW.user_a_consented = true and NEW.user_b_consented = true
        and (OLD.user_a_consented = false or OLD.user_b_consented = false) then
    v_event := 'consent_granted';
  elsif NEW.is_active = false and OLD.is_active = true then
    v_actor := NEW.revoked_by;
    if OLD.user_a_consented = true and OLD.user_b_consented = true then
      v_event := 'consent_revoked';
    else
      v_event := 'consent_declined';
    end if;
  else
    return NEW;
  end if;

  if v_event = 'consent_granted' then
    perform net.http_post(
      url := 'https://akodhmnaykaifzxxvher.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object('Content-Type', 'application/json',
        'x-webhook-secret', '<same value as PUSH_WEBHOOK_SECRET>'),
      body := jsonb_build_object('type', 'UPDATE', 'table', 'consent_records',
        'event', v_event, 'target_user_id', v_conn.initiator_id, 'record', to_jsonb(NEW))
    );
    perform net.http_post(
      url := 'https://akodhmnaykaifzxxvher.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object('Content-Type', 'application/json',
        'x-webhook-secret', '<same value as PUSH_WEBHOOK_SECRET>'),
      body := jsonb_build_object('type', 'UPDATE', 'table', 'consent_records',
        'event', v_event, 'target_user_id', v_conn.receiver_id, 'record', to_jsonb(NEW))
    );
    return NEW;
  end if;

  v_target := case when v_actor = v_conn.initiator_id
                    then v_conn.receiver_id else v_conn.initiator_id end;

  perform net.http_post(
    url := 'https://akodhmnaykaifzxxvher.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-webhook-secret', '<same value as PUSH_WEBHOOK_SECRET>'),
    body := jsonb_build_object('type', TG_OP, 'table', 'consent_records',
      'event', v_event, 'target_user_id', v_target, 'record', to_jsonb(NEW))
  );
  return NEW;
end;
$$;
```

**Removed em dashes from every notification title/body** (user's explicit
request, notification copy only — code comments untouched) —
`connection_accepted`, `consent_requested`, and `consent_granted` bodies in
`send-push/index.ts` reworded with plain punctuation.

**New: avatar image in push notifications.** Every `PushTarget` can now
carry an `imageUrl` — the *other* participant's avatar PNG, resolved via a
new `avatarImageUrl()` helper (`profiles.avatar_id` → a public URL) and
passed as `notification.image` in the FCM payload. Android renders this as
an automatic expanded/big-picture notification with **no client-side code
change needed** — this only required editing the edge function. Wired into
every event/table that has an unambiguous "who this is about": messages
(sender), new connection request (initiator), and all the
accept/decline/pause/resume/end/consent events (the other participant
relative to `target_user_id`). Deliberately **not** wired for
`ice_breaker_sessions` (no `created_by` column, so there's no single
"who this is about" — see the existing note in that branch).

**Requires one new thing not yet done: a public Storage bucket for the
avatar PNGs.** The 40 files under `assets/avatars/` (`{key}-m.png` /
`{key}-f.png`, exactly matching `profiles.avatar_id`) are bundled into the
app binary, not hosted anywhere — FCM's `notification.image` needs a real
public URL it can fetch server-side, which a bundled asset can't provide.
**Not yet done:**
1. Dashboard → Storage → create a new bucket named exactly `avatar-icons`,
   marked **public**.
2. Upload all 40 files from `assets/avatars/` into it, keeping their exact
   filenames (no subfolder) — `avatarImageUrl()` builds
   `.../avatar-icons/{avatar_id}.png` directly from the column value.

Until that bucket exists, `avatarImageUrl()` still returns a URL, but it
will 404 — FCM handles a broken image URL by just showing the notification
without an image (confirmed behavior of the HTTP v1 API: a fetch failure
on `notification.image` doesn't fail the whole send), so this is a
soft-fail, not something that will break notifications in the meantime.

**Still true from the section above:** none of this changes the fact that
`chat_unlock`/`media_share` are UI-gating only. Actual server-side
enforcement (RLS on `messages`, RLS on the `chat-media` storage bucket)
still only checks `connections.status` and verification tier respectively
— it has no idea `consent_records` exists. Someone bypassing the app
entirely (e.g. hand-crafted Supabase client calls) could still send
messages the moment status reaches `limited_chat`, regardless of whether
`chat_unlock` was ever granted. Worth a real RLS-level fix later if that
threat model matters; out of scope for this pass, which was about the
in-app experience.
