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

/// A request this user sent that's still awaiting a response, so the hub
/// screen has something to show between "Send Request" and the other
/// person accepting/declining (see `getActiveConnection`, which excludes
/// `pending` rows entirely).
final outgoingPendingRequestProvider = FutureProvider.autoDispose<Connection?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(connectionsRepositoryProvider).getOutgoingPendingRequest(userId);
});

/// Realtime stream of a single connection's status — used by the
/// connection hub, chat, games and consent screens.
final connectionStreamProvider =
    StreamProvider.autoDispose.family<Connection?, String>((ref, connectionId) {
  return ref.watch(connectionsRepositoryProvider).watchConnection(connectionId);
});

