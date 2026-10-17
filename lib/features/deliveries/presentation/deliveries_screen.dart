import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/pagination/pagination.dart';
import '../../../core/providers.dart';
import '../../../core/scanner/scanner_providers.dart';
import '../../../core/services/barcode_parser.dart';
import '../../../core/services/barcode_resolver.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/pc_send.dart';
import '../../products/presentation/products_screen.dart';
import '../../customers/presentation/customers_screen.dart';

class DeliveriesScreen extends ConsumerWidget {
  const DeliveriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(deliveryQueryProvider);
    final page = ref.watch(deliveryPageProvider);
    final list = ref.watch(deliveryListProvider);
    final total = list.valueOrNull?.total ?? 0;
    final lastPage = Pagination.totalPages(total) - 1;
    if (total > 0 && page > lastPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(deliveryPageProvider.notifier).state = lastPage;
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('أذون التسليم')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: SearchField(
                hint: 'بحث برقم الإذن أو العميل...',
                onChanged: (v) {
                  ref.read(deliveryQueryProvider.notifier).state = v;
                  ref.read(deliveryPageProvider.notifier).state = 0;
                })),
        Expanded(
            child: list.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (paged) {
                  final rs = paged.items.cast<DeliveryHeader>();
                  if (rs.isEmpty) {
                    return const EmptyState(
                        message: 'لا توجد أذون تسليم بعد');
                  }
                  return ListView.builder(
                      key: ValueKey('deliveries-$q-$page'),
                      itemCount: rs.length,
                      itemBuilder: (_, i) => VoucherCard(
                            partnerName: rs[i].customerName,
                            voucherId: rs[i].id,
                            date: rs[i].date,
                            totalItems: rs[i].totalItems,
                            totalQty: rs[i].totalQty,
                            isReceipt: false,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        DeliveryDetailsScreen(
                                            id: rs[i].id))),
                          ));
                })),
        PaginationBar(
          currentPage: page,
          total: total,
          isLoading: list.isLoading,
          onPageChanged: (p) =>
              ref.read(deliveryPageProvider.notifier).state = p,
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('إذن تسليم'),
          onPressed: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreateDeliveryScreen()));
            ref.invalidate(deliveryListProvider);
            ref.invalidate(dashboardProvider);
          }),
    );
  }
}

class CreateDeliveryScreen extends ConsumerStatefulWidget {
  const CreateDeliveryScreen({super.key});
  @override
  ConsumerState<CreateDeliveryScreen> createState() => _CD();
}

class _CD extends ConsumerState<CreateDeliveryScreen> {
  Customer? customer;
  final lines = <DocLine>[];
  final dateC = TextEditingController();
  StreamSubscription? sub;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    dateC.text = AppUtils.todayStr();
    try {
      sub = ref
          .read(scannerServiceProvider)
          .scanStream
          .listen((c) => _addCode(BarcodeParser.clean(c)));
    } catch (_) {}
  }

  @override
  void dispose() {
    sub?.cancel();
    dateC.dispose();
    super.dispose();
  }

  /// مسح بالماسح يضيف الصنف تلقائيًا تحت.
  /// يقبل: باركود مسجل في product_codes، أو حقل باركود الصنف،
  /// أو مقطع الكود داخل الباركود، أو قالب وزن متغير، أو كود صنف مباشر.
  /// غلاف آمن: أي عطل غير متوقع يُعرض كرسالة بدل التجاهل الصامت.
  Future<void> _addCode(String raw) async {
    try {
      await _resolveAndPush(raw);
    } catch (e) {
      if (!mounted) return;
      showError(context, 'تعذر إتمام المسح: $e');
    }
  }

  Future<void> _resolveAndPush(String raw) async {
    final code = BarcodeParser.clean(raw);
    if (code.isEmpty) return;
    // 1) باركود مسجل في product_codes
    final pc =
        await ref.read(productCodeRepoProvider).findByBarcode(code);
    if (pc != null) {
      final p =
          await ref.read(productRepoProvider).findByCode(pc.productCode);
      if (!mounted) return;
      if (p == null || !p.isActive) {
        _notFound(code);
        return;
      }
      var w = pc.weight;
      // صنف بلا وزن باركودي (hasWeight مطفي) → الوزن صفر دائمًا،
      // ما لم يكن وزنًا ثابتًا مدخلًا صراحة.
      if (!p.hasWeight) w = 0;
      if (w <= 0 && p.weightType == 'ثابت' && p.fixedWeight > 0) {
        w = p.fixedWeight;
      }
      _pushLine(p.code, p.desc, weight: w, price: p.price);
      return;
    }
    // 2) باركود مسجل في حقل الصنف نفسه (products.barcode)
    try {
      final pb = await ref.read(productRepoProvider).findByBarcode(code);
      if (pb != null) {
        if (!mounted) return;
        if (!pb.isActive) {
          _notFound(code);
          return;
        }
        var w = 0.0;
        if (pb.weightType == 'ثابت' && pb.fixedWeight > 0) {
          w = pb.fixedWeight;
        }
        _pushLine(pb.code, pb.desc, weight: w, price: pb.price);
        return;
      }
    } catch (_) {}
    // 3) مقطع الكود داخل الباركود (يحدد الصنف تلقائيًا بدون اختيار يدوي)
    try {
      final seg =
          await ref.read(productCodeRepoProvider).resolveByCodeSegment(code);
      if (seg != null) {
        if (!mounted) return;
        if (!seg.product.isActive) {
          _notFound(code);
          return;
        }
        var w = seg.product.hasWeight
            ? BarcodeResolver.templateWeight(code, seg.template)
            : 0.0;
        if (w <= 0 &&
            seg.product.weightType == 'ثابت' &&
            seg.product.fixedWeight > 0) {
          w = seg.product.fixedWeight;
        }
        _pushLine(seg.product.code, seg.product.desc,
            weight: w, price: seg.product.price);
        return;
      }
    } catch (_) {}
    // 4) قالب وزن متغير: نفس الطول + ثبات خارج مقطع الوزن
    try {
      final templates = await ref.read(productCodeRepoProvider).all();
      final t = _matchTemplate(code, templates);
      if (t != null) {
        final p =
            await ref.read(productRepoProvider).findByCode(t.productCode);
        if (!mounted) return;
        if (p == null || !p.isActive) {
          _notFound(code);
          return;
        }
        var w =
            BarcodeParser.calcValue(code, t.wStart, t.wEnd, t.mark);
        if (!p.hasWeight) w = 0;
        _pushLine(p.code, p.desc, weight: w, price: p.price);
        return;
      }
    } catch (_) {}
    // 5) كود صنف مباشر
    final p = await ref.read(productRepoProvider).findByCode(code);
    if (!mounted) return;
    if (p == null || !p.isActive) {
      _notFound(code);
      return;
    }
    var w = 0.0;
    if (p.weightType == 'ثابت' && p.fixedWeight > 0) w = p.fixedWeight;
    _pushLine(p.code, p.desc, weight: w, price: p.price);
  }

  /// كل مسحة عنصر مستقل (للحفاظ على تفصيلة الأوزان المتغيرة) —
  /// العرض مدمج (صف واحد لكل صنف)، والتعديل يعرض كل مسحة في صف.
  void _pushLine(String pCode, String pName,
      {double weight = 0, double price = 0}) {
    HapticFeedback.lightImpact();
    setState(() {
      lines.add(DocLine(
          productCode: pCode,
          productName: pName,
          quantity: 1,
          weight: weight,
          price: price));
    });
  }

  /// صفوف مدمجة للعرض: نفس الصنف بكل مسحاته في صف واحد.
  List<MergedDocLine> get _grouped => mergeDocLines(lines);

  /// حوار التعديل: كل مسحة في صف مستقل بوزنها — عرض وحذف فقط في إذن التسليم.
  Future<void> _editGrouped(MergedDocLine g) async {
    await showDialog(
      context: context,
      builder: (_) => ScansBreakdownDialog(
        productName: g.name,
        productCode: g.code,
        scans: g.scans,
        editing: false,
        onChanged: () => setState(() {}),
        onDelete: (s) => setState(() => lines.remove(s)),
      ),
    );
    if (mounted) setState(() {});
  }

  /// هل النص يحل لصنف معروف؟ (فحص قبل نقل مسحة ضالة من خلية رقمية).
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

  /// مسحة ضلّت لخلية رقمية (الماسح wedge يكتب في الحقل المركّز) —
  /// تُعالج كمسحة عادية بدل حفظها كرقم.
  Future<bool> _handleCellScan(String text) async {
    final code = BarcodeParser.clean(text);
    if (code.length < 4 || !mounted) return false;
    if (!await _resolvesToProduct(code)) return false;
    await _addCode(code);
    return true;
  }

  Future<void> _notFound(String code) async {
    final want = await productNotFoundDialog(context, code);
    if (want && mounted) {
      final ok = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProductFormRoute(presetCode: code)));
      if (ok == true) {
        await _addCode(code);
        if (mounted) setState(() {});
      }
    }
  }

  ProductCode? _matchTemplate(String scanned, List<ProductCode> ts) {
    for (final t in ts) {
      if (t.wStart <= 0 || t.wEnd <= 0) continue;
      if (BarcodeResolver.matchesTemplate(scanned, t)) return t;
    }
    return null;
  }

  Future<void> _save() async {
    if (customer == null) {
      showError(context, 'اختر العميل أولًا');
      return;
    }
    if (lines.isEmpty) {
      showError(context, 'أضف صنفًا واحدًا على الأقل');
      return;
    }
    setState(() => saving = true);
    try {
      final id = await ref.read(deliveryRepoProvider).save(
            customerCode: customer!.code,
            customerName: customer!.desc,
            date: dateC.text.trim().isEmpty
                ? AppUtils.todayStr()
                : dateC.text.trim(),
            lines: lines,
          );
      ref.invalidate(deliveryListProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(productListProvider);
      if (!mounted) return;
      toast(context, 'تم حفظ الإذن: $id');
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => DeliveryDetailsScreen(id: id)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إذن تسليم جديد')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
            child: ListTile(
          leading: const Icon(Icons.person),
          title: Text(customer == null
              ? 'اختر العميل'
              : '${customer!.desc} (${customer!.code})'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () async {
            final c = await showModalBottomSheet<Customer>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _CustomerPicker());
            if (c != null) setState(() => customer = c);
          },
        )),
        TextField(
            controller: dateC,
            decoration: const InputDecoration(
                labelText: 'التاريخ (YYYY-MM-DD)',
                prefixIcon: Icon(Icons.date_range))),
        const SizedBox(height: 8),
        ScanPanel(
          scannedCount: lines.length,
          message: 'لإضافة الأصناف ابدأ بالمسح مباشرة بالضغط على زر المسح',
          onTriggerScan: () async {
            try {
              await ref.read(scannerServiceProvider).triggerScan();
            } catch (_) {
              if (mounted) {
                toast(context,
                    'اضغط زر المسح الفيزيائي في الجهاز للمسح المباشر');
              }
            }
          },
        ),
        if (lines.isEmpty)
          const EmptyState(message: 'لم تُمسح أصناف بعد — اضغط زر المسح وابدأ')
        else
          Builder(builder: (context) {
            final gs = _grouped;
            return LinesCellTable(
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
              // نفس الصنف مدمج في صف واحد — عرض فقط بلا تعديل كمية/وزن/سعر،
              // وزر التعديل يفتح تفصيلة المسحات للحذف. أي مسحة تضل لخلية
              // رقمية تُعالج كمسحة بدل حفظها كرقم.
              editable: false,
              onScanRedirect: _handleCellScan,
              onEdit: (i) => _editGrouped(gs[i]),
              onDelete: (i) =>
                  setState(() => lines.removeWhere((e) =>
                      e.productCode == gs[i].code)),
            );
          }),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final distinct = _grouped.length;
          return FilledButton(
              onPressed: saving ? null : _save,
              child: Text(
                  'حفظ الإذن ($distinct أصناف — إجمالي ${AppUtils.fmtQty(lines.fold(0.0, (a, b) => a + b.quantity))})'));
        }),
      ]),
    );
  }
}

class _CustomerPicker extends ConsumerStatefulWidget {
  const _CustomerPicker();
  @override
  ConsumerState<_CustomerPicker> createState() => __CP();
}

class __CP extends ConsumerState<_CustomerPicker> {
  String q = '';
  int _limit = 10;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
                child: SearchField(
                    hint: 'بحث عن عميل...',
                    onChanged: (v) => setState(() {
                          q = v;
                          _limit = 10;
                        }))),
            IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () async {
                  final code = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const CustomerFormRoute()));
                  if (code != null && context.mounted) {
                    Navigator.pop(context);
                    toast(context, 'تمت إضافة العميل: $code');
                  }
                }),
          ]),
          FutureBuilder(
            future: Future.wait([
              ref.read(customerRepoProvider).search(q, limit: _limit),
              ref.read(customerRepoProvider).count(q: q),
            ]),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const CircularProgressIndicator();
              }
              final items = (snap.data![0] as List).cast<Customer>();
              final total = snap.data![1] as int;
              return Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (_, i) => ListTile(
                                title: Text(items[i].desc),
                                subtitle: Text(items[i].code),
                                onTap: () => Navigator.pop(
                                    context, items[i]),
                              )),
                    ),
                    if (items.length < total)
                      TextButton(
                        onPressed: () =>
                            setState(() => _limit += 10),
                        child: Text(
                            'عرض المزيد (${items.length} من $total)'),
                      ),
                  ],
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

class DeliveryDetailsScreen extends ConsumerWidget {
  final String id;
  const DeliveryDetailsScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(id), actions: [
        IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirm(context, 'حذف الإذن $id؟')) return;
              await ref.read(deliveryRepoProvider).delete(id);
              ref.invalidate(deliveryListProvider);
              if (context.mounted) Navigator.pop(context);
            }),
      ]),
      body: FutureBuilder(
        future: Future.wait([
          ref.read(deliveryRepoProvider).find(id),
          ref.read(deliveryRepoProvider).items(id),
        ]),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final h = snap.data![0] as DeliveryHeader?;
          final items = (snap.data![1] as List).cast<DeliveryItem>();
          if (h == null) return const EmptyState(message: 'غير موجود');
          return ListView(padding: const EdgeInsets.all(12), children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('إذن تسليم',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFE65100))),
                          const SizedBox(height: 6),
                          // عنوان الكارد: اسم العميل كبير وواضح
                          Text(h.customerName,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3)),
                          const SizedBox(height: 6),
                          Text('الرقم: ${h.id}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          Text('التاريخ: ${h.date}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          Text('الكود: ${h.customerCode}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                                child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFE3F0FD),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text(
                                        'الأصناف: ${h.totalItems}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800)))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFFF0E0),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text(
                                        'الكمية: ${AppUtils.fmtQty(h.totalQty)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFE65100))))),
                          ]),
                        ]))),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              // عرض مدمج: نفس الصنف بكل مسحاته في صف واحد.
              final gs = mergeDocLines([
                for (final it in items)
                  DocLine(
                      productCode: it.productCode,
                      productName: it.productName,
                      quantity: it.quantity,
                      weight: it.weight,
                      price: it.price),
              ]);
              return LinesCellTable(
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
                editable: false,
              );
            }),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                  onPressed: () async {
                    final folder = await ref
                        .read(storageServiceProvider)
                        .customerDeliveriesDir(
                            h.customerCode, h.customerName);
                    final path = await ref
                        .read(pdfServiceProvider)
                        .deliveryPdf(h, items, folder);
                    await OpenFilex.open(path);
                  }),
              FilledButton.tonalIcon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Excel'),
                  onPressed: () async {
                    final folder = await ref
                        .read(storageServiceProvider)
                        .customerDeliveriesDir(
                            h.customerCode, h.customerName);
                    final path = await ref
                        .read(excelServiceProvider)
                        .exportDelivery(h, items, folder);
                    await OpenFilex.open(path);
                  }),
              OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('مشاركة'),
                  onPressed: () async {
                    final folder = await ref
                        .read(storageServiceProvider)
                        .customerDeliveriesDir(
                            h.customerCode, h.customerName);
                    final path = await ref
                        .read(pdfServiceProvider)
                        .deliveryPdf(h, items, folder);
                    await Share.shareXFiles([XFile(path)]);
                  }),
              FilledButton.tonalIcon(
                  icon: const Icon(Icons.lan_outlined),
                  label: const Text('كمبيوتر'),
                  onPressed: () => askAndSendToPc(
                        context: context,
                        ref: ref,
                        makePdf: () async {
                          final folder = await ref
                              .read(storageServiceProvider)
                              .customerDeliveriesDir(h.customerCode,
                                  h.customerName);
                          return ref
                              .read(pdfServiceProvider)
                              .deliveryPdf(h, items, folder);
                        },
                        makeExcel: () async {
                          final folder = await ref
                              .read(storageServiceProvider)
                              .customerDeliveriesDir(h.customerCode,
                                  h.customerName);
                          return ref
                              .read(excelServiceProvider)
                              .exportDelivery(h, items, folder);
                        },
                      )),
            ]),
          ]);
        },
      ),
    );
  }
}
