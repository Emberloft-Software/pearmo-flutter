import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/daily_match.dart';
import '../data/models/public_profile.dart';
import 'auth_providers.dart';
import 'connections_providers.dart';
import 'repository_providers.dart';

/// Pairs each of today's [DailyMatch] rows with the candidate's
/// [PublicProfile] for display on the match cards screen.
class MatchCard {
  final DailyMatch match;
  final PublicProfile profile;

  const MatchCard({required this.match, required this.profile});
}

final dailyMatchCardsProvider = FutureProvider.autoDispose<List<MatchCard>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final matchesRepo = ref.watch(matchesRepositoryProvider);

  // Generate before reading. This is what makes day 2 onwards work at all —
  // `generate_daily_matches` has no scheduler behind it, so without a call
  // here the user only ever sees the batch created at onboarding. The
  // function's own no-op-while-unexpired guard keeps this cheap.
  //
  // Deliberately non-fatal: if generation fails (RPC missing because the
  // SQL hasn't been applied yet, network blip), still show whatever batch
  // already exists rather than turning the whole screen into an error.
  try {
    await matchesRepo.refreshMyMatches();
  } catch (_) {
    // Intentionally swallowed — see above.
  }

  final matches = await matchesRepo.getTodaysMatches(userId);

  final cards = <MatchCard>[];
  Object? lastError;
  for (final match in matches) {
    try {
      final profile = await matchesRepo.getCandidateProfile(match.candidateId);
      cards.add(MatchCard(match: match, profile: profile));
    } catch (e) {
      // Candidate profile may have been removed/banned/paused since match
      // generation — skip it rather than failing the whole list.
      lastError = e;
      continue;
    }
  }

  // ...but if *every* lookup failed, that's not "no matches", it's a broken
  // read path, and silently returning an empty list makes the two
  // indistinguishable. That exact confusion cost an hour of debugging when
  // `public_profiles` was switched to `security_invoker = true` and started
  // returning nothing for other users — the screen just said "No new
  // matches today" with no error anywhere.
  if (cards.isEmpty && matches.isNotEmpty && lastError != null) {
    throw lastError;
  }
  return cards;
});

/// When the current batch expires — drives the "next matches in Xh" copy on
/// the empty state. Null means no unexpired batch exists, in which case the
/// next visit to the matches screen will generate one.
final nextBatchExpiryProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  // Depend on the cards provider so this is read *after* generation has had
  // a chance to run, not racing it.
  await ref.watch(dailyMatchCardsProvider.future);
  return ref.watch(matchesRepositoryProvider).getCurrentBatchExpiry(userId);
});

/// Whether the user can send a new connection request right now (i.e. they
/// don't already have an active connection).
final canSendRequestProvider = FutureProvider.autoDispose<bool>((ref) async {
  final connection = await ref.watch(activeConnectionProvider.future);
  return connection == null;
});

/// A single candidate's public profile, looked up by id — used by the
/// candidate detail screen when navigating from a match card.
final candidateProfileProvider =
    FutureProvider.autoDispose.family<PublicProfile, String>((ref, candidateId) {
  return ref.watch(matchesRepositoryProvider).getCandidateProfile(candidateId);
});

/// Signed URL for a profile photo storage path (private bucket).
final signedProfilePhotoUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, path) {
  return ref.watch(storageRepositoryProvider).signedProfilePhotoUrl(path);
});

/// Signed URL for an audio intro storage path (private bucket).
final signedAudioIntroUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, path) {
  return ref.watch(storageRepositoryProvider).signedAudioIntroUrl(path);
});
