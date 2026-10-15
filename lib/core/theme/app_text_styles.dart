import 'package:flutter/material.dart';

import 'app_colors.dart';

/// مقاسات الخطوط الموحدة — Cairo.
/// Page Title 24-28 / Section 20-22 / Card 17-19 / Body 15-17
/// Small 12-14 / Numbers 18-24.
class AppTextStyles {
  AppTextStyles._();

  static const String family = 'Cairo';

  static const TextStyle pageTitle = TextStyle(
    fontFamily: family,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    height: 1.5,
  );

  static const TextStyle number = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle numberSmall = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.4,
  );

  static TextStyle onPrimary({
    double size = 14,
    FontWeight weight = FontWeight.w800,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        color: Colors.white,
        height: 1.4,
      );
}
