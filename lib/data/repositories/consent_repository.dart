import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/enums.dart';
import '../models/consent_record.dart';

/// The progressive-unlock consent system. `active_consents` is a view that
/// is true only once BOTH participants have granted a given consent type.
class ConsentRepository {
  ConsentRepository(this._client);

  final SupabaseClient _client;

  Future<List<ActiveConsent>> getActiveConsents(String connectionId) async {
    final rows =
        await _client.from('active_consents').select().eq('connection_id', connectionId);
    return (rows as List).map((e) => ActiveConsent.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `active_consents` is a read-only view, so it can't be streamed
  /// directly. Instead the UI watches `consent_records` (a real table) for
  /// changes and re-fetches `getActiveConsents` whenever it fires.
  Stream<List<Map<String, dynamic>>> watchConsentRecords(String connectionId) {
    return _client
        .from('consent_records')
        .stream(primaryKey: ['id'])
        .eq('connection_id', connectionId);
  }

  Future<void> setConsent({
    required String connectionId,
    required ConsentType type,
    required bool consenting,
  }) async {
    await _client.functions.invoke(
      SupabaseConfig.fnUpdateConsent,
      body: {
        'connection_id': connectionId,
        'consent_type': type.dbValue,
        'consenting': consenting,
      },
    );
  }
}
