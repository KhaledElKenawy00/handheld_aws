import 'dart:async';

import 'scanner_service.dart';

/// للاختبارات فقط — ممنوع استخدامه في النسخة النهائية على الجهاز.
class MockScannerService implements ScannerService {
  final _c = StreamController<String>.broadcast();
  bool _paused = false;
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
  @override
  void setPaused(bool paused) => _paused = paused;

  void emit(String code) {
    if (_paused) return;
    _c.add(code);
  }
}
