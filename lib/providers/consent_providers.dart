import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/consent_record.dart';
import 'repository_providers.dart';

/// Active consents + the raw records for a connection, bundled together so
/// both can be derived from a single `consent_records` realtime
/// subscription instead of two independent ones watching the same table.
class ConnectionConsents {
  final List<ActiveConsent> active;
  final List<ConsentRecord> records;

  const ConnectionConsents({required this.active, required this.records});

  ConsentRecord? recordFor(String dbType) =>
      records.where((r) => r.consentType.dbValue == dbType).firstOrNull;
}

/// Re-fetches both `active_consents` (the both-agreed view) and the raw
/// `consent_records` rows every time `consent_records` changes via
/// realtime — `active_consents` itself is a read-only view that can't be
/// streamed directly.
final connectionConsentsProvider =
    StreamProvider.autoDispose.family<ConnectionConsents, String>((ref, connectionId) async* {
  final consentRepo = ref.watch(consentRepositoryProvider);

  Future<ConnectionConsents> fetch() async {
    final active = await consentRepo.getActiveConsents(connectionId);
    final records = await consentRepo.getConsentRecords(connectionId);
    return ConnectionConsents(active: active, records: records);
  }

  yield await fetch();

  await for (final _ in consentRepo.watchConsentRecords(connectionId)) {
    yield await fetch();
  }
});

/// Convenience lookup: is [type] granted (by both sides) for this connection?
bool isConsentGranted(List<ActiveConsent> consents, String connectionId, String dbType) {
  return consents.any((c) =>
      c.connectionId == connectionId && c.consentType.dbValue == dbType && c.isGranted);
}
