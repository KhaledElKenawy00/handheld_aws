import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/scanner/scanner_providers.dart';
import '../../core/services/barcode_parser.dart';
import '../../core/services/barcode_resolver.dart';
import '../../core/theme/ref_style.dart';
import '../../core/utils/app_utils.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/common.dart';
import 'op_kind.dart';

/// التفاصيل — باركود/صنف/سعر/وزن يدوي + أضف + جدول + إجماليات.
/// - الباركود يدعم ماسح SUNMI L2s Pro (Broadcast + زر فيزيائي wedge):
///   حقل مركز تلقائيًا + زر "مسح" برمجي.
/// - السعر: مطلوب لو العملية نقدية (cash=true)، واختياري لو غير نقدية.
/// - الوزن: يدوي (يُملأ تلقائيًا من الباركود عند الإمكان ويقبل التعديل).
/// - كل مسح = وحدة واحدة (لا يوجد حقل عدد كراتين).
class OpDetailsScreen extends ConsumerStatefulWidget {
  final OpKind kind;
  final String headerId;
  final bool? cash;
  const OpDetailsScreen(
      {super.key, required this.kind, required this.headerId, this.cash});
  @override
  ConsumerState<OpDetailsScreen> createState() => _OpDetailsState();
}

class _DetailsLine {
  final int id;
  final String code;
  final String name;
  final double qty;
  final double weight;
  final double price;
  _DetailsLine(this.id, this.code, this.name, this.qty, this.weight, this.price);
}

/// صف مدمج في الجدول: نفس الصنف بكل مسحاته في صف واحد.
/// - الكمية = مجموع مسحات الصنف، الوزن = مجموع الأوزان، السعر = الأحدث.
/// - التفصيلة (كل مسحة في صف) تظهر في حوار التعديل فقط.
class _GroupedLine {
  final String code;
  String name;
  double qty = 0;
  double weight = 0;
  double price = 0;
  final List<_DetailsLine> scans = [];
  _GroupedLine({required this.code, required this.name});
}

/// لقطة إضافة واحدة في طابور التنفيذ (تُؤخذ لحظة المسح/الضغط).
class _PendingAdd {
  final String code;
  final String name;
  final double qty;
  final double price;
  final double weight;
  final String scanned;
  const _PendingAdd({
    required this.code,
    required this.name,
    required this.qty,
    required this.price,
    required this.weight,
    required this.scanned,
  });
}

class _OpDetailsState extends ConsumerState<OpDetailsScreen> {
  final barcodeC = TextEditingController();
  final barcodeFocus = FocusNode();
  final priceC = TextEditingController();
  final priceFocus = FocusNode();
  final weightC = TextEditingController();
  String? productCode;
  String? productName;
  String? lastScanned;
  List<Product> products = [];
  List<_DetailsLine> lines = [];
  StreamSubscription? scanSub;
  bool saving = false;
  bool cash = false;
  // سقف الكمية المطلوبة (من معلومات العملية — 0 = بلا سقف).
  double reqQty = 0;
  // كميات معلّقة في طابور التنفيذ (ممسوحة ولم تُحفظ بعد) — تُحسب مع
  // المنفذ عند فحص السقف حتى لا تتجاوزه المسحات السريعة.
  double _pendingQty = 0;
  // إضافة تلقائية عند ظهور الرقم في الحقل (وضع wedge بدون Enter):
  // نراقب الحقل، وبعد توقف الكتابة نضيف تلقائيًا مع منع التكرار.
  Timer? _autoT;
  String _lastHandled = '';
  final _inFlight = <String>{};
  // ── فاصل المسحات الملزوقة (wedge سريع): نتتبع سرعة الكتابة في حقل
  // الباركود — الدفعة السريعة (ماسح) تُستهلك فور وصول دفعة بعدها بدل ما
  // تلزق فيها ويطلع "الصنف غير موجود". الكتابة البطيئة (يدوي) لا تُفصل.
  String _prevBText = '';
  DateTime _burstStartT = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastBChangeT = DateTime.fromMillisecondsSinceEpoch(0);
  int _burstChars = 0;
  bool _progBarcode = false; // ضبط برمجي للحقل — تجاهله في المراقب
  // ── السعر التلقائي: كتابة السعر (نقدي) مع صنف معلّق تُضيف تلقائيًا
  // بعد توقف قصير — بدون الضغط على "أضف".
  Timer? _priceAutoT;
  bool _resolving = false; // حلّ جارٍ — تجاهل تغيرات السعر البرمجية
  bool priceError = false; // السعر مطلوب (نقدي بلا سعر) — يُعرض بالأحمر
  // ── حراسة المسحات الضالة: الماسح بوضع wedge يكتب في الحقل المركّز،
  // فلو ضغط اليوزر المسح وهو واقف على حقل السعر/الوزن، الدفعة السريعة
  // بمواصفات باركود تُنقل لحقل الباركود بدل ما تتحفظ كسعر/وزن.
  String _prevPriceText = '';
  DateTime _priceBurstStart = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _priceLastChange = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _priceScanT;
  String _prevWeightText = '';
  DateTime _weightBurstStart = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _weightLastChange = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _weightScanT;
  // آخر كود عولج وتوقيته — لمنع إضافة المسحة الواحدة مرتين عند وصولها
  // من مسارين (بث + كتابة + Enter) معًا. النافذة 400ms فقط حتى لا تلتهم
  // الضغطات السريعة المتتالية لنفس الصنف (كل ضغطة بعدها تُسجل).
  String _consumed = '';
  DateTime _consumedAt = DateTime.fromMillisecondsSinceEpoch(0);
  // تسلسل الإضافات: كل مسحة تلتقط بياناتها وتُنفذ بدورها دون تداخل
  // (حتى لا تضيع تحديثات الإجماليات مع المسح السريع).
  Future<void> _addQueue = Future.value();
  // آخر صنف تم اعتماده/مسحه — لتنبيه "صنف جديد" عند تغيّر الصنف
  // (الاستلام/التسليم فقط): لو مسح صنف مختلف عن السابق يظهر حوار تأكيد
  // قبل الإضافة حتى لا تدخل كرتونة صنف آخر بالغلط.
  String? _ackedCode;
  bool _confirmingNewItem = false;
  bool get _isReceiptDelivery =>
      widget.kind == OpKind.receipt || widget.kind == OpKind.delivery;

  @override
  void initState() {
    super.initState();
    _load();
    barcodeC.addListener(_onBarcodeChanged);
    priceC.addListener(_onPriceChanged);
    weightC.addListener(_onWeightChanged);
    // تركيز تلقائي على الباركود لاستقبال زر المسح الفيزيائي (wedge) فورًا.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) barcodeFocus.requestFocus();
    });
    try {
      // المسح بالماسح الفيزيائي يضيف الصنف تلقائيًا تحت بدون أي زرار.
      scanSub = ref.read(scannerServiceProvider).scanStream.listen((raw) {
        if (!mounted) return;
        _onScanAuto(raw);
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    final ps = await ref.read(productRepoProvider).search('', limit: 1000);
    if (!mounted) return;
    setState(() => products = ps);
    await _loadCash();
    await _reloadLines();
  }

  /// قراءة علامة نقدي + الكمية المطلوبة من الهيدر
  /// (أو النقدي من البراميتر لو قادم من شاشة المعلومات).
  /// السعر مطلوب لو نقدي، واختياري لو غير نقدي — والمسح شغال في الحالتين.
  /// الكمية المطلوبة سقف للإضافة: لا تُتجاوز في التفاصيل.
  Future<void> _loadCash() async {
    try {
      final k = widget.kind;
      if (k == OpKind.delivery) {
        final h = await ref.read(deliveryRepoProvider).find(widget.headerId);
        if (mounted) {
          setState(() {
            cash = widget.cash ?? h?.cash ?? false;
            reqQty = h?.reqQty ?? 0;
          });
        }
        return;
      }
      if (k == OpKind.receipt) {
        final h = await ref.read(receiptRepoProvider).find(widget.headerId);
        if (mounted) {
          setState(() {
            cash = widget.cash ?? h?.cash ?? false;
            reqQty = h?.reqQty ?? 0;
          });
        }
        return;
      }
      final h = await ref.read(opsRepoProvider).find(widget.headerId);
      if (mounted) {
        setState(() {
          cash = widget.cash ?? h?.cash ?? false;
          reqQty = h?.reqQty ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _reloadLines() async {
    final k = widget.kind;
    // سطور خام: كل مسحة سطر مستقل بوزنها (للحفاظ على تفصيلة الأوزان المتغيرة).
    // العرض مدمج (صف واحد لكل صنف عبر [grouped])، والتعديل يعرض كل مسحة في صف.
    final out = <_DetailsLine>[];
    if (k == OpKind.delivery) {
      final its = await ref.read(deliveryRepoProvider).items(widget.headerId);
      for (final it in its) {
        if (it.id == null) continue;
        out.add(_DetailsLine(it.id!, it.productCode, it.productName,
            it.quantity, it.weight, it.price));
      }
    } else if (k == OpKind.receipt) {
      final its = await ref.read(receiptRepoProvider).items(widget.headerId);
      for (final it in its) {
        if (it.id == null) continue;
        out.add(_DetailsLine(it.id!, it.productCode, it.productName,
            it.quantity, it.weight, it.price));
      }
    } else {
      final its = await ref.read(opsRepoProvider).items(widget.headerId);
      for (final it in its) {
        if (it.id == null) continue;
        out.add(_DetailsLine(it.id!, it.productCode, it.productName,
            it.quantity, it.weight, it.price));
      }
    }
    if (mounted) setState(() => lines = out);
  }

  /// تجميع المسحات الخام إلى صف واحد لكل صنف للعرض في الجدول.
  /// نفس الصنف ممسوح 5 مرات → صف واحد: كمية = المجموع، وزن = المجموع، سعر = الأحدث.
  List<_GroupedLine> get grouped {
    final map = <String, _GroupedLine>{};
    final order = <String>[];
    for (final l in lines) {
      var g = map[l.code];
      if (g == null) {
        g = _GroupedLine(code: l.code, name: l.name);
        map[l.code] = g;
        order.add(l.code);
      }
      g.qty += l.qty;
      g.weight += l.weight;
      g.price = l.price; // الأحدث (السطور بترتيب الإضافة)
      if (l.name.isNotEmpty) g.name = l.name;
      g.scans.add(l);
    }
    return [for (final c in order) map[c]!];
  }

  @override
  void dispose() {
    scanSub?.cancel();
    _autoT?.cancel();
    _priceAutoT?.cancel();
    _priceScanT?.cancel();
    _weightScanT?.cancel();
    barcodeC.removeListener(_onBarcodeChanged);
    priceC.removeListener(_onPriceChanged);
    weightC.removeListener(_onWeightChanged);
    barcodeC.dispose();
    barcodeFocus.dispose();
    priceC.dispose();
    priceFocus.dispose();
    weightC.dispose();
    super.dispose();
  }

  /// ضبط حقل الباركود برمجيًا مع مزامنة متتبع الدفعات (حتى لا تُقرأ
  /// الكتابة البرمجية كدفعة ماسح).
  void _setBarcode(String v) {
    _progBarcode = true;
    try {
      barcodeC.text = v;
    } finally {
      _progBarcode = false;
    }
    final now = DateTime.now();
    _prevBText = v;
    _burstChars = 0;
    _burstStartT = now;
    _lastBChangeT = now;
  }

  /// أي تغير في حقل الباركود (كتابة ماسح wedge بدون Enter أو إدخال يدوي).
  /// - الدفعة السريعة (ماسح: ≥4 أحرف بمتوسط <50ms) تُستهلك بعد 250ms فقط.
  /// - لو بدأت دفعة جديدة وسابقتها دفعة ماسح كاملة لم تُستهلك، تُقدَّم
  ///   السابقة فورًا ويُفصل الجديد في الحقل — 3 مسحات ورا بعض تتسجل كلها
  ///   بدل ما يلزقوا في بعض ويطلع "الصنف غير موجود".
  /// - الكتابة اليدوية البطيئة تُمهل 900ms ولا تُفصل أبدًا.
  void _onBarcodeChanged() {
    if (_progBarcode) return;
    final raw = barcodeC.text;
    final now = DateTime.now();
    final gap = now.difference(_lastBChangeT).inMilliseconds;
    // ذيل wedge لنفس المسحة المعالَجة (أحرف سريعة بعد الكود المستهلَك):
    // تجاهله وأعد الحقل للكود المعالَج بدل ما يلزق عليه.
    if (gap <= 120 &&
        _lastHandled.length >= 4 &&
        raw.startsWith(_lastHandled) &&
        raw.length > _lastHandled.length) {
      _autoT?.cancel();
      _setBarcode(_lastHandled);
      return;
    }
    if (raw.length < _prevBText.length) {
      // مسح يدوي (Backspace) — بداية بطيئة جديدة.
      _prevBText = raw;
      _burstChars = 0;
      _burstStartT = now;
      _lastBChangeT = now;
      _autoT?.cancel();
      _autoT = Timer(const Duration(milliseconds: 900), _fireBarcodeTimer);
      return;
    }
    if (gap > 120) {
      // فاصل — قيّم الدفعة السابقة قبل بدء الجديدة.
      final prev = _prevBText;
      final burstMs = _lastBChangeT.difference(_burstStartT).inMilliseconds;
      final prevFast = _burstChars >= 4 &&
          burstMs < _burstChars * 50 &&
          prev.length >= 4;
      if (prevFast && raw.startsWith(prev) && raw.length > prev.length) {
        final remainder = raw.substring(prev.length);
        _setBarcode(remainder);
        _burstStartT = now;
        _burstChars = remainder.length;
        _lastBChangeT = now;
        _autoT?.cancel();
        _autoT = Timer(const Duration(milliseconds: 250), _fireBarcodeTimer);
        final cleanPrev = BarcodeParser.clean(prev);
        if (cleanPrev.isNotEmpty && cleanPrev != _lastHandled) {
          _onScanAuto(cleanPrev);
        }
        return;
      }
      // بداية دفعة جديدة.
      _burstStartT = now;
      _burstChars = raw.length;
    } else {
      _burstChars = raw.length;
    }
    _prevBText = raw;
    _lastBChangeT = now;
    _autoT?.cancel();
    final fastNow = _burstChars >= 4 &&
        now.difference(_burstStartT).inMilliseconds < _burstChars * 50;
    _autoT = Timer(
        Duration(milliseconds: fastNow ? 250 : 900), _fireBarcodeTimer);
  }

  void _fireBarcodeTimer() {
    if (!mounted) return;
    final t = BarcodeParser.clean(barcodeC.text);
    if (t.isEmpty) {
      _lastHandled = '';
      return;
    }
    // تجاهل القصير جدًا وما سبق معالجته (ضبطناه برمجيًا بأنفسنا).
    if (t.length < 4 || t == _lastHandled) return;
    _onScanAuto(t);
  }

  /// كتابة السعر في النقدي مع صنف معلّق (من مسحة بلا سعر أو اختيار يدوي)
  /// تُضيف الصنف تلقائيًا بعد توقف قصير — بدون الضغط على "أضف".
  void _onPriceChanged() {
    // حراسة المسحة الضالة أولًا (شغالة نقدي وغير نقدي).
    if (_resolving) {
      _prevPriceText = priceC.text;
      final now = DateTime.now();
      _priceBurstStart = now;
      _priceLastChange = now;
      return;
    }
    if (!mounted) return;
    _trackFieldBurst(priceC.text, true);
    if (!cash) return;
    if (productCode == null) return;
    if (AppUtils.parseNum(priceC.text) <= 0) return;
    // سعر صحيح دخل — أطفئ علامة الخطأ الحمراء.
    if (priceError && mounted) setState(() => priceError = false);
    _priceAutoT?.cancel();
    _priceAutoT = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || !cash || productCode == null) return;
      if (AppUtils.parseNum(priceC.text) <= 0) return;
      _add();
    });
  }

  /// تغير حقل الوزن: القيمة تُقرأ لحظة الإضافة — هنا فقط حراسة المسحة الضالة.
  void _onWeightChanged() {
    if (_resolving) {
      _prevWeightText = weightC.text;
      final now = DateTime.now();
      _weightBurstStart = now;
      _weightLastChange = now;
      return;
    }
    if (!mounted) return;
    _trackFieldBurst(weightC.text, false);
  }

  /// تتبع سرعة الكتابة في حقلي السعر/الوزن: الدفعة السريعة بمواصفات
  /// باركود (≥4 محارف بمتوسط <50ms) تُمهل 250ms ثم تُفحص للنقل.
  /// الكتابة اليدوية البطيئة والحذف لا يُلتقطان أبدًا.
  void _trackFieldBurst(String text, bool isPrice) {
    final now = DateTime.now();
    if (isPrice) {
      if (text.length < _prevPriceText.length) {
        _prevPriceText = text;
        _priceBurstStart = now;
        _priceLastChange = now;
        _priceScanT?.cancel();
        return;
      }
      if (now.difference(_priceLastChange).inMilliseconds > 120) {
        _priceBurstStart = now;
      }
      _prevPriceText = text;
      _priceLastChange = now;
      _priceScanT?.cancel();
      if (text.trim().length < 4) return;
      _priceScanT = Timer(
          const Duration(milliseconds: 250), () => _fireFieldScan(true));
    } else {
      if (text.length < _prevWeightText.length) {
        _prevWeightText = text;
        _weightBurstStart = now;
        _weightLastChange = now;
        _weightScanT?.cancel();
        return;
      }
      if (now.difference(_weightLastChange).inMilliseconds > 120) {
        _weightBurstStart = now;
      }
      _prevWeightText = text;
      _weightLastChange = now;
      _weightScanT?.cancel();
      if (text.trim().length < 4) return;
      _weightScanT = Timer(
          const Duration(milliseconds: 250), () => _fireFieldScan(false));
    }
  }

  void _fireFieldScan(bool isPrice) {
    if (!mounted) return;
    final text = isPrice ? priceC.text : weightC.text;
    final t = text.trim();
    if (t.length < 4) return;
    final ms = (isPrice ? _priceLastChange : _weightLastChange)
        .difference(isPrice ? _priceBurstStart : _weightBurstStart)
        .inMilliseconds;
    if (ms >= t.length * 50) return; // سرعة يدوية — سعر/وزن حقيقي
    _redirectFieldScan(t, isPrice);
  }

  /// هل النص يحل لصنف معروف؟ (فحص قبل النقل حتى لا تضيع كتابة يدوية
  /// سريعة لا تمثل باركود — تبقى كسعر/وزن كما هي).
  Future<bool> _resolvesToProduct(String code) async {
    final c = BarcodeParser.clean(code);
    if (c.length < 4) return false;
    try {
      final pc =
          await ref.read(productCodeRepoProvider).findByBarcode(c);
      if (pc != null) return true;
    } catch (_) {}
    try {
      final p = await ref.read(productRepoProvider).findByBarcode(c);
      if (p != null) return true;
    } catch (_) {}
    try {
      final seg = await ref
          .read(productCodeRepoProvider)
          .resolveByCodeSegment(c);
      if (seg != null) return true;
    } catch (_) {}
    try {
      final ts = await ref.read(productCodeRepoProvider).all();
      for (final t in ts) {
        if (t.wStart <= 0 || t.wEnd <= 0) continue;
        if (BarcodeResolver.matchesTemplate(c, t)) return true;
      }
    } catch (_) {}
    try {
      final p = await ref.read(productRepoProvider).findByCode(c);
      if (p != null) return true;
    } catch (_) {}
    return false;
  }

  /// نقل مسحة ضالة من حقل السعر/الوزن إلى مكانها (حقل الباركود).
  Future<void> _redirectFieldScan(String text, bool isPrice) async {
    final code = BarcodeParser.clean(text);
    if (code.length < 4 || !mounted) return;
    if (!await _resolvesToProduct(code)) return; // كتابة يدوية — تُترك
    if (!mounted) return;
    // ألغِ أي إضافة تلقائية معلقة بالسعر قبل مسح الحقل.
    _priceAutoT?.cancel();
    _priceScanT?.cancel();
    _weightScanT?.cancel();
    _resolving = true;
    try {
      if (isPrice) {
        priceC.clear();
        _prevPriceText = '';
        final now = DateTime.now();
        _priceBurstStart = now;
        _priceLastChange = now;
      } else {
        weightC.clear();
        _prevWeightText = '';
        final now = DateTime.now();
        _weightBurstStart = now;
        _weightLastChange = now;
      }
    } finally {
      _resolving = false;
    }
    if (!mounted) return;
    try {
      barcodeFocus.requestFocus();
    } catch (_) {}
    _lastHandled = '';
    if (mounted) refToast(context, 'نُقلت المسحة إلى حقل الباركود');
    _onScanAuto(code);
  }

  /// معالج المسحات الضالة القادمة من خلايا الجدول.
  Future<bool> _handleCellScan(String text) async {
    final code = BarcodeParser.clean(text);
    if (code.length < 4 || !mounted) return false;
    if (!await _resolvesToProduct(code)) return false;
    _onScanAuto(code);
    return true;
  }

  /// حوار تنبيه يعيد التركيز لحقل الباركود بعد الإغلاق
  /// حتى لا تضيع المسحات التالية (وضع wedge يحتاج حقلًا مركزًا).
  /// [backToBarcode]=false يبقي التركيز حيث هو (مثل حقل السعر المطلوب).
  Future<void> _scanAlert(String msg, {bool backToBarcode = true}) async {
    try {
      await refError(context, msg);
    } catch (_) {}
    if (mounted && backToBarcode) {
      try {
        barcodeFocus.requestFocus();
      } catch (_) {}
    }
  }

  /// تنبيه "صنف جديد": يظهر عند مسح صنف مختلف عن آخر صنف معتمد
  /// (في الاستلام/التسليم فقط) — يذكر اسم الصنف ويسأل: إضافة أم لا.
  /// صوت نظام + اهتزاز ليُنتبه له، ثم إعادة التركيز لحقل الباركود.
  Future<bool> _confirmNewItem(String name) async {
    _confirmingNewItem = true;
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    bool ok = false;
    try {
      final r = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('صنف جديد',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 19,
                  fontWeight: FontWeight.w800)),
          content: Text(
            'بدأت مسح صنف جديد:\n\n$name\n\nهل تريد إضافته؟',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.6),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إضافة')),
          ],
        ),
      );
      ok = r == true;
    } catch (_) {
      ok = false;
    }
    if (mounted) {
      try {
        barcodeFocus.requestFocus();
      } catch (_) {}
    }
    _confirmingNewItem = false;
    return ok;
  }

  /// إدخال باركود: يبحث في أكواد الأصناف ثم حقل باركود الصنف ثم القالب
  /// المتغير ثم كود الصنف مباشرة،
  /// مسح بالماسح الفيزيائي أو Enter — يحل الباركود ويضيف الصنف
  /// تلقائيًا تحت بدون الضغط على "أضف".
  /// - يبحث في أكواد الأصناف (product_codes) ثم حقل products.barcode
  ///   ثم القالب المتغير ثم كود الصنف.
  /// - لو العملية نقدية والسعر غير معروف يُبقي الصنف محددًا ويطلب السعر يدويًا.
  /// غلاف آمن: أي عطل غير متوقع أثناء حل الباركود يُعرض كرسالة بدل
  /// الصمت (اهتزاز فقط بدون أي رد — البلاغ الأخير).
  Future<void> _onScanAuto(String raw) async {
    try {
      final code = BarcodeParser.clean(raw);
      if (code.isEmpty || !mounted) return;
      // حوار "صنف جديد" مفتوح — تجاهل أي مسحة حتى لا تُضاف بدون تأكيد.
      if (_confirmingNewItem) return;
      // منع المعالجة المكررة لنفس المسحة الواحدة عند وصولها من مسارين
      // (بث + كتابة + Enter + تلقائي) معًا — النافذة 400ms فقط، وأي ضغطة
      // جديدة بعدها لنفس الصنف تُعالج وتُسجل (لا تُلتهم).
      final now = DateTime.now();
      if (_inFlight.contains(code)) return;
      if (code == _consumed &&
          now.difference(_consumedAt).inMilliseconds < 400) {
        return;
      }
      _inFlight.add(code);
      try {
        await _resolveAndAdd(code);
      } finally {
        _inFlight.remove(code);
      }
    } catch (e) {
      if (!mounted) return;
      _setBarcode('');
      try {
        setState(() {
          lastScanned = BarcodeParser.clean(raw);
          _lastHandled = BarcodeParser.clean(raw);
        });
      } catch (_) {}
      if (mounted) _scanAlert('تعذر إتمام المسح: $e');
    }
  }

  Future<void> _resolveAndAdd(String code) async {
    if (!mounted) return;
    // علّم الكود كمعالَج حتى لا يعيد مفجر التلقائي إطلاقه
    // بسبب ضبطنا الحقل برمجيًا أدناه، وحتى تُمتص نسخة المسحة
    // نفسها القادمة من مسار موازٍ خلال 400ms.
    _consumed = code;
    _consumedAt = DateTime.now();
    _lastHandled = code;
    HapticFeedback.lightImpact();
    // مسحة جديدة — أطفئ علامة السعر الحمراء القديمة (لو ظهرت ستُضاء مجددًا).
    if (priceError && mounted) setState(() => priceError = false);
    // تغيرات السعر البرمجية أثناء الحل (ملء تلقائي) لا تُشعل الإضافة التلقائية.
    _resolving = true;
    try {
      await _resolveBody(code);
    } finally {
      _resolving = false;
    }
  }

  Future<void> _resolveBody(String code) async {
    if (!mounted) return;
    // ملاحظة: لا نكتب الكود الممسوح في حقل الباركود عمدًا — الحقل ملك
    // لإدخال الماسح/اليد فقط، وأي كتابة برمجية فيه تلزق مع المسحة التالية
    // السريعة فيطلع "الصنف غير موجود". آخر مسح يظهر تحت الحقل.
    // 1) باركود مسجل في product_codes
    final pc = await ref.read(productCodeRepoProvider).findByBarcode(code);
    if (pc != null) {
      final p =
          await ref.read(productRepoProvider).findByCode(pc.productCode);
      if (!mounted) return;
      if (p != null && !p.isActive) {
        setState(() {
          lastScanned = code;
        });
        _scanAlert('الصنف موقوف: $code');
        return;
      }
      setState(() {
        lastScanned = code;
        productCode = pc.productCode;
        productName = p?.desc ?? pc.productCode;
        // نقدي: املأ السعر تلقائيًا من سعر الصنف الافتراضي (لو مدخلتش
        // سعرًا، المسح لن يضيف — السعر مطلوب في النقدي).
        if (cash && priceC.text.trim().isEmpty && p != null && p.price > 0) {
          priceC.text = _f(p.price);
        }
        // صنف بلا وزن باركودي → تجاهل وزن الباركود (صفر) إلا الثابت الصريح.
        if (pc.weight != 0 && (p == null || p.hasWeight)) {
          weightC.text = _f(pc.weight);
        } else if (p != null &&
            p.weightType == 'ثابت' &&
            p.fixedWeight > 0 &&
            weightC.text.trim().isEmpty) {
          weightC.text = _f(p.fixedWeight);
        }
      });
      await _add(fromScan: true);
      return;
    }
    // 2) باركود مسجل في حقل الصنف نفسه (products.barcode)
    // — كان يُحفظ عند إضافة الصنف لكن لم يُبحث عنه أبدًا (سبب البلاغ).
    try {
      final pb = await ref.read(productRepoProvider).findByBarcode(code);
      if (pb != null) {
        if (!mounted) return;
        if (!pb.isActive) {
        setState(() {
          lastScanned = code;
        });
        _scanAlert('الصنف موقوف: $code');
          return;
        }
        setState(() {
          lastScanned = code;
          productCode = pb.code;
          productName = pb.desc;
          if (cash &&
              priceC.text.trim().isEmpty &&
              pb.price > 0) {
            priceC.text = _f(pb.price);
          }
          if (pb.weightType == 'ثابت' &&
              pb.fixedWeight > 0 &&
              weightC.text.trim().isEmpty) {
            weightC.text = _f(pb.fixedWeight);
          }
        });
        await _add(fromScan: true);
        return;
      }
    } catch (_) {}
    // 3) مقطع الكود داخل الباركود (cStart..cEnd المحدد من المستخدم)
    // — يستخرج كود الصنف من داخل الممسوح ويحدد الصنف تلقائيًا.
    try {
      final seg =
          await ref.read(productCodeRepoProvider).resolveByCodeSegment(code);
      if (seg != null) {
        final p = seg.product;
        if (!mounted) return;
        if (!p.isActive) {
        setState(() {
          lastScanned = code;
        });
        _scanAlert('الصنف موقوف: $code');
          return;
        }
        final w =
            p.hasWeight ? BarcodeResolver.templateWeight(code, seg.template) : 0.0;
        setState(() {
          lastScanned = code;
          productCode = p.code;
          productName = p.desc;
          if (cash &&
              priceC.text.trim().isEmpty &&
              p.price > 0) {
            priceC.text = _f(p.price);
          }
          if (w != 0) {
            weightC.text = _f(w);
          } else if (p.weightType == 'ثابت' &&
              p.fixedWeight > 0 &&
              weightC.text.trim().isEmpty) {
            weightC.text = _f(p.fixedWeight);
          }
        });
        await _add(fromScan: true);
        return;
      }
    } catch (_) {}
    // 4) قالب وزن متغير
    try {
      final templates = await ref.read(productCodeRepoProvider).all();
      final t = _matchTemplate(code, templates);
      if (t != null) {
        final p =
            await ref.read(productRepoProvider).findByCode(t.productCode);
        var w =
            BarcodeParser.calcValue(code, t.wStart, t.wEnd, t.mark);
        // صنف بلا وزن باركودي → صفر.
        if (p != null && !p.hasWeight) w = 0;
        if (!mounted) return;
        if (p != null && !p.isActive) {
        setState(() {
          lastScanned = code;
        });
        _scanAlert('الصنف موقوف: $code');
          return;
        }
        setState(() {
          lastScanned = code;
          productCode = t.productCode;
          productName = p?.desc ?? t.productCode;
          if (cash &&
              priceC.text.trim().isEmpty &&
              p != null &&
              p.price > 0) {
            priceC.text = _f(p.price);
          }
          if (w != 0) {
            weightC.text = _f(w);
          }
        });
        await _add(fromScan: true);
        return;
      }
    } catch (_) {}
    // 5) كود صنف مباشر
    final p = await ref.read(productRepoProvider).findByCode(code);
    if (!mounted) return;
    if (p == null || !p.isActive) {
      setState(() {
        lastScanned = code;
      });
      // رسالة تشخيصية توضح السبب والحل بدل العمومية.
      String msg = 'الصنف غير موجود: $code';
      try {
        final templates = await ref.read(productCodeRepoProvider).all();
        if (mounted) msg = BarcodeResolver.diagnoseNotFound(code, templates);
      } catch (_) {}
      if (mounted) _scanAlert(msg);
      return;
    }
    setState(() {
      lastScanned = code;
      productCode = p.code;
      productName = p.desc;
      if (cash && priceC.text.trim().isEmpty && p.price > 0) {
        priceC.text = _f(p.price);
      }
      if (p.weightType == 'ثابت' &&
          p.fixedWeight > 0 &&
          weightC.text.trim().isEmpty) {
        weightC.text = _f(p.fixedWeight);
      }
    });
    await _add(fromScan: true);
  }

  String _f(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  /// تنسيق الوزن برقمين عشريين فقط (مثال: 21.50).
  String _f2(double v) => v.toStringAsFixed(2);

  /// حساب وزن الوحدة تلقائيًا من الباركود الممسوح (يُستخدم كقيمة مقترحة
  /// لحقل الوزن اليدوي وكـ fallback لو الحقل فاضي عند الإضافة).

  /// مطابقة قالب متغير (مفوضة للمحلل المشترك: الوزن + التاريخ متغيران).
  ProductCode? _matchTemplate(String scanned, List<ProductCode> ts) {
    // القالب القديم يتطلب مقطع وزن مضبوطًا؛ نحتفظ بهذا الشرط هنا
    // حتى لا يطابق قالب بلا وزن أي باركود بنفس الطول عن طريق الخطأ.
    for (final t in ts) {
      if (t.wStart <= 0 || t.wEnd <= 0) continue;
      if (BarcodeResolver.matchesTemplate(scanned, t)) return t;
    }
    return null;
  }

  /// دخول الإضافة: يلتقط لقطة من البيانات الحالية ثم يصفّها في طابور
  /// التنفيذ. اللقطة ضرورية مع المسح السريع حتى لا تُكتب مسحة فوق
  /// بيانات مسحة أخرى قبل تنفيذها، والطابور يمنع تداخل تحديثات
  /// الإجماليات في قاعدة البيانات.
  Future<void> _add({bool fromScan = false}) async {
    // إلغاء الإضافة التلقائية المعلقة بالسعر — الدخول هنا (يدوي أو تلقائي)
    // يعني تنفيذًا واحدًا فقط حتى لا يتكرر السطر.
    _priceAutoT?.cancel();
    if (productCode == null) {
      _scanAlert('حدد الصنف أولًا (امسح الباركود أو اختر من القائمة)');
      return;
    }
    // كل إضافة = وحدة واحدة (لا يوجد عدد كراتين).
    const qty = 1.0;
    // سقف الكمية المطلوبة (من معلومات العملية): المنفذ فعليًا + المعلّق
    // في الطابور لا يتجاوزه — ولو زادت مسحة تُرفض برسالة خطأ.
    final doneQty =
        lines.fold(0.0, (a, b) => a + b.qty) + _pendingQty;
    if (reqQty > 0 && doneQty + qty > reqQty) {
      HapticFeedback.heavyImpact();
      _scanAlert(
          'تم تنفيذ الكمية المطلوبة (${_f(reqQty)}) — لا يمكن إضافة المزيد');
      return;
    }
    // تنبيه "صنف جديد" (استلام/تسليم فقط): لو المسح صنفًا مختلفًا عن آخر
    // صنف معتمد نعرض حوار تأكيد قبل الإضافة حتى لا تدخل كرتونة صنف آخر
    // بالغلط. الإضافة اليدوية (من القائمة/زر أضف) تُعتمد مباشرة.
    if (_isReceiptDelivery) {
      if (fromScan) {
        final code = productCode!;
        if (code != _ackedCode) {
          final ok = await _confirmNewItem(productName ?? code);
          if (!ok) {
            if (mounted) {
              _setBarcode('');
              setState(() {
                productCode = null;
                productName = null;
              });
            }
            return;
          }
          if (!mounted) return;
          _ackedCode = code;
        }
      } else {
        _ackedCode = productCode;
      }
    }
    // لو العملية غير نقدية السعر يُحفظ صفرًا دائمًا (طلب المستخدم).
    // parseNum يقبل الأرقام العربية أيضًا حتى يسمع السعر المدخل بأي لوحة.
    final price = cash ? AppUtils.parseNum(priceC.text) : 0.0;
    // السعر مطلوب للنقدي فقط — بدونه لا تُضاف المسحة (حتى لا يدخل صنف بلا سعر).
    if (cash && price <= 0) {
      // حقل السعر بالأحمر + اهتزاز الجهاز + تنبيه، والتركيز يبقى على السعر.
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => priceError = true);
      _scanAlert(
          'الصنف اتعرف (${productName ?? productCode}) لكن السعر مطلوب (عملية نقدية) — ادخله وسيُضاف تلقائيًا',
          backToBarcode: false);
      // وجّه المستخدم لحقل السعر مباشرة.
      try {
        priceFocus.requestFocus();
      } catch (_) {}
      return;
    }
    // حُجزت في الطابور — تُخصم عند التنفيذ (نجاحًا أو فشلًا) حتى يبقى
    // فحص السقف دقيقًا مع المسح السريع المتتالي.
    _pendingQty += qty;
    final snap = _PendingAdd(
      code: productCode!,
      name: productName ?? productCode!,
      qty: qty,
      price: price,
      // الوزن يدوي: لو الحقل فاضي يُحسب تلقائيًا وقت التنفيذ.
      weight: AppUtils.parseNum(weightC.text),
      scanned: BarcodeParser.clean(barcodeC.text),
    );
    final next = _addQueue.then((_) => _performAdd(snap));
    // إبقاء الطابور سليمًا لو فشلت إضافة (التالي يعمل بعده).
    _addQueue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _performAdd(_PendingAdd s) async {
    // الوزن يدوي: لو الحقل فاضي حاول التعبئة التلقائية من الباركود/الصنف.
    var weight = s.weight;
    if (weight <= 0) {
      weight = await _calcAutoWeight(
          scanned: s.scanned, productCode: s.code);
    }
    if (!mounted) return;
    setState(() => saving = true);
    try {
      final line = DocLine(
          productCode: s.code, productName: s.name, quantity: s.qty, weight: weight, price: s.price);
      final k = widget.kind;
      if (k == OpKind.delivery) {
        await ref.read(deliveryRepoProvider).addItem(widget.headerId, line);
      } else if (k == OpKind.receipt) {
        await ref.read(receiptRepoProvider).addItem(widget.headerId, line);
      } else {
        await ref.read(opsRepoProvider).addItem(widget.headerId, line);
      }
      _setBarcode('');
      // نقدي: السعر لازق — يفضل ثابتًا للمسحات التالية (تحطه مرة واحدة
      // ويسمع مع كل صنف)، ويتغير فقط لو كتبت قيمة جديدة أو مسحته يدويًا.
      // غير نقدي: السعر غير مستخدم (يُحفظ صفرًا) فيُمسح حتى لا يضلل.
      if (!cash) priceC.clear();
      weightC.clear();
      // تصفير المعالَج يتيح للمراقب التلقائي التقاط المسحة التالية ولو مطابقة.
      _lastHandled = '';
      setState(() {
        productCode = null;
        productName = null;
        priceError = false;
      });
      await _reloadLines();
      if (mounted) {
        refToast(context, 'تمت الإضافة');
        // إبقاء التركيز على الباركود لمسح الصنف التالي مباشرة.
        barcodeFocus.requestFocus();
      }
    } catch (e) {
      if (mounted) _scanAlert('$e');
    } finally {
      // تحرير الحجز من فحص السقف — نجاحًا أو فشلًا.
      _pendingQty -= s.qty;
      if (_pendingQty < 0) _pendingQty = 0;
      if (mounted) setState(() => saving = false);
    }
  }

  /// وزن تلقائي مقترح من الباركود/الصنف (للملء التلقائي + fallback).
  /// صنف بلا وزن باركودي (hasWeight مطفي) → صفر مباشرة (أو الثابت الصريح).
  Future<double> _calcAutoWeight(
      {required String scanned, required String productCode}) async {
    try {
      final p0 = await ref.read(productRepoProvider).findByCode(productCode);
      if (p0 != null && !p0.hasWeight) {
        if (p0.weightType == 'ثابت' && p0.fixedWeight > 0) {
          return p0.fixedWeight;
        }
        return 0.0;
      }
    } catch (_) {}
    if (scanned.isNotEmpty) {
      try {
        final exact =
            await ref.read(productCodeRepoProvider).findByBarcode(scanned);
        if (exact != null && exact.weight > 0) {
          // لا تأخذ وزن قالب يخص صنفًا موقوفًا/بلا وزن.
          final ep =
              await ref.read(productRepoProvider).findByCode(exact.productCode);
          if (ep == null || (ep.isActive && ep.hasWeight)) {
            return exact.weight;
          }
        }
      } catch (_) {}
      try {
        final ts = await ref.read(productCodeRepoProvider).all();
        final t = _matchTemplate(scanned, ts);
        if (t != null) {
          final w = BarcodeParser.calcValue(scanned, t.wStart, t.wEnd, t.mark);
          if (w > 0) return w;
        }
      } catch (_) {}
      try {
        final pcs =
            await ref.read(productCodeRepoProvider).forProduct(productCode);
        // اشتق الوزن فقط من قالب يُطابق الممسوح فعلًا — لا تطبق مقطعًا
        // على باركود لا ينتمي لعائلته فيخرج وزن وهمي (مثل رقم الباركود نفسه).
        for (final c in pcs) {
          if (!BarcodeResolver.matchesTemplate(scanned, c)) continue;
          if (c.wStart > 0 && c.wEnd > 0) {
            final w =
                BarcodeParser.calcValue(scanned, c.wStart, c.wEnd, c.mark);
            if (w > 0) return w;
          }
          if (c.weight > 0) return c.weight;
        }
      } catch (_) {}
    } else {
      try {
        final pcs =
            await ref.read(productCodeRepoProvider).forProduct(productCode);
        if (pcs.isNotEmpty && pcs.first.weight > 0) {
          return pcs.first.weight;
        }
      } catch (_) {}
    }
    try {
      final p = await ref.read(productRepoProvider).findByCode(productCode);
      if (p != null && p.weightType == 'ثابت' && p.fixedWeight > 0) {
        return p.fixedWeight;
      }
    } catch (_) {}
    return 0.0;
  }

  /// تحديث سطر خام واحد (يُستخدم من التعديل السريع وحوار التفصيلة).
  Future<void> _applyScanUpdate(_DetailsLine l,
      {required double quantity,
      required double weight,
      required double price}) async {
    final k = widget.kind;
    if (k == OpKind.delivery) {
      await ref.read(deliveryRepoProvider).updateItem(
          widget.headerId, l.id,
          quantity: quantity, weight: weight, price: price);
    } else if (k == OpKind.receipt) {
      await ref.read(receiptRepoProvider).updateItem(
          widget.headerId, l.id,
          quantity: quantity, weight: weight, price: price);
    } else {
      await ref.read(opsRepoProvider).updateItem(widget.headerId, l.id,
          quantity: quantity, weight: weight, price: price);
    }
  }

  Future<void> _deleteScan(_DetailsLine l) async {
    final k = widget.kind;
    if (k == OpKind.delivery) {
      await ref.read(deliveryRepoProvider).deleteItem(widget.headerId, l.id);
    } else if (k == OpKind.receipt) {
      await ref.read(receiptRepoProvider).deleteItem(widget.headerId, l.id);
    } else {
      await ref.read(opsRepoProvider).deleteItem(widget.headerId, l.id);
    }
  }

  /// حذف صف مدمج كامل (كل مسحات الصنف) مع عكس أثرها المخزني — بتأكيد أولًا.
  Future<void> _deleteGrouped(_GroupedLine g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الصنف؟',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        content: Text(
            '${g.name}\n${g.scans.length} مسحات — كمية ${_f(g.qty)} — وزن ${_f2(g.weight)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.6)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف الكل')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => saving = true);
    try {
      for (final s in g.scans) {
        await _deleteScan(s);
      }
      await _reloadLines();
      if (mounted) refToast(context, 'تم حذف الصنف');
    } catch (e) {
      if (mounted) _scanAlert('$e');
      await _reloadLines();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// حوار التعديل للصف المدمج: يعرض كل مسحة في صف مستقل
  /// (كمية/وزن/سعر كل مسحة) — للأوزان المتغيرة كل كرتونة في صف.
  Future<void> _editGrouped(_GroupedLine g) async {
    final others = grouped
        .where((e) => e.code != g.code)
        .fold(0.0, (a, b) => a + b.qty);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _GroupedEditDialog(
        kind: widget.kind,
        headerId: widget.headerId,
        productCode: g.code,
        productName: g.name,
        reqQty: reqQty,
        othersQty: others,
        readOnly: widget.kind == OpKind.receipt ||
            widget.kind == OpKind.delivery,
      ),
    );
    if (ok == true) {
      if (mounted) refToast(context, 'تم تعديل الصنف');
      await _reloadLines();
    } else {
      // حتى لو أُغلق بدون حفظ صريح، حدّث (الحوار يحفظ لحظيًا).
      await _reloadLines();
    }
  }

  /// تحديث خلية مباشر من الجدول المدمج (كمية/وزن/سعر) بدون حوار.
  /// - السعر: يُطبق على كل مسحات الصنف (سعر واحد للصنف).
  /// - الكمية/الوزن: الفرق يُحمّل على آخر مسحة حتى تبقى تفصيلة
  ///   المسحات السابقة محفوظة (مهم للأوزان المتغيرة).
  Future<void> _quickUpdateGrouped(int gi,
      {double? qty, double? weight, double? price}) async {
    final gs = grouped;
    if (gi < 0 || gi >= gs.length) return;
    final g = gs[gi];
    if (g.scans.isEmpty) return;
    if (qty != null && qty <= 0) {
      refError(context, 'الكمية يجب أن تكون أكبر من صفر');
      return;
    }
    final others =
        gs.where((e) => e.code != g.code).fold(0.0, (a, b) => a + b.qty);
    final newTotalQty = qty ?? g.qty;
    if (reqQty > 0 && others + newTotalQty > reqQty) {
      refError(context,
          'تم تنفيذ الكمية المطلوبة (${_f(reqQty)}) — لا يمكن الزيادة');
      return;
    }
    setState(() => saving = true);
    try {
      // السعر الفعّال بعد التحديث (حتى لا تُرجع التحديثات اللاحقة السعر القديم).
      var effectivePrice = g.price;
      if (price != null && price != g.price) {
        for (final s in g.scans) {
          await _applyScanUpdate(s,
              quantity: s.qty, weight: s.weight, price: price);
        }
        effectivePrice = price;
      }
      if (qty != null && qty != g.qty) {
        final last = g.scans.last;
        final nq = last.qty + (qty - g.qty);
        if (nq <= 0) {
          if (mounted) {
            refError(context,
                'لا يمكن تصفير الإجمالي من هنا — احذف مسحات من حوار التعديل');
          }
        } else {
          await _applyScanUpdate(last,
              quantity: nq, weight: last.weight, price: effectivePrice);
        }
      }
      if (weight != null && weight != g.weight) {
        final last = g.scans.last;
        final nw = last.weight + (weight - g.weight);
        if (nw < 0) {
          if (mounted) refError(context, 'الوزن لا يمكن أن يكون سالبًا');
        } else {
          await _applyScanUpdate(last,
              quantity: qty ?? last.qty,
              weight: nw,
              price: effectivePrice);
        }
      }
      await _reloadLines();
    } catch (e) {
      if (mounted) _scanAlert('$e');
      await _reloadLines();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalQty = lines.fold(0.0, (a, b) => a + b.qty);
    final totalWeight = lines.fold(0.0, (a, b) => a + b.weight);
    final totalPrice = lines.fold(0.0, (a, b) => a + b.qty * b.price);
    final firstPrice = lines.isEmpty ? 0.0 : lines.first.price;
    return RefScaffold(
      title: 'التفاصيل',
      headerActions: [
        InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.save_outlined, color: Colors.white, size: 28),
          ),
        ),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.more_vert_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: barcodeC,
                  focusNode: barcodeFocus,
                  autofocus: true,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 22),
                  decoration: InputDecoration(
                    hintText: 'امسح الباركود بالماسح',
                    helperText: lastScanned == null
                        ? 'امسح أو اكتب الرقم — يُضاف تلقائيًا تحت'
                        : 'آخر مسح: $lastScanned',
                  ),
                        textInputAction: TextInputAction.done,
                        // نقرأ النص الحالي لا القيمة المرسلة: لو كان البث قد
                        // عالج المسحة ومسح الحقل نتجاهل الـ Enter المتأخر.
                        onSubmitted: (_) => _onScanAuto(barcodeC.text),
                      ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: RefDropdown<String>(
                        label: 'حدد الصنف',
                        value: productCode,
                        items: [
                          for (final p in products)
                            DropdownMenuItem(
                                value: p.code,
                                child: Text('${p.desc} - ${p.code}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) async {
                          if (v == null) return;
                          final p = await ref.read(productRepoProvider).findByCode(v);
                          setState(() {
                            productCode = v;
                            productName = p?.desc ?? v;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RefField(
                          controller: priceC,
                          focusNode: priceFocus,
                          label: cash
                              ? 'السعر (مطلوب — يثبت للمسح التالي)'
                              : 'السعر (اختياري)',
                          errorText:
                              priceError ? 'السعر مطلوب' : null,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: saving ? null : () => _add(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RefColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            textStyle: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('أضف'),
                              SizedBox(width: 6),
                              Icon(Icons.add_rounded, size: 26),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: RefField(
                          controller: weightC,
                          label: 'الوزن (يدوي)',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // الجدول مدمج: نفس الصنف بكل مسحاته في صف واحد (كمية/وزن مجموع، سعر أحدث) —
          // زر التعديل يعرض تفصيلة كل مسحة في صف مستقل (للأوزان المتغيرة).
          if (reqQty > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                'المنفذ: ${_f(totalQty)} / ${_f(reqQty)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: totalQty >= reqQty
                        ? RefColors.green
                        : RefColors.navy),
              ),
            ),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('لا توجد أصناف بعد — امسح للإضافة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      color: RefColors.hintGrey)),
            )
          else
            Builder(builder: (context) {
              final gs = grouped;
              // الاستلام/التسليم: عرض فقط (تيكست ثابت) بلا تعديل مباشر
              // للكمية/الوزن/السعر — وزر التعديل يفتح تفصيلة المسحات للحذف.
              final ro = widget.kind == OpKind.receipt ||
                  widget.kind == OpKind.delivery;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: LinesCellTable(
                  rows: [
                    for (final g in gs)
                      CellLineData(
                          code: g.code,
                          name: g.scans.length > 1
                              ? '${g.name} (${g.scans.length} مسحات)'
                              : g.name,
                          qty: g.qty,
                          weight: g.weight,
                          price: g.price),
                  ],
                  // نفس الصنف مدمج في صف واحد — الخلايا تحدّث الإجمالي،
                  // والتعديل يعرض كل مسحة في صف مستقل.
                  // أي مسحة تضل لحقل خلية تُعاد للباركود بدل حفظها كرقم.
                  editable: !ro,
                  onQtyChanged:
                      ro ? null : (i, v) => _quickUpdateGrouped(i, qty: v),
                  onWeightChanged: ro
                      ? null
                      : (i, v) => _quickUpdateGrouped(i, weight: v),
                  onPriceChanged:
                      ro ? null : (i, v) => _quickUpdateGrouped(i, price: v),
                  onScanRedirect: _handleCellScan,
                  onEdit: (i) => _editGrouped(gs[i]),
                  onDelete: (i) => _deleteGrouped(gs[i]),
                  fontScale: 1.3,
                ),
              );
            }),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(children: [
                    Text(_f(firstPrice),
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w600, color: RefColors.navy)),
                    const Text('اجمالي السعر',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 17, color: Colors.black87)),
                    Text(_f(totalPrice),
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w800, color: RefColors.navy)),
                  ]),
                ),
                Expanded(
                  child: Column(children: [
                      const Text('اجمالي الوزن', style: TextStyle(fontFamily: 'Cairo', fontSize: 17)),
                      Text(_f2(totalWeight),
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w800, color: RefColors.navy)),
                  ]),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('اجمالي الكمية', style: TextStyle(fontFamily: 'Cairo', fontSize: 17)),
                    Text(_f(totalQty),
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w800, color: RefColors.navy)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// حوار تعديل سطر (كمية/وزن/سعر) — StatefulWidget مستقل يملك كنترولراته
/// ويتخلص منها في dispose الخاص به، فلا يحدث use-after-dispose أثناء
/// أنيميشن خروج الحوار (كراش: TextEditingController was used after
/// being disposed — كان يجمد الشاشة ويوقف المسح).
class _EditLineDialog extends ConsumerStatefulWidget {
  final OpKind kind;
  final String headerId;
  final _DetailsLine line;
  final double reqQty;
  final double othersQty;
  final String qtyText;
  final String weightText;
  final String priceText;
  const _EditLineDialog({
    required this.kind,
    required this.headerId,
    required this.line,
    required this.reqQty,
    required this.othersQty,
    required this.qtyText,
    required this.weightText,
    required this.priceText,
  });
  @override
  ConsumerState<_EditLineDialog> createState() => _EditLineDialogState();
}

class _EditLineDialogState extends ConsumerState<_EditLineDialog> {
  late final TextEditingController qC =
      TextEditingController(text: widget.qtyText);
  late final TextEditingController wC =
      TextEditingController(text: widget.weightText);
  late final TextEditingController pC =
      TextEditingController(text: widget.priceText);
  bool busy = false;

  @override
  void dispose() {
    qC.dispose();
    wC.dispose();
    pC.dispose();
    super.dispose();
  }

  String _f(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _save() async {
    final nq = AppUtils.parseNum(qC.text);
    final nw = AppUtils.parseNum(wC.text);
    final np = AppUtils.parseNum(pC.text);
    if (nq <= 0) {
      refError(context, 'الكمية يجب أن تكون أكبر من صفر');
      return;
    }
    // التعديل لا يتجاوز سقف الكمية المطلوبة.
    if (widget.reqQty > 0 && widget.othersQty + nq > widget.reqQty) {
      refError(context,
          'تم تنفيذ الكمية المطلوبة (${_f(widget.reqQty)}) — لا يمكن الزيادة');
      return;
    }
    setState(() => busy = true);
    try {
      final k = widget.kind;
      if (k == OpKind.delivery) {
        await ref.read(deliveryRepoProvider).updateItem(
            widget.headerId, widget.line.id,
            quantity: nq, weight: nw, price: np);
      } else if (k == OpKind.receipt) {
        await ref.read(receiptRepoProvider).updateItem(
            widget.headerId, widget.line.id,
            quantity: nq, weight: nw, price: np);
      } else {
        await ref.read(opsRepoProvider).updateItem(
            widget.headerId, widget.line.id,
            quantity: nq, weight: nw, price: np);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => busy = false);
      if (mounted) refError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تعديل سطر: ${widget.line.name}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 19,
              fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: qC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                decoration:
                    const InputDecoration(labelText: 'الكمية')),
            const SizedBox(height: 8),
            TextField(
                controller: wC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                decoration:
                    const InputDecoration(labelText: 'الوزن')),
            const SizedBox(height: 8),
            TextField(
                controller: pC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                decoration:
                    const InputDecoration(labelText: 'السعر')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: busy ? null : _save,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('حفظ')),
      ],
    );
  }
}

/// حوار تعديل صنف مدمج: يعرض كل مسحة في صف مستقل (كمية/وزن/سعر كل مسحة
/// على حدة) — للأوزان المتغيرة كل كرتونة بوزنها في صف، مع إمكانية تعديل
/// أو حذف أي مسحة، وتوحيد السعر على كل المسحات.
class _GroupedEditDialog extends ConsumerStatefulWidget {
  final OpKind kind;
  final String headerId;
  final String productCode;
  final String productName;
  final double reqQty;
  final double othersQty;
  /// true = عرض وحذف فقط (بدون تعديل مسحة/توحيد سعر) — للاستلام والتسليم.
  final bool readOnly;
  const _GroupedEditDialog({
    required this.kind,
    required this.headerId,
    required this.productCode,
    required this.productName,
    required this.reqQty,
    required this.othersQty,
    this.readOnly = false,
  });
  @override
  ConsumerState<_GroupedEditDialog> createState() =>
      _GroupedEditDialogState();
}

class _GroupedEditDialogState extends ConsumerState<_GroupedEditDialog> {
  List<_DetailsLine> scans = [];
  bool loading = true;
  bool busy = false;
  bool changed = false;
  late final TextEditingController priceAllC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    priceAllC.dispose();
    super.dispose();
  }

  String _f(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  String _f2(double v) => v.toStringAsFixed(2);

  Future<List<_DetailsLine>> _fetchScans() async {
    final out = <_DetailsLine>[];
    final k = widget.kind;
    if (k == OpKind.delivery) {
      final its =
          await ref.read(deliveryRepoProvider).items(widget.headerId);
      for (final it in its) {
        if (it.id == null || it.productCode != widget.productCode) continue;
        out.add(_DetailsLine(it.id!, it.productCode, it.productName,
            it.quantity, it.weight, it.price));
      }
    } else if (k == OpKind.receipt) {
      final its =
          await ref.read(receiptRepoProvider).items(widget.headerId);
      for (final it in its) {
        if (it.id == null || it.productCode != widget.productCode) continue;
        out.add(_DetailsLine(it.id!, it.productCode, it.productName,
            it.quantity, it.weight, it.price));
      }
    } else {
      final its = await ref.read(opsRepoProvider).items(widget.headerId);
      for (final it in its) {
        if (it.id == null || it.productCode != widget.productCode) continue;
        out.add(_DetailsLine(it.id!, it.productCode, it.productName,
            it.quantity, it.weight, it.price));
      }
    }
    return out;
  }

  Future<void> _load() async {
    final s = await _fetchScans();
    if (mounted) {
      setState(() {
        scans = s;
        loading = false;
      });
    }
  }

  Future<void> _updateScan(_DetailsLine s,
      {required double quantity,
      required double weight,
      required double price}) async {
    final k = widget.kind;
    if (k == OpKind.delivery) {
      await ref.read(deliveryRepoProvider).updateItem(
          widget.headerId, s.id,
          quantity: quantity, weight: weight, price: price);
    } else if (k == OpKind.receipt) {
      await ref.read(receiptRepoProvider).updateItem(
          widget.headerId, s.id,
          quantity: quantity, weight: weight, price: price);
    } else {
      await ref.read(opsRepoProvider).updateItem(widget.headerId, s.id,
          quantity: quantity, weight: weight, price: price);
    }
  }

  Future<void> _deleteScan(_DetailsLine s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المسحة؟',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        content: Text('مسحة #${scans.indexOf(s) + 1} — وزن ${_f2(s.weight)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      final k = widget.kind;
      if (k == OpKind.delivery) {
        await ref
            .read(deliveryRepoProvider)
            .deleteItem(widget.headerId, s.id);
      } else if (k == OpKind.receipt) {
        await ref
            .read(receiptRepoProvider)
            .deleteItem(widget.headerId, s.id);
      } else {
        await ref.read(opsRepoProvider).deleteItem(widget.headerId, s.id);
      }
      changed = true;
      await _load();
    } catch (e) {
      if (mounted) refError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// تعديل مسحة واحدة (كمية/وزن/سعر) عبر حوار السطر المفرد.
  Future<void> _editScan(_DetailsLine s) async {
    final others = widget.othersQty +
        scans.where((e) => e.id != s.id).fold(0.0, (a, b) => a + b.qty);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _EditLineDialog(
        kind: widget.kind,
        headerId: widget.headerId,
        line: s,
        reqQty: widget.reqQty,
        othersQty: others,
        qtyText: _f(s.qty),
        weightText: _f2(s.weight),
        priceText: _f(s.price),
      ),
    );
    if (ok == true) {
      changed = true;
      await _load();
    }
  }

  /// توحيد السعر على كل مسحات الصنف.
  Future<void> _applyPriceAll() async {
    final np = AppUtils.parseNum(priceAllC.text);
    if (np <= 0) {
      refError(context, 'ادخل السعر أولًا');
      return;
    }
    setState(() => busy = true);
    try {
      for (final s in scans) {
        await _updateScan(s,
            quantity: s.qty, weight: s.weight, price: np);
      }
      changed = true;
      priceAllC.clear();
      await _load();
      if (mounted) refToast(context, 'تم توحيد السعر');
    } catch (e) {
      if (mounted) refError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalQty = scans.fold(0.0, (a, b) => a + b.qty);
    final totalWeight = scans.fold(0.0, (a, b) => a + b.weight);
    return AlertDialog(
      title: Text('${widget.productName} (${scans.length} مسحات)',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        child: loading
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()))
                : scans.isEmpty
                ? const Text('لا توجد مسحات — احذف الصنف من الجدول',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 15))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            'الإجمالي: كمية ${_f(totalQty)} — وزن ${_f2(totalWeight)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        if (!widget.readOnly) ...[
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: priceAllC,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                textDirection: TextDirection.ltr,
                                decoration: const InputDecoration(
                                    labelText: 'سعر موحد للكل',
                                    isDense: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                                onPressed: busy ? null : _applyPriceAll,
                                child: const Text('توحيد')),
                          ]),
                          const SizedBox(height: 8),
                        ],
                        ...scans.asMap().entries.map((e) {
                          final i = e.key;
                          final s = e.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: i.isEven
                                  ? const Color(0xFFF6F8F6)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFD9E2E3)),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('مسحة #${i + 1}',
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800)),
                                    Text(
                                        'كمية ${_f(s.qty)} | وزن ${_f2(s.weight)} | سعر ${_f(s.price)}',
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54)),
                                  ],
                                ),
                              ),
                              if (!widget.readOnly)
                                InkWell(
                                  onTap: busy ? null : () => _editScan(s),
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.edit_outlined,
                                        size: 20,
                                        color: Color(0xFF184E77)),
                                  ),
                                ),
                              InkWell(
                                onTap: busy ? null : () => _deleteScan(s),
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: Color(0xFFB71C1C)),
                                ),
                              ),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context, changed),
            child: const Text('تم')),
      ],
    );
  }
}
