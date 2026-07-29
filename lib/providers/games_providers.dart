import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ice_breaker_session.dart';
import 'repository_providers.dart';

/// All ice-breaker sessions ever created for a connection (most recent
/// last), used to show history and resume an in-progress game.
final gameSessionsProvider =
    FutureProvider.autoDispose.family<List<IceBreakerSession>, String>((ref, connectionId) {
  return ref.watch(gamesRepositoryProvider).getSessions(connectionId);
});

/// Realtime stream of a single game session's state.
final gameSessionStreamProvider =
    StreamProvider.autoDispose.family<IceBreakerSession?, String>((ref, sessionId) {
  return ref.watch(gamesRepositoryProvider).watchSession(sessionId);
});

/// Realtime list of every session for a connection — used to notice a new
/// game invite as soon as it's created, not just to display game state.
final gameSessionsStreamProvider =
    StreamProvider.autoDispose.family<List<IceBreakerSession>, String>((ref, connectionId) {
  return ref.watch(gamesRepositoryProvider).watchSessions(connectionId);
});
