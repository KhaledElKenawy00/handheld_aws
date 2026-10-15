import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database_helper.dart';
import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import 'op_details_screen.dart';
import 'op_kind.dart';

/// معلومات عملية — طرف/رقم/تاريخ/بواسطة/كمية/وزن/نقدي + حفظ.
class OpInfoScreen extends ConsumerStatefulWidget {
  final OpKind kind;
  final String? editId;
  const OpInfoScreen({super.key, required this.kind, this.editId});
  @override
  ConsumerState<OpInfoScreen> createState() => _OpInfoState();
}

class _OpInfoState extends ConsumerState<OpInfoScreen> {
  String? partyCode;
  String? partyName;
  List<({String code, String name})> parties = [];
  final numC = TextEditingController();
  final dateC = TextEditingController();
  final qtyC = TextEditingController();
  final byC = TextEditingController();
  bool cash = false;
  bool loading = true;

  String get partyLabel => widget.kind.partyTypes.first;

  @override
  void initState() {
    super.initState();
    dateC.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _load();
  }

  Future<List<({String code, String name})>> _fetchParties() async {
    // حد أقصى صغير للدروب داون حتى لا يهنج الجهاز — الاختيار التفصيلي
    // يتم عبر شاشات الأطراف المرقّمة (10/صفحة).
    switch (partyLabel) {
      case 'عميل':
        final r = await ref.read(customerRepoProvider).search('', limit: 50);
        return [for (final e in r) (code: e.code, name: e.desc)];
      case 'مورد':
        final r = await ref.read(supplierRepoProvider).search('', limit: 50);
        return [for (final e in r) (code: e.code, name: e.desc)];
      default:
        final r = await ref.read(warehouseRepoProvider).search('', limit: 50);
        return [for (final e in r) (code: e.code, name: e.name)];
    }
  }

  Future<int> _nextNum() async {
    // معاينة الرقم التالي (MAX+1) بدون استهلاك التسلسل.
    try {
      // ignore: invalid_use_of_protected_member
      final db = await DatabaseHelper.instance.db;
      final table = widget.kind == OpKind.delivery
          ? 'deliveries'
          : widget.kind == OpKind.receipt
              ? 'receipts'
              : 'op_headers';
      String where = '';
      List<Object> args = [];
      if (table == 'op_headers') {
        where = ' WHERE kind=?';
        args = [widget.kind.label];
      }
      final r = await db.rawQuery('SELECT COALESCE(MAX(num),0) m FROM $table$where', args);
      return ((r.first['m'] ?? 0) as num).toInt() + 1;
    } catch (_) {
      return 1;
    }
  }

  Future<void> _load() async {
    parties = await _fetchParties();
    byC.text = ref.read(currentUserProvider)?.username ?? 'admin';
    if (widget.editId != null) {
      await _loadHeader();
    } else {
      numC.text = (await _nextNum()).toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadHeader() async {
    final k = widget.kind;
    if (k == OpKind.delivery) {
      final h = await ref.read(deliveryRepoProvider).find(widget.editId!);
      if (h != null) {
        partyCode = h.customerCode;
        partyName = h.customerName;
        numC.text = h.number.toString();
        dateC.text = h.date;
        qtyC.text = _f(h.reqQty);
        cash = h.cash;
      }
    } else if (k == OpKind.receipt) {
      final h = await ref.read(receiptRepoProvider).find(widget.editId!);
      if (h != null) {
        partyCode = h.supplierCode;
        partyName = h.supplierName;
        numC.text = h.number.toString();
        dateC.text = h.date;
        qtyC.text = _f(h.reqQty);
        cash = h.cash;
      }
    } else {
      final h = await ref.read(opsRepoProvider).find(widget.editId!);
      if (h != null) {
        partyCode = h.partyCode;
        partyName = h.partyName;
        numC.text = h.number.toString();
        dateC.text = h.date;
        qtyC.text = _f(h.reqQty);
        cash = h.cash;
      }
    }
  }

  String _f(double v) => v == 0 ? '' : (v == v.truncateToDouble() ? v.toInt().toString() : v.toString());

  @override
  void dispose() {
    numC.dispose();
    dateC.dispose();
    qtyC.dispose();
    byC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (partyCode == null) {
      refError(context, 'اختر $partyLabel أولًا');
      return;
    }
    final user = ref.read(currentUserProvider)?.username ?? 'admin';
    final reqQty = double.tryParse(qtyC.text.trim()) ?? 0;
    // الكمية إجباري في الحالتين (نقدي وغير نقدي).
    if (reqQty <= 0) {
      refError(context, 'ادخل الكمية أولًا (مطلوبة)');
      return;
    }
    // الوزن لا يُدخل يدويًا — يُحسب تلقائيًا من الأصناف الممسوحة في التفاصيل.
    const reqWeight = 0.0;
    try {
      if (widget.editId != null) {
        final k = widget.kind;
        if (k == OpKind.delivery) {
          await ref.read(deliveryRepoProvider).updateHeader(
              id: widget.editId!,
              customerCode: partyCode!,
              customerName: partyName!,
              date: dateC.text.trim(),
              cash: cash,
              reqQty: reqQty,
              reqWeight: reqWeight);
        } else if (k == OpKind.receipt) {
          await ref.read(receiptRepoProvider).updateHeader(
              id: widget.editId!,
              supplierCode: partyCode!,
              supplierName: partyName!,
              date: dateC.text.trim(),
              cash: cash,
              reqQty: reqQty,
              reqWeight: reqWeight);
        } else {
          await ref.read(opsRepoProvider).updateHeader(
              id: widget.editId!,
              partyCode: partyCode!,
              partyName: partyName!,
              date: dateC.text.trim(),
              cash: cash,
              reqQty: reqQty,
              reqWeight: reqWeight);
        }
        if (mounted) {
          refToast(context, 'تم الحفظ');
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => OpDetailsScreen(
                      kind: k, headerId: widget.editId!, cash: cash)));
        }
        return;
      }
      String id;
      final k = widget.kind;
      if (k == OpKind.delivery) {
        id = await ref.read(deliveryRepoProvider).createHeader(
            customerCode: partyCode!,
            customerName: partyName!,
            date: dateC.text.trim(),
            byUser: user,
            cash: cash,
            reqQty: reqQty,
            reqWeight: reqWeight);
      } else if (k == OpKind.receipt) {
        id = await ref.read(receiptRepoProvider).createHeader(
            supplierCode: partyCode!,
            supplierName: partyName!,
            date: dateC.text.trim(),
            byUser: user,
            cash: cash,
            reqQty: reqQty,
            reqWeight: reqWeight);
      } else {
        id = await ref.read(opsRepoProvider).createHeader(
            kind: k.label,
            partyType: partyLabel,
            partyCode: partyCode!,
            partyName: partyName!,
            date: dateC.text.trim(),
            byUser: user,
            cash: cash,
            reqQty: reqQty,
            reqWeight: reqWeight);
      }
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  OpDetailsScreen(kind: k, headerId: id, cash: cash)));
    } catch (e) {
      if (mounted) refError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'معلومات عملية',
      bottomButton: RefButton(label: 'حفظ', onPressed: loading ? null : _save),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                RefDropdown<String>(
                  label: partyLabel,
                  value: partyCode,
                  items: [
                    for (final p in parties)
                      DropdownMenuItem(value: p.code, child: Text('${p.name} - ${p.code}')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    final p = parties.firstWhere((e) => e.code == v);
                    setState(() {
                      partyCode = p.code;
                      partyName = p.name;
                    });
                  },
                ),
                const SizedBox(height: 12),
                RefField(controller: numC, label: 'رقم العملية', readOnly: true),
                const SizedBox(height: 12),
                // التاريخ ثابت لا يتغير — يوم إنشاء العملية فقط.
                RefField(controller: dateC, label: 'التاريخ (ثابت — لا يتغير)', readOnly: true),
                const SizedBox(height: 12),
                RefField(controller: byC, label: 'بواسطة:', readOnly: true),
                const SizedBox(height: 12),
                RefField(
                    controller: qtyC,
                    label: 'الكمية (مطلوبة)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 14),
                RefCashRow(cash: cash, onChanged: (v) => setState(() => cash = v)),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
