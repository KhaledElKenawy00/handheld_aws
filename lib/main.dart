import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/database/database_helper.dart';
import 'core/scanner/scanner_providers.dart';
import 'core/scanner/scanner_route_observer.dart';
import 'core/scanner/scanner_service.dart';
import 'core/scanner/sunmi_scanner_service.dart';

//حساب الأدمن: hossam@yad.tech — الباسورد: Hossam@997c8fSanad!
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // تهيئة قاعدة البيانات مبكرًا (إنشاء الجداول)
  try {
    await DatabaseHelper.instance.db;
  } catch (e) {
    debugPrint('db init failed: $e');
  }
  // تهيئة ماسح SUNMI — لا يمنع إقلاع التطبيق عند الفشل
  final ScannerService scanner = sunmiServiceSingleton;
  try {
    await scanner.initialize();
    // طبّق إعدادات السكانر المحفوظة (debounce) — يدعم L2s Pro بدون تهنيج
    // من المسح المزدوج.
    try {
      final db = await DatabaseHelper.instance.db;
      final rows = await db.query(
        'app_settings',
        where: 'key=?',
        whereArgs: ['scanner_debounce_ms'],
      );
      final ms = rows.isNotEmpty
          ? int.tryParse((rows.first['value'] ?? '400').toString()) ?? 400
          : 400;
      if (scanner is SunmiScannerService) {
        scanner.configure(ScannerConfig(debounceMs: ms.clamp(100, 2000)));
      }
    } catch (_) {}
  } catch (e) {
    debugPrint('scanner init failed: $e');
  }
  // تهيئة Supabase (التراخيص) — لا تمنع الإقلاع أوفلاين
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('supabase init failed: $e');
  }
  runApp(
    ProviderScope(
      overrides: [scannerServiceProvider.overrideWithValue(scanner)],
      child: SanadApp(
        navigatorObservers: [ScannerRouteObserver(scanner)],
      ),
    ),
  );
}
