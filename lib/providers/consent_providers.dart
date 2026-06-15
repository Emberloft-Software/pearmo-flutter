import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/consent_record.dart';
import 'repository_providers.dart';

/// Active (both-sides-granted) consents for a connection. Re-fetches every
/// time `consent_records` changes via realtime, since `active_consents`
/// itself is a read-only view that can't be streamed.
final activeConsentsProvider =
    StreamProvider.autoDispose.family<List<ActiveConsent>, String>((ref, connectionId) async* {
  final consentRepo = ref.watch(consentRepositoryProvider);

  // Emit once immediately, then again whenever consent_records changes.
  yield await consentRepo.getActiveConsents(connectionId);

  await for (final _ in consentRepo.watchConsentRecords(connectionId)) {
    yield await consentRepo.getActiveConsents(connectionId);
  }
});

/// Convenience lookup: is [type] granted (by both sides) for this connection?
bool isConsentGranted(List<ActiveConsent> consents, String connectionId, String dbType) {
  return consents.any((c) =>
      c.connectionId == connectionId && c.consentType.dbValue == dbType && c.isGranted);
}
