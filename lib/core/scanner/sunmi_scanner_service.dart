import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'scanner_service.dart';

/// تكامل ماسح الجهاز المدمج — بدون أي حزمة خارجية (يعمل مع Dart 3.11).
/// يدعم SUNMI L2s Pro وأجهزة Honeywell (عبر Data Intent Claim).
///
/// القنوات الأصلية (انظر MainActivity.kt):
///  - EventChannel `com.sanad.scanner/stream`: يستقبل كل مسح من
///    Broadcast الرسمي `com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED`
///    (extra `data` — ووضع Broadcast Output) + fallbacks لأجهزة L2s Pro
///    (`ACTION_DECODE_DATA` / `ACTION_SCAN_RESULT` + مفاتيح barcode/code/...
///    + بايتات source_byte/data_byte) + بث Honeywell
///    (`com.sanad.scanner.HONEYWELL_DATA` بعد Claim تلقائي).
///  - MethodChannel `com.sanad.scanner/control`: أوامر `trigger` / `stop`
///    تُترجم في MainActivity إلى بثّات SUNMI الرسمية لتشغيل الماسح برمجيًا.
///  - Keyboard-wedge: زر المسح الفيزيائي يصب في أي TextField مركّز
///    تلقائيًا بدون أي كود (وضع KeyEvent الافتراضي) — لذلك كل حقول
///    الباركود/الرمز فيها autofocus + زر مسح برمجي كبديل.
/// ملاحظة جهاز L2s Pro: فعّل من إعدادات الماسح وضع Broadcast Output
/// أو KeyEvent حسب الاستخدام — التطبيق يدعم الاثنين معًا.
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
      // بعض أجهزة L2s Pro ترسل الباركود مع \n في النهاية (wedge) —
      // _emit بيعمل trim تلقائيًا.
      _nativeSub = _streamCh.receiveBroadcastStream().listen(
        (dynamic e) {
          if (e == null) return;
          if (e is List<int>) {
            try {
              _emit(String.fromCharCodes(e));
            } catch (_) {
              _emit(e.toString());
            }
          } else {
            _emit(e.toString());
          }
        },
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
