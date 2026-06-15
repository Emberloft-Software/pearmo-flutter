import '../../core/constants/enums.dart';

/// Row from the `users` table — the minimal account record created right
/// after auth, separate from the richer `profiles` row.
class AppUser {
  final String id;
  final String? phone;
  final VerificationTier verificationTier;

  const AppUser({
    required this.id,
    this.phone,
    this.verificationTier = VerificationTier.unverified,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      phone: json['phone'] as String?,
      verificationTier: VerificationTier.fromDb(
        json['verification_tier'] as String? ?? 'unverified',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
      };
}
