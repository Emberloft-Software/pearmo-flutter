import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// What each tier actually confirms — precise, not a marketing word. Shown
/// wherever a tier badge/label appears, per the explicit product decision
/// that "verified" is just terminology, not a claim of a background check.
String verificationClaimFor(VerificationTier tier) => switch (tier) {
      VerificationTier.unverified => "This person hasn't completed any verification yet.",
      VerificationTier.selfieVerified =>
        "We've confirmed a live selfie check, so this is a real person. Their age and identity "
            "haven't been separately confirmed.",
      VerificationTier.idVerified =>
        "We've confirmed a live selfie check, and that a submitted national ID matches their "
            "selfie and stated age.",
      VerificationTier.paidVerified => "This is a paid membership tier, unrelated to identity checks.",
    };

/// Always-true regardless of tier — the part that actually matters legally.
const String verificationSafetyDisclaimer =
    "Pearmo does not run criminal background checks on anyone. Verification confirms identity "
    "details like the above. It is not a guarantee of anyone's safety, character, or "
    "intentions. Always use your own judgement when meeting someone new.";

/// Persistent inline disclaimer box — used on the verification screen itself,
/// always visible rather than tap-to-reveal.
class VerificationDisclaimer extends StatelessWidget {
  const VerificationDisclaimer({super.key, this.tier});

  /// If provided, shows the tier-specific claim line above the universal
  /// safety disclaimer. If null, shows only the universal line.
  final VerificationTier? tier;

  @override
  Widget build(BuildContext context) {
    final tier0 = tier;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tier0 != null) ...[
                  Text(verificationClaimFor(tier0), style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                ],
                Text(verificationSafetyDisclaimer, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable info affordance for a verified badge shown elsewhere (candidate
/// cards, profile headers) — opens the same disclaimer in a dialog rather
/// than permanently occupying space on screens where the badge is one of
/// many elements.
Future<void> showVerificationInfoDialog(BuildContext context, {VerificationTier? tier}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('What does this mean?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tier != null) ...[
            Text(verificationClaimFor(tier), style: AppTextStyles.body),
            const SizedBox(height: 12),
          ],
          Text(verificationSafetyDisclaimer, style: AppTextStyles.body),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
      ],
    ),
  );
}
