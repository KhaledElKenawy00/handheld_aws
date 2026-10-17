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

  /// إيقاف/استئناف استقبال المسحات مؤقتًا — يُستخدم لإسكات الماسح وإيقافه
  /// طالما فيه رسالة/حوار مفتوح أمام المستخدم (بدل ما يزحم مسحات وصوت).
  void setPaused(bool paused) {}
}

/// إعدادات Scanner من Settings
class ScannerConfig {
  final bool beep;
  final bool vibrate;
  final int debounceMs;

  /// منع إخراج الماسح كـ "كيبورد" (keyboard-wedge) على أجهزة SUNMI.
  ///
  /// بعض أجهزة L2s Pro بتطلع الكود مرتين: مرة كبثّ (broadcast) ومرة كضغطات
  /// كيبورد على الحقل المركّز، فيتشوّه/ييجي ناقص. لما تكون `true` نمنع
  /// ضغطات الكيبورد الفيزيائية ونعتمد على البثّ بس (وهو المفعّل افتراضيًا).
  final bool blockWedge;
  const ScannerConfig({
    this.beep = true,
    this.vibrate = true,
    this.debounceMs = 400,
    this.blockWedge = true,
  });
}

/// نتيجة مسح واحدة
class ScanEvent {
  final String code;
  final DateTime at;
  ScanEvent(this.code) : at = DateTime.now();
}
