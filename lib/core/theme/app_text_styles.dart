import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized type system (design set v5). Display/headings use
/// "Bricolage Grotesque" (characterful, only at large sizes), body and all
/// small text use the highly-legible "Schibsted Grotesk", and user quotes
/// ("in their own words") use "Instrument Serif" italic for an editorial
/// pull-quote feel. Nothing user-facing renders below 12px.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _headingBase =>
      GoogleFonts.bricolageGrotesque(color: AppColors.textPrimary);
  static TextStyle get _bodyBase =>
      GoogleFonts.schibstedGrotesk(color: AppColors.textPrimary);

  static TextStyle get displayLarge => _headingBase.copyWith(
      fontSize: 32, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.8);

  static TextStyle get displayMedium => _headingBase.copyWith(
      fontSize: 26, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5);

  static TextStyle get headline => _headingBase.copyWith(
      fontSize: 22, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.3);

  static TextStyle get title =>
      _headingBase.copyWith(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3);

  /// Big stat numbers (trust score, match %) — display face, tight.
  static TextStyle get statNumber => _headingBase.copyWith(
      fontSize: 36, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -1);

  static TextStyle get bodyLarge =>
      _bodyBase.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.55);

  static TextStyle get body =>
      _bodyBase.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);

  static TextStyle get bodyMedium =>
      _bodyBase.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);

  static TextStyle get caption => _bodyBase.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  /// Uppercase card labels ("TRUST SCORE") — small but bold + spaced.
  static TextStyle get label => _bodyBase.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 1.4,
        color: AppColors.textSecondary,
      );

  /// User quotes — italic serif, the app's editorial voice.
  static TextStyle get quote => GoogleFonts.instrumentSerif(
        fontSize: 20,
        fontStyle: FontStyle.italic,
        height: 1.45,
        color: AppColors.textPrimary,
      );

  static TextStyle get button =>
      _bodyBase.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2);

  static TextStyle get safetyNotice => _bodyBase.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.danger,
      );
}
