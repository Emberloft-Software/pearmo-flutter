import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../avatars/avatar_catalog.dart';
import 'signed_avatar_display.dart';

/// Full-width gradient hero used at the top of profile screens (own profile
/// and candidate detail) — the one vivid moment per screen. Shows the
/// avatar on the shared stage gradient, an age/gender line, the character
/// badge (lime) and an optional verification badge, plus an optional match
/// score chip.
class HeroProfileCard extends StatelessWidget {
  const HeroProfileCard({
    super.key,
    required this.avatarId,
    required this.title,
    this.photoPath,
    this.showPhoto = false,
    this.subtitle,
    this.tierLabel,
    this.isVerified = false,
    this.matchPercent,
  });

  final String avatarId;
  final String? photoPath;
  final bool showPhoto;

  /// e.g. "26 · Woman".
  final String title;

  /// e.g. region name.
  final String? subtitle;

  /// Verification badge text; hidden when null.
  final String? tierLabel;
  final bool isVerified;

  /// 0–100 match score chip (candidate screens only); hidden when null.
  final int? matchPercent;

  @override
  Widget build(BuildContext context) {
    final character = AvatarCatalog.resolve(avatarId).character;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          SignedAvatarDisplay(
            avatarId: avatarId,
            photoPath: photoPath,
            showPhoto: showPhoto,
            size: 120,
            borderColor: Colors.white,
          ),
          const SizedBox(height: 14),
          Text(title, style: AppTextStyles.headline.copyWith(color: Colors.white)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.caption.copyWith(color: Colors.white70)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _HeroBadge(
                icon: Icons.auto_awesome,
                label: 'The ${character.name}',
                background: AppColors.secondary,
                foreground: AppColors.textPrimary,
              ),
              if (tierLabel != null)
                _HeroBadge(
                  icon: isVerified ? Icons.verified : Icons.shield_outlined,
                  label: tierLabel!,
                  background: Colors.white.withValues(alpha: isVerified ? 0.92 : 0.25),
                  foreground: isVerified ? AppColors.primaryDark : Colors.white,
                ),
              if (matchPercent != null)
                _HeroBadge(
                  icon: Icons.bolt,
                  label: '$matchPercent% match',
                  background: AppColors.textPrimary,
                  foreground: AppColors.secondary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            character.tagline,
            style: AppTextStyles.caption.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
