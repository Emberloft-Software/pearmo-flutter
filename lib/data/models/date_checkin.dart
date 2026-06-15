/// Row from `date_checkins`. Created/updated via the `date-checkin` edge
/// function (create / acknowledge / cancel), but read directly so the UI
/// can show upcoming and past check-ins.
class DateCheckin {
  final String id;
  final String connectionId;
  final String createdBy;
  final DateTime scheduledFor;
  final String emergencyContact;
  final String status; // scheduled / acknowledged / cancelled / missed
  final DateTime? acknowledgedAt;

  const DateCheckin({
    required this.id,
    required this.connectionId,
    required this.createdBy,
    required this.scheduledFor,
    required this.emergencyContact,
    required this.status,
    this.acknowledgedAt,
  });

  bool get isUpcoming => status == 'scheduled' && scheduledFor.isAfter(DateTime.now());
  bool get needsAcknowledgement =>
      status == 'scheduled' && scheduledFor.isBefore(DateTime.now().add(const Duration(minutes: 30)));

  factory DateCheckin.fromJson(Map<String, dynamic> json) {
    return DateCheckin(
      id: json['id'] as String,
      connectionId: json['connection_id'] as String,
      createdBy: json['created_by'] as String,
      scheduledFor: DateTime.parse(json['scheduled_for'] as String),
      emergencyContact: json['emergency_contact'] as String,
      status: json['status'] as String? ?? 'scheduled',
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'] as String)
          : null,
    );
  }
}
