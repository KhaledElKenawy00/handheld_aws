import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/pagination/pagination.dart';
import '../../../core/providers.dart';
import '../../../core/scanner/scanner_providers.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/scan_input.dart';
import '../../products/presentation/products_screen.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(inventoryQueryProvider);
    final page = ref.watch(inventoryPageProvider);
    final list = ref.watch(inventoryListProvider);
    final total = list.valueOrNull?.total ?? 0;
    final lastPage = Pagination.totalPages(total) - 1;
    if (total > 0 && page > lastPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(inventoryPageProvider.notifier).state = lastPage;
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الجرد')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SearchField(
            hint: 'بحث برقم الجرد أو التاريخ...',
            onChanged: (v) {
              ref.read(inventoryQueryProvider.notifier).state = v;
              ref.read(inventoryPageProvider.notifier).state = 0;
            },
          ),
        ),
        Expanded(
          child: list.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (paged) {
              final ss = paged.items.cast<InventorySession>();
              if (ss.isEmpty) {
                return const EmptyState(message: 'لا توجد جلسات جرد — ابدأ جردًا جديدًا');
              }
              return ListView.builder(
                key: ValueKey('inventory-$q-$page'),
                itemCount: ss.length,
                itemBuilder: (_, i) => Card(
                  child: ListTile(
                    leading: Icon(
                        ss[i].status == 'closed'
                            ? Icons.lock_rounded
                            : Icons.fact_check_rounded,
                        color: ss[i].status == 'closed'
                            ? Colors.grey
                            : AppColors.primary),
                    title: Text(ss[i].id),
                    subtitle: Text('${ss[i].date} — ${ss[i].status == 'closed' ? 'مغلق' : 'مفتوح'}'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                InventoryDetailsScreen(id: ss[i].id))),
                  ),
                ),
              );
            },
          ),
        ),
        PaginationBar(
          currentPage: page,
          total: total,
          isLoading: list.isLoading,
          onPageChanged: (p) =>
              ref.read(inventoryPageProvider.notifier).state = p,
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('جرد جديد'),
        onPressed: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CreateInventoryScreen()));
          ref.invalidate(inventoryListProvider);
        },
      ),
    );
  }
}

class CreateInventoryScreen extends ConsumerStatefulWidget {
  const CreateInventoryScreen({super.key});
  @override
  ConsumerState<CreateInventoryScreen> createState() => _CI();
}

class _CI extends ConsumerState<CreateInventoryScreen> {
  final dateC = TextEditingController();
  List<Map<String, Object>>? expected;
  String? fileName;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    dateC.text = AppUtils.todayStr();
  }

  Future<void> _pickExpected() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
    if (r == null || r.files.single.path == null) return;
    final rows = await ref
        .read(importServiceProvider)
        .readInventoryExpected(File(r.files.single.path!));
    setState(() {
      expected = rows;
      fileName = r.files.single.name;
    });
  }

  Future<void> _create() async {
    setState(() => busy = true);
    try {
      final id = await ref.read(inventoryRepoProvider).createSession(
          date: dateC.text.trim().isEmpty
              ? AppUtils.todayStr()
              : dateC.text.trim(),
          expected: expected);
      ref.invalidate(inventoryListProvider);
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => InventoryDetailsScreen(id: id)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بدء جرد جديد')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        TextField(
            controller: dateC,
            decoration: const InputDecoration(
                labelText: 'تاريخ الجرد (YYYY-MM-DD)')),
        const SizedBox(height: 12),
        const Card(
            child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'اختياري: استورد ملف Excel (code | desc | qty) ككميات متوقعة. إذا لم تستورد، تُستخدم أرصدة النظام الحالية تلقائيًا عند المسح.'))),
        Row(children: [
          ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('استيراد المتوقع'),
              onPressed: _pickExpected),
          const SizedBox(width: 8),
          OutlinedButton(
              onPressed: () async {
                final p = await ref
                    .read(excelServiceProvider)
                    .template(withQty: true);
                if (context.mounted) toast(context, 'القالب: $p');
              },
              child: const Text('قالب')),
        ]),
        if (fileName != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  'الملف: $fileName — ${expected?.length ?? 0} صنف')),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: busy ? null : _create,
            child: Text(busy ? 'جارٍ الإنشاء...' : 'بدء الجرد')),
      ]),
    );
  }
}

class InventoryDetailsScreen extends ConsumerStatefulWidget {
  final String id;
  const InventoryDetailsScreen({super.key, required this.id});
  @override
  ConsumerState<InventoryDetailsScreen> createState() => _ID();
}

class _ID extends ConsumerState<InventoryDetailsScreen> {
  final scanC = TextEditingController();
  StreamSubscription? sub;
  String filter = 'all'; // all | shortage | excess | matched
  String query = '';
  int _page = 0;
  static const int _pageSize = 10;
  // حد التصدير الكامل (PDF/Excel) — إجراء صريح من المستخدم فيشمل كل البنود
  static const int _exportLimit = 1 << 20;

  void _setFilter(String f) => setState(() {
        filter = f;
        _page = 0;
      });

  void _setQuery(String v) => setState(() {
        query = v;
        _page = 0;
      });

  /// زر فلتر بألوان صريحة ثابتة (مش معتمد على الثيم) عشان الكلام
  /// يفضل ظاهر دائمًا: المحدد = كحلي بخط أبيض، غير المحدد = لبني بخط كحلي
  Widget _filterBtn(String label, String value) {
    final sel = filter == value;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor:
            sel ? const Color(0xFF0B1F3A) : const Color(0xFFE3F0FD),
        foregroundColor:
            sel ? Colors.white : const Color(0xFF0B1F3A),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: () => _setFilter(value),
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: sel ? Colors.white : const Color(0xFF0B1F3A))),
    );
  }

  @override
  void initState() {
    super.initState();
    try {
      sub = ref
          .read(scannerServiceProvider)
          .scanStream
          .listen((c) => _scan(c.trim().replaceAll(RegExp(r'\s+'), '')));
    } catch (_) {}
  }

  @override
  void dispose() {
    sub?.cancel();
    scanC.dispose();
    super.dispose();
  }

  Future<void> _scan(String code) async {
    if (code.isEmpty) return;
    HapticFeedback.lightImpact();
    try {
      await ref.read(inventoryRepoProvider).scanOrAdd(widget.id, code);
      if (mounted) setState(() => scanC.clear());
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('غير موجود')) {
        final want = await productNotFoundDialog(context, code);
        if (want && mounted) {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProductFormRoute(presetCode: code)));
          try {
            await ref
                .read(inventoryRepoProvider)
                .scanOrAdd(widget.id, code);
            if (mounted) setState(() {});
          } catch (e2) {
            if (mounted) showError(context, e2);
          }
        }
      } else {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('جرد: ${widget.id}')),
      body: FutureBuilder(
        future: ref.read(inventoryRepoProvider).find(widget.id),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data;
          if (s == null) return const EmptyState(message: 'غير موجود');
          return _sessionBody(context, s);
        },
      ),
    );
  }

  /// جسم الجلسة: الهيدر + المسح + البحث + الفلتر + بنود paginated + الأزرار.
  /// البحث والفلترة يتمّان في قاعدة البيانات قبل LIMIT/OFFSET.
  Widget _sessionBody(BuildContext context, InventorySession s) {
    return FutureBuilder(
      future: Future.wait([
        ref.read(inventoryRepoProvider).items(
              widget.id,
              q: query,
              filter: filter,
              limit: _pageSize,
              offset: Pagination.offsetFor(_page, _pageSize),
            ),
        ref.read(inventoryRepoProvider).itemsCount(
              widget.id,
              q: query,
              filter: filter,
            ),
        ref.read(inventoryRepoProvider).itemsStats(widget.id),
      ]),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = (snap.data![0] as List).cast<InventoryItem>();
        final filteredTotal = snap.data![1] as int;
        final stats = snap.data![2] as Map<String, int>;
        final shortage = stats['shortage'] ?? 0;
        final excess = stats['excess'] ?? 0;
        final matched = stats['matched'] ?? 0;
        return ListView(padding: const EdgeInsets.all(12), children: [
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'التاريخ: ${s.date} — الحالة: ${s.status == 'closed' ? 'مغلق' : 'مفتوح'}'),
                        Text(
                            'الإجمالي: $filteredTotal | ناقص: $shortage | زائد: $excess | متساوي: $matched',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ]))),
          if (s.status != 'closed') ...[
            ScanBar(
              controller: scanC,
              hint: 'امسح صنفًا للجرد',
              onTriggerScan: () async {
                try {
                  await ref
                      .read(scannerServiceProvider)
                      .triggerScan();
                } catch (_) {
                  if (mounted) {
                    toast(context,
                        'استخدم زر المسح الفيزيائي أو أدخل الكود');
                  }
                }
              },
              onSubmit: _scan,
            ),
          ],
          ScanTextField(
            hint: 'بحث في أصناف الجرد — اكتب أو امسح',
            onChanged: _setQuery,
          ),
          const SizedBox(height: 8),
          // فلاتر صريحة بألوان ثابتة: المحدد كحلي بخط أبيض — ظاهرة دائمًا
          Wrap(spacing: 6, runSpacing: 6, children: [
            _filterBtn('الكل', 'all'),
            _filterBtn('ناقص', 'shortage'),
            _filterBtn('زائد', 'excess'),
            _filterBtn('متساوي', 'matched'),
          ]),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const EmptyState(message: 'لا توجد بنود مطابقة'),
          ...items.map((it) => Card(
                  child: ListTile(
                title: Text('${it.productName} (${it.productCode})'),
                subtitle: Text(
                    'متوقع: ${AppUtils.fmtQty(it.expectedQty)} | فعلي: ${AppUtils.fmtQty(it.actualQty)} | فرق: ${AppUtils.fmtQty(it.difference)} — ${it.statusAr}'),
                trailing: s.status == 'closed'
                    ? Chip(
                        label: Text(it.statusAr,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: it.difference == 0
                                    ? Colors.green.shade900
                                    : it.difference < 0
                                        ? Colors.red.shade900
                                        : Colors.orange.shade900)),
                        backgroundColor: it.difference == 0
                            ? Colors.green.shade100
                            : it.difference < 0
                                ? Colors.red.shade100
                                : Colors.orange.shade100)
                    : SizedBox(
                        width: 90,
                        child: TextField(
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'فعلي'),
                          controller: TextEditingController(
                              text:
                                  AppUtils.fmtQty(it.actualQty)),
                          onSubmitted: (v) async {
                            final n = double.tryParse(v) ?? 0;
                            await ref
                                .read(inventoryRepoProvider)
                                .setActual(
                                    widget.id, it.productCode, n);
                            setState(() {});
                          },
                        ),
                      ),
              ))),
          PaginationBar(
            currentPage: _page,
            total: filteredTotal,
            pageSize: _pageSize,
            onPageChanged: (p) => setState(() => _page = p),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            if (s.status != 'closed')
              FilledButton.icon(
                  icon: const Icon(Icons.lock),
                  label: const Text('إغلاق الجرد'),
                  onPressed: () async {
                    await ref
                        .read(inventoryRepoProvider)
                        .close(widget.id);
                    setState(() {});
                  }),
            FilledButton.tonalIcon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF'),
                onPressed: () async {
                  final all = await ref
                      .read(inventoryRepoProvider)
                      .items(widget.id, limit: _exportLimit);
                  final folder = await ref
                      .read(storageServiceProvider)
                      .inventoryDir(s.date);
                  final path = await ref
                      .read(pdfServiceProvider)
                      .inventoryPdf(s, all, folder);
                  await OpenFilex.open(path);
                }),
            FilledButton.tonalIcon(
                icon: const Icon(Icons.table_chart),
                label: const Text('Excel'),
                onPressed: () async {
                  final all = await ref
                      .read(inventoryRepoProvider)
                      .items(widget.id, limit: _exportLimit);
                  final folder = await ref
                      .read(storageServiceProvider)
                      .inventoryDir(s.date);
                  final path = await ref
                      .read(excelServiceProvider)
                      .exportInventory(s, all, folder);
                  await OpenFilex.open(path);
                }),
            OutlinedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('مشاركة'),
                onPressed: () async {
                  final all = await ref
                      .read(inventoryRepoProvider)
                      .items(widget.id, limit: _exportLimit);
                  final folder = await ref
                      .read(storageServiceProvider)
                      .inventoryDir(s.date);
                  final path = await ref
                      .read(pdfServiceProvider)
                      .inventoryPdf(s, all, folder);
                  await Share.shareXFiles([XFile(path)]);
                }),
          ]),
        ]);
      },
    );
  }
}
