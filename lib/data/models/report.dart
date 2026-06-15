import '../../core/constants/enums.dart';

/// Payload for a row inserted into `reports`.
class Report {
  final String reporterId;
  final String reportedId;
  final String? connectionId;
  final ReportCategory category;
  final String description;

  const Report({
    required this.reporterId,
    required this.reportedId,
    this.connectionId,
    required this.category,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'reporter_id': reporterId,
        'reported_id': reportedId,
        if (connectionId != null) 'connection_id': connectionId,
        'category': category.dbValue,
        'description': description,
      };
}
