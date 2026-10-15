import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pagination/pagination.dart';
import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/pagination_bar.dart';

/// شاشة طرف عامة (العملاء / الموردين / المخازن) — بحث + كروت + دايلوج إضافة.
/// باجنيشن 10 كونتينر / صفحة كحد أقصى لمنع التهنيج.
enum PartyKind { customer, supplier, warehouse }

class PartiesScreen extends ConsumerStatefulWidget {
  final PartyKind kind;
  const PartiesScreen({super.key, required this.kind});
  const PartiesScreen.customers({super.key}) : kind = PartyKind.customer;
  const PartiesScreen.suppliers({super.key}) : kind = PartyKind.supplier;
  const PartiesScreen.warehouses({super.key}) : kind = PartyKind.warehouse;
  @override
  ConsumerState<PartiesScreen> createState() => _PartiesState();
}

class _PartiesState extends ConsumerState<PartiesScreen> {
  final searchC = TextEditingController();
  String q = '';
  int _page = 0;
  static const int _pageSize = Pagination.defaultPageSize; // 10

  String get title {
    switch (widget.kind) {
      case PartyKind.customer:
        return 'العملاء';
      case PartyKind.supplier:
        return 'الموردين';
      case PartyKind.warehouse:
        return 'المخازن';
    }
  }

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  Future<({List<({String code, String name})> items, int total})>
      _load() async {
    final offset = Pagination.offsetFor(_page, _pageSize);
    switch (widget.kind) {
      case PartyKind.customer:
        final res = await Future.wait([
          ref
              .read(customerRepoProvider)
              .search(q, limit: _pageSize, offset: offset),
          ref.read(customerRepoProvider).count(q: q),
        ]);
        final list = (res[0] as List<Customer>);
        return (
          items: [for (final e in list) (code: e.code, name: e.desc)],
          total: res[1] as int,
        );
      case PartyKind.supplier:
        final res = await Future.wait([
          ref
              .read(supplierRepoProvider)
              .search(q, limit: _pageSize, offset: offset),
          ref.read(supplierRepoProvider).count(q: q),
        ]);
        final list = (res[0] as List<Supplier>);
        return (
          items: [for (final e in list) (code: e.code, name: e.desc)],
          total: res[1] as int,
        );
      case PartyKind.warehouse:
        final res = await Future.wait([
          ref
              .read(warehouseRepoProvider)
              .search(q, limit: _pageSize, offset: offset),
          ref.read(warehouseRepoProvider).count(q: q),
        ]);
        final list = (res[0] as List<Warehouse>);
        return (
          items: [for (final e in list) (code: e.code, name: e.name)],
          total: res[1] as int,
        );
    }
  }

  Future<void> _save(String code, String name, {String? oldCode}) async {
    try {
      switch (widget.kind) {
        case PartyKind.customer:
          if (oldCode != null) {
            await ref
                .read(customerRepoProvider)
                .update(Customer(code: oldCode, desc: name));
          } else {
            await ref.read(customerRepoProvider).create(Customer(code: code, desc: name));
          }
          ref.invalidate(customerListProvider);
          break;
        case PartyKind.supplier:
          if (oldCode != null) {
            await ref
                .read(supplierRepoProvider)
                .update(Supplier(code: oldCode, desc: name));
          } else {
            await ref.read(supplierRepoProvider).create(Supplier(code: code, desc: name));
          }
          ref.invalidate(supplierListProvider);
          break;
        case PartyKind.warehouse:
          if (oldCode != null) {
            await ref.read(warehouseRepoProvider).delete(oldCode);
            await ref.read(warehouseRepoProvider).create(Warehouse(code: code, name: name));
          } else {
            await ref.read(warehouseRepoProvider).create(Warehouse(code: code, name: name));
          }
          break;
      }
      if (mounted) {
        Navigator.pop(context);
        refToast(context, 'تم الحفظ');
        setState(() {});
      }
    } catch (e) {
      if (mounted) refError(context, e);
    }
  }

  Future<void> _delete(String code, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف؟',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 19,
                fontWeight: FontWeight.w800)),
        content: Text('حذف "$name" ($code)؟',
            textAlign: TextAlign.center,
            style: const TextStyle(
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
      switch (widget.kind) {
        case PartyKind.customer:
          await ref.read(customerRepoProvider).softDelete(code);
          ref.invalidate(customerListProvider);
          break;
        case PartyKind.supplier:
          await ref.read(supplierRepoProvider).softDelete(code);
          ref.invalidate(supplierListProvider);
          break;
        case PartyKind.warehouse:
          await ref.read(warehouseRepoProvider).delete(code);
          break;
      }
      if (mounted) {
        refToast(context, 'تم الحذف');
        setState(() {});
      }
    } catch (e) {
      if (mounted) refError(context, e);
    }
  }

  void _showAdd({String? code, String? name}) {
    final codeC = TextEditingController(text: code ?? '');
    final nameC = TextEditingController(text: name ?? '');
    final isEdit = code != null;
    refDialog(
      context: context,
      dialogTitle: '${isEdit ? 'تعديل' : 'إضافة'} $title',
      onSave: () => _save(codeC.text.trim(), nameC.text.trim(), oldCode: isEdit ? code : null),
      content: Column(
        children: [
          RefField(controller: codeC, label: 'ادخل الرمز', textDirection: TextDirection.ltr),
          const SizedBox(height: 12),
          RefField(controller: nameC, label: 'أدخل الاسم'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: title,
      fab: RefFab(onPressed: () => _showAdd()),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchC,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 18),
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
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('خطأ: ${snap.error}'));
                }
                final items = snap.data?.items ?? [];
                final total = snap.data?.total ?? 0;
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
                          child: Text('لا توجد بيانات',
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
                      key: ValueKey(
                          '${widget.kind.name}-$q-$_page'),
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final e = items[i];
                        final num = offset + i + 1;
                        return Container(
                          margin:
                              const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.fromLTRB(
                              14, 10, 14, 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: .09),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () =>
                                        _delete(e.code, e.name),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 32,
                                          color: RefColors.red),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(e.name,
                                        textAlign:
                                            TextAlign.right,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 22,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: RefColors
                                                .nameOrange)),
                                  ),
                                ],
                              ),
                              Text('#$num',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 18)),
                              const SizedBox(height: 8),
                              RefButton(
                                  label: 'تعديل',
                                  icon: Icons.edit_outlined,
                                  onPressed: () => _showAdd(
                                      code: e.code,
                                      name: e.name)),
                            ],
                          ),
                        );
                      },
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
}
