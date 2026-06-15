import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/matches_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// One of today's curated candidates, shown as a tappable card on the
/// matches screen. Always leads with the avatar — a photo is never shown
/// here even if the candidate has opted in, to keep the daily list
/// consistent and low-pressure.
class MatchCardWidget extends StatelessWidget {
  const MatchCardWidget({super.key, required this.card, required this.onTap});

  final MatchCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = card.profile;

    return PearmoCard(
      onTap: onTap,
      child: Row(
        children: [
          AvatarDisplay(avatarId: profile.avatarId, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${profile.age} · ${profile.gender.label}', style: AppTextStyles.title),
                    if (profile.verificationTier.label != 'Unverified') ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: AppColors.secondary, size: 18),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(profile.relationshipIntent.label, style: AppTextStyles.body),
                if (profile.regionName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.regionName!,
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
