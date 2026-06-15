import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/date_checkin.dart';
import 'repository_providers.dart';

/// Date safety check-ins for a connection, newest first.
final checkinsProvider =
    FutureProvider.autoDispose.family<List<DateCheckin>, String>((ref, connectionId) {
  return ref.watch(checkinRepositoryProvider).getCheckins(connectionId);
});
