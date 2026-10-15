import '../../shared/models/entities.dart';
import 'barcode_parser.dart';

/// مرشح كود مستخرج من مقطع داخل الباركود الممسوح.
class CodeCandidate {
  final ProductCode template;
  final String code;
  const CodeCandidate({required this.template, required this.code});
}

/// استخراج كود الصنف من داخل الباركود.
///
/// الفكرة: المستخدم يحدد بداية/نهاية مقطع الكود (cStart..cEnd) من الباركود
/// (شاشة إضافة صنف ← خيارات الكود، أو دايلوج أضف الكود)، وعند المسح في الطلب
/// نستخرج هذا المقطع ونبحث عن صنف بكوده — بدون اختيار يدوي من القائمة.
///
/// مثال: باركود `2001234500789` ومقطع الكود 4-8 → المرشح `12345`.
class BarcodeResolver {
  BarcodeResolver._();

  /// يستخرج كل مرشحات الأكواد من القوالب التي لها مقطع كود مضبوط.
  /// - القوالب بنفس طول الممسوح أولًا (نفس عائلة الباركود).
  /// - لكل مقطع نجرب القيمة الخام ثم بدون أصفار بادئة (00123 ← 123).
  static List<CodeCandidate> extractCodeCandidates(
      String scanned, List<ProductCode> templates) {
    final s = BarcodeParser.clean(scanned);
    final out = <CodeCandidate>[];
    if (s.isEmpty) return out;
    final sorted = [...templates]..sort((a, b) {
        final ae = a.barcode.length == s.length ? 0 : 1;
        final be = b.barcode.length == s.length ? 0 : 1;
        return ae.compareTo(be);
      });
    final seen = <String>{};
    for (final t in sorted) {
      var cs = t.cStart;
      var ce = t.cEnd;
      if (cs <= 0 || ce <= 0) continue;
      if (cs > ce) {
        final tmp = cs;
        cs = ce;
        ce = tmp;
      }
      // المقطع يجب أن يكون داخل الممسوح.
      if (cs < 1 || ce > s.length) continue;
      final raw = s.substring(cs - 1, ce);
      final stripped = raw.replaceFirst(RegExp(r'^0+'), '');
      for (final cand in [raw, stripped]) {
        final c = cand.trim();
        if (c.isEmpty || !seen.add(c)) continue;
        out.add(CodeCandidate(template: t, code: c));
      }
    }
    return out;
  }

  /// وزن مقترح من قالب (مقطع الوزن ÷ العلامة)، أو 0 لو غير مضبوط.
  /// مقطع يغطي الممسوح كله يعني "الوزن = رقم الباركود نفسه" (وهمي تلقائي
  /// غالبًا — المستخدم لم يحدده) فيُرجع 0 بدل رقم الباركود.
  static double templateWeight(String scanned, ProductCode t) {
    if (t.wStart <= 0 || t.wEnd <= 0) return 0;
    final s = BarcodeParser.clean(scanned);
    var a = t.wStart;
    var b = t.wEnd;
    if (a > b) {
      final tmp = a;
      a = b;
      b = tmp;
    }
    if (s.isNotEmpty && a <= 1 && b >= s.length) return 0;
    try {
      return BarcodeParser.calcValue(scanned, t.wStart, t.wEnd, t.mark);
    } catch (_) {
      return 0;
    }
  }

  static bool _inSeg(int pos, int a, int b) {
    if (a <= 0 || b <= 0) return false;
    if (a > b) {
      final tmp = a;
      a = b;
      b = tmp;
    }
    return pos >= a && pos <= b;
  }

  /// مطابقة قالب متغير: نفس الطول + ثبات كل الأرقام خارج مقطع الوزن
  /// ومقطع التاريخ (الاثنان متغيران من ملصق لآخر).
  /// حماية: لو اتحاد المقطعين يغطي الباركود كله فلا توجد أرقام ثابتة
  /// للمطابقة أصلًا — قالب منحل (غالبًا وهمي تلقائي) لا يُطابق أبدًا،
  /// وإلا أي باركود بنفس الطول كان سيُطابق أول قالب ويُدخل صنفًا غلطًا.
  static bool matchesTemplate(String scanned, ProductCode t) {
    final s = BarcodeParser.clean(scanned);
    final tb = BarcodeParser.clean(t.barcode);
    if (s.isEmpty || tb.isEmpty || tb.length != s.length) return false;
    var stable = false;
    for (var i = 0; i < s.length; i++) {
      final pos = i + 1;
      if (_inSeg(pos, t.wStart, t.wEnd)) continue; // جزء الوزن متغير
      if (_inSeg(pos, t.dStart, t.dEnd)) continue; // جزء التاريخ متغير
      stable = true;
      if (s[i] != tb[i]) return false;
    }
    return stable;
  }

  /// أول قالب مطابق من القائمة (يُستخدم بدل التكرار اليدوي في الشاشات).
  static ProductCode? matchTemplate(
      String scanned, List<ProductCode> templates) {
    for (final t in templates) {
      if (matchesTemplate(scanned, t)) return t;
    }
    return null;
  }

  /// رسالة تشخيصية بالعربية عند فشل التعرف — توضح للمستخدم السبب
  /// والحل بدل "الصنف غير موجود" العامة.
  static String diagnoseNotFound(
      String scanned, List<ProductCode> templates) {
    final s = BarcodeParser.clean(scanned);
    if (s.isEmpty) return 'امسح الباركود أولًا أو اكتبه ثم اضغط بحث.';
    if (templates.isEmpty) {
      return 'الصنف غير موجود: $s\n\nلا توجد أي باركودات مسجلة. سجّل الباركود أولًا من شاشة الأصناف (زر أضف الكود) ثم امسح هنا.';
    }
    final sameLen =
        templates.where((t) => BarcodeParser.clean(t.barcode).length == s.length).toList();
    if (sameLen.isEmpty) {
      final lens = templates
          .map((t) => BarcodeParser.clean(t.barcode).length)
          .toSet()
          .toList()
        ..sort();
      return 'الصنف غير موجود: $s\n\nطول الممسوح (${s.length}) لا يطابق أي باركود محفوظ (الأطوال المحفوظة: ${lens.join('، ')}). تأكد أنك تمسح الباركود الصحيح وليس رقمًا آخر على الملصق.';
    }
    // هل استخرجنا مرشح كود ولا يوجد صنف به؟
    final cands = extractCodeCandidates(s, templates);
    if (cands.isNotEmpty) {
      final tried = cands.map((c) => c.code).toSet().join('، ');
      return 'الصنف غير موجود: $s\n\nاستخرجنا من الممسوح الكود ($tried) ولا يوجد صنف بهذا الكود. راجع بداية/نهاية مقطع الكود في زر أضف الكود، أو تأكد من كود الصنف نفسه.';
    }
    // أقرب قالب: أين تختلف الأرقام؟
    ProductCode? best;
    var bestDiffs = <int>[];
    for (final t in sameLen) {
      final tb = BarcodeParser.clean(t.barcode);
      final diffs = <int>[];
      for (var i = 0; i < s.length; i++) {
        final pos = i + 1;
        if (_inSeg(pos, t.wStart, t.wEnd)) continue;
        if (_inSeg(pos, t.dStart, t.dEnd)) continue;
        if (s[i] != tb[i]) diffs.add(pos);
      }
      if (best == null || diffs.length < bestDiffs.length) {
        best = t;
        bestDiffs = diffs;
      }
    }
    if (best != null && bestDiffs.isNotEmpty) {
      final pos = bestDiffs.take(8).join('، ');
      final more = bestDiffs.length > 8 ? '…' : '';
      return 'الصنف غير موجود: $s\n\nأقرب باركود محفوظ (صنف ${best.productCode}): يختلف في المواضع ($pos$more). لو هذه الأرقام تتغير من ملصق لآخر (وزن/تاريخ) حدّد مقطعها من زر أضف الكود في شاشة الأصناف.';
    }
    return 'الصنف غير موجود: $s';
  }
}
