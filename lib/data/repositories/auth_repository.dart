import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// Phone OTP authentication, per the handoff doc's auth flow.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  String? get currentUserId => _client.auth.currentUser?.id;

  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> sendOtp(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  Future<void> verifyOtp({required String phone, required String token}) async {
    await _client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Creates the `users` row the first time a user signs in. Safe to call
  /// repeatedly — `ignoreDuplicates` makes this an INSERT-or-noop, since the
  /// RLS policies on `users` only grant INSERT (not UPDATE) to the owner.
  Future<void> ensureUserRow() async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('users').upsert(
      {
        'id': user.id,
        'phone': user.phone,
      },
      ignoreDuplicates: true,
    );
  }

  /// Fetches the `users` row (mainly for `verification_tier`).
  Future<AppUser> getCurrentAppUser() async {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    final row = await _client.from('users').select().eq('id', user.id).single();
    return AppUser.fromJson(row);
  }
}
