import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/enums.dart';
import '../models/ice_breaker_session.dart';

/// Ice-breaker game sessions stored as flexible JSON `state`.
class GamesRepository {
  GamesRepository(this._client);

  final SupabaseClient _client;

  Future<List<IceBreakerSession>> getSessions(String connectionId) async {
    final rows = await _client
        .from('ice_breaker_sessions')
        .select()
        .eq('connection_id', connectionId)
        .order('id');
    return (rows as List)
        .map((e) => IceBreakerSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<IceBreakerSession> createSession({
    required String connectionId,
    required GameType gameType,
    Map<String, dynamic> initialState = const {},
  }) async {
    final row = await _client
        .from('ice_breaker_sessions')
        .insert({
          'connection_id': connectionId,
          'game_type': gameType.dbValue,
          'state': initialState,
        })
        .select()
        .single();
    return IceBreakerSession.fromJson(row);
  }

  Future<void> updateState(String sessionId, Map<String, dynamic> state) async {
    await _client.from('ice_breaker_sessions').update({'state': state}).eq('id', sessionId);
  }

  Stream<IceBreakerSession?> watchSession(String sessionId) {
    return _client
        .from('ice_breaker_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .map((rows) => rows.isEmpty ? null : IceBreakerSession.fromJson(rows.first));
  }

  /// Realtime list of every session for a connection — used by the
  /// notification watcher to detect a brand-new game invite. `getSessions`
  /// stays a one-shot fetch for the game-selection screen; this is only
  /// for the live "did a new session just appear" check.
  Stream<List<IceBreakerSession>> watchSessions(String connectionId) {
    return _client
        .from('ice_breaker_sessions')
        .stream(primaryKey: ['id'])
        .eq('connection_id', connectionId)
        .map((rows) => rows.map((e) => IceBreakerSession.fromJson(e)).toList());
  }
}
