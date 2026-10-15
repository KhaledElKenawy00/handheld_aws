import 'package:flutter/material.dart';

/// أبعاد موحدة لكل التطبيق — radius / padding / touch targets.
class AppDimensions {
  AppDimensions._();

  static const double radiusCard = 18;
  static const double radiusField = 14;
  static const double radiusButton = 14;
  static const double radiusBadge = 10;
  static const double radiusDialog = 20;

  static const double padPage = 16;
  static const double padCard = 16;
  static const double padFieldH = 14;
  static const double padFieldV = 12;

  static const double buttonHeight = 52;
  static const double touchMin = 48;

  static const double iconAction = 22;
  static const double iconHero = 32;

  static const EdgeInsets pagePadding =
      EdgeInsets.all(padPage);
  static const EdgeInsets cardPadding =
      EdgeInsets.all(padCard);

  /// عرض متجاوب: عمود واحد للهواتف الصغيرة، عمودان للشاشات الأكبر.
  static int gridColumns(BuildContext context, {int wide = 2}) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 700) return wide + 1;
    if (w >= 420) return wide;
    return wide - 1 < 1 ? 1 : wide - 1;
  }

  static double gridAspect(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 1.35;
    if (w < 420) return 1.5;
    return 1.65;
  }
}
