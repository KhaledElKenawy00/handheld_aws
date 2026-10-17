/// تحليل باركود الوزن المتغير — قصّ جزء من الباركود بين البداية والنهاية
/// ثم القسمة على العلامة للحصول على القيمة تلقائيًا.
///
/// الاتفاق (مطابق لصور التطبيق):
/// - `start` و `end` بترقيم يبدأ من 1 (أول رقم في الباركود = 1) وشاملين.
///   مثال: باركود `746040210013` (12 رقم)، start=7 end=11 → المقطع `21001`.
/// - `mark` واحدة من 1/10/100/1000/10000.
/// - القيمة = الرقم المقصوص / العلامة. مثال: `21001` / 1000 = 21.001
/// - الوحدة KG/LB للعرض فقط.
class BarcodeParser {
  BarcodeParser._();

  /// تنظيف موحد للباركود: إزالة كل المسافات البيضاء والمحارف غير المرئية
  /// (أسطر جديدة من الماسح \n \r، مسافات، Zero-Width) من الطرفين والداخل.
  /// يُستخدم عند الحفظ وعند البحث معًا حتى يتطابق الاثنان دائمًا.
  /// نحافظ على كل محارف الباركود نفسها (أرقام/حروف/شرطات) — نزيل الأبيض فقط.
  static String clean(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    // إزالة محارف التحكم + zero-width الشائعة من الماسحات.
    s = s.replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200B\u200C\u200D\uFEFF]'), '');
    // إزالة أي مسافات بيضاء داخلية (الماسح قد يضيف فراغًا).
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s.trim();
  }

  /// قصّ مقطع من الباركود. يُرجع '' لو المدى خارج الباركود.
  /// [start1] و [end1] بترقيم 1-based وشاملين، ويتم تطبيعهما تلقائيًا
  /// (تبديل لو معكوسين، وقصّ على حدود الباركود).
  static String slice(String barcode, int start1, int end1) {
    final b = clean(barcode);
    if (b.isEmpty) return '';
    var s = start1;
    var e = end1;
    if (s < 1) s = 1;
    if (e < 1) e = 1;
    if (s > b.length) return '';
    if (e > b.length) e = b.length;
    if (s > e) {
      final t = s;
      s = e;
      e = t;
    }
    // substring نهايته exclusive لذلك نستخدم e كـ index نهائي.
    return b.substring(s - 1, e);
  }

  /// حوّل المقطع لرقم صحيح (يتجاهل أي غير أرقام).
  static int sliceInt(String sliceStr) {
    final digits = sliceStr.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  static double markValue(String mark) {
    switch (mark.trim()) {
      case '10':
        return 10;
      case '100':
        return 100;
      case '1000':
        return 1000;
      case '10000':
        return 10000;
      default:
        return 1;
    }
  }

  /// معامل تحويل الوحدة LB إلى القيمة المخزّنة (1 LB = 0.545).
  /// باقي الوحدات (KG) بلا تغيير.
  static const double lbFactor = 0.545;

  /// معامل الوحدة: 0.545 للـ LB وإلا 1.
  static double unitFactor(String unit) =>
      unit.trim().toUpperCase() == 'LB' ? lbFactor : 1.0;

  /// القيمة النهائية = (المقطع / العلامة) × معامل الوحدة.
  /// [unit] = LB يضرب الناتج في 0.545 (كما هو متفق عليه في التطبيق).
  static double calcValue(String barcode, int start1, int end1, String mark,
      {String unit = ''}) {
    final s = slice(barcode, start1, end1);
    final n = sliceInt(s);
    final m = markValue(mark);
    final raw = m <= 0 ? n.toDouble() : n / m;
    return raw * unitFactor(unit);
  }

  static String fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    // قصّ الأصفار الزائدة بدون فقدان الدقة.
    var s = v.toStringAsFixed(3);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  /// تحقّق سريع من المدى مقابل طول الباركود.
  static int clampPos(int v, int len) {
    if (len <= 0) return 1;
    if (v < 1) return 1;
    if (v > len) return len;
    return v;
  }

  /// عدد أرقام صيغة التاريخ (DD=2 + MM=2 + YYYY=4 أو YY=2).
  /// مثال: DD/MM/YYYY → 8، YY/MM/DD → 6.
  static int dateDigits(String fmt) {
    var n = 0;
    for (final p in fmt.split('/')) {
      final t = p.trim().toUpperCase();
      if (t == 'YYYY') {
        n += 4;
      } else if (t == 'DD' || t == 'MM' || t == 'YY') {
        n += 2;
      }
    }
    return n;
  }

  /// نسّق مقطع التاريخ حسب الصيغة بدل عرضه أرقامًا ملتصقة.
  /// يقسّم الأرقام بالترتيب حسب أطوال الأجزاء ويفصل بينها بـ `/`.
  /// مثال: "251007" + YY/MM/DD → "25/10/07"،
  /// "07102025" + DD/MM/YYYY → "07/10/2025".
  static String formatDateSlice(String slice, String fmt) {
    final digits = slice.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final parts = fmt.split('/');
    final lens = <int>[];
    for (final p in parts) {
      final t = p.trim().toUpperCase();
      if (t == 'YYYY') {
        lens.add(4);
      } else if (t == 'DD' || t == 'MM' || t == 'YY') {
        lens.add(2);
      }
    }
    if (lens.isEmpty) return digits;
    final out = <String>[];
    var i = 0;
    for (final l in lens) {
      if (i >= digits.length) break;
      final end = (i + l > digits.length) ? digits.length : i + l;
      out.add(digits.substring(i, end));
      i = end;
    }
    if (i < digits.length) out.add(digits.substring(i));
    return out.join('/');
  }
}
