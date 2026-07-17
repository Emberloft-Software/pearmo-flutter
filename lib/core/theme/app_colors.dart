import 'package:flutter/material.dart';

/// Pearmo's "Electric Boom" palette (design set v5, light theme).
/// Neutrals carry 90% of every screen; violet is the primary action/data
/// color, lime is the single signature accent, and pink/magenta are
/// reserved for match & love moments. Lime and pink are *fill* colors —
/// they fail contrast as text on light surfaces, so their text-safe
/// siblings ([limeText], [magenta]) must be used for type.
class AppColors {
  AppColors._();

  // Brand — violet is primary (buttons, links, personality data).
  static const Color primary = Color(0xFF6C4CF1); // electric violet
  static const Color primaryDark = Color(0xFF5A3DD8);
  static const Color primaryLight = Color(0xFFEFEAFE);

  // Lime — the signature accent. Fills/badges/bars only, never text.
  static const Color secondary = Color(0xFFC6FF3D); // boom lime
  static const Color secondaryDark = Color(0xFF567C00); // lime's text-safe sibling
  static const Color secondaryLight = Color(0xFFF2FFD6);

  /// Alias for [secondaryDark]: use for any lime-family text.
  static const Color limeText = secondaryDark;

  // Pink family — match / love moments ONLY.
  static const Color pink = Color(0xFFFF3D7F); // electric pink (fills, large display)
  static const Color magenta = Color(0xFFC4176A); // pink's text-safe sibling
  static const Color pinkLight = Color(0xFFFFE9F1);

  static const Color accentLavender = Color(0xFFB7A6FF);
  static const Color accentYellow = Color(0xFFFFD166);

  // Neutrals
  static const Color background = Color(0xFFFAF8FF); // paper
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F0FB); // single neutral tint
  static const Color textPrimary = Color(0xFF17101F); // ink
  static const Color textSecondary = Color(0xFF575068);
  static const Color divider = Color(0xFFE8E2F8);

  // Status / safety — functional colors stay conventional (amber/green/red)
  // so warnings and errors read instantly; only decorative statuses use the
  // brand family.
  static const Color success = Color(0xFF4CAF82);
  static const Color warning = Color(0xFFF2A93B);
  static const Color error = Color(0xFFE5604D);
  static const Color danger = Color(0xFFD64545);

  // Connection-status colors used across the app
  static const Color statusPending = Color(0xFFF2A93B);
  static const Color statusIceBreaking = Color(0xFFB7A6FF);
  static const Color statusLimitedChat = Color(0xFF6C4CF1);
  static const Color statusOpenChat = Color(0xFF4CAF82);
  static const Color statusMediaUnlocked = Color(0xFFFF3D7F);
  static const Color statusDatePlanned = Color(0xFFC4176A);
  static const Color statusEnded = Color(0xFF575068);

  /// Deep magenta → violet, the shared stage every avatar/hero sits on.
  static const List<Color> heroGradient = [magenta, primary];

  /// Legacy generated-avatar background palette. Only used as the fallback
  /// when a bundled character asset fails to load — kept so old `av_XXX`
  /// ids and error states still render something friendly.
  static const List<Color> avatarPalette = [
    Color(0xFFB7A6FF),
    Color(0xFF8467F5),
    Color(0xFFFF8AB4),
    Color(0xFFD6C9FB),
    Color(0xFFA8D62E),
    Color(0xFFF694C1),
    Color(0xFFCDB4DB),
    Color(0xFFA0C4FF),
  ];
}
