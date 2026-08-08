import '../../core/constants/enums.dart';

/// Row from `connections` — the central record tracking two users moving
/// through the progressive-unlock journey.
class Connection {
  final String id;
  final String initiatorId;
  final String receiverId;
  final ConnectionStatus status;
  final DateTime? createdAt;
  final DateTime? endedAt;
  final String? endedBy;
  final EndReason? endReason;
  final bool isPaused;
  final String? pausedBy;
  final DateTime? pausedAt;

  const Connection({
    required this.id,
    required this.initiatorId,
    required this.receiverId,
    required this.status,
    this.createdAt,
    this.endedAt,
    this.endedBy,
    this.endReason,
    this.isPaused = false,
    this.pausedBy,
    this.pausedAt,
  });

  /// Returns the other participant's user id given the current user's id.
  String otherUserId(String currentUserId) =>
      initiatorId == currentUserId ? receiverId : initiatorId;

  bool get isActive => status != ConnectionStatus.ended && status != ConnectionStatus.pending;

  /// Whether messages can be sent right now — the status allows it AND
  /// neither side has paused. Reading history is still allowed while
  /// paused (same read-only treatment as `ended`); only sending is blocked.
  bool get canChatNow => status.canChat && !isPaused;

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'] as String,
      initiatorId: json['initiator_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: ConnectionStatus.fromDb(json['status'] as String),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
      endedBy: json['ended_by'] as String?,
      endReason:
          json['end_reason'] != null ? EndReason.fromDb(json['end_reason'] as String) : null,
      isPaused: json['is_paused'] as bool? ?? false,
      pausedBy: json['paused_by'] as String?,
      pausedAt: json['paused_at'] != null ? DateTime.parse(json['paused_at'] as String) : null,
    );
  }
}
