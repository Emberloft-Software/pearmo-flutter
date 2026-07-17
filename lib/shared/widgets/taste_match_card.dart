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
  });

  final String myAvatarId;
  final String theirAvatarId;
  final List<MusicGenre> sharedGenres;

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
