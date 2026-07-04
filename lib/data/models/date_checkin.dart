/// Row from `date_checkins`. Created/updated via the `date-checkin` edge
/// function (create / acknowledge / cancel), but read directly so the UI
/// can show upcoming and past check-ins.
///
/// Column names/status values here must match the real `date_checkins`
/// schema (confirmed via `information_schema` — see CLAUDE.md), not the
/// generic "scheduled/acknowledged/missed" naming this model used to
/// assume: there is no `created_by`/`acknowledged_at` column, and `status`
/// is check-constrained to `active`/`checked_in`/`escalated`/`cancelled`.
class DateCheckin {
  final String id;
  final String connectionId;
  final String userId;
  final DateTime scheduledFor;
  final String emergencyContact;
  final DateTime? lastCheckedInAt;
  final String status; // active / checked_in / escalated / cancelled
  final DateTime? escalatedAt;

  const DateCheckin({
    required this.id,
    required this.connectionId,
    required this.userId,
    required this.scheduledFor,
    required this.emergencyContact,
    this.lastCheckedInAt,
    required this.status,
    this.escalatedAt,
  });

  bool get isUpcoming => status == 'active' && scheduledFor.isAfter(DateTime.now());
  bool get needsAcknowledgement =>
      status == 'active' && scheduledFor.isBefore(DateTime.now().add(const Duration(minutes: 30)));

  factory DateCheckin.fromJson(Map<String, dynamic> json) {
    return DateCheckin(
      id: json['id'] as String,
      connectionId: json['connection_id'] as String,
      userId: json['user_id'] as String,
      scheduledFor: DateTime.parse(json['scheduled_for'] as String),
      emergencyContact: json['emergency_contact'] as String,
      lastCheckedInAt: json['last_checked_in_at'] != null
          ? DateTime.parse(json['last_checked_in_at'] as String)
          : null,
      status: json['status'] as String? ?? 'active',
      escalatedAt:
          json['escalated_at'] != null ? DateTime.parse(json['escalated_at'] as String) : null,
    );
  }
}
