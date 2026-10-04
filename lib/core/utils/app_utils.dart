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
