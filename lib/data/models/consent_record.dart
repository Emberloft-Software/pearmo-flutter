import '../../core/constants/enums.dart';

/// Row from the `active_consents` view — whether both participants in a
/// connection have agreed to a given unlock type.
class ActiveConsent {
  final String connectionId;
  final ConsentType consentType;
  final bool isGranted;

  const ActiveConsent({
    required this.connectionId,
    required this.consentType,
    required this.isGranted,
  });

  factory ActiveConsent.fromJson(Map<String, dynamic> json) {
    return ActiveConsent(
      connectionId: json['connection_id'] as String,
      consentType: ConsentType.fromDb(json['consent_type'] as String),
      isGranted: json['is_granted'] as bool? ?? false,
    );
  }
}
