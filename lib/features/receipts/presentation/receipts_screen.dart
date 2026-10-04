import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/pagination/pagination.dart';
import '../../../core/providers.dart';
import '../../../core/scanner/scanner_providers.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../products/presentation/products_screen.dart';
import '../../suppliers/presentation/suppliers_screen.dart';

/// قائمة أذون الاستلام — paginated (30 صف/صفحة)، البحث برقم الإذن أو المورد
/// يتم في قاعدة البيانات ويشمل كل الأذون.
class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(receiptQueryProvider);
    final page = ref.watch(receiptPageProvider);
    final list = ref.watch(receiptListProvider);
    final total = list.valueOrNull?.total ?? 0;
    final lastPage = Pagination.totalPages(total) - 1;
    if (total > 0 && page > lastPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(receiptPageProvider.notifier).state = lastPage;
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('أذون الاستلام')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: SearchField(
                hint: 'بحث برقم الإذن أو المورد...',
                onChanged: (v) {
                  ref.read(receiptQueryProvider.notifier).state = v;
                  ref.read(receiptPageProvider.notifier).state = 0;
                })),
        Expanded(
            child: list.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (paged) {
                  final rs = paged.items.cast<ReceiptHeader>();
                  if (rs.isEmpty) {
                    return const EmptyState(
                        message: 'لا توجد أذون استلام بعد');
                  }
                  return ListView.builder(
                      key: ValueKey('receipts-$q-$page'),
                      itemCount: rs.length,
                      itemBuilder: (_, i) => VoucherCard(
                            partnerName: rs[i].supplierName,
                            voucherId: rs[i].id,
                            date: rs[i].date,
                            totalItems: rs[i].totalItems,
                            totalQty: rs[i].totalQty,
                            isReceipt: true,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ReceiptDetailsScreen(
                                            id: rs[i].id))),
                          ));
                })),
        PaginationBar(
          currentPage: page,
          total: total,
          isLoading: list.isLoading,
          onPageChanged: (p) =>
              ref.read(receiptPageProvider.notifier).state = p,
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('إذن استلام'),
          onPressed: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreateReceiptScreen()));
            ref.invalidate(receiptListProvider);
            ref.invalidate(dashboardProvider);
          }),
    );
  }
}

/// إنشاء إذن استلام: اختيار مورد + Scan + كميات + حفظ Transactional
class CreateReceiptScreen extends ConsumerStatefulWidget {
  const CreateReceiptScreen({super.key});
  @override
  ConsumerState<CreateReceiptScreen> createState() => _CR();
}

class _CR extends ConsumerState<CreateReceiptScreen> {
  Supplier? supplier;
  final lines = <DocLine>[];
  final dateC = TextEditingController(text: '');
  StreamSubscription? sub;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    dateC.text = AppUtils.todayStr();
    // الاستماع للـ Scanner المدمج (SUNMI) — المسح يسمع مباشرة بدون حقل
    try {
      final svc = ref.read(scannerServiceProvider);
      sub = svc.scanStream.listen(_onScan,
          onError: (Object e) =>
              mounted ? showError(context, e) : null);
    } catch (_) {}
  }

  @override
  void dispose() {
    sub?.cancel();
    dateC.dispose();
    super.dispose();
  }

  Future<void> _onScan(String code) async {
    HapticFeedback.lightImpact();
    await _addCode(code.trim());
  }

  Future<void> _addCode(String code) async {
    if (code.isEmpty) return;
    final p = await ref.read(productRepoProvider).findByCode(code);
    if (!mounted) return;
    if (p == null || !p.isActive) {
      final wantAdd = await productNotFoundDialog(context, code);
      if (wantAdd && mounted) {
        final ok = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ProductFormRoute(presetCode: code)));
        if (ok == true) {
          await _addCode(code);
          setState(() {});
          ref.invalidate(productListProvider);
        }
      }
      return;
    }
    setState(() {
      final i = lines.indexWhere((e) => e.productCode == code);
      if (i >= 0) {
        lines[i].quantity += 1;
      } else {
        lines.add(DocLine(
            productCode: p.code, productName: p.desc, quantity: 1));
      }
    });
  }

  Future<void> _pickSupplier() async {
    final s = await showModalBottomSheet<Supplier>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SupplierPicker(),
    );
    if (s != null) setState(() => supplier = s);
  }

  Future<void> _save() async {
    if (supplier == null) {
      showError(context, 'اختر المورد أولًا');
      return;
    }
    if (lines.isEmpty) {
      showError(context, 'أضف صنفًا واحدًا على الأقل');
      return;
    }
    setState(() => saving = true);
    try {
      final id = await ref.read(receiptRepoProvider).save(
            supplierCode: supplier!.code,
            supplierName: supplier!.desc,
            date: dateC.text.trim().isEmpty
                ? AppUtils.todayStr()
                : dateC.text.trim(),
            lines: lines,
          );
      ref.invalidate(receiptListProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(productListProvider);
      if (!mounted) return;
      toast(context, 'تم حفظ الإذن: $id');
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ReceiptDetailsScreen(id: id)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إذن استلام جديد')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
            child: ListTile(
          leading: const Icon(Icons.local_shipping),
          title: Text(supplier == null
              ? 'اختر المورد'
              : '${supplier!.desc} (${supplier!.code})'),
          trailing: const Icon(Icons.chevron_left),
          onTap: _pickSupplier,
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
            } catch (e) {
              if (mounted) {
                toast(context,
                    'اضغط زر المسح الفيزيائي في الجهاز للمسح المباشر');
              }
            }
          },
        ),
        const SizedBox(height: 8),
        if (lines.isEmpty)
          const EmptyState(
              message: 'لم تُمسح أصناف بعد — اضغط زر المسح وابدأ'),
        ...lines.asMap().entries.map((e) {
          final i = e.key;
          final l = e.value;
          return VoucherLineCard(
            productName: l.productName,
            productCode: l.productCode,
            quantity: l.quantity,
            isReceipt: true,
            stepper: QtyStepper(
                value: l.quantity,
                onChanged: (v) =>
                    setState(() => lines[i].quantity = v <= 0 ? 1 : v)),
            onDelete: () =>
                setState(() => lines.removeAt(i)),
          );
        }),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const CircularProgressIndicator()
                : Text(
                    'حفظ الإذن (${lines.length} أصناف — إجمالي ${AppUtils.fmtQty(lines.fold(0.0, (a, b) => a + b.quantity))})')),
      ]),
    );
  }
}

class _SupplierPicker extends ConsumerStatefulWidget {
  const _SupplierPicker();
  @override
  ConsumerState<_SupplierPicker> createState() => __SP();
}

class __SP extends ConsumerState<_SupplierPicker> {
  String q = '';
  int _limit = 30;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
                child: SearchField(
                    hint: 'بحث عن مورد...',
                    onChanged: (v) => setState(() {
                          q = v;
                          _limit = 30;
                        }))),
            IconButton(
                icon: const Icon(Icons.add_business),
                tooltip: 'إضافة مورد',
                onPressed: () async {
                  final code = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const SupplierFormRoute()));
                  if (code != null && context.mounted) {
                    Navigator.pop(context);
                    toast(context, 'تمت إضافة المورد: $code');
                  }
                }),
          ]),
          const SizedBox(height: 8),
          FutureBuilder(
            future: Future.wait([
              ref.read(supplierRepoProvider).search(q, limit: _limit),
              ref.read(supplierRepoProvider).count(q: q),
            ]),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const CircularProgressIndicator();
              }
              final items = (snap.data![0] as List).cast<Supplier>();
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
                                onTap: () =>
                                    Navigator.pop(context, items[i]),
                              )),
                    ),
                    if (items.length < total)
                      TextButton(
                        onPressed: () =>
                            setState(() => _limit += 30),
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

/// تفاصيل إذن + PDF + Excel + حذف
class ReceiptDetailsScreen extends ConsumerWidget {
  final String id;
  const ReceiptDetailsScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(id), actions: [
        IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirm(
                  context, 'حذف الإذن $id؟ سيتم عكس المخزون.')) {
                return;
              }
              try {
                await ref.read(receiptRepoProvider).delete(id);
                ref.invalidate(receiptListProvider);
                if (context.mounted) {
                  toast(context, 'تم حذف الإذن');
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            }),
      ]),
      body: FutureBuilder(
        future: Future.wait([
          ref.read(receiptRepoProvider).find(id),
          ref.read(receiptRepoProvider).items(id),
        ]),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final h = snap.data![0] as ReceiptHeader?;
          final items = (snap.data![1] as List).cast<ReceiptItem>();
          if (h == null) return const EmptyState(message: 'غير موجود');
          return ListView(padding: const EdgeInsets.all(12), children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('إذن استلام',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green)),
                          const SizedBox(height: 6),
                          // عنوان الكارد: اسم المورد كبير وواضح
                          Text(h.supplierName,
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
                          Text('الكود: ${h.supplierCode}',
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
                                        color: const Color(0xFFE6F4EA),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text(
                                        'الكمية: ${AppUtils.fmtQty(h.totalQty)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1B7A2B))))),
                          ]),
                        ]))),
            const SizedBox(height: 8),
            ...items.map((it) => VoucherLineCard(
                  productName: it.productName,
                  productCode: it.productCode,
                  quantity: it.quantity,
                  isReceipt: true,
                )),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                  onPressed: () async {
                    try {
                      final folder = await ref
                          .read(storageServiceProvider)
                          .supplierReceiptsDir(
                              h.supplierCode, h.supplierName);
                      final path = await ref
                          .read(pdfServiceProvider)
                          .receiptPdf(h, items, folder);
                      if (context.mounted) {
                        toast(context, 'تم إنشاء PDF: $path');
                      }
                      await OpenFilex.open(path);
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  }),
              FilledButton.tonalIcon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Excel'),
                  onPressed: () async {
                    try {
                      final folder = await ref
                          .read(storageServiceProvider)
                          .supplierReceiptsDir(
                              h.supplierCode, h.supplierName);
                      final path = await ref
                          .read(excelServiceProvider)
                          .exportReceipt(h, items, folder);
                      if (context.mounted) {
                        toast(context, 'تم إنشاء Excel: $path');
                      }
                      await OpenFilex.open(path);
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  }),
              OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('مشاركة'),
                  onPressed: () async {
                    try {
                      final folder = await ref
                          .read(storageServiceProvider)
                          .supplierReceiptsDir(
                              h.supplierCode, h.supplierName);
                      final path = await ref
                          .read(pdfServiceProvider)
                          .receiptPdf(h, items, folder);
                      await Share.shareXFiles([XFile(path)],
                          text: 'إذن استلام ${h.id}');
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  }),
            ]),
          ]);
        },
      ),
    );
  }
}
