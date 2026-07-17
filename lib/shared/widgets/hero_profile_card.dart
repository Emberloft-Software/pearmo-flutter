import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../avatars/avatar_catalog.dart';
import 'signed_avatar_display.dart';

/// Full-width gradient hero used at the top of profile screens — the one
/// vivid moment per screen.
///
/// Two layouts:
/// - **Editorial** (when [displayName] is provided): kicker line, big
///   display-face name on the left, the 3D character anchored large at the
///   bottom-right — mirrors the v5 HTML hero. Used on the own-profile
///   screen where the name is known.
/// - **Centered** (default): circular avatar, title, badges. Used on
///   candidate screens where no display name is exposed.
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
    this.displayName,
    this.kicker,
  });

  final String avatarId;
  final String? photoPath;
  final bool showPhoto;

  /// e.g. "26 · Woman".
  final String title;

  /// e.g. region name (centered) or "City, Country" (editorial).
  final String? subtitle;

  /// Verification badge text; hidden when null. Centered layout only.
  final String? tierLabel;
  final bool isVerified;

  /// 0–100 match score chip (candidate screens only); hidden when null.
  final int? matchPercent;

  /// Big editorial name. Providing this switches to the editorial layout.
  final String? displayName;

  /// Small uppercase line above the name, e.g. "Profile · She/Her".
  final String? kicker;

  @override
  Widget build(BuildContext context) {
    final character = AvatarCatalog.resolve(avatarId);

    final decoration = BoxDecoration(
      gradient: const LinearGradient(
        colors: AppColors.heroGradient,
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.circular(28),
    );

    if (displayName != null) {
      return Container(
        height: 216,
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Lime glow behind the character, like the HTML hero.
            Positioned(
              right: -30,
              bottom: -40,
              child: Container(
                width: 190,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.35),
                      AppColors.secondary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -18,
              bottom: -6,
              width: 168,
              child: Image.asset(
                character.assetPath,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: 20,
              right: 150,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kicker != null)
                    Text(
                      kicker!.toUpperCase(),
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.secondary,
                        fontSize: 10.5,
                        letterSpacing: 2,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    displayName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.displayMedium.copyWith(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 13, color: Colors.white.withValues(alpha: 0.65)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            subtitle!,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white.withValues(alpha: 0.65)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: decoration,
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
                label: 'The ${character.character.name}',
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
            character.character.tagline,
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
