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
          .listen((c) => _addCode(c.trim()));
    } catch (_) {}
  }

  @override
  void dispose() {
    sub?.cancel();
    dateC.dispose();
    super.dispose();
  }

  Future<void> _addCode(String code) async {
    if (code.isEmpty) return;
    final p = await ref.read(productRepoProvider).findByCode(code);
    if (!mounted) return;
    if (p == null || !p.isActive) {
      final want = await productNotFoundDialog(context, code);
      if (want && mounted) {
        final ok = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProductFormRoute(presetCode: code)));
        if (ok == true) {
          await _addCode(code);
          setState(() {});
        }
      }
      return;
    }
    HapticFeedback.lightImpact();
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
          const EmptyState(message: 'لم تُمسح أصناف بعد — اضغط زر المسح وابدأ'),
        ...lines.asMap().entries.map((e) {
          final i = e.key;
          final l = e.value;
          return VoucherLineCard(
            productName: l.productName,
            productCode: l.productCode,
            quantity: l.quantity,
            isReceipt: false,
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
            child: Text(
                'حفظ الإذن (${lines.length} أصناف — إجمالي ${AppUtils.fmtQty(lines.fold(0.0, (a, b) => a + b.quantity))})')),
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
                    hint: 'بحث عن عميل...',
                    onChanged: (v) => setState(() {
                          q = v;
                          _limit = 30;
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
            ...items.map((it) => VoucherLineCard(
                  productName: it.productName,
                  productCode: it.productCode,
                  quantity: it.quantity,
                  isReceipt: false,
                )),
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
            ]),
          ]);
        },
      ),
    );
  }
}
