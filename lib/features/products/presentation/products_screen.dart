import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pagination/pagination.dart';
import '../../../core/providers.dart';
import '../../../core/scanner/scanner_providers.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/scan_input.dart';

/// قائمة الأصناف + بحث + إضافة + استيراد — paginated (30 صف/صفحة).
/// البحث يتم في قاعدة البيانات قبل التقطيع: يشمل كل الأصناف.
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(productQueryProvider);
    final page = ref.watch(productPageProvider);
    final list = ref.watch(productListProvider);
    final total = list.valueOrNull?.total ?? 0;
    // لو الصفحة الحالية خارج المدى (مثلًا بعد حذف أو بحث جديد) — رجّع لآخر صفحة صالحة
    final lastPage = Pagination.totalPages(total) - 1;
    if (total > 0 && page > lastPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(productPageProvider.notifier).state = lastPage;
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الأصناف')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ScanTextField(
            hint: 'بحث بالكود أو الاسم — اكتب أو امسح',
            onChanged: (v) {
              ref.read(productQueryProvider.notifier).state = v;
              ref.read(productPageProvider.notifier).state = 0;
            },
          ),
        ),
        Expanded(
          child: list.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
            data: (paged) {
              final ps = paged.items.cast<Product>();
              if (ps.isEmpty) {
                return const EmptyState(message: 'لا توجد أصناف — أضف صنفًا أو استورد من Excel');
              }
              return ListView.builder(
                key: ValueKey('products-$q-$page'),
                itemCount: ps.length,
                itemBuilder: (_, i) {
                  final p = ps[i];
                  final tag = p.code.length > 3
                      ? p.code.substring(p.code.length - 3)
                      : p.code;
                  return ListTile(
                    // مربع صريح قدام الاسم: كحلي بخط أبيض — ظاهر دائمًا
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1F3A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                    title: Text(p.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF101A2E))),
                    subtitle: Text(
                        'كود: ${p.code} | مخزون: ${p.stock == p.stock.truncateToDouble() ? p.stock.toInt() : p.stock}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3A4763))),
                    trailing: const Icon(Icons.chevron_left,
                        color: Color(0xFF3A4763)),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProductDetailsScreen(code: p.code))),
                  );
                },
              );
            },
          ),
        ),
        PaginationBar(
          currentPage: page,
          total: total,
          isLoading: list.isLoading,
          onPageChanged: (p) =>
              ref.read(productPageProvider.notifier).state = p,
        ),
      ]),
      floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: 'importP',
              icon: const Icon(Icons.upload_file),
              label: const Text('استيراد'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ImportHubScreen(initial: 0))),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.extended(
              heroTag: 'addP',
              icon: const Icon(Icons.add),
              label: const Text('صنف'),
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProductFormRoute()));
                ref.invalidate(productListProvider);
                ref.invalidate(dashboardProvider);
              },
            ),
          ]),
    );
  }
}

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final String code;
  const ProductDetailsScreen({super.key, required this.code});
  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsState();
}

class _ProductDetailsState extends ConsumerState<ProductDetailsScreen> {
  static const int _pageSize = 20;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    // شاشة عرض فقط: بدون تعديل وبدون مسح — حسب طلب المستخدم
    return Scaffold(
      appBar: AppBar(title: Text('صنف: $code')),
      body: FutureBuilder(
        future: ref.read(productRepoProvider).findByCode(code),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data;
          if (p == null) return const EmptyState(message: 'الصنف غير موجود');
          final qtyStr = p.stock == p.stock.truncateToDouble()
              ? p.stock.toInt().toString()
              : p.stock.toString();
          return ListView(padding: const EdgeInsets.all(12), children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.desc,
                                  maxLines: 3,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF101A2E))),
                              const SizedBox(height: 2),
                              Text('الكود: ${p.code}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF3A4763))),
                            ]),
                      ),
                      const SizedBox(width: 6),
                      // مربع المخزون صريح: ظاهر دائمًا
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF1B7A2B)
                                  .withValues(alpha: .45),
                              width: 1.5),
                        ),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(qtyStr,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1B7A2B),
                                      height: 1.1)),
                              const Text('مخزون',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1B7A2B))),
                            ]),
                      ),
                    ]))),
            const SizedBox(height: 8),
            const Text('سجل الحركة',
                style: TextStyle(fontWeight: FontWeight.bold)),
            FutureBuilder(
              future: Future.wait([
                ref.read(productRepoProvider).movements(code,
                    limit: _pageSize,
                    offset: Pagination.offsetFor(_page, _pageSize)),
                ref.read(productRepoProvider).movementsCount(code),
              ]),
              builder: (_, s2) {
                if (!s2.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final ms = (s2.data![0] as List).cast<StockMovement>();
                final total = s2.data![1] as int;
                if (ms.isEmpty && _page == 0) {
                  return const EmptyState(message: 'لا توجد حركات بعد');
                }
                return Column(children: [
                  ...ms.map((m) => ListTile(
                        leading: Icon(
                            m.type == 'DELIVERY'
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: m.type == 'DELIVERY'
                                ? Colors.red
                                : Colors.green),
                        title: Text('${m.type} — ${m.referenceId}'),
                        subtitle: Text(m.createdAt),
                        trailing: Text(
                            '${m.quantity > 0 ? '+' : ''}${m.quantity} (${m.beforeQty} → ${m.afterQty})'),
                      )),
                  PaginationBar(
                    currentPage: _page,
                    total: total,
                    pageSize: _pageSize,
                    onPageChanged: (p) => setState(() => _page = p),
                  ),
                ]);
              },
            ),
          ]);
        },
      ),
    );
  }
}

class ProductFormRoute extends ConsumerStatefulWidget {
  final String? code;
  final String? presetCode;
  const ProductFormRoute({super.key, this.code, this.presetCode});
  @override
  ConsumerState<ProductFormRoute> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductFormRoute> {
  final codeC = TextEditingController();
  final descC = TextEditingController();
  final codeFocus = FocusNode();
  final descFocus = FocusNode();
  StreamSubscription? scanSub;
  String? lastScanned;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.presetCode != null) codeC.text = widget.presetCode!;
    _load();
    // الاستماع لماسح SUNMI أثناء شاشة إضافة الصنف — يملأ الكود مباشرة.
    // (وضع keyboard-wedge يعمل تلقائيًا أيضًا لأن حقل الكود autofocus)
    try {
      scanSub = ref
          .read(scannerServiceProvider)
          .scanStream
          .listen(_onScannerCode);
    } catch (_) {}
    if (widget.code == null && widget.presetCode == null) {
      // تركيز تلقائي على الكود لاستقبال زر المسح الفيزيائي فورًا
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) codeFocus.requestFocus();
      });
    }
  }

  void _onScannerCode(String raw) {
    if (!mounted || widget.code != null) return; // وضع التعديل: الكود مقفل
    final code = raw.trim();
    if (code.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      codeC.text = code;
      lastScanned = code;
    });
    // انقل التركيز للاسم لإكمال الإدخال بسرعة
    descFocus.requestFocus();
    toast(context, 'تم مسح الكود: $code');
  }

  @override
  void dispose() {
    scanSub?.cancel();
    codeC.dispose();
    descC.dispose();
    codeFocus.dispose();
    descFocus.dispose();
    super.dispose();
  }

  Future<void> _triggerScan() async {
    codeFocus.requestFocus();
    try {
      await ref.read(scannerServiceProvider).triggerScan();
    } catch (_) {
      // على غير SUNMI أو بدون دعم trigger: المستخدم يضغط زر الجهاز
      // الفيزيائي أو يكتب يدويًا — الحقل مركّز وجاهز للاستقبال.
      if (mounted) {
        toast(context,
            'اضغط زر المسح الفيزيائي في الجهاز — الحقل جاهز للاستقبال');
      }
    }
  }

  Future<void> _load() async {
    if (widget.code != null) {
      final p =
          await ref.read(productRepoProvider).findByCode(widget.code!);
      if (p != null) {
        codeC.text = p.code;
        descC.text = p.desc;
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.code != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل صنف' : 'إضافة صنف')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                          controller: codeC,
                          focusNode: codeFocus,
                          enabled: !isEdit,
                          autofocus: !isEdit,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                              descFocus.requestFocus(),
                          decoration: InputDecoration(
                            labelText: 'الكود (فريد)',
                            hintText: 'امسح بالماسح أو أدخل يدويًا',
                            helperText: lastScanned == null
                                ? 'اضغط زر المسح في الجهاز لملء الكود'
                                : 'آخر مسح: $lastScanned',
                            suffixIcon: isEdit
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons
                                        .document_scanner_outlined),
                                    tooltip: 'مسح بالـ Scanner',
                                    onPressed: _triggerScan,
                                  ),
                          )),
                    ),
                    if (!isEdit) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _triggerScan,
                        icon: const Icon(
                            Icons.document_scanner_outlined),
                        label: const Text('مسح'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: descC,
                    focusNode: descFocus,
                    textInputAction: TextInputAction.done,
                    decoration:
                        const InputDecoration(labelText: 'الوصف / الاسم')),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    try {
                      if (isEdit) {
                        await ref.read(productRepoProvider).update(Product(
                            code: codeC.text.trim(),
                            desc: descC.text.trim()));
                      } else {
                        await ref
                            .read(productRepoProvider)
                            .create(Product(
                                code: codeC.text.trim(),
                                desc: descC.text.trim()));
                      }
                      if (context.mounted) {
                        toast(context, 'تم الحفظ بنجاح');
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ]),
            ),
    );
  }
}

/// مركز الاستيراد: أصناف / موردين / عملاء / جرد — مع Preview
class ImportHubScreen extends ConsumerStatefulWidget {
  final int initial;
  const ImportHubScreen({super.key, this.initial = 0});
  @override
  ConsumerState<ImportHubScreen> createState() => _ImportHubState();
}

class _ImportHubState extends ConsumerState<ImportHubScreen> {
  List<Map<String, String>>? preview;
  String? fileName;
  File? file;
  String? kind;
  bool busy = false;

  Future<void> _pick(String k) async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
    if (r == null || r.files.single.path == null) return;
    setState(() {
      file = File(r.files.single.path!);
      fileName = r.files.single.name;
      kind = k;
      preview = null;
    });
    try {
      final rows =
          await ref.read(importServiceProvider).readRows(file!);
      setState(() => preview = rows.take(20).toList());
      if (preview!.isEmpty && mounted) {
        showError(context, 'الملف فارغ أو بدون بيانات');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _import() async {
    if (file == null || kind == null) return;
    setState(() => busy = true);
    try {
      final svc = ref.read(importServiceProvider);
      final sum = kind == 'products'
          ? await svc.importProducts(file!)
          : kind == 'suppliers'
              ? await svc.importSuppliers(file!)
              : await svc.importCustomers(file!);
      ref.invalidate(productListProvider);
      ref.invalidate(supplierListProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('نتيجة الاستيراد'),
          content: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إجمالي الصفوف: ${sum.total}'),
                  Text('جديد: ${sum.imported}'),
                  Text('محدّث: ${sum.updated}'),
                  Text('متخطى: ${sum.skipped}'),
                  if (sum.errors.isNotEmpty) ...[
                    const Divider(),
                    const Text('الأخطاء:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...sum.errors
                        .take(30)
                        .map((e) => Text('• $e')),
                    if (sum.errors.length > 30)
                      Text('... و${sum.errors.length - 30} أخرى'),
                  ],
                ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'))
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد Excel')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        const Card(
            child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'الصيغة: code | desc — الصف الأول عناوين. للجرد: code | desc | qty'))),
        Wrap(spacing: 8, children: [
          ElevatedButton(
              onPressed: () => _pick('products'),
              child: const Text('ملف الأصناف')),
          ElevatedButton(
              onPressed: () => _pick('suppliers'),
              child: const Text('ملف الموردين')),
          ElevatedButton(
              onPressed: () => _pick('customers'),
              child: const Text('ملف العملاء')),
          OutlinedButton(
              onPressed: () async {
                final p = await ref
                    .read(excelServiceProvider)
                    .template();
                if (context.mounted) toast(context, 'تم إنشاء القالب: $p');
              },
              child: const Text('تحميل قالب')),
        ]),
        if (fileName != null) ...[
          const SizedBox(height: 12),
          Text('الملف: $fileName ($kind)'),
          if (preview != null) ...[
            const SizedBox(height: 8),
            Text('معاينة أول ${preview!.length} صفوف:',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ...preview!.map((r) => Card(
                child: ListTile(
                    dense: true,
                    title: Text(
                        'code: ${r['code'] ?? ''} — desc: ${r['desc'] ?? ''} ${r['qty'] != null ? '| qty: ${r['qty']}' : ''}')))),
          ],
          const SizedBox(height: 12),
          FilledButton(
              onPressed: busy ? null : _import,
              child: busy
                  ? const CircularProgressIndicator()
                  : const Text('تنفيذ الاستيراد')),
        ],
      ]),
    );
  }
}
