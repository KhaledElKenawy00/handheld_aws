import 'package:intl/intl.dart';

/// نتائج عمليات موحدة + رسائل عربية + تنسيق
class AppUtils {
  static final DateFormat dateFmt = DateFormat('yyyy-MM-dd');
  static final DateFormat dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat displayFmt = DateFormat('dd/MM/yyyy');

  static String todayStr() => dateFmt.format(DateTime.now());
  static String nowStr() =>
      DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');

  static String fmtQty(num q) {
    if (q == q.truncateToDouble()) return q.toInt().toString();
    return q.toString();
  }

  /// تحويل رقم مدخل بأي لوحة مفاتيح إلى double — يحوّل الأرقام العربية
  /// (٠١٢٣٤٥٦٧٨٩) والفارسية (۰۱۲۳۴۵۶۷۸۹) والفاصلة العربية (٫) إلى ASCII
  /// قبل التحليل، حتى "يسمع" السعر/الوزن المكتوب بالعربي بدل اعتباره صفرًا.
  /// مثال: "٢٥٠٫٥" ← 250.5
  static double parseNum(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return 0;
    const ar = '٠١٢٣٤٥٦٧٨٩';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      final ai = ar.indexOf(ch);
      if (ai >= 0) {
        buf.write(ai);
        continue;
      }
      final fi = fa.indexOf(ch);
      if (fi >= 0) {
        buf.write(fi);
        continue;
      }
      if (ch == '٫') {
        buf.write('.');
        continue;
      }
      buf.write(ch);
    }
    return double.tryParse(buf.toString().trim()) ?? 0;
  }

  static String sanitizeFileName(String s) {
    return s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  static String yearOf(DateTime d) => d.year.toString();
}

/// أخطاء مفهومة بالعربية
class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);
  @override
  String toString() => message;
}

/// نتيجة استيراد Excel
class ImportSummary {
  final int imported;
  final int updated;
  final int skipped;
  final int total;
  final List<String> errors;
  const ImportSummary({
    this.imported = 0,
    this.updated = 0,
    this.skipped = 0,
    this.total = 0,
    this.errors = const [],
  });
  int get valid => imported + updated;
  @override
  String toString() =>
      'تم الاستيراد: $imported | تحديث: $updated | تخطي: $skipped | أخطاء: ${errors.length}';
}
