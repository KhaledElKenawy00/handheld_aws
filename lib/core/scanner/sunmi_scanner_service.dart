import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sunmi_scanner/sunmi_scanner.dart' as sunmi;

import 'scanner_service.dart';

/// سائق الماسح المستخدم على الجهاز الحالي — واحد فقط يعمل في الوقت نفسه،
/// حتى لا يتزاحم سائقان على نفس رأس المسح.
enum ScannerBackend { sunmi, honeywell, none }

/// خدمة المسح الموحّدة.
///
/// - أجهزة SUNMI (L2s Pro ...): نستخدم حزمة `sunmi_scanner` — تربط خدمة
///   الماسح عبر AIDL (`scan`/`stop`) وتستقبل الكود من بثّ
///   `com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED` (مفتاح `data`) فقط.
/// - أجهزة Honeywell: نستخدم الجسر الأصلي (Data Collection SDK) عبر القناة
///   `com.sanad.scanner/stream`.
///
/// سبب الفصل: بعض أجهزة SUNMI L2s Pro بيبقى فيها رأس Honeywell، وكان سائق
/// Honeywell الأصلي يخطف الماسح من خدمة SUNMI في نفس الوقت → قراءة ناقصة/
/// مشوّشة. دلوقتي نختار سائقًا واحدًا حسب مُصنّع الجهاز.
class SunmiScannerService implements ScannerService {
  final _controller = StreamController<String>.broadcast();
  StreamSubscription? _nativeSub;
  StreamSubscription? _sunmiSub;
  static const _streamCh = EventChannel('com.sanad.scanner/stream');
  static const _controlCh = MethodChannel('com.sanad.scanner/control');

  ScannerBackend _backend = ScannerBackend.none;
  ScannerBackend get backend => _backend;

  String _lastCode = '';
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _debounceMs = 400;
  bool _ready = false;
  bool _paused = false;
  bool _blockWedge = true;
  DateTime _lastPausedBuzzAt = DateTime.fromMillisecondsSinceEpoch(0);

  void configure(ScannerConfig c) {
    _debounceMs = c.debounceMs;
    _blockWedge = c.blockWedge;
    _applyWedgeSuppression();
  }

  /// على SUNMI: نمنع إخراج الماسح كـ keyboard-wedge حتى لا يتزاحم مع البثّ
  /// ويشوّه الحقل. لا تأثير على أجهزة Honeywell أو الكيبورد على الشاشة.
  void _applyWedgeSuppression() {
    if (_backend != ScannerBackend.sunmi) return;
    try {
      _controlCh.invokeMethod('setSuppressWedge', {'value': _blockWedge});
    } catch (_) {}
  }

  /// تحديد السائق حسب مُصنّع الجهاز.
  Future<ScannerBackend> _detect() async {
    if (!Platform.isAndroid) return ScannerBackend.none;
    try {
      final a = await DeviceInfoPlugin().androidInfo;
      final id = '${a.manufacturer} ${a.brand} ${a.model}'.toLowerCase();
      if (id.contains('sunmi')) return ScannerBackend.sunmi;
      return ScannerBackend.honeywell;
    } catch (_) {
      return ScannerBackend.honeywell;
    }
  }

  /// إيقاف/استئناف استقبال المسح. عند الإيقاف نمنع زر الماسح الفيزيائي
  /// في الفرموير (SUNMI ACTION_TRIGGER_CONTROL) ونوقف مسح AIDL.
  @override
  void setPaused(bool paused) {
    _paused = paused;
    if (paused && _backend == ScannerBackend.sunmi) {
      try {
        sunmi.SunmiScanner.stop();
      } catch (_) {}
    }
    _controlCh.invokeMethod(paused ? 'pause' : 'resume').catchError((Object e) {
      debugPrint('setPaused native failed: $e');
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
    _backend = await _detect();

    // قناة الجسر الأصلي: مسحات Honeywell (+ بديل Data Collection Intent).
    try {
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
        onError: (Object e) => debugPrint('native scanner err: $e'),
      );
    } catch (e) {
      debugPrint('native scanner channel unavailable: $e');
    }

    switch (_backend) {
      case ScannerBackend.sunmi:
        await _initSunmi();
        break;
      case ScannerBackend.honeywell:
        // نربط سائق Honeywell عند الطلب فقط — لا نتصل تلقائيًا، حتى لا
        // يتزاحم مع خدمة SUNMI على أجهزة L2s Pro.
        try {
          await _controlCh.invokeMethod('initHoneywell');
        } catch (e) {
          debugPrint('initHoneywell failed: $e');
        }
        break;
      case ScannerBackend.none:
        break;
    }
    _ready = true;
  }

  Future<void> _initSunmi() async {
    try {
      await sunmi.SunmiScanner.bindService(showToast: false);
      _sunmiSub = sunmi.SunmiScanner.onBarcodeScanned().listen(
        (String code) => _emit(code),
        onError: (Object e) => debugPrint('sunmi scanner err: $e'),
      );
      _applyWedgeSuppression();
    } catch (e) {
      debugPrint('sunmi scanner init failed: $e');
    }
  }

  @override
  Future<void> triggerScan() async {
    // فيه رسالة/حوار مفتوح — لا تبدأ مسحًا جديدًا (تفادي الصوت والزحمة).
    if (_paused) return;
    if (_backend == ScannerBackend.sunmi) {
      // `scan()`/`stop()` من الحزمة `void async` — لا يمكن await لها،
      // فنتأكد أولًا أن الخدمة جاهزة ثم نطلقها.
      var available = false;
      try {
        available = await sunmi.SunmiScanner.isScannerAvailable();
      } catch (_) {}
      if (available) {
        sunmi.SunmiScanner.scan();
        return;
      }
      throw PlatformException(
          code: 'SCAN_FAILED',
          message: 'تعذّر تشغيل الماسح — استخدم زر الجهاز الفيزيائي');
    }
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
    if (_backend == ScannerBackend.sunmi) {
      try {
        sunmi.SunmiScanner.stop();
      } catch (_) {}
    }
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
    if (_backend == ScannerBackend.sunmi) {
      try {
        await sunmi.SunmiScanner.unbindService();
      } catch (_) {}
    }
    await _sunmiSub?.cancel();
    await _nativeSub?.cancel();
    await _controller.close();
    _ready = false;
  }
}
