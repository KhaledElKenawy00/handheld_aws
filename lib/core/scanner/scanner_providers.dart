import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'scanner_service.dart';
import 'sunmi_scanner_service.dart';

/// Singleton على مستوى التطبيق — يُهيأ مرة واحدة في main().
final scannerServiceProvider = Provider<ScannerService>((ref) {
  throw UnimplementedError('scannerServiceProvider must be overridden in main');
});

/// بث الأكواد للشاشات
final scanStreamProvider = StreamProvider<String>((ref) {
  return ref.watch(scannerServiceProvider).scanStream;
});

final sunmiServiceSingleton = SunmiScannerService();
