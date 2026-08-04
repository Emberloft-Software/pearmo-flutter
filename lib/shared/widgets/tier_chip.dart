import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'verification_disclaimer.dart';

/// Compact verification-state pill, rendered for **every** tier — including
/// `unverified`.
///
/// Deliberately not hidden when unverified. Match cards and the profile
/// header both used to show a badge only for verified users, which meant an
/// unverified profile looked like a profile with no opinion about
/// verification at all, and it let the app label *other* people while the
/// viewer's own identical state stayed invisible. Showing it everywhere,
/// including on your own profile, is what makes the same-tier pool rule
/// read as symmetric rather than as a hidden penalty.
///
/// Unverified renders muted/neutral, never red. It's a factual state that
/// usually describes the viewer too — not a danger signal — and a red badge
/// on half the app trains people to ignore it within days.
///
/// Always tappable into [showVerificationInfoDialog] so the exact claim
/// ("what has actually been confirmed") is one tap from every badge.
class TierChip extends StatelessWidget {
  const TierChip({super.key, required this.tier, this.compact = false});

  final VerificationTier tier;

  /// Drops the label for *verified* tiers only, where the icon alone reads
  /// clearly and horizontal space is tight (match cards). Unverified always
  /// keeps its label — a bare muted icon would be exactly the ambiguity
  /// this widget exists to remove.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final verified = tier.isAtLeastSelfieVerified;
    final showLabel = !compact || !verified;

    return GestureDetector(
      onTap: () => showVerificationInfoDialog(context, tier: tier),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: showLabel ? 8 : 5, vertical: 4),
        decoration: BoxDecoration(
          color: verified ? AppColors.secondary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: verified ? null : Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Icons.verified_user : Icons.shield_outlined,
              size: 12,
              color: verified ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  tier.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: verified ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
