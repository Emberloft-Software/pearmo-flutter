import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository_providers.dart';

/// Streams Supabase auth state changes — the router listens to this to
/// decide between login / onboarding / home.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// The current signed-in user's id, or null if logged out.
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  return authState?.session?.user.id ?? ref.watch(authRepositoryProvider).currentUserId;
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserIdProvider) != null;
});
