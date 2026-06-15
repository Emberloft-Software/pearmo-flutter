# Pearmo

A curated-matching dating app — Flutter client built against a Supabase backend
(auth, Postgres + RLS, storage, edge functions, realtime).

## Setup

1. Install Flutter dependencies:

   ```
   flutter pub get
   ```

2. Drop in your Supabase project credentials in
   [`lib/core/config/supabase_config.dart`](lib/core/config/supabase_config.dart):

   ```dart
   static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';
   ```

   **Only the anon key belongs here.** The `service_role` key must never be
   committed to or used from the Flutter app — all privileged operations are
   done via RLS policies and edge functions on the Supabase side.

3. Run the app:

   ```
   flutter run
   ```

## Required Supabase storage buckets

The app expects these private storage buckets to exist, with signed URLs used
for all reads/writes:

- `profile-photos`
- `audio-intros`
- `nic-documents`

## Required edge functions

- `analyse-profile`
- `send-connection-request`
- `respond-to-connection`
- `update-consent`
- `submit-verification`
- `date-checkin`
- `create-payhere-order` *(not yet implemented server-side — see "Known
  backend gaps" below)*

## Project structure

```
lib/
  core/        # config, theme, router, constants/enums, error mapper
  data/        # models + repositories (only layer that talks to Supabase)
  providers/   # Riverpod providers (manual, no codegen)
  features/    # one folder per feature area (auth, onboarding, matches,
               # connections, icebreakers, chat, verification, safety,
               # ratings, settings, payments, profile)
  shared/      # shared widgets (PearmoButton, PearmoCard, AvatarDisplay, ...)
```

## Known backend gaps (`TODO(backend)`)

These features are implemented on the Flutter side but depend on backend
pieces that don't exist yet in the current handoff. Each is marked inline
with a `TODO(backend)` comment:

1. **PayHere checkout** — [`lib/core/config/supabase_config.dart`](lib/core/config/supabase_config.dart)
   declares `fnCreatePayhereOrder`, and
   [`lib/data/repositories/payments_repository.dart`](lib/data/repositories/payments_repository.dart) /
   [`lib/features/payments/screens/payments_screen.dart`](lib/features/payments/screens/payments_screen.dart)
   call it — but the edge function itself needs to be created server-side
   (where `merchant_secret` can live safely), returning a hosted checkout URL
   with `custom_1` set to the user's id so a PayHere webhook can update
   `users.verification_tier` on payment.

2. **Hide-from-contacts matching** — [`lib/features/settings/screens/settings_screen.dart`](lib/features/settings/screens/settings_screen.dart)
   persists the `profiles.hide_from_contacts` toggle, but actually excluding
   matches requires a contact-hash matching step (reading the user's
   contacts, hashing numbers, filtering candidates server-side) that isn't
   built yet.

3. **Automated ID verification (OCR/liveness)** — [`lib/features/verification/screens/verification_screen.dart`](lib/features/verification/screens/verification_screen.dart)
   uploads NIC photos + a selfie and calls `submit-verification`, which is
   currently manual-review only. An OCR/liveness pre-check could call an edge
   function here before queuing for review.

4. **AI harassment filtering & screenshot detection** — [`lib/features/chat/screens/chat_screen.dart`](lib/features/chat/screens/chat_screen.dart)
   needs a moderation edge function for AI-based message filtering and
   platform-level hooks for screenshot detection/watermarking. Neither
   exists yet, so the `reports` flow (see [`lib/features/safety/screens/report_screen.dart`](lib/features/safety/screens/report_screen.dart))
   is the primary safety mechanism for now.

5. **Gift-sharing / affiliate flow** — [`lib/features/connections/screens/connection_detail_screen.dart`](lib/features/connections/screens/connection_detail_screen.dart)
   handles the `gift_address` consent toggle, but the affiliate catalog +
   anonymous delivery flow needs its own screen and edge function.

6. **AI agent assistant** — [`lib/features/profile/screens/my_profile_screen.dart`](lib/features/profile/screens/my_profile_screen.dart)
   has no entry point yet for a chat-based profile/coaching assistant —
   would need its own edge function before adding a UI entry point.

## Verification status

`flutter analyze` runs clean with **0 errors** (a handful of pre-existing
info-level lints around `use_null_aware_elements` and a deprecated
`anonKey` reference remain, intentionally left as-is). Full runtime testing
on a device/emulator is still required before release.
