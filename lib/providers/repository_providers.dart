import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/checkin_repository.dart';
import '../data/repositories/connections_repository.dart';
import '../data/repositories/consent_repository.dart';
import '../data/repositories/games_repository.dart';
import '../data/repositories/matches_repository.dart';
import '../data/repositories/messages_repository.dart';
import '../data/repositories/payments_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/push_token_repository.dart';
import '../data/repositories/ratings_repository.dart';
import '../data/repositories/reports_repository.dart';
import '../data/repositories/storage_repository.dart';
import '../data/repositories/verification_repository.dart';

/// The single Supabase client instance, initialized in `main.dart`.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final matchesRepositoryProvider = Provider<MatchesRepository>((ref) {
  return MatchesRepository(ref.watch(supabaseClientProvider));
});

final connectionsRepositoryProvider = Provider<ConnectionsRepository>((ref) {
  return ConnectionsRepository(ref.watch(supabaseClientProvider));
});

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepository(ref.watch(supabaseClientProvider));
});

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  return ConsentRepository(ref.watch(supabaseClientProvider));
});

final gamesRepositoryProvider = Provider<GamesRepository>((ref) {
  return GamesRepository(ref.watch(supabaseClientProvider));
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(ref.watch(supabaseClientProvider));
});

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  return VerificationRepository(ref.watch(supabaseClientProvider));
});

final checkinRepositoryProvider = Provider<CheckinRepository>((ref) {
  return CheckinRepository(ref.watch(supabaseClientProvider));
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(supabaseClientProvider));
});

final ratingsRepositoryProvider = Provider<RatingsRepository>((ref) {
  return RatingsRepository(ref.watch(supabaseClientProvider));
});

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(ref.watch(supabaseClientProvider));
});

final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  return PushTokenRepository(ref.watch(supabaseClientProvider));
});
