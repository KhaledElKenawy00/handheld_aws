import 'package:flutter/material.dart';

/// Meadow Green palette — الهوية البصرية الجديدة لتطبيق SANAD.
/// المصدر الوحيد للألوان في التطبيق كله.
class AppColors {
  AppColors._();

  // ── Meadow Green scale ──────────────────────────────
  static const Color meadow100 = Color(0xFFD9ED92);
  static const Color meadow200 = Color(0xFFB5E48C);
  static const Color meadow300 = Color(0xFF99D98C);
  static const Color meadow400 = Color(0xFF76C893);
  static const Color meadow500 = Color(0xFF52B69A);
  static const Color meadow600 = Color(0xFF34A0A4);
  static const Color meadow700 = Color(0xFF168AAD);
  static const Color meadow800 = Color(0xFF1A759F);
  static const Color meadow900 = Color(0xFF1E6091);
  static const Color meadow950 = Color(0xFF184E77);

  // ── Semantic roles ──────────────────────────────────
  static const Color primary = meadow700; // #168AAD
  static const Color primaryDark = meadow950; // #184E77
  static const Color primaryDeep = meadow900; // #1E6091
  static const Color secondary = meadow500; // #52B69A
  static const Color success = meadow400; // #76C893
  static const Color successStrong = Color(0xFF1B7A2B);
  static const Color lightGreen = meadow100; // #D9ED92

  static const Color textPrimary = meadow950; // #184E77
  static const Color textSecondary = meadow900; // #1E6091
  static const Color textMuted = Color(0xFF5B6B7B);

  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFD9E2E3);
  static const Color borderSoft = Color(0xFFE8EFF0);

  static const Color ink = meadow950;
  static const Color inkSoft = textSecondary;

  // legacy aliases — حتى لا ينكسر أي كود قديم يشير للأسماء القديمة
  static const Color navy = primaryDark;
  static const Color navyLight = primaryDeep;
  static const Color accent = primary;
  static const Color accentBright = meadow800;
  static const Color accentSoft = Color(0xFFE3F1F4);
  static const Color successBg = Color(0xFFE6F4EA);
  static const Color warning = Color(0xFFE65100);
  static const Color warningBg = Color(0xFFFFF0E0);
  static const Color danger = Color(0xFFB71C1C);
  static const Color dangerBg = Color(0xFFFFEBEE);
  static const Color bg = background;

  // ── Header gradient (يُستخدم في الـ headers فقط) ────
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      meadow100, // #D9ED92
      meadow400, // #76C893
      meadow600, // #34A0A4
      meadow700, // #168AAD
      meadow950, // #184E77
    ],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [meadow700, meadow950],
  );

  /// لون شارة الكمية حسب نوع العملية
  static Color qtyBg(bool isReceipt) =>
      isReceipt ? successBg : warningBg;
  static Color qtyFg(bool isReceipt) =>
      isReceipt ? successStrong : warning;

  /// لون حالة المخزون
  static Color stockBg(bool isLow) => isLow ? dangerBg : successBg;
  static Color stockFg(bool isLow) => isLow ? danger : successStrong;
}
