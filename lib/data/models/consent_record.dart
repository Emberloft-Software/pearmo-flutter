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
  final DateTime? requestedAt;
  final DateTime? revokedAt;

  const ConsentRecord({
    required this.connectionId,
    required this.consentType,
    this.requestedBy,
    required this.isActive,
    this.revokedBy,
    this.requestedAt,
    this.revokedAt,
  });

  /// True once this row has been revoked/declined and *not* re-requested
  /// since. Deliberately derived from the `revoked_*` columns rather than
  /// `is_active`: `update-consent`'s source isn't visible from this repo
  /// (see CLAUDE.md), so whether a freshly-created pending row starts
  /// `is_active = true` ("live request") or `false` ("not yet mutually
  /// agreed") is unverified — and reading it the wrong way collapses every
  /// pending request into "nothing here". `revoked_by`/`revoked_at` are
  /// unambiguous: only a revoke/decline ever sets them.
  ///
  /// The timestamp comparison covers the case where `update-consent`
  /// re-requests by updating the same row without clearing `revoked_at` —
  /// a request newer than the revoke means it's pending again.
  bool get isRevoked {
    final revoked = revokedAt;
    if (revoked == null) return revokedBy != null && requestedAt == null;
    final requested = requestedAt;
    if (requested != null && requested.isAfter(revoked)) return false;
    return true;
  }

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String key) {
      final value = json[key];
      return value == null ? null : DateTime.tryParse(value as String);
    }

    return ConsentRecord(
      connectionId: json['connection_id'] as String,
      consentType: ConsentType.fromDb(json['consent_type'] as String),
      requestedBy: json['requested_by'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      revokedBy: json['revoked_by'] as String?,
      requestedAt: parse('requested_at'),
      revokedAt: parse('revoked_at'),
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

/// Derives the panel state for one consent type.
///
/// Deliberately does **not** branch on [ConsentRecord.isActive] — see
/// [ConsentRecord.isRevoked] for why (its meaning on a pending row is
/// unverified, and guessing wrong made every pending request invisible to
/// both sides). The only signals used are: the `active_consents` view's
/// both-agreed boolean, the `revoked_*` columns, and `requested_by` — all
/// of which have unambiguous meanings.
ConsentState resolveConsentState({
  required String currentUserId,
  required bool isGranted,
  required ConsentRecord? record,
}) {
  if (isGranted) return ConsentState.granted;
  if (record == null) return ConsentState.none;
  if (record.isRevoked) {
    return record.revokedBy == currentUserId
        ? ConsentState.revokedByMe
        : ConsentState.revokedByThem;
  }
  // A row that exists, isn't mutually granted, and hasn't been revoked is
  // a live request — whoever asked is waiting on the other one.
  if (record.requestedBy == currentUserId) return ConsentState.waitingOnThem;
  return ConsentState.needsYourResponse;
}
