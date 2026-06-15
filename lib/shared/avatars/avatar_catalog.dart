import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// Generates Pearmo's avatar set deterministically from an `avatar_id`
/// string like `av_001`. No image assets needed — each avatar is a
/// colorful circle with an icon, so the set can grow just by bumping
/// [AppConstants.avatarCount].
class AvatarCatalog {
  AvatarCatalog._();

  static const List<IconData> _icons = [
    Icons.pets,
    Icons.local_florist,
    Icons.star,
    Icons.favorite,
    Icons.eco,
    Icons.cruelty_free,
    Icons.wb_sunny,
    Icons.nightlight_round,
    Icons.water_drop,
    Icons.local_fire_department,
    Icons.bolt,
    Icons.cloud,
    Icons.icecream,
    Icons.cookie,
    Icons.coffee,
    Icons.music_note,
    Icons.palette,
    Icons.sports_basketball,
    Icons.directions_bike,
    Icons.anchor,
    Icons.rocket_launch,
    Icons.diamond,
    Icons.spa,
    Icons.emoji_nature,
  ];

  /// All selectable avatar ids, e.g. `av_001` .. `av_024`.
  static List<String> get allIds =>
      List.generate(AppConstants.avatarCount, (i) => 'av_${(i + 1).toString().padLeft(3, '0')}');

  static int _indexOf(String avatarId) {
    final match = RegExp(r'(\d+)$').firstMatch(avatarId);
    final n = match != null ? int.tryParse(match.group(1)!) ?? 1 : 1;
    return (n - 1).clamp(0, 1 << 30);
  }

  static Color colorFor(String avatarId) {
    final i = _indexOf(avatarId);
    return AppColors.avatarPalette[i % AppColors.avatarPalette.length];
  }

  static IconData iconFor(String avatarId) {
    final i = _indexOf(avatarId);
    return _icons[i % _icons.length];
  }
}
