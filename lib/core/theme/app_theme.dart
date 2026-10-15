import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_text_styles.dart';

/// Theme مركزي — Meadow Green + Cairo + RTL.
/// أي تغيير في Primary هنا ينعكس على التطبيق كله.
class AppTheme {
  // ── re-export للأسماء القديمة (توافق مع الكود الحالي) ──
  static const Color navy = AppColors.primaryDark;
  static const Color navyLight = AppColors.primaryDeep;
  static const Color accent = AppColors.primary;
  static const Color accentBright = AppColors.meadow800;
  static const Color accentSoft = AppColors.accentSoft;
  static const Color success = AppColors.successStrong;
  static const Color successBg = AppColors.successBg;
  static const Color warning = AppColors.warning;
  static const Color warningBg = AppColors.warningBg;
  static const Color danger = AppColors.danger;
  static const Color dangerBg = AppColors.dangerBg;
  static const Color bg = AppColors.background;
  static const Color ink = AppColors.textPrimary;
  static const Color inkSoft = AppColors.textSecondary;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTextStyles.family,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.3),
        headlineSmall: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.3),
        titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.35),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.35),
        titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.4),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.5),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            height: 1.5),
        bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            height: 1.5),
        labelLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.4),
        labelMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.family,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 24),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xB3FFFFFF),
        indicatorColor: Colors.white,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(
            fontFamily: AppTextStyles.family,
            fontSize: 15,
            fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(
            fontFamily: AppTextStyles.family,
            fontSize: 14,
            fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusCard),
          side: const BorderSide(
              color: AppColors.borderSoft, width: 1),
        ),
        color: Colors.white,
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
            fontFamily: AppTextStyles.family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary),
        subtitleTextStyle: TextStyle(
            fontFamily: AppTextStyles.family,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary),
        iconColor: AppColors.primary,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(
            fontSize: 14, color: AppColors.textMuted),
        labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary),
        helperStyle: const TextStyle(
            fontSize: 12, color: AppColors.textMuted),
        prefixIconColor: AppColors.primary,
        suffixIconColor: AppColors.textSecondary,
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusField),
          borderSide:
              const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusField),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusField),
          borderSide:
              const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusField),
          borderSide:
              const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.padFieldH,
            vertical: AppDimensions.padFieldV),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        extendedTextStyle: TextStyle(
            fontFamily: AppTextStyles.family,
            fontSize: 14,
            fontWeight: FontWeight.w800),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize:
              const Size(64, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  AppDimensions.radiusButton)),
          textStyle: const TextStyle(
              fontFamily: AppTextStyles.family,
              fontSize: 15,
              fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize:
              const Size(64, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  AppDimensions.radiusButton)),
          textStyle: const TextStyle(
              fontFamily: AppTextStyles.family,
              fontSize: 15,
              fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(
              color: AppColors.primary, width: 1.4),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  AppDimensions.radiusButton)),
          textStyle: const TextStyle(
              fontFamily: AppTextStyles.family,
              fontSize: 14,
              fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
              fontFamily: AppTextStyles.family,
              fontSize: 14,
              fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.accentSoft,
        labelStyle: TextStyle(
            fontFamily: AppTextStyles.family,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary),
        side: BorderSide.none,
        shape: StadiumBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.accentSoft,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
            fontFamily: AppTextStyles.family,
            fontSize: 12,
            fontWeight: FontWeight.w700)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: AppTextStyles.onPrimary(size: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                AppDimensions.radiusDialog)),
        titleTextStyle: AppTextStyles.cardTitle,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 16,
      ),
    );
  }

  /// شارة كمية عالية التباين — تُستخدم في كل الأذون والقوائم
  static Color qtyBg(bool isReceipt) =>
      AppColors.qtyBg(isReceipt);
  static Color qtyFg(bool isReceipt) =>
      AppColors.qtyFg(isReceipt);
}
