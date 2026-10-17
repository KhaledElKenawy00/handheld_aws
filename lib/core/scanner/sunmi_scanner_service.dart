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
  bool _paused = false;
  DateTime _lastPausedBuzzAt = DateTime.fromMillisecondsSinceEpoch(0);

  void configure(ScannerConfig c) => _debounceMs = c.debounceMs;

  /// إيقاف/استئناف استقبال المسح. عند الإيقاف نعطّل زر الماسح الفيزيائي
  /// في الفرموير نفسه (SUNMI ACTION_TRIGGER_CONTROL) — بدون كده الزر
  /// يفضل شغال ويصدر صوت/قراءة أثناء الرسالة المفتوحة.
  @override
  void setPaused(bool paused) {
    _paused = paused;
    _controlCh.invokeMethod(paused ? 'pause' : 'resume').catchError((Object e) {
      debugPrint('setPaused native failed: $e');
      // لو القناة مش موجودة، منوقفش المحاولة: على الأقل نوقف القراءة.
      if (paused) {
        try {
          stopScan();
        } catch (_) {}
      }
      return null;
    });
  }

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
    // مسحة وصلت أثناء رسالة/حوار مفتوح: نتجاهلها، نوقف الماسح والصوت،
    // ونستبدل صوت الماسح باهتزاز من الجهاز عشان اليوزر يحس إن فيه رسالة.
    if (_paused) {
      // وصلت مسحة رغم الإيقاف (الترّيجر كان لسه مفعّل) — نعيد تعطيله فورًا.
      try {
        _controlCh.invokeMethod('pause');
      } catch (_) {}
      final now = DateTime.now();
      if (now.difference(_lastPausedBuzzAt).inMilliseconds > 600) {
        _lastPausedBuzzAt = now;
        try {
          HapticFeedback.heavyImpact();
        } catch (_) {}
      }
      return;
    }
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
    // فيه رسالة/حوار مفتوح — لا تبدأ مسحًا جديدًا (تفادي الصوت والزحمة).
    if (_paused) return;
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
    // لا نترك زر الماسح معطّلًا في الفرموير لو الحوار كان مفتوحًا وقت الإغلاق.
    if (_paused) {
      try {
        await _controlCh.invokeMethod('resume');
      } catch (_) {}
      _paused = false;
    }
    await _nativeSub?.cancel();
    await _controller.close();
    _ready = false;
  }
}
