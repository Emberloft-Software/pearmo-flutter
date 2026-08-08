import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/enums.dart';
import '../models/connection.dart';

/// Connection requests and the connection lifecycle (pending -> accepted ->
/// ice_breaking -> limited_chat -> open_chat -> media_unlocked ->
/// date_planned, or ended).
class ConnectionsRepository {
  ConnectionsRepository(this._client);

  final SupabaseClient _client;

  /// The current active (non-ended, non-pending-incoming) connection for
  /// this user, if any. Used to enforce "one active connection at a time"
  /// in the UI before the backend ever needs to reject anything.
  Future<Connection?> getActiveConnection(String userId) async {
    final row = await _client
        .from('connections')
        .select()
        .or('initiator_id.eq.$userId,receiver_id.eq.$userId')
        .not('status', 'in', '("ended","pending")')
        .maybeSingle();
    if (row == null) return null;
    return Connection.fromJson(row);
  }

  /// Pending connection requests sent to this user.
  Future<List<Connection>> getIncomingRequests(String userId) async {
    final rows = await _client
        .from('connections')
        .select()
        .eq('receiver_id', userId)
        .eq('status', 'pending');
    return (rows as List).map((e) => Connection.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// A request this user sent that's still awaiting the other person's
  /// response — `getActiveConnection` deliberately excludes `pending` rows,
  /// so without this a sent request has no visible state at all until it's
  /// accepted or declined.
  Future<Connection?> getOutgoingPendingRequest(String userId) async {
    final row = await _client
        .from('connections')
        .select()
        .eq('initiator_id', userId)
        .eq('status', 'pending')
        .maybeSingle();
    if (row == null) return null;
    return Connection.fromJson(row);
  }

  Stream<Connection?> watchConnection(String connectionId) {
    return _client
        .from('connections')
        .stream(primaryKey: ['id'])
        .eq('id', connectionId)
        .map((rows) => rows.isEmpty ? null : Connection.fromJson(rows.first));
  }

  /// Live version of `getIncomingRequests` — used by the notification
  /// watcher to notice a new request as it arrives. Filters to `pending`
  /// client-side rather than chaining a second `.eq()` on the stream
  /// builder, since only `receiver_id` is confirmed safe to filter
  /// server-side on a realtime stream here.
  Stream<List<Connection>> watchIncomingRequests(String userId) {
    return _client
        .from('connections')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .map((rows) => rows
            .map((e) => Connection.fromJson(e))
            .where((c) => c.status == ConnectionStatus.pending)
            .toList());
  }

  Future<void> sendConnectionRequest({
    required String userId,
    required String candidateId,
  }) async {
    // Mark the daily match card as actioned first.
    await _client
        .from('daily_matches')
        .update({'user_action': 'request_sent'})
        .eq('user_id', userId)
        .eq('candidate_id', candidateId);

    await _client.functions.invoke(
      SupabaseConfig.fnSendConnectionRequest,
      body: {'candidate_id': candidateId},
    );
  }

  Future<void> respondToConnection({
    required String connectionId,
    required bool accept,
  }) async {
    await _client.functions.invoke(
      SupabaseConfig.fnRespondToConnection,
      body: {'connection_id': connectionId, 'accept': accept},
    );
  }

  Future<void> endConnection({
    required String connectionId,
    required String endedBy,
    EndReason reason = EndReason.unilateral,
  }) async {
    await _client.from('connections').update({
      'status': ConnectionStatus.ended.dbValue,
      'ended_at': DateTime.now().toIso8601String(),
      'ended_by': endedBy,
      'end_reason': reason.dbValue,
    }).eq('id', connectionId);
  }

  /// Reversible pause — unlike [endConnection], the status/progress
  /// (`limited_chat`, `open_chat`, etc.) is left untouched, only sending is
  /// blocked (see `Connection.canChatNow`) until [resumeConnection]. Only
  /// the person who paused can resume — enforced client-side (the UI hides
  /// the Resume button from the other participant), not by RLS, since the
  /// existing `connections` UPDATE policy already allows either participant
  /// to write any column.
  Future<void> pauseConnection({
    required String connectionId,
    required String pausedBy,
  }) async {
    await _client.from('connections').update({
      'is_paused': true,
      'paused_by': pausedBy,
      'paused_at': DateTime.now().toIso8601String(),
    }).eq('id', connectionId);
  }

  Future<void> resumeConnection({required String connectionId}) async {
    await _client.from('connections').update({
      'is_paused': false,
      'paused_by': null,
      'paused_at': null,
    }).eq('id', connectionId);
  }
}
