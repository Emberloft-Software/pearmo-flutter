import 'package:flutter/material.dart';

/// Pearmo's brand palette — warm peach/coral primary (a nod to "Pearmo"),
/// a calm teal/lavender accent pair, and a soft warm-neutral background so
/// the app feels bubbly and friendly without tipping into childish, and
/// stays calm/trustworthy on safety & consent screens.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFFF8C6B); // Pearmo coral/peach
  static const Color primaryDark = Color(0xFFE8704C);
  static const Color primaryLight = Color(0xFFFFD8C9);

  static const Color secondary = Color(0xFF5FBFB3); // calm teal
  static const Color secondaryDark = Color(0xFF3F9D92);
  static const Color secondaryLight = Color(0xFFCFF1EC);

  static const Color accentLavender = Color(0xFFB8A9F3);
  static const Color accentYellow = Color(0xFFFFD166);

  // Neutrals
  static const Color background = Color(0xFFFFF8F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF6EFE9);
  static const Color textPrimary = Color(0xFF2D2A32);
  static const Color textSecondary = Color(0xFF7A7480);
  static const Color divider = Color(0xFFEDE4DC);

  // Status / safety
  static const Color success = Color(0xFF4CAF82);
  static const Color warning = Color(0xFFF2A93B);
  static const Color error = Color(0xFFE5604D);
  static const Color danger = Color(0xFFD64545);

  // Connection-status colors used across the app
  static const Color statusPending = Color(0xFFF2A93B);
  static const Color statusIceBreaking = Color(0xFFB8A9F3);
  static const Color statusLimitedChat = Color(0xFF5FBFB3);
  static const Color statusOpenChat = Color(0xFF4CAF82);
  static const Color statusMediaUnlocked = Color(0xFFFF8C6B);
  static const Color statusDatePlanned = Color(0xFFE8704C);
  static const Color statusEnded = Color(0xFF7A7480);

  static const List<Color> heroGradient = [primary, accentLavender];

  /// Avatar background palette — cheerful, varied colors used to render
  /// generated avatars deterministically from a user's `avatar_id`.
  static const List<Color> avatarPalette = [
    Color(0xFFFFB4A2),
    Color(0xFFB8A9F3),
    Color(0xFF8ECAE6),
    Color(0xFFFFD166),
    Color(0xFF95D5B2),
    Color(0xFFF694C1),
    Color(0xFFCDB4DB),
    Color(0xFFA0C4FF),
  ];
}
