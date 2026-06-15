import '../../core/constants/enums.dart';

/// Row from `ice_breaker_sessions`. The `state` column is a fully flexible
/// JSON blob — each game type owns its own shape inside `state`.
class IceBreakerSession {
  final String id;
  final String connectionId;
  final GameType gameType;
  final Map<String, dynamic> state;

  const IceBreakerSession({
    required this.id,
    required this.connectionId,
    required this.gameType,
    required this.state,
  });

  factory IceBreakerSession.fromJson(Map<String, dynamic> json) {
    return IceBreakerSession(
      id: json['id'] as String,
      connectionId: json['connection_id'] as String,
      gameType: GameType.fromDb(json['game_type'] as String),
      state: Map<String, dynamic>.from(json['state'] as Map? ?? const {}),
    );
  }
}
