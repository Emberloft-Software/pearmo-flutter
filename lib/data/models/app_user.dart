import '../../core/constants/enums.dart';

/// Row from the `users` table — the minimal account record created right
/// after auth, separate from the richer `profiles` row.
class AppUser {
  final String id;
  final String? phone;
  final VerificationTier verificationTier;
  final bool isBanned;
  final bool isActive;
  final String? banReason;

  /// When this identity was most recently self-deleted, if ever. Purely a
  /// historical/safety record — it does NOT block login. The same phone can
  /// delete and re-onboard freely; `trust_score`/`report_count`/`reports`
  /// stay tied to this same `id` regardless, so a bad reputation can't be
  /// laundered away by deleting and starting over. See CLAUDE.md "Account
  /// deletion".
  final DateTime? lastDeletedAt;

  /// How many times this identity has gone through delete-and-recreate —
  /// a repeated pattern here is a signal a future moderation tool could use,
  /// even though a single deletion is never acted on automatically.
  final int deletionCount;

  const AppUser({
    required this.id,
    this.phone,
    this.verificationTier = VerificationTier.unverified,
    this.isBanned = false,
    this.isActive = true,
    this.banReason,
    this.lastDeletedAt,
    this.deletionCount = 0,
  });

  /// Whether this account should be allowed to use the app at all. Deletion
  /// history is deliberately NOT part of this — see `lastDeletedAt`.
  bool get isBlocked => isBanned || !isActive;

  bool get hasDeletedBefore => lastDeletedAt != null;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      phone: json['phone'] as String?,
      verificationTier: VerificationTier.fromDb(
        json['verification_tier'] as String? ?? 'unverified',
      ),
      isBanned: json['is_banned'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      banReason: json['ban_reason'] as String?,
      lastDeletedAt: json['last_deleted_at'] != null
          ? DateTime.parse(json['last_deleted_at'] as String)
          : null,
      deletionCount: json['deletion_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
      };
}
