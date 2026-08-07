import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers this device's FCM token against the signed-in user, so the
/// `send-push` edge function knows where to deliver a push. See CLAUDE.md
/// "Push notifications".
class PushTokenRepository {
  PushTokenRepository(this._client);

  final SupabaseClient _client;

  /// `token` is unique across `push_tokens` (see the table SQL in
  /// CLAUDE.md), so this both registers a new device and re-homes a token
  /// to a different account if the same device later signs in as someone
  /// else — `onConflict: 'token'` makes that an update, not a duplicate row.
  Future<void> upsertToken({required String token, required String platform}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('push_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  /// Best-effort cleanup on sign-out. Not strictly required — a stale token
  /// just means this device gets no pushes until a future login's upsert
  /// replaces it — but keeps `push_tokens` from accumulating dead rows for
  /// devices that are no longer signed in to anyone.
  Future<void> removeToken(String token) async {
    await _client.from('push_tokens').delete().eq('token', token);
  }
}
