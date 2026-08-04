import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/matches_providers.dart';
import '../../../shared/avatars/avatar_catalog.dart';
import '../../../shared/widgets/widgets.dart';

/// One of today's curated candidates, shown as a tappable bento card on the
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
    final character = AvatarCatalog.resolve(profile.avatarId);
    final percent = (card.match.score * 100).round().clamp(0, 100);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              // Character on the shared stage gradient — rounded bento tile.
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: AppColors.heroGradient,
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  character.assetPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${profile.age} · ${profile.gender.label}',
                            style: AppTextStyles.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Shown for every tier, unverified included — see
                        // TierChip's doc for why hiding it was the wrong
                        // default. Flexible so the "Unverified" pill (the
                        // widest one) can't push this row past the card.
                        Flexible(
                          child: TierChip(tier: profile.verificationTier, compact: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'The ${character.character.name}'
                      '${profile.regionName != null ? ' · ${profile.regionName}' : ''}',
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.relationshipIntent.label,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Match score chip — ink tile, lime number (v5 "match" moment).
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent',
                      style: AppTextStyles.statNumber
                          .copyWith(fontSize: 20, color: AppColors.secondary),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'MATCH',
                      style: AppTextStyles.label
                          .copyWith(fontSize: 8, color: Colors.white70, letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
