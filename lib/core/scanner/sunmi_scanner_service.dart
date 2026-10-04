import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'scanner_service.dart';

/// تكامل SUNMI L2s Pro الرسمي — بدون أي حزمة خارجية (يعمل مع Dart 3.11).
///
/// القنوات الأصلية (انظر MainActivity.kt):
///  - EventChannel `com.sanad.scanner/stream`: يستقبل كل مسح من
///    Broadcast الرسمي `com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED`
///    (extra `data`) — وضع Broadcast Output.
///  - MethodChannel `com.sanad.scanner/control`: أوامر `trigger` / `stop`
///    تُترجم في MainActivity إلى بثّات SUNMI الرسمية لتشغيل الماسح برمجيًا.
///  - Keyboard-wedge: زر المسح الفيزيائي يصب في أي TextField مركّز
///    تلقائيًا بدون أي كود (وضع KeyEvent الافتراضي).
class SunmiScannerService implements ScannerService {
  final _controller = StreamController<String>.broadcast();
  StreamSubscription? _nativeSub;
  static const _streamCh = EventChannel('com.sanad.scanner/stream');
  static const _controlCh = MethodChannel('com.sanad.scanner/control');

  String _lastCode = '';
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _debounceMs = 400;
  bool _ready = false;

  void configure(ScannerConfig c) => _debounceMs = c.debounceMs;

  bool _debounced(String code) {
    final now = DateTime.now();
    if (code == _lastCode &&
        now.difference(_lastAt).inMilliseconds < _debounceMs) {
      return true;
    }
    _lastCode = code;
    _lastAt = now;
    return false;
  }

  void _emit(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;
    if (_debounced(code)) return;
    if (!_controller.isClosed) _controller.add(code);
  }

  @override
  Stream<String> get scanStream => _controller.stream;

  @override
  Future<void> initialize() async {
    if (_ready) return;
    try {
      _nativeSub = _streamCh.receiveBroadcastStream().listen(
        (dynamic e) => _emit(e.toString()),
        onError: (Object e) => debugPrint('sunmi broadcast err: $e'),
      );
    } catch (e) {
      debugPrint('native scanner channel unavailable: $e');
    }
    _ready = true;
  }

  @override
  Future<void> triggerScan() async {
    try {
      await _controlCh.invokeMethod('trigger');
    } on MissingPluginException {
      // على أجهزة غير SUNMI: يلتقط المستخدم الكود يدويًا / زر فيزيائي
      throw PlatformException(
          code: 'NO_SCANNER',
          message: 'ابدأ المسح بزر الجهاز الفيزيائي أو أدخل الكود يدويًا');
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      await _controlCh.invokeMethod('stop');
    } catch (e) {
      debugPrint('stopScan: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _nativeSub?.cancel();
    await _controller.close();
    _ready = false;
  }
}
