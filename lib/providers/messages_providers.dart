import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/message.dart';
import 'repository_providers.dart';

/// Realtime stream of all messages for a connection, ordered by `sent_at`.
final messagesStreamProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, connectionId) {
  return ref.watch(messagesRepositoryProvider).watchMessages(connectionId);
});
