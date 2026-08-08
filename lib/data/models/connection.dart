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

  const Connection({
    required this.id,
    required this.initiatorId,
    required this.receiverId,
    required this.status,
    this.createdAt,
    this.endedAt,
    this.endedBy,
    this.endReason,
  });

  /// Returns the other participant's user id given the current user's id.
  String otherUserId(String currentUserId) =>
      initiatorId == currentUserId ? receiverId : initiatorId;

  bool get isActive => status != ConnectionStatus.ended && status != ConnectionStatus.pending;

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
    );
  }
}
