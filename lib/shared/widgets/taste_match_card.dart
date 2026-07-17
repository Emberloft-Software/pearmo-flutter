import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'avatar_display.dart';

/// "You both play Indie on repeat · 4 shared genres" — overlapping avatars
/// plus the real genre overlap between two users. Renders nothing when
/// there is no overlap (no fake numbers, ever — artists are not collected
/// by the app, so only genres are compared).
class TasteMatchCard extends StatelessWidget {
  const TasteMatchCard({
    super.key,
    required this.myAvatarId,
    required this.theirAvatarId,
    required this.sharedGenres,
    this.matchPercent,
  });

  final String myAvatarId;
  final String theirAvatarId;
  final List<MusicGenre> sharedGenres;

  /// 0–100 compatibility score chip (ink tile, lime number — the v5
  /// "match" moment). Hidden when null (e.g. no daily-match row exists).
  final int? matchPercent;

  @override
  Widget build(BuildContext context) {
    if (sharedGenres.isEmpty) return const SizedBox.shrink();

    final headline = sharedGenres.first.label;
    final count = sharedGenres.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 48,
            child: Stack(
              children: [
                _face(myAvatarId),
                Positioned(left: 28, child: _face(theirAvatarId)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'You both play ',
                    style: AppTextStyles.bodyMedium,
                    children: [
                      TextSpan(
                        text: '$headline on repeat',
                        style: AppTextStyles.quote.copyWith(
                          fontSize: 16,
                          color: AppColors.magenta,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  count == 1 ? '1 shared genre' : '$count shared genres',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (matchPercent != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$matchPercent',
                    style: AppTextStyles.statNumber
                        .copyWith(fontSize: 19, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'MATCH',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 7.5,
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _face(String avatarId) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: AvatarDisplay(avatarId: avatarId, size: 44),
    );
  }
}
