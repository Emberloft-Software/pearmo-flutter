import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/enums.dart';
import '../data/models/profile.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// The signed-in user's own profile row, or null if onboarding hasn't been
/// completed yet. Used by the router to decide whether to show onboarding.
final myProfileProvider = FutureProvider.autoDispose<Profile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).getMyProfile(userId);
});

/// Live verification tier for the signed-in user, used to gate features
/// (e.g. who can see whom) and to show the verification status banner.
final myVerificationTierProvider = StreamProvider.autoDispose<VerificationTier>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(VerificationTier.unverified);
  }
  return ref.watch(verificationRepositoryProvider).watchVerificationTier(userId);
});
