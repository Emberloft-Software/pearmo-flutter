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

/// Raw row from `consent_records` (one row per connection+type — see
/// CLAUDE.md). Unlike `active_consents` (which only exposes the both-agreed
/// boolean via `is_granted`), this carries `requestedBy`/`revokedBy` — real
/// user ids, not the ambiguous `user_a`/`user_b` columns whose mapping to
/// initiator/receiver isn't derivable from the schema — so the UI can tell
/// "I requested, waiting on them" from "they requested, respond" from "they
/// turned it off" by comparing these against the current user's id.
class ConsentRecord {
  final String connectionId;
  final ConsentType consentType;
  final String? requestedBy;
  final bool isActive;
  final String? revokedBy;

  const ConsentRecord({
    required this.connectionId,
    required this.consentType,
    this.requestedBy,
    required this.isActive,
    this.revokedBy,
  });

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      connectionId: json['connection_id'] as String,
      consentType: ConsentType.fromDb(json['consent_type'] as String),
      requestedBy: json['requested_by'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      revokedBy: json['revoked_by'] as String?,
    );
  }
}

/// The four states the "Shared unlocks" panel distinguishes for one
/// [ConsentType], derived from [ActiveConsent.isGranted] plus the raw
/// [ConsentRecord] for the same type.
enum ConsentState {
  /// Neither side has requested this yet.
  none,

  /// The current user requested it; waiting on the other participant.
  waitingOnThem,

  /// The other participant requested it; the current user hasn't responded.
  needsYourResponse,

  /// Both sides have agreed — unlocked.
  granted,

  /// It was granted before, then the current user turned it off.
  revokedByMe,

  /// It was granted before, then the other participant turned it off.
  revokedByThem,
}

ConsentState resolveConsentState({
  required String currentUserId,
  required bool isGranted,
  required ConsentRecord? record,
}) {
  if (isGranted) return ConsentState.granted;
  if (record == null) return ConsentState.none;
  if (!record.isActive) {
    if (record.revokedBy == null) return ConsentState.none;
    return record.revokedBy == currentUserId
        ? ConsentState.revokedByMe
        : ConsentState.revokedByThem;
  }
  if (record.requestedBy == currentUserId) return ConsentState.waitingOnThem;
  return ConsentState.needsYourResponse;
}
