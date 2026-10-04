import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pagination/pagination.dart';
import '../../../core/providers.dart';
import '../../../core/services/code_generator_service.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/partner_export_buttons.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../products/presentation/products_screen.dart';
import '../../receipts/presentation/receipts_screen.dart';

/// الموردون: قائمة + تفاصيل + إضافة — paginated (30 صف/صفحة).
/// البحث يتم في قاعدة البيانات: يشمل كل الموردين.
class SuppliersTab extends ConsumerWidget {
  const SuppliersTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(supplierQueryProvider);
    final page = ref.watch(supplierPageProvider);
    final list = ref.watch(supplierListProvider);
    final total = list.valueOrNull?.total ?? 0;
    final lastPage = Pagination.totalPages(total) - 1;
    if (total > 0 && page > lastPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(supplierPageProvider.notifier).state = lastPage;
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الموردين')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: SearchField(
                hint: 'بحث بالكود أو الاسم...',
                onChanged: (v) {
                  ref.read(supplierQueryProvider.notifier).state = v;
                  ref.read(supplierPageProvider.notifier).state = 0;
                })),
        Expanded(
            child: list.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (paged) {
                  final ss = paged.items.cast<Supplier>();
                  if (ss.isEmpty) {
                    return const EmptyState(
                        message: 'لا يوجد موردون بعد');
                  }
                  return ListView.builder(
                      key: ValueKey('suppliers-$q-$page'),
                      itemCount: ss.length,
                      itemBuilder: (_, i) => ListTile(
                            leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B1F3A),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                    Icons.local_shipping,
                                    color: Colors.white,
                                    size: 24)),
                            title: Text(ss[i].desc),
                            subtitle: Text(ss[i].code),
                            trailing:
                                const Icon(Icons.chevron_left),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        SupplierDetailsScreen(
                                            code: ss[i].code))),
                          ));
                })),
        PaginationBar(
          currentPage: page,
          total: total,
          isLoading: list.isLoading,
          onPageChanged: (p) =>
              ref.read(supplierPageProvider.notifier).state = p,
        ),
      ]),
      floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: 'importS',
              icon: const Icon(Icons.upload_file),
              label: const Text('استيراد'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ImportHubScreen(initial: 1))),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.extended(
                heroTag: 'addS',
                icon: const Icon(Icons.add),
                label: const Text('مورد'),
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SupplierFormRoute()));
                  ref.invalidate(supplierListProvider);
                }),
          ]),
    );
  }
}

class SupplierDetailsScreen extends ConsumerStatefulWidget {
  final String code;
  const SupplierDetailsScreen({super.key, required this.code});
  @override
  ConsumerState<SupplierDetailsScreen> createState() =>
      _SupplierDetailsState();
}

class _SupplierDetailsState extends ConsumerState<SupplierDetailsScreen> {
  static const int _pageSize = 20;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    return Scaffold(
      appBar: AppBar(title: Text('مورد: $code')),
      body: FutureBuilder(
        future: Future.wait([
          ref.read(supplierRepoProvider).findByCode(code),
          ref.read(supplierRepoProvider).stats(code),
          ref.read(supplierRepoProvider).history(code,
              limit: _pageSize,
              offset: Pagination.offsetFor(_page, _pageSize)),
          ref.read(supplierRepoProvider).historyCount(code),
        ]),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data![0] as Supplier?;
          final stats = snap.data![1] as Map<String, Object>;
          final hist = (snap.data![2] as List).cast<ReceiptHeader>();
          final total = snap.data![3] as int;
          if (s == null) return const EmptyState(message: 'غير موجود');
          return ListView(padding: const EdgeInsets.all(12), children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // عنوان الكارد: اسم المورد كبير وواضح
                          Text(s.desc,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3)),
                          const SizedBox(height: 4),
                          Text('الكود: ${s.code}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: StatBox(
                                    label: 'الأذون',
                                    value: '${stats['count']}',
                                    color: const Color(0xFF0B1F3A))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: StatBox(
                                    label: 'إجمالي الكميات',
                                    value: '${stats['totalQty']}',
                                    color: const Color(0xFF1B7A2B))),
                          ]),
                          const SizedBox(height: 8),
                          Text('آخر تعامل: ${stats['lastDate']}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ]))),
            const SizedBox(height: 8),
            // تصدير ملف المورد: كل الأذون بتفاصيلها — PDF أو Excel حسب اختيار المستخدم
            PartnerExportButtons(
                partnerCode: s.code,
                partnerName: s.desc,
                isSupplier: true),
            const SizedBox(height: 8),
            const Text('سجل الأذون',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
            ...hist.map((h) => VoucherCard(
                  partnerName: h.id.toString(),
                  voucherId: h.date.toString(),
                  date: 'أصناف: ${h.totalItems}',
                  totalItems: h.totalItems,
                  totalQty: (h.totalQty as num).toDouble(),
                  isReceipt: true,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ReceiptDetailsScreen(
                              id: h.id.toString()))),
                )),
            if (hist.isEmpty && _page == 0)
              const EmptyState(message: 'لا توجد أذون لهذا المورد'),
            PaginationBar(
              currentPage: _page,
              total: total,
              pageSize: _pageSize,
              onPageChanged: (p) => setState(() => _page = p),
            ),
          ]);
        },
      ),
    );
  }
}

class SupplierFormRoute extends ConsumerStatefulWidget {
  const SupplierFormRoute({super.key});
  @override
  ConsumerState<SupplierFormRoute> createState() => _SF();
}

class _SF extends ConsumerState<SupplierFormRoute> {
  final nameC = TextEditingController();
  final codeC = TextEditingController();
  bool auto = true;

  @override
  void initState() {
    super.initState();
    _gen();
  }

  Future<void> _gen() async {
    if (!auto) return;
    final c = await DocumentNumberService().nextSupplierCode();
    // لا نستهلك الرقم فعليًا هنا — مجرد اقتراح؛ الرقم النهائي عند الحفظ
    // لذلك نعرضه ونسمح بتعديله، وعند الحفظ نتحقق من التفرد.
    if (mounted) setState(() => codeC.text = c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مورد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
              controller: nameC,
              decoration:
                  const InputDecoration(labelText: 'اسم المورد')),
          const SizedBox(height: 12),
          TextField(
              controller: codeC,
              decoration: const InputDecoration(
                  labelText: 'الكود (يُولّد تلقائيًا — قابل للتعديل)',
                  helperText: 'مثال: SUP-000001')),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: () async {
                try {
                  var code = codeC.text.trim();
                  if (code.isEmpty) {
                    code = await DocumentNumberService()
                        .nextSupplierCode();
                  }
                  await ref.read(supplierRepoProvider).create(
                      Supplier(code: code, desc: nameC.text.trim()));
                  if (context.mounted) {
                    toast(context, 'تم حفظ المورد: $code');
                    Navigator.pop(context, code);
                  }
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
              child: const Text('حفظ')),
        ]),
      ),
    );
  }
}
