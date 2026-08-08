import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Raw `consent_records` rows for this connection — carries
  /// `requested_by`/`revoked_by` (real user ids), which `active_consents`
  /// doesn't expose. Used to distinguish "waiting on them" from "they
  /// declined" instead of just granted/not-granted.
  Future<List<ConsentRecord>> getConsentRecords(String connectionId) async {
    final rows =
        await _client.from('consent_records').select().eq('connection_id', connectionId);
    return (rows as List).map((e) => ConsentRecord.fromJson(e as Map<String, dynamic>)).toList();
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

  /// Records this user's own answer for [type] on a connection:
  /// `consenting: true` requests it (first caller) or agrees to it (second
  /// caller); `consenting: false` declines someone else's request, cancels
  /// your own, or turns off an already-granted unlock.
  ///
  /// Calls the `set_consent` Postgres function rather than the
  /// `update-consent` edge function it replaced (2026-08-08). The edge
  /// function's source was never visible from this repo, and its
  /// respond-to-a-request path silently did nothing: the requester's row
  /// was created correctly, but the *second* participant tapping Agree
  /// left the row completely untouched, so `active_consents.is_granted`
  /// (which needs `is_active AND user_a_consented AND user_b_consented`)
  /// could never become true and no unlock was reachable. Consent is core
  /// safety logic, so it now lives in SQL that can be read and fixed from
  /// here. See CLAUDE.md.
  Future<void> setConsent({
    required String connectionId,
    required ConsentType type,
    required bool consenting,
  }) async {
    await _client.rpc(
      'set_consent',
      params: {
        'p_connection_id': connectionId,
        'p_consent_type': type.dbValue,
        'p_consenting': consenting,
      },
    );
  }
}
