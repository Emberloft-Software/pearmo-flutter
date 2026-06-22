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
creates the `public.users` row idempotently. It uses
`upsert(..., ignoreDuplicates: true)` (→ `INSERT ... ON CONFLICT DO NOTHING`),
**not** a plain upsert — because RLS on `users` only grants `INSERT` to the
owner (`auth.uid() = id`), not `UPDATE`. A real upsert hits `42501` on the
second call.

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

## Other tables (columns inferred from repository code, not yet confirmed via `information_schema`)

- `connections`: `id`, `initiator_id`, `receiver_id`, `status`, `ended_at`, `ended_by`, `end_reason`. Status lifecycle per `ConnectionStatus` enum: `pending → ice_breaking → limited_chat → open_chat → media_unlocked → date_planned`, or `ended`. No literal "accepted" status — pending → ice_breaking is acceptance.
- `daily_matches`: `id`, `user_id`, `candidate_id`, `score`, `expires_at`, `user_action`.
- `ice_breaker_sessions`: `id`, `connection_id`, `game_type`, `state` (flexible jsonb).
  **Bug found 2026-06-22:** confirmed via `pg_policies` that this table had only ONE RLS policy total — `icb_select_participant` (`SELECT`, checks `connection_id` belongs to a connection where `auth.uid()` is `initiator_id`/`receiver_id`). No `INSERT` or `UPDATE` policy existed, so `GamesRepository.createSession()`/`updateState()` ([lib/data/repositories/games_repository.dart](lib/data/repositories/games_repository.dart)) were unusable for *any* user, not just test accounts — `42501` on every insert. Fixed by adding `icb_insert_participant` / `icb_update_participant` policies mirroring the same participant check (no extra status/consent restriction, consistent with the existing SELECT policy). If ice-breaker games still don't unlock as expected after this, check `pg_policies` again rather than assuming — don't trust this section's "fixed" status without re-confirming, since RLS for this app has repeatedly had gaps the app code assumes are filled.
- `consent_records` (confirmed via `information_schema`): **one row per `(connection_id, consent_type)`**, not one row per user. Columns: `id`, `connection_id`, `consent_type` (enum `consent_type`), `requested_by`, `requested_at`, `user_a_consented` (bool), `user_b_consented` (bool), `user_a_consented_at`, `user_b_consented_at`, `is_active` (bool), `revoked_by`, `revoked_at`. **No column says which participant is "a" vs "b"** — that mapping isn't derivable from the schema alone (probably `initiator_id`/`receiver_id` order, or `least(uuid)`, decided inside the `update-consent` edge function). When faking this via SQL, just set both `user_a_consented`/`user_b_consented` true to sidestep the ambiguity.
- `active_consents`: read-only view, true (`is_granted`) only once **both** participants have granted a given `ConsentType` — presumably reads off `consent_records.is_active` plus both `_consented` flags.

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

