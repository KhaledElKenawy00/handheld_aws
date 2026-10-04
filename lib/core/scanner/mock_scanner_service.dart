import 'dart:async';

import 'scanner_service.dart';

/// للاختبارات فقط — ممنوع استخدامه في النسخة النهائية على الجهاز.
class MockScannerService implements ScannerService {
  final _c = StreamController<String>.broadcast();
  @override
  Stream<String> get scanStream => _c.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> triggerScan() async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<void> dispose() async => _c.close();

  void emit(String code) => _c.add(code);
}
