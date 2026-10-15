import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pagination/pagination.dart';
import '../../../core/providers.dart';
import '../../../core/services/code_generator_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/partner_export_buttons.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../products/presentation/products_screen.dart';
import '../../deliveries/presentation/deliveries_screen.dart';

class CustomersTab extends ConsumerWidget {
  const CustomersTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(customerQueryProvider);
    final page = ref.watch(customerPageProvider);
    final list = ref.watch(customerListProvider);
    final total = list.valueOrNull?.total ?? 0;
    final lastPage = Pagination.totalPages(total) - 1;
    if (total > 0 && page > lastPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(customerPageProvider.notifier).state = lastPage;
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('العملاء')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: SearchField(
                hint: 'بحث بالكود أو الاسم...',
                onChanged: (v) {
                  ref.read(customerQueryProvider.notifier).state = v;
                  ref.read(customerPageProvider.notifier).state = 0;
                })),
        Expanded(
            child: list.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (paged) {
                  final ss = paged.items.cast<Customer>();
                  if (ss.isEmpty) {
                    return const EmptyState(
                        message: 'لا يوجد عملاء بعد');
                  }
                  return ListView.builder(
                      key: ValueKey('customers-$q-$page'),
                      itemCount: ss.length,
                      itemBuilder: (_, i) => ListTile(
                            leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.people_rounded,
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
                                        CustomerDetailsScreen(
                                            code: ss[i].code))),
                          ));
                })),
        PaginationBar(
          currentPage: page,
          total: total,
          isLoading: list.isLoading,
          onPageChanged: (p) =>
              ref.read(customerPageProvider.notifier).state = p,
        ),
      ]),
      floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: 'importC',
              icon: const Icon(Icons.upload_file),
              label: const Text('استيراد'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ImportHubScreen(initial: 2))),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.extended(
                heroTag: 'addC',
                icon: const Icon(Icons.add),
                label: const Text('عميل'),
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CustomerFormRoute()));
                  ref.invalidate(customerListProvider);
                }),
          ]),
    );
  }
}

class CustomerDetailsScreen extends ConsumerStatefulWidget {
  final String code;
  const CustomerDetailsScreen({super.key, required this.code});
  @override
  ConsumerState<CustomerDetailsScreen> createState() =>
      _CustomerDetailsState();
}

class _CustomerDetailsState extends ConsumerState<CustomerDetailsScreen> {
  static const int _pageSize = 10;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    return Scaffold(
      appBar: AppBar(title: Text('عميل: $code')),
      body: FutureBuilder(
        future: Future.wait([
          ref.read(customerRepoProvider).findByCode(code),
          ref.read(customerRepoProvider).stats(code),
          ref.read(customerRepoProvider).history(code,
              limit: _pageSize,
              offset: Pagination.offsetFor(_page, _pageSize)),
          ref.read(customerRepoProvider).historyCount(code),
        ]),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data![0] as Customer?;
          final stats = snap.data![1] as Map<String, Object>;
          final hist = (snap.data![2] as List).cast<DeliveryHeader>();
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
                          // عنوان الكارد: اسم العميل كبير وواضح
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
                                    color: const Color(0xFFE65100))),
                          ]),
                          const SizedBox(height: 8),
                          Text('آخر تعامل: ${stats['lastDate']}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ]))),
            const SizedBox(height: 8),
            // تصدير ملف العميل: كل الأذون بتفاصيلها — PDF أو Excel
            PartnerExportButtons(
                partnerCode: s.code,
                partnerName: s.desc,
                isSupplier: false),
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
                  isReceipt: false,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DeliveryDetailsScreen(
                              id: h.id.toString()))),
                )),
            if (hist.isEmpty && _page == 0)
              const EmptyState(message: 'لا توجد أذون لهذا العميل'),
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

class CustomerFormRoute extends ConsumerStatefulWidget {
  const CustomerFormRoute({super.key});
  @override
  ConsumerState<CustomerFormRoute> createState() => _CF();
}

class _CF extends ConsumerState<CustomerFormRoute> {
  final nameC = TextEditingController();
  final codeC = TextEditingController();

  @override
  void initState() {
    super.initState();
    DocumentNumberService().nextCustomerCode().then((c) {
      if (mounted) setState(() => codeC.text = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عميل')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
              controller: nameC,
              decoration:
                  const InputDecoration(labelText: 'اسم العميل')),
          const SizedBox(height: 12),
          TextField(
              controller: codeC,
              decoration: const InputDecoration(
                  labelText: 'الكود (يُولّد تلقائيًا — قابل للتعديل)')),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: () async {
                try {
                  var code = codeC.text.trim();
                  if (code.isEmpty) {
                    code = await DocumentNumberService()
                        .nextCustomerCode();
                  }
                  await ref.read(customerRepoProvider).create(
                      Customer(code: code, desc: nameC.text.trim()));
                  if (context.mounted) {
                    toast(context, 'تم حفظ العميل: $code');
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
