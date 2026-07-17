import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Icon per music genre — stroke icons on the neutral tint, per the v5
/// restrained-color rule (icons never carry their own accent colors).
IconData genreIcon(MusicGenre genre) => switch (genre) {
      MusicGenre.pop => Icons.star_outline,
      MusicGenre.rock => Icons.local_fire_department_outlined,
      MusicGenre.hipHop => Icons.mic_none,
      MusicGenre.indie => Icons.album_outlined,
      MusicGenre.electronic => Icons.graphic_eq,
      MusicGenre.classical => Icons.piano,
      MusicGenre.jazz => Icons.music_note_outlined,
      MusicGenre.rnb => Icons.favorite_outline,
      MusicGenre.country => Icons.landscape_outlined,
      MusicGenre.metal => Icons.bolt_outlined,
      MusicGenre.kpop => Icons.auto_awesome_outlined,
      MusicGenre.reggae => Icons.waves,
    };

/// Two-column grid of a user's music genres as icon tiles — the v5 music
/// section treatment (replaces plain chips).
class GenreTileGrid extends StatelessWidget {
  const GenreTileGrid({super.key, required this.genres});

  final List<MusicGenre> genres;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3.1,
      children: [
        for (final genre in genres)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(genreIcon(genre), size: 18, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    genre.label,
                    style: AppTextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
