import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/connection.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// The user's current active connection (any status other than `ended` or
/// incoming `pending`), or null if they're free to match with someone new.
final activeConnectionProvider = FutureProvider.autoDispose<Connection?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(connectionsRepositoryProvider).getActiveConnection(userId);
});

/// Incoming pending connection requests for the inbox screen.
final incomingRequestsProvider = FutureProvider.autoDispose<List<Connection>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(connectionsRepositoryProvider).getIncomingRequests(userId);
});

/// Realtime stream of a single connection's status — used by the
/// connection hub, chat, games and consent screens.
final connectionStreamProvider =
    StreamProvider.autoDispose.family<Connection?, String>((ref, connectionId) {
  return ref.watch(connectionsRepositoryProvider).watchConnection(connectionId);
});

/// Live version of [incomingRequestsProvider] — used by the notification
/// watcher, which needs to notice a new request arriving, not just fetch
/// the list once.
final incomingRequestsStreamProvider =
    StreamProvider.autoDispose<List<Connection>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(connectionsRepositoryProvider).watchIncomingRequests(userId);
});
