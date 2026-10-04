import 'package:flutter/material.dart';

/// هوية بصرية: كحلي داكن + أزرق + أبيض — Material3 — عربي RTL
/// خطوط كبيرة واضحة + تباين عالٍ للقراءة على أجهزة SUNMI.
class AppTheme {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color navyLight = Color(0xFF14305E);
  static const Color accent = Color(0xFF1565C0);
  static const Color accentBright = Color(0xFF1E88E5);
  static const Color accentSoft = Color(0xFFE3F0FD);
  static const Color success = Color(0xFF1B7A2B);
  static const Color successBg = Color(0xFFE6F4EA);
  static const Color warning = Color(0xFFE65100);
  static const Color warningBg = Color(0xFFFFF0E0);
  static const Color danger = Color(0xFFB71C1C);
  static const Color dangerBg = Color(0xFFFFEBEE);
  static const Color bg = Color(0xFFF4F6FB);
  static const Color ink = Color(0xFF101A2E);
  static const Color inkSoft = Color(0xFF3A4763);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      primary: navy,
      secondary: accent,
      surface: Colors.white,
    );
    // خطوط متوسطة واضحة — مقاس مريح للقراءة على أجهزة SUNMI
    const text = TextTheme(
      displayLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: ink, height: 1.3),
      headlineSmall: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: ink, height: 1.3),
      titleLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w800, color: ink, height: 1.35),
      titleMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: ink, height: 1.35),
      titleSmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: ink, height: 1.4),
      bodyLarge: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: ink, height: 1.5),
      bodyMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: ink, height: 1.5),
      bodySmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: inkSoft, height: 1.5),
      labelLarge: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: ink, height: 1.4),
      labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: ink, height: 1.4),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Cairo',
      textTheme: text,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      // التبويبات تحت الاب بار (المعاملات/الأطراف): نص أبيض صريح
      // على خلفية كحلي — المحدد أبيض عريض وغير المحدد أبيض باهت.
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xB3FFFFFF),
        indicatorColor: Colors.white,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ink),
        subtitleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: inkSoft),
        leadingAndTrailingTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(fontSize: 12, color: inkSoft),
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: ink),
        helperStyle: const TextStyle(fontSize: 11, color: inkSoft),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        extendedTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w800),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w800),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w700),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: const ChipThemeData(
        labelStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w700),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: navy,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
    );
  }

  /// شارة كمية كبيرة عالية التباين — تُستخدم في كل الأذون والقوائم
  static Color qtyBg(bool isReceipt) =>
      isReceipt ? successBg : warningBg;
  static Color qtyFg(bool isReceipt) =>
      isReceipt ? success : warning;
}
