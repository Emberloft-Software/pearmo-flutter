import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized type system. Headings use the rounded, friendly "Baloo 2"
/// (the bubbly part of "bubbly but serious"), while body and safety-critical
/// copy use the highly-legible "Nunito Sans" so consent dialogs, safety
/// alerts and legal-ish text read as trustworthy, not playful.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _headingBase => GoogleFonts.baloo2(color: AppColors.textPrimary);
  static TextStyle get _bodyBase => GoogleFonts.nunitoSans(color: AppColors.textPrimary);

  static TextStyle get displayLarge =>
      _headingBase.copyWith(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2);

  static TextStyle get displayMedium =>
      _headingBase.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25);

  static TextStyle get headline =>
      _headingBase.copyWith(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get title =>
      _headingBase.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get bodyLarge =>
      _bodyBase.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);

  static TextStyle get body =>
      _bodyBase.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);

  static TextStyle get bodyMedium =>
      _bodyBase.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);

  static TextStyle get caption => _bodyBase.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textSecondary,
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
