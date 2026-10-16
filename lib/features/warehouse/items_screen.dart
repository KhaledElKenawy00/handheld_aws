import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pagination/pagination.dart';
import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/pagination_bar.dart';
import 'add_item_screen.dart';
import 'add_code_dialog.dart';

/// الاصناف — بحث + كروت (حذف/اسم/رقم/أضف الكود/تعديل) + زر +.
/// باجنيشن 10 كونتينر / صفحة كحد أقصى لمنع التهنيج بدل تحميل الكل مرة واحدة.
/// البحث يتم في قاعدة البيانات قبل LIMIT/OFFSET فيشمل كل الأصناف.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});
  @override
  ConsumerState<ItemsScreen> createState() => _ItemsState();
}

class _ItemsState extends ConsumerState<ItemsScreen> {
  final searchC = TextEditingController();
  String q = '';
  int _page = 0;
  static const int _pageSize = Pagination.defaultPageSize; // 10

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) setState(() {});
    // حدّث القوائم المشتركة (الأصناف/المخزون/الداشبورد) بعد الحذف/الإضافة
    try {
      ref.invalidate(productListProvider);
      ref.invalidate(dashboardProvider);
    } catch (_) {}
  }

  void _setQuery(String v) {
    setState(() {
      q = v;
      _page = 0;
    });
  }

  Future<({List<Product> items, int total})> _load() async {
    final repo = ref.read(productRepoProvider);
    final res = await Future.wait([
      // مهم: activeOnly=true (الافتراضي) حتى تختفي الأصناف المحذوفة من القائمة.
      // كان activeOnly:false فكان الحذف الناعم لا يُخفي الصنف — فيبدو أنه "مش بيتحذف".
      repo.search(q,
          limit: _pageSize,
          offset: Pagination.offsetFor(_page, _pageSize)),
      repo.count(q: q),
    ]);
    return (
      items: (res[0] as List<Product>),
      total: res[1] as int,
    );
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الصنف؟',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 19,
                fontWeight: FontWeight.w800)),
        content: Text('حذف "${p.desc}" (${p.code})؟',
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
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(productRepoProvider).softDelete(p.code);
      // لو حذفنا آخر عنصر في الصفحة ارجع صفحة للخلف حتى لا تبقى صفحة فاضية
      final total = await ref.read(productRepoProvider).count(q: q);
      final last = Pagination.totalPages(total, _pageSize) - 1;
      if (mounted && _page > last) {
        setState(() => _page = last < 0 ? 0 : last);
      }
      if (mounted) refToast(context, 'تم حذف الصنف');
      await _reload();
    } catch (e) {
      if (mounted) refError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'الاصناف',
      fab: RefFab(onPressed: () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddItemScreen()));
        _page = 0;
        _reload();
      }),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchC,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 18),
              decoration: const InputDecoration(hintText: 'بحث'),
              onChanged: _setQuery,
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _load(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('خطأ: ${snap.error}'));
                }
                final items = snap.data?.items ?? [];
                final total = snap.data?.total ?? 0;
                // لو الصفحة خارج المدى بعد حذف/بحث — صححها تلقائيًا
                final lastPage =
                    Pagination.totalPages(total, _pageSize) - 1;
                if (total > 0 && _page > lastPage) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _page = lastPage);
                  });
                }
                if (items.isEmpty) {
                  return Column(children: [
                    const Expanded(
                      child: Center(
                          child: Text('لا توجد أصناف',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 18,
                                  color: RefColors.hintGrey))),
                    ),
                    PaginationBar(
                      currentPage: _page,
                      total: total,
                      pageSize: _pageSize,
                      onPageChanged: (p) =>
                          setState(() => _page = p),
                    ),
                  ]);
                }
                final offset =
                    Pagination.offsetFor(_page, _pageSize);
                return Column(children: [
                  Expanded(
                    child: ListView.builder(
                      key: ValueKey('items-$q-$_page'),
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: items.length,
                      itemBuilder: (_, i) =>
                          _itemCard(items[i], offset + i + 1),
                    ),
                  ),
                  PaginationBar(
                    currentPage: _page,
                    total: total,
                    pageSize: _pageSize,
                    onPageChanged: (p) =>
                        setState(() => _page = p),
                  ),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(Product p, int n) {
    final fieldBc = (p.barcode ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0x190B3A5B), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _delete(p),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 32, color: RefColors.red),
                ),
              ),
              Expanded(
                child: Text(p.desc,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: RefColors.nameOrange)),
              ),
            ],
          ),
          Text('#$n • ${p.code}',
              textAlign: TextAlign.right,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          // عرض باركود حقل الصنف مباشرة من نتيجة البحث — بدون استعلام
          // إضافي لكل كارت (كان كل كارت يعمل Future.wait فيسبب التهنيج N+1).
          if (fieldBc.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('لا يوجد باركود محفوظ — أضف واحدًا بالزر أسفل',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: RefColors.red,
                      fontWeight: FontWeight.w700)),
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF1B7A2B)
                        .withValues(alpha: .4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_rounded,
                      size: 18, color: Color(0xFF1B7A2B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(fieldBc,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('باركودات الصنف',
                              textAlign: TextAlign.center),
                          content: _ProductCodesView(
                              productCode: p.code),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context),
                                child: const Text('إغلاق')),
                          ],
                        ),
                      );
                      _reload();
                    },
                    child: const Text('عرض الكل',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Color(0xFF1B7A2B))),
                  ),
                ],
              ),
            ),
          RefOutlineButton(
              label: 'أضف الكود',
              onPressed: () async {
                await showAddCodeDialog(context, ref, p);
                _reload();
              }),
          const SizedBox(height: 10),
          RefButton(
              label: 'تعديل',
              icon: Icons.edit_outlined,
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddItemScreen(editCode: p.code)));
                _reload();
              }),
        ],
      ),
    );
  }
}

/// عرض باركودات الصنف عند الطلب فقط (وليس لكل الكروت مرة واحدة)
/// حتى لا يحدث N+1 ويهنج الجهاز.
class _ProductCodesView extends ConsumerWidget {
  final String productCode;
  const _ProductCodesView({required this.productCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.maxFinite,
      child: FutureBuilder(
        future: ref
            .read(productCodeRepoProvider)
            .forProduct(productCode),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final codes = snap.data!.cast<ProductCode>();
          if (codes.isEmpty) {
            return const Text('لا توجد باركودات إضافية',
                textAlign: TextAlign.center);
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in codes)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F0FD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: RefColors.primary
                            .withValues(alpha: .4)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(c.barcode,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                      ),
                      InkWell(
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('حذف الباركود؟',
                                  textAlign: TextAlign.center),
                              content: Text(
                                  'حذف ${c.barcode} من الصنف $productCode؟',
                                  textDirection:
                                      TextDirection.ltr,
                                  textAlign: TextAlign.center),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(
                                        context, false),
                                    child: const Text('إلغاء')),
                                FilledButton(
                                    onPressed: () => Navigator.pop(
                                        context, true),
                                    child: const Text('حذف')),
                              ],
                            ),
                          );
                          if (ok == true && c.id != null) {
                            await ref
                                .read(productCodeRepoProvider)
                                .delete(c.id!);
                            if (context.mounted) {
                              Navigator.pop(context);
                              refToast(context, 'تم حذف الباركود');
                            }
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: RefColors.red),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
