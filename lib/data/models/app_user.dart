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

  const AppUser({
    required this.id,
    this.phone,
    this.verificationTier = VerificationTier.unverified,
    this.isBanned = false,
    this.isActive = true,
    this.banReason,
  });

  /// Whether this account should be allowed to use the app at all.
  bool get isBlocked => isBanned || !isActive;

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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
      };
}
