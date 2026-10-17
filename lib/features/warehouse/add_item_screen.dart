import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/scanner/scanner_providers.dart';
import '../../core/services/barcode_parser.dart';
import '../../core/theme/ref_style.dart';
import '../../core/utils/app_utils.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/barcode_ruler.dart';
import '../../shared/widgets/pos_stepper.dart';
import 'add_code_dialog.dart';

/// اضافة صنف — الرمز/الاسم/نوع الوزن/الباركود + مربعات الكود والوزن والتاريخ.
///
/// - يدعم ماسح SUNMI L2s Pro (Broadcast + wedge).
/// - كل مربع يفتح دايلوج خيارات بنفس منطق صورة "أضف الكود":
///   حدّد الرقم بين البداية والنهاية بالأسهم من الباركود نفسه،
///   والوزن = المقطع ÷ العلامة (10/100/1000/...)، والوحدة KG/LB،
///   والقيمة تظهر تلقائيًا.
class AddItemScreen extends ConsumerStatefulWidget {
  final String? editCode;
  const AddItemScreen({super.key, this.editCode});
  @override
  ConsumerState<AddItemScreen> createState() => _AddItemState();
}

class _AddItemState extends ConsumerState<AddItemScreen> {
  final codeC = TextEditingController();
  final nameC = TextEditingController();
  final weightC = TextEditingController();
  final barcodeC = TextEditingController();
  final codeFocus = FocusNode();
  final nameFocus = FocusNode();
  final barcodeFocus = FocusNode();
  StreamSubscription? scanSub;
  String? lastScanned;

  String weightType = 'متغير'; // متغير | ثابت | باركود ثابت
  // الكود والوزن مفعّلان افتراضيًا (الأهم) — التاريخ اختياري مطفي.
  // الوزن شغال لكن لو لم تُدخل له قيمة/مقطع يُحفظ صفرًا تلقائيًا.
  bool hasCode = true;
  bool hasWeight = true;
  bool hasDate = false;
  bool loading = false;

  // خيارات المربعات — مقاطع 1-based شاملة + علامة/وحدة/صيغة.
  // القيمة 0 تعني "غير محدد" (مثل دايلوج أضف الكود):
  // لا يُستخرج وزن/كود/تاريخ من الباركود ويُحفظ الوزن صفرًا.
  String cfgMark = '1';
  String cfgUnit = 'KG';
  String cfgDateFmt = 'DD/MM/YYYY';
  int wStart = 0;
  int wEnd = 0;
  int cStart = 0;
  int cEnd = 0;
  int dStart = 0;
  int dEnd = 0;

  // بصمة البيانات الابتدائية + علامة الحفظ — للتحذير عند الرجوع
  // ببيانات غير محفوظة (موافق/لا).
  String? _initialPrint;
  bool _saved = false;

  /// بصمة كل المدخلات الحالية لمقارنتها بالابتدائية.
  String _fingerprint() => [
        codeC.text,
        nameC.text,
        weightC.text,
        barcodeC.text,
        weightType,
        hasCode,
        hasWeight,
        hasDate,
        cfgMark,
        cfgUnit,
        cfgDateFmt,
        wStart,
        wEnd,
        cStart,
        cEnd,
        dStart,
        dEnd,
      ].join('|');

  bool get _isDirty =>
      !_saved && _initialPrint != null && _fingerprint() != _initialPrint;

  /// حوار الرجوع: البيانات المدخلة ستُمسح ولن تُحفظ — موافق / لا.
  Future<bool> _confirmDiscard() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تجاهل البيانات؟',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 19,
                fontWeight: FontWeight.w800)),
        content: const Text(
          'أدخلت بيانات ولم تحفظها — هل أنت واثق من الخروج؟',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لا')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('موافق')),
        ],
      ),
    );
    return r ?? false;
  }

  // حماية الحقول: الرمز والاسم يُكتبان يدويًا فقط ولا يقبلان المسح —
  // لو وقعت مسحة ماسح (wedge) في أي منهما بالغلط تُنزع كاملة وتُنقل
  // لحقل الباركود بعد استقرار الدفعة، بدل أن تفسد الرمز/الاسم.
  // وحقل الباركود نفسه: كل مسحة جديدة تستبدل القديمة بالكامل (مسح مرتين
  // ورا بعض = آخر باركود فقط). الكتابة اليدوية البطيئة لا تتأثر.
  late final _ScanFieldGuard _codeGuard;
  late final _ScanFieldGuard _nameGuard;
  late final _ScanFieldGuard _barcodeGuard;

  void _initScanGuards() {
    _codeGuard = _ScanFieldGuard(
      codeC,
      idleResetMs: 250,
      maxMsPerChar: 160,
      onBurst: (burst, base) {
        _codeGuard.setText(base);
        _consumeScan(burst, 'الرمز يُكتب يدويًا — نُقلت المسحة لحقل الباركود');
      },
    );
    _nameGuard = _ScanFieldGuard(
      nameC,
      idleResetMs: 250,
      maxMsPerChar: 160,
      onBurst: (burst, base) {
        _nameGuard.setText(base);
        _consumeScan(burst, 'الاسم يُكتب يدويًا — نُقلت المسحة لحقل الباركود');
      },
    );
    // حقل الباركود: أي قراءة جديدة تستبدل القديمة بالكامل، ويتعامل مع
    // الماسحات اللي بتستبدل النص المحدد كله (freshOnReplace) أو بتضيف
    // في الآخر — وفي الحالتين آخر قراءة هي اللي تتحط.
    _barcodeGuard = _ScanFieldGuard(
      barcodeC,
      idleResetMs: 300,
      maxMsPerChar: 200,
      freshOnReplace: true,
      onBurst: (burst, base) {
        // مسحة جديدة فوق باركود قديم → القديم يُمسح والجديد فقط يُحفظ.
        _consumeScan(burst);
      },
    );
  }

  /// استقبال مسحة في حقل الباركود: تضبط المقاطع وتستبدل المحتوى السابق
  /// بالكامل (حتى لو كانت هناك مسحة قديمة)، مع اهتزاز وتنبيه.
  void _consumeScan(String code, [String? toast]) {
    if (!mounted || code.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      lastScanned = code;
      // لا توسّع تلقائيًا: 0 تعني "غير محدد" وتبقى كذلك حتى يحددها
      // المستخدم من الدايلوج — فقط قصّ القيم المضبوطة على الطول الجديد.
      wStart = _clampSeg(wStart, code.length);
      wEnd = _clampSeg(wEnd, code.length);
      cStart = _clampSeg(cStart, code.length);
      cEnd = _clampSeg(cEnd, code.length);
      dStart = _clampSeg(dStart, code.length);
      dEnd = _clampSeg(dEnd, code.length);
    });
    _barcodeGuard.setText(code);
    barcodeFocus.requestFocus();
    refToast(context, toast ?? 'تم مسح الباركود: $code');
  }

  @override
  void initState() {
    super.initState();
    _initScanGuards();
    if (widget.editCode != null) {
      _load();
    } else {
      _initialPrint = _fingerprint();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) codeFocus.requestFocus();
      });
    }
    try {
      scanSub = ref
          .read(scannerServiceProvider)
          .scanStream
          .listen(_onScannerCode);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final p = await ref.read(productRepoProvider).findByCode(widget.editCode!);
    if (p != null && mounted) {
      // ضبط برمجي للحقول عبر الحراس — حتى لا تُفسَّر بيانات التحميل
      // كمسحة ماسح وتُنقل لحقل الباركود.
      _codeGuard.setText(p.code);
      _nameGuard.setText(p.desc);
      weightType = p.weightType;
      weightC.text = p.fixedWeight == 0 ? '' : p.fixedWeight.toString();
      _barcodeGuard.setText(p.barcode ?? '');
      hasCode = p.hasCode;
      hasWeight = p.hasWeight;
      hasDate = p.hasDate;
      try {
        final codes =
            await ref.read(productCodeRepoProvider).forProduct(p.code);
        if (codes.isNotEmpty) {
          final c = codes.first;
          cfgMark = c.mark;
          cfgUnit = c.unit;
          cfgDateFmt = c.dateFmt;
          wStart = c.wStart;
          wEnd = c.wEnd;
          cStart = c.cStart;
          cEnd = c.cEnd;
          dStart = c.dStart;
          dEnd = c.dEnd;
        }
      } catch (_) {}
    }
    if (mounted) {
      // بصمة البيانات المحملة — أي تغيير عنها يُعد بيانات غير محفوظة.
      _initialPrint = _fingerprint();
      setState(() => loading = false);
    }
  }

  /// تطبيع موضع مقطع مع السماح بـ 0 = "غير محدد"
  /// (مطابق لمنطق دايلوج أضف الكود).
  int _clampSeg(int v, int len) {
    if (v <= 0) return 0;
    if (len <= 0) return v > 99 ? 99 : v;
    if (v > len) return len;
    return v;
  }

  /// هل المقطع مضبوط فعلًا (غير صفري)؟
  bool _segSet(int s, int e) => s > 0 && e > 0;

  /// المسح مخصص لحقل الباركود فقط — حقل الرمز يدوي ولا يقبل المسح.
  /// غلاف آمن: أي عطل يُعرض بدل الصمت حتى لا يبدو "الماسح لا يقرأ".
  void _onScannerCode(String raw) {
    try {
      if (!mounted) return;
      final code = BarcodeParser.clean(raw);
      if (code.isEmpty) return;
      // حقل الباركود مطلوب في وضعي "متغير" و"باركود ثابت" فقط.
      if (weightType != 'متغير' && weightType != 'باركود ثابت') return;
      _consumeScan(code);
    } catch (e) {
      if (mounted) refError(context, 'تعذر استقبال المسحة: $e');
    }
  }

  @override
  void dispose() {
    scanSub?.cancel();
    _codeGuard.dispose();
    _nameGuard.dispose();
    _barcodeGuard.dispose();
    codeC.dispose();
    nameC.dispose();
    weightC.dispose();
    barcodeC.dispose();
    codeFocus.dispose();
    nameFocus.dispose();
    barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (codeC.text.trim().isEmpty || nameC.text.trim().isEmpty) {
      refError(context, 'ادخل الرمز والاسم');
      return;
    }
    final isVar = weightType == 'متغير';
    final isFixedBc = weightType == 'باركود ثابت';
    final barcode =
        barcodeC.text.trim().isEmpty ? null : barcodeC.text.trim();
    // الوزن المتغير: الباركود + مقطع الوزن + مقطع الكود إجباريون.
    if (isVar) {
      if (barcode == null) {
        refError(context, 'امسح/ادخل الباركود أولًا');
        return;
      }
      if (!(hasWeight && _segSet(wStart, wEnd))) {
        refError(context, 'حدّد مقطع الوزن (إدخال الوزن إجباري)');
        return;
      }
      if (!(hasCode && _segSet(cStart, cEnd))) {
        refError(context, 'حدّد مقطع الكود (إدخال الكود إجباري)');
        return;
      }
    }
    // الباركود الثابت: لازم باركود (وهو نفسه كود الصنف).
    if (isFixedBc && barcode == null) {
      refError(context, 'امسح الباركود أولًا');
      return;
    }
    try {
      final repo = ref.read(productRepoProvider);
      // المقاطع الفعالة: المطفي/غير المتغير يُحفظ صفرًا (غير محدد) —
      // الباركود الثابت = الكود هو الباركود كله (مقطع 0) بلا وزن/تاريخ.
      final effWStart = (isVar && hasWeight) ? wStart : 0;
      final effWEnd = (isVar && hasWeight) ? wEnd : 0;
      final effCStart = (isVar && hasCode) ? cStart : 0;
      final effCEnd = (isVar && hasCode) ? cEnd : 0;
      final effDStart = (isVar && hasDate) ? dStart : 0;
      final effDEnd = (isVar && hasDate) ? dEnd : 0;
      // أعلام الحفظ: الباركود الثابت بلا وزن ولا تاريخ وكوده كامل الباركود.
      final saveHasWeight = isFixedBc ? false : hasWeight;
      final saveHasCode = isFixedBc ? true : hasCode;
      final saveHasDate = isFixedBc ? false : hasDate;
      double effCalc(String bc) {
        if (!isVar || !hasWeight || !_segSet(effWStart, effWEnd)) return 0;
        try {
          return BarcodeParser.calcValue(bc, effWStart, effWEnd, cfgMark,
              unit: cfgUnit);
        } catch (_) {
          return 0;
        }
      }
      if (widget.editCode != null) {
        // وضع التعديل: حافظ على قيمة المجزر المخزنة (الجزء اتشال من الواجهة).
        final old = await repo.findByCode(widget.editCode!);
        await repo.update(Product(
          code: codeC.text.trim(),
          desc: nameC.text.trim(),
          weightType: weightType,
          fixedWeight: AppUtils.parseNum(weightC.text),
          barcode: barcode,
          hasCode: saveHasCode,
          hasWeight: saveHasWeight,
          hasDate: saveHasDate,
          hasMazraa: old?.hasMazraa ?? true,
        ));
        // احفظ مقاطع الباركود أيضًا (كانت تضيع عند التعديل — فيبقى
        // مقطع الكود/الوزن المحدد من المستخدم فعالًا للمسح في الطلب).
        if ((isVar || isFixedBc) && barcode != null && barcode.isNotEmpty) {
          try {
            final calc = effCalc(barcode);
            final codeRepo = ref.read(productCodeRepoProvider);
            final existing =
                await codeRepo.forProduct(codeC.text.trim());
            ProductCode? same;
            for (final e in existing) {
              if (e.barcode == barcode) {
                same = e;
                break;
              }
            }
            if (same != null && same.id != null) {
              await codeRepo.update(ProductCode(
                id: same.id,
                productCode: codeC.text.trim(),
                barcode: barcode,
                qty: same.qty,
                weight: calc,
                unit: cfgUnit,
                mark: cfgMark,
                dateFmt: cfgDateFmt,
                value: calc,
                wStart: effWStart,
                wEnd: effWEnd,
                cStart: effCStart,
                cEnd: effCEnd,
                dStart: effDStart,
                dEnd: effDEnd,
              ));
            } else if (existing.isNotEmpty && existing.first.id != null) {
              final first = existing.first;
              await codeRepo.update(ProductCode(
                id: first.id,
                productCode: codeC.text.trim(),
                barcode: barcode,
                qty: first.qty,
                weight: calc,
                unit: cfgUnit,
                mark: cfgMark,
                dateFmt: cfgDateFmt,
                value: calc,
                wStart: effWStart,
                wEnd: effWEnd,
                cStart: effCStart,
                cEnd: effCEnd,
                dStart: effDStart,
                dEnd: effDEnd,
              ));
            } else {
              await codeRepo.add(ProductCode(
                productCode: codeC.text.trim(),
                barcode: barcode,
                qty: 0,
                weight: calc,
                unit: cfgUnit,
                mark: cfgMark,
                dateFmt: cfgDateFmt,
                value: calc,
                wStart: effWStart,
                wEnd: effWEnd,
                cStart: effCStart,
                cEnd: effCEnd,
                dStart: effDStart,
                dEnd: effDEnd,
              ));
            }
          } catch (_) {}
        }
      } else {
        await repo.create(Product(
          code: codeC.text.trim(),
          desc: nameC.text.trim(),
          weightType: weightType,
          fixedWeight: AppUtils.parseNum(weightC.text),
          barcode: barcode,
          hasCode: saveHasCode,
          hasWeight: saveHasWeight,
          hasDate: saveHasDate,
        ));
        if ((isVar || isFixedBc) && barcode != null && barcode.isNotEmpty) {
          try {
            final calc = effCalc(barcode);
            await ref.read(productCodeRepoProvider).add(ProductCode(
                  productCode: codeC.text.trim(),
                  barcode: barcode,
                  qty: 0,
                  weight: calc,
                  unit: cfgUnit,
                  mark: cfgMark,
                  dateFmt: cfgDateFmt,
                  value: calc,
                  wStart: effWStart,
                  wEnd: effWEnd,
                  cStart: effCStart,
                  cEnd: effCEnd,
                  dStart: effDStart,
                  dEnd: effDEnd,
                ));
          } catch (_) {}
        }
      }
      if (mounted) {
        refToast(context, 'تم الحفظ');
        // تم الحفظ — السماح بالرجوع دون تحذير.
        _saved = true;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) refError(context, e);
    }
  }

  String get _barcode => barcodeC.text.trim();

  bool _needBarcode() {
    if (_barcode.isEmpty) {
      refError(context, 'ادخل/امسح الباركود أولًا ثم اضغط على المربع');
      return false;
    }
    return true;
  }

  // ── دايلوج الوزن: بداية/نهاية بالأسهم + علامة + وحدة + قيمة تلقائي ──
  // 0 = غير محدد (الوزن صفر) — يُضبط بالأسهم من 0 حتى طول الباركود.
  Future<void> _openWeightOptions() async {
    if (!_needBarcode()) return;
    var en = hasWeight;
    var mark = cfgMark;
    var unit = cfgUnit;
    var s = _clampSeg(wStart, _barcode.length);
    var e = _clampSeg(wEnd, _barcode.length);
    // الخانة النشطة للمرّر التلقائي للمسطرة (الأخيرة المضبوطة).
    var focusPos = e > 0 ? e : (s > 0 ? s : 0);
    // كنترولر ثابت لحقل القيمة — يُحدَّث نصه يدويًا بدل إنشائه في كل build
    // (إنشاؤه داخل build يسبب استخدام كنترولر بعد dispose).
    final valueC = TextEditingController();
    void refreshValue() {
      final v = !_segSet(s, e)
          ? ''
          : BarcodeParser.fmt(
              BarcodeParser.calcValue(_barcode, s, e, mark, unit: unit));
      if (valueC.text != v) valueC.text = v;
    }

    await refDialog(
      context: context,
      dialogTitle: 'خيارات الوزن',
      saveLabel: 'حفظ',
      onSave: () {
        setState(() {
          hasWeight = en;
          cfgMark = mark;
          cfgUnit = unit;
          wStart = s;
          wEnd = e;
        });
        Navigator.pop(context);
      },
      content: StatefulBuilder(
        builder: (ctx, setS) {
          final slice =
              !_segSet(s, e) ? '' : BarcodeParser.slice(_barcode, s, e);
          refreshValue();
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _enableRow('تفعيل الوزن', en, (v) => setS(() => en = v)),
                const SizedBox(height: 8),
                Text('الباركود: $_barcode',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                BarcodeRuler(
                    barcode: _barcode,
                    start: s,
                    end: e,
                    focusPos: focusPos),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _posStepper(
                            'البداية', s, _barcode.length,
                            (v) => setS(() {
                                  s = v;
                                  focusPos = v;
                                }))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _posStepper('النهاية', e,
                            _barcode.length, (v) => setS(() {
                                  e = v;
                                  focusPos = v;
                                }))),
                  ],
                ),
                const SizedBox(height: 8),
                _sliceBox(_segSet(s, e)
                    ? 'المقطع [$s-$e]: $slice'
                    : 'المقطع: — (غير محدد = الوزن صفر)'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RefDropdown<String>(
                        label: 'العلامة',
                        value: mark,
                        items: [
                          for (final m in refMarks)
                            DropdownMenuItem(
                                value: m,
                                child: Text(m,
                                    textDirection: TextDirection.ltr)),
                        ],
                        onChanged: (v) => setS(() => mark = v ?? mark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RefDropdown<String>(
                        label: 'الوحدة',
                        value: unit,
                        items: [
                          for (final u in refUnits)
                            DropdownMenuItem(
                                value: u,
                                child: Text(u,
                                    textDirection: TextDirection.ltr)),
                        ],
                        onChanged: (v) => setS(() => unit = v ?? unit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RefField(
                  controller: valueC,
                  label: 'القيمة (تلقائي = المقطع ÷ العلامة — فاضي = صفر)',
                  readOnly: true,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          );
        },
      ),
    );
    // مهلة لاكتمال أنيميشن خروج الحوار قبل التخلص من كنترولر القيمة —
    // وإلا أي إعادة بناء أثناء الخروج تكراش (used after being disposed).
    await Future.delayed(const Duration(milliseconds: 500));
    valueC.dispose();
  }

  // ── دايلوج الكود: بداية/نهاية + المقطع كقيمة ──
  // 0 = غير محدد = الباركود كله هو الكود (الوضع الافتراضي للكود فقط).
  Future<void> _openCodeOptions() async {
    if (!_needBarcode()) return;
    var en = hasCode;
    var s = _clampSeg(cStart, _barcode.length);
    var e = _clampSeg(cEnd, _barcode.length);
    // الخانة النشطة للمرّر التلقائي للمسطرة (الأخيرة المضبوطة).
    var focusPos = e > 0 ? e : (s > 0 ? s : 0);
    await refDialog(
      context: context,
      dialogTitle: 'خيارات الكود',
      saveLabel: 'حفظ',
      onSave: () {
        setState(() {
          hasCode = en;
          cStart = s;
          cEnd = e;
        });
        Navigator.pop(context);
      },
      content: StatefulBuilder(
        builder: (ctx, setS) {
          final slice =
              !_segSet(s, e) ? '' : BarcodeParser.slice(_barcode, s, e);
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _enableRow('تفعيل الكود', en, (v) => setS(() => en = v)),
                const SizedBox(height: 8),
                Text('الباركود: $_barcode',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                BarcodeRuler(
                    barcode: _barcode,
                    start: s,
                    end: e,
                    focusPos: focusPos),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _posStepper(
                            'البداية', s, _barcode.length,
                            (v) => setS(() {
                                  s = v;
                                  focusPos = v;
                                }))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _posStepper('النهاية', e,
                            _barcode.length, (v) => setS(() {
                                  e = v;
                                  focusPos = v;
                                }))),
                  ],
                ),
                if (slice.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sliceBox('الكود [$s-$e]: $slice'),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ── دايلوج المجزر: بداية/نهاية + المقطع ──
  // ── دايلوج التاريخ: بداية/نهاية + صيغة التاريخ ──
  // 0 = غير محدد = يُتجاهل عند المطابقة (الوضع الافتراضي: مطفي).
  Future<void> _openDateOptions() async {
    if (!_needBarcode()) return;
    var en = hasDate;
    var fmt = cfgDateFmt;
    var s = _clampSeg(dStart, _barcode.length);
    var e = _clampSeg(dEnd, _barcode.length);
    // الخانة النشطة للمرّر التلقائي للمسطرة (الأخيرة المضبوطة).
    var focusPos = e > 0 ? e : (s > 0 ? s : 0);
    await refDialog(
      context: context,
      dialogTitle: 'خيارات التاريخ',
      saveLabel: 'حفظ',
      onSave: () {
        setState(() {
          hasDate = en;
          cfgDateFmt = fmt;
          dStart = s;
          dEnd = e;
        });
        Navigator.pop(context);
      },
      content: StatefulBuilder(
        builder: (ctx, setS) {
          final slice =
              !_segSet(s, e) ? '' : BarcodeParser.slice(_barcode, s, e);
          final shown = slice.isEmpty
              ? ''
              : BarcodeParser.formatDateSlice(slice, fmt);
          final need = BarcodeParser.dateDigits(fmt);
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _enableRow('تفعيل التاريخ', en, (v) => setS(() => en = v)),
                const SizedBox(height: 8),
                Text('الباركود: $_barcode',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                BarcodeRuler(
                    barcode: _barcode,
                    start: s,
                    end: e,
                    focusPos: focusPos),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _posStepper(
                            'البداية', s, _barcode.length,
                            (v) => setS(() {
                                  s = v;
                                  focusPos = v;
                                }))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _posStepper('النهاية', e,
                            _barcode.length, (v) => setS(() {
                                  e = v;
                                  focusPos = v;
                                }))),
                  ],
                ),
                const SizedBox(height: 8),
                _sliceBox(shown.isEmpty
                    ? 'التاريخ: — (غير محدد = يُتجاهل)'
                    : 'التاريخ [$s-$e]: $shown'),
                const SizedBox(height: 4),
                Text(
                  !_segSet(s, e)
                      ? 'غير محدد — فعّل التاريخ وحدّد بدايته ونهايته من الباركود'
                      : 'المقطع ${slice.length} أرقام — الصيغة $fmt تحتاج $need أرقام',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: !_segSet(s, e)
                          ? RefColors.hintGrey
                          : (slice.length == need
                              ? RefColors.green
                              : RefColors.red)),
                ),
                const SizedBox(height: 12),
                RefDropdown<String>(
                  label: 'صيغة التاريخ',
                  value: fmt,
                  items: [
                    for (final f in refDateFmts)
                      DropdownMenuItem(
                          value: f,
                          child:
                              Text(f, textDirection: TextDirection.ltr)),
                  ],
                  onChanged: (v) => setS(() => fmt = v ?? fmt),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editCode != null;
    final bc = _barcode;
    // 0 = غير محدد: لا تعرض قيمًا تلقائية وهمية — الكود فقط هو المهم
    // افتراضيًا، والوزن صفر لو لم يُحدد.
    final wSet = _segSet(wStart, wEnd);
    final cSet = _segSet(cStart, cEnd);
    final dSet = _segSet(dStart, dEnd);
    final wSlice =
        (!wSet || bc.isEmpty) ? '' : BarcodeParser.slice(bc, wStart, wEnd);
    final wVal = (!wSet || bc.isEmpty)
        ? ''
        : BarcodeParser.fmt(
            BarcodeParser.calcValue(bc, wStart, wEnd, cfgMark,
                unit: cfgUnit));
    final wTileSub = bc.isEmpty
        ? ''
        : (!wSet
            ? '— (غير محدد = صفر)'
            : '$wSlice ÷ $cfgMark = $wVal $cfgUnit');
    final cTileSub = bc.isEmpty
        ? ''
        : (!cSet
            ? '— (الباركود كله هو الكود)'
            : BarcodeParser.slice(bc, cStart, cEnd));
    final dTileSub = bc.isEmpty
        ? ''
        : (!dSet
            ? '— (بدون تاريخ)'
            : BarcodeParser.formatDateSlice(
                BarcodeParser.slice(bc, dStart, dEnd), cfgDateFmt));
    // اعتراض الرجوع (زر الرجوع أو سحب النظام): لو توجد بيانات غير
    // محفوظة يُعرض تحذير المسح (موافق/لا) قبل الخروج.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!mounted) return;
        final navigator = Navigator.of(context);
        if (!_isDirty) {
          navigator.pop(result);
          return;
        }
        final ok = await _confirmDiscard();
        if (ok && mounted) navigator.pop(result);
      },
      child: RefScaffold(
      title: isEdit ? 'تعديل صنف' : 'اضافة صنف',
      bottomButton: RefButton(label: 'حفظ', onPressed: _save),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                // حقل الرمز يدوي فقط — لا يقبل المسح ولا زر مسح بجواره.
                RefField(
                  controller: codeC,
                  label: 'ادخل الرمز',
                  textDirection: TextDirection.ltr,
                  focusNode: codeFocus,
                  autofocus: !isEdit,
                  keyboardType: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => nameFocus.requestFocus(),
                ),
                if (lastScanned != null) ...[
                  const SizedBox(height: 4),
                  Text('آخر مسح: $lastScanned',
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: RefColors.hintGrey)),
                ],
                const SizedBox(height: 12),
                RefField(
                  controller: nameC,
                  label: 'أدخل الاسم',
                  focusNode: nameFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    if (weightType == 'متغير' ||
                        weightType == 'باركود ثابت') {
                      barcodeFocus.requestFocus();
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text('نوع الوزن',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                        child: _radio('وزن متغير', 'متغير', RefColors.green)),
                    Expanded(child: _radio('ثابت', 'ثابت', RefColors.red)),
                    Expanded(
                        child: _radio(
                            'باركود ثابت', 'باركود ثابت', RefColors.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                if (weightType == 'متغير') ...[
                  _barcodeInput(),
                  const SizedBox(height: 4),
                  const Text(
                    'الكود والوزن إجباريان — حدّد مقطع الوزن ومقطع الكود من الباركود، والتاريخ اختياري',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: RefColors.hintGrey),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.35,
                    children: [
                      _tile('كود', Icons.qr_code_rounded, RefColors.green,
                          hasCode, cTileSub, _openCodeOptions),
                      _tile(
                          'الوزن',
                          Icons.scale_rounded,
                          RefColors.red,
                          hasWeight,
                          wTileSub,
                          _openWeightOptions),
                      _tile(
                          'التاريخ',
                          Icons.calendar_month_rounded,
                          RefColors.primary,
                          hasDate,
                          dTileSub,
                          _openDateOptions),
                    ],
                  ),
                ] else if (weightType == 'باركود ثابت') ...[
                  _barcodeInput(),
                  const SizedBox(height: 4),
                  const Text(
                    'امسح الباركود — يُحفظ كما هو ويصبح هو كود الصنف، بدون أي وزن أو تاريخ أو إعدادات.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: RefColors.hintGrey),
                  ),
                ] else ...[
                  RefField(
                      controller: weightC,
                      label: 'الوزن (اختياري — يُترك صفرًا لو بلا وزن)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ],
                const SizedBox(height: 16),
              ],
            ),
      ),
    );
  }

  /// حقل الباركود — للقراءة فقط: يُملأ من الماسح فقط ولا يقبل الكتابة
  /// اليدوية (كما طُلب)، فلا يمكن إدخال كود باليد هنا.
  Widget _barcodeInput() {
    return RefField(
      controller: barcodeC,
      label: 'امسح الباركود بالماسح',
      textDirection: TextDirection.ltr,
      focusNode: barcodeFocus,
      readOnly: true,
      keyboardType: TextInputType.none,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _radio(String label, String value, Color color) {
    final sel = weightType == value;
    return InkWell(
      onTap: () => setState(() => weightType = value),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: sel ? color : Colors.black54)),
            const SizedBox(width: 6),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.2)),
              child: sel
                  ? Center(
                      child: Container(
                          width: 12,
                          height: 12,
                          decoration:
                              BoxDecoration(shape: BoxShape.circle, color: color)))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, IconData icon, Color color, bool sel,
      String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: sel ? 1 : .45,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 2.4),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 34, color: RefColors.primary),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(subtitle,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                ),
              const SizedBox(height: 2),
              const Text('اضغط للخيارات',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: RefColors.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _enableRow(String label, bool en, ValueChanged<bool> onCh) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 19,
                    fontWeight: FontWeight.w700))),
        Switch(value: en, activeThumbColor: RefColors.green, onChanged: onCh),
      ],
    );
  }

  // خانة بداية/نهاية قابلة للكتابة باليد (أرقام فقط) + أسهم —
  // تقف عند طول الباركود و0 يعني "غير محدد".
  Widget _posStepper(
      String label, int value, int len, ValueChanged<int> onCh) {
    return PosStepper(
      label: label,
      value: value,
      max: len,
      allowZero: true,
      onChanged: onCh,
    );
  }

  Widget _sliceBox(String text) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RefColors.fieldBorder),
      ),
      child: Text(
        text,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }

}

/// حراسة حقل نصي من مسحات الماسح الضالة (وضع wedge يكتب في الحقل المركّز):
/// يراقب التغييرات، ولو رصد دفعة سريعة بمواصفات باركود (طول ≥ [minBurst]
/// بمتوسط <[maxMsPerChar] مللي للمحرف) يستدعي [onBurst] بالمسحة وحدها
/// وبالنص الذي كان قبلها. الكتابة اليدوية البطيئة أو الحذف لا يتأثران.
///
/// - [idleResetMs]: فجوة بهذا القدر تعني بداية إدخال جديد، فيُعتبر النص
///   السابق هو نقطة الأساس (يُرفع ليستوعب الماسحات الأبطأ ويتجاهل التهنيج).
/// - [freshOnReplace]: لو غيّر الماسح النص كله/حدد الكل وكت ب فوقه، تُعالج
///   المحتوى الجديد كقراءة كاملة (لا يُلحق بالقديم).
class _ScanFieldGuard {
  final TextEditingController controller;
  final void Function(String burst, String base) onBurst;
  final int idleResetMs;
  final int maxMsPerChar;
  final bool freshOnReplace;

  /// أقل طول يُعتبر مسحة ماسح (مش كتابة يدوية).
  static const int minBurst = 4;

  String _prev;
  String _base;
  DateTime _burstStart = DateTime.now();
  DateTime _lastChange = DateTime.now();
  Timer? _settle;
  bool _suppress = false;

  _ScanFieldGuard(
    this.controller, {
    required this.onBurst,
    this.idleResetMs = 120,
    this.maxMsPerChar = 50,
    this.freshOnReplace = false,
  })  : _prev = controller.text,
        _base = controller.text {
    controller.addListener(_onChanged);
  }

  void dispose() {
    _settle?.cancel();
    controller.removeListener(_onChanged);
  }

  /// ضبط برمجي للنص (تحميل/نتيجة مسح) — لا يُعدّ إدخالًا من المستخدم.
  void setText(String value) {
    _suppress = true;
    controller.text = value;
    controller.selection = TextSelection.collapsed(offset: value.length);
    _suppress = false;
    _prev = value;
    _base = value;
    _settle?.cancel();
    final now = DateTime.now();
    _burstStart = now;
    _lastChange = now;
  }

  bool _isBurst(String text) {
    if (text.length <= _base.length || !text.startsWith(_base)) return false;
    final grew = text.length - _base.length;
    if (grew < minBurst) return false;
    final ms = _lastChange.difference(_burstStart).inMilliseconds;
    return ms < grew * maxMsPerChar;
  }

  void _onChanged() {
    if (_suppress) {
      _prev = controller.text;
      return;
    }
    final t = controller.text;
    final now = DateTime.now();
    // حذف أو استبدال (غير إلحاق في الآخر) — قاعدة جديدة وإلغاء أي مسحة معلقة.
    // في الحقل اللي بيتعامل مع الاستبدال (freshOnReplace): الماسح اللي
    // بيستبدل النص المحدد كله نعتبر اللي هيتكتب هو القراءة كاملة، فالقاعدة
    // فاضية عشان المسحة تلتقط من أول حرف.
    if (t.length < _prev.length || !t.startsWith(_prev)) {
      _prev = t;
      _base = freshOnReplace ? '' : t;
      _burstStart = now;
      _lastChange = now;
      _settle?.cancel();
      return;
    }
    // فجوة زمنية = قد تبدأ مسحة جديدة → الأساس هو النص قبل هذا التغيير.
    if (now.difference(_lastChange).inMilliseconds > idleResetMs) {
      _base = _prev;
      _burstStart = now;
    }
    _prev = t;
    _lastChange = now;
    _settle?.cancel();
    if (t.length - _base.length < minBurst) return;
    _settle = Timer(const Duration(milliseconds: 250), _fire);
  }

  void _fire() {
    final t = controller.text;
    if (!_isBurst(t)) return;
    onBurst(t.substring(_base.length), _base);
  }
}
