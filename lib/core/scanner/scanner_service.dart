import 'dart:async';

/// Abstraction لأي Scanner — الشاشات لا تعرف SUNMI مباشرة.
abstract class ScannerService {
  /// بث الأكواد المقروءة (بعد debounce)
  Stream<String> get scanStream;

  /// تهيئة الخدمة وربطها بالجهاز
  Future<void> initialize();

  /// بدء مسح برمجي (إن دعمه الجهاز)
  Future<void> triggerScan();

  /// إيقاف المسح
  Future<void> stopScan();

  Future<void> dispose();
}

/// إعدادات Scanner من Settings
class ScannerConfig {
  final bool beep;
  final bool vibrate;
  final int debounceMs;
  const ScannerConfig({
    this.beep = true,
    this.vibrate = true,
    this.debounceMs = 400,
  });
}

/// نتيجة مسح واحدة
class ScanEvent {
  final String code;
  final DateTime at;
  ScanEvent(this.code) : at = DateTime.now();
}
