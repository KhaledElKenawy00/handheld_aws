import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/pagination/pagination.dart';
import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import '../../shared/widgets/pagination_bar.dart';
import '../ops/op_details_screen.dart';
import 'op_info_screen.dart';
import 'op_kind.dart';
import 'op_print.dart';

/// قائمة المعاملات — كارت لكل عملية: طباعة/حذف + الاسم + # + التواريخ والكميات + تعديل.
/// باجنيشن 10 كونتينر / صفحة كحد أقصى لمنع التهنيج بدل تحميل الكل مرة واحدة.
class OpListScreen extends ConsumerStatefulWidget {
  final OpKind kind;
  const OpListScreen({super.key, required this.kind});
  @override
  ConsumerState<OpListScreen> createState() => _OpListState();
}

class _OpCard {
  final String id;
  final String name;
  final int number;
  final String date;
  final double reqQty;
  final double totalQty;
  final double totalWeight;
  final String byUser;
  _OpCard(this.id, this.name, this.number, this.date, this.reqQty, this.totalQty,
      this.totalWeight, this.byUser);
}

class _OpListState extends ConsumerState<OpListScreen> {
  String q = '';
  int _page = 0;
  static const int _pageSize = Pagination.defaultPageSize; // 10
  final searchC = TextEditingController();

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: widget.kind.listTitle,
      fab: RefFab(onPressed: () async {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => OpInfoScreen(kind: widget.kind)));
        setState(() {});
      }),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchC,
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontFamily: 'Cairo', fontSize: 18),
              decoration: const InputDecoration(hintText: 'بحث'),
              onChanged: (v) => setState(() {
                q = v;
                _page = 0;
              }),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _load(),
              builder: (_, snap) {
                if (snap.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                      child: Text('خطأ: ${snap.error}'));
                }
                final items = snap.data?.items ?? [];
                final total = snap.data?.total ?? 0;
                final lastPage = Pagination.totalPages(
                        total, _pageSize) -
                    1;
                if (total > 0 && _page > lastPage) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _page = lastPage);
                    }
                  });
                }
                if (items.isEmpty) {
                  return Column(children: [
                    const Expanded(
                      child: Center(
                          child: Text('لا توجد معاملات بعد',
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
                return Column(children: [
                  Expanded(
                    child: ListView.builder(
                      key: ValueKey(
                          '${widget.kind.name}-$q-$_page'),
                      padding: const EdgeInsets.fromLTRB(
                          16, 8, 16, 8),
                      itemCount: items.length,
                      itemBuilder: (_, i) =>
                          _card(items[i]),
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

  Future<({List<_OpCard> items, int total})> _load() async {
    final k = widget.kind;
    final offset = Pagination.offsetFor(_page, _pageSize);
    if (k == OpKind.delivery) {
      final res = await Future.wait([
        ref.read(deliveryRepoProvider).list(
            q: q, limit: _pageSize, offset: offset),
        ref.read(deliveryRepoProvider).count(q: q),
      ]);
      final r = (res[0] as List);
      return (
        items: [
          for (final h in r)
            _OpCard(h.id, h.customerName, h.number, h.date, h.reqQty,
                h.totalQty, h.totalWeight, h.byUser)
        ],
        total: res[1] as int,
      );
    } else if (k == OpKind.receipt) {
      final res = await Future.wait([
        ref.read(receiptRepoProvider).list(
            q: q, limit: _pageSize, offset: offset),
        ref.read(receiptRepoProvider).count(q: q),
      ]);
      final r = (res[0] as List);
      return (
        items: [
          for (final h in r)
            _OpCard(h.id, h.supplierName, h.number, h.date, h.reqQty,
                h.totalQty, h.totalWeight, h.byUser)
        ],
        total: res[1] as int,
      );
    } else {
      final res = await Future.wait([
        ref.read(opsRepoProvider).list(k.label,
            q: q, limit: _pageSize, offset: offset),
        ref.read(opsRepoProvider).count(k.label, q: q),
      ]);
      final r = (res[0] as List);
      return (
        items: [
          for (final h in r)
            _OpCard(h.id, h.partyName, h.number, h.date, h.reqQty,
                h.totalQty, h.totalWeight, h.byUser)
        ],
        total: res[1] as int,
      );
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف العملية؟',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 19,
                fontWeight: FontWeight.w800)),
        content: const Text('سيتم عكس المخزون. متابعة؟',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 15, height: 1.6)),
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
      final k = widget.kind;
      if (k == OpKind.delivery) {
        await ref.read(deliveryRepoProvider).delete(id);
      } else if (k == OpKind.receipt) {
        await ref.read(receiptRepoProvider).delete(id);
      } else {
        await ref.read(opsRepoProvider).delete(id);
      }
      if (mounted) {
        refToast(context, 'تم الحذف');
        setState(() {});
      }
    } catch (e) {
      if (mounted) refError(context, e);
    }
  }

  Future<void> _print(_OpCard c) async {
    final detailed = await _askPrintKind();
    if (detailed == null || !mounted) return;
    try {
      final path =
          await printOperation(ref, widget.kind, c.id, detailed: detailed);
      if (mounted) {
        refToast(context,
            detailed ? 'تم إنشاء PDF تفصيلي' : 'تم إنشاء PDF إجمالي');
      }
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) refError(context, e);
    }
  }

  /// دايلوج اختيار نوع الطباعة: تفصيلي (وزن كل كرتونة) أو إجمالي.
  /// يُرجع true لتفصيلي، false لإجمالي، null للإلغاء.
  Future<bool?> _askPrintKind() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('نوع الطباعة',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'التفصيلي يعرض كل كرتونة ممسوحة لوحدها مع وزنها — مناسب لأصناف الوزن المتغير.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: RefColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                textStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              child: const Text('تفصيلي'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: RefColors.navy,
                side:
                    const BorderSide(color: RefColors.navy, width: 1.6),
                minimumSize: const Size(64, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                textStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              child: const Text('إجمالي'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
        ],
      ),
    );
  }

  Widget _card(_OpCard c) {
    String f(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
    String f2(double v) => v.toStringAsFixed(2);
    return InkWell(
      onTap: () async {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => OpDetailsScreen(kind: widget.kind, headerId: c.id)));
        setState(() {});
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .09), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => _delete(c.id),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline_rounded, size: 32, color: RefColors.red),
                  ),
                ),
                RefPrintButton(onPressed: () => _print(c)),
                Expanded(
                  child: Text(c.name,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: RefColors.nameOrange)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(c.date,
                      textAlign: TextAlign.left,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 17)),
                ),
                Text('#${c.number}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 17)),
              ],
            ),
            const SizedBox(height: 2),
            _stat('الكمية المطلوبة:', f(c.reqQty), RefColors.primary),
            _stat('الكمية المسجلة:', f(c.totalQty), RefColors.green),
            _stat('الوزن:', f2(c.totalWeight), RefColors.red),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(c.byUser,
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w600, color: RefColors.blue)),
                const Text(' :بواسطة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 17, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 8),
            RefButton(
                label: 'تعديل',
                icon: Icons.edit_outlined,
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => OpInfoScreen(kind: widget.kind, editId: c.id)));
                  setState(() {});
                }),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(value,
              textDirection: TextDirection.ltr,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w600, color: color)),
          Text(' $label',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, color: Colors.black87)),
        ],
      ),
    );
  }
}
