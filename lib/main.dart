import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/scanner/scanner_providers.dart';
import 'core/scanner/scanner_service.dart';

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
  } catch (e) {
    debugPrint('scanner init failed: $e');
  }
  runApp(
    ProviderScope(
      overrides: [
        scannerServiceProvider.overrideWithValue(scanner),
      ],
      child: const SanadApp(),
    ),
  );
}
