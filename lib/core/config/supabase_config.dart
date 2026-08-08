/// Supabase project configuration.
///
/// SECURITY: Only the public `anon` key belongs here. The anon key is safe
/// to ship inside the app because every table is protected by Row Level
/// Security policies on the backend — it cannot read or write anything the
/// signed-in user isn't allowed to. The `service_role` key must NEVER be
/// placed in this file, committed to the repo, or shipped in a build: it
/// bypasses RLS entirely and is for trusted server-side code only.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://akodhmnaykaifzxxvher.supabase.co';

  /// Replace with the project's anon/public key before running the app.
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFrb2RobW5heWthaWZ6eHh2aGVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEzOTQwOTQsImV4cCI6MjA5Njk3MDA5NH0.qqgSQIX9-1z7L04UoVYABBLfIMFXEehVwlDb_2yo-uc';

  // Storage bucket names used throughout the app.
  static const String profilePhotosBucket = 'profile-photos';
  static const String audioIntrosBucket = 'audio-intros';
  static const String nicDocumentsBucket = 'nic-documents';
  static const String chatMediaBucket = 'chat-media';

  // Edge function names.
  static const String fnAnalyseProfile = 'analyse-profile';
  static const String fnSendConnectionRequest = 'send-connection-request';
  static const String fnRespondToConnection = 'respond-to-connection';

  /// Superseded 2026-08-08 by the `set_consent` Postgres function (see
  /// [ConsentRepository.setConsent]) after its respond-to-a-request path
  /// was found to silently no-op. Kept only so the name isn't lost; nothing
  /// in the app calls it.
  @Deprecated('Use the set_consent RPC instead. See CLAUDE.md.')
  static const String fnUpdateConsent = 'update-consent';
  static const String fnSubmitVerification = 'submit-verification';
  static const String fnDateCheckin = 'date-checkin';
  static const String fnDeleteAccount = 'delete-account';

  /// TODO(backend): not yet in the handoff's function list. Should create a
  /// PayHere order server-side (where `merchant_secret` can live safely),
  /// returning a hosted checkout URL with `custom_1` set to the user's id so
  /// the PayHere webhook can update `users.verification_tier` on payment.
  static const String fnCreatePayhereOrder = 'create-payhere-order';
}
