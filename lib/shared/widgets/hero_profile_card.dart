import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../avatars/avatar_catalog.dart';
import 'audio_intro_player.dart';
import 'signed_avatar_display.dart';
import 'verification_disclaimer.dart';

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
    this.tier,
    this.matchPercent,
    this.displayName,
    this.kicker,
    this.audioPath,
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

  /// If provided, tapping the tier badge opens a plain-language explanation
  /// of what this tier actually confirms (see `verification_disclaimer.dart`)
  /// — "verified" is terminology, not a claim of a background check.
  final VerificationTier? tier;

  /// 0–100 match score chip (candidate screens only); hidden when null.
  final int? matchPercent;

  /// Editorial name line (shown small, under the big title). Providing
  /// this switches to the editorial layout.
  final String? displayName;

  /// Small uppercase line at the top, e.g. "Profile · She/Her".
  final String? kicker;

  /// Voice-intro storage path; when set, a compact play button is embedded
  /// in the hero (editorial layout only).
  final String? audioPath;

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
      // Both the character's width and the text column's width are derived
      // from the actual card width rather than hard-coded. The art used to
      // be sized off a fixed 190px card height (so its width was constant on
      // every device) while the text column reserved a fixed 168px on the
      // right — on a narrow phone that left the name block ~90px wide, which
      // is what made this card look misaligned there but fine on a large
      // phone. The height is a *minimum* now too, so the card grows instead
      // of clipping when the system text scale is turned up.
      return LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          final artWidth = (cardWidth * 0.44).clamp(120.0, 210.0);
          // Text stops just before the art starts, with a small gutter.
          final textRightInset = (artWidth - 26).clamp(80.0, cardWidth * 0.5);

          return Container(
            decoration: decoration,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Lime glow behind the character, like the HTML hero.
                Positioned(
                  right: -34,
                  bottom: -46,
                  child: Container(
                    width: 220,
                    height: 175,
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
                // Character fills the card's full height — no dead space
                // above. `contain` (not `fitHeight`) so a tall card at a
                // large text scale scales the art down to the reserved
                // width instead of letting it grow under the name.
                Positioned(
                  right: -22,
                  top: 6,
                  bottom: -8,
                  width: artWidth,
                  child: Image.asset(
                    character.assetPath,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                // Non-positioned child: this is what gives the Stack its
                // height, so the card tracks its own content.
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 190),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, textRightInset, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Kicker pinned to the top so the card has no empty
                        // band.
                        if (kicker != null)
                          Text(
                            kicker!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.secondary,
                              fontSize: 10.5,
                              letterSpacing: 2,
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Big line: age · gender.
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.displayMedium.copyWith(
                                color: Colors.white,
                                fontSize: 30,
                                height: 1.02,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Small line: the character/display name.
                            Text(
                              displayName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: Colors.white.withValues(alpha: 0.85)),
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption
                                          .copyWith(color: Colors.white.withValues(alpha: 0.65)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // Voice-intro play button, below the location line.
                            if (audioPath != null && audioPath!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              AudioIntroPlayer(storagePath: audioPath!, compact: true),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
                GestureDetector(
                  onTap: tier == null
                      ? null
                      : () => showVerificationInfoDialog(context, tier: tier),
                  child: _HeroBadge(
                    icon: isVerified ? Icons.verified : Icons.shield_outlined,
                    label: tierLabel!,
                    background: Colors.white.withValues(alpha: isVerified ? 0.92 : 0.25),
                    foreground: isVerified ? AppColors.primaryDark : Colors.white,
                  ),
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
