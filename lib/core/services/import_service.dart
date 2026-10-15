import 'dart:io';

import 'package:excel/excel.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/ops/ops_repository.dart';
import '../../features/receipts/voucher_repositories.dart';
import '../../shared/models/entities.dart';
import '../database/database_helper.dart';
import '../utils/app_utils.dart';

/// استيراد Excel للأصناف/الموردين/العملاء + جرد — مع Preview وValidation كامل
class ImportService {
  Future<Database> _db() => DatabaseHelper.instance.db;

  /// قراءة ملف Excel وإرجاع الصفوف كخرائط (أول صف = عناوين)
  Future<List<Map<String, String>>> readRows(File file,
      {List<String>? expectedHeaders}) async {
    final bytes = await file.readAsBytes();
    final xls = Excel.decodeBytes(bytes);
    if (xls.tables.isEmpty) throw const AppFailure('ملف Excel فارغ');
    final table = xls.tables.values.first;
    if (table.rows.isEmpty) throw const AppFailure('ملف Excel بدون صفوف');
    final headers = table.rows.first
        .map((c) => (c?.value?.toString() ?? '').trim().toLowerCase())
        .toList();
    if (expectedHeaders != null) {
      for (final h in expectedHeaders) {
        if (!headers.contains(h)) {
          throw AppFailure('العمود مطلوب وغير موجود: $h');
        }
      }
    }
    final out = <Map<String, String>>[];
    for (var i = 1; i < table.rows.length; i++) {
      final row = table.rows[i];
      if (row.every((c) =>
          c?.value == null || c!.value.toString().trim().isEmpty)) {
        continue;
      }
      final m = <String, String>{};
      for (var j = 0; j < headers.length && j < row.length; j++) {
        m[headers[j]] = (row[j]?.value?.toString() ?? '').trim();
      }
      m['_row'] = (i + 1).toString();
      out.add(m);
    }
    return out;
  }

  /// استيراد أصناف: code | desc
  Future<ImportSummary> importProducts(File file) async {
    final rows = await readRows(file, expectedHeaders: ['code', 'desc']);
    final d = await _db();
    int imported = 0, updated = 0, skipped = 0;
    final errors = <String>[];
    final seen = <String>{};
    await d.transaction((txn) async {
      for (final r in rows) {
        final rowNo = r['_row'] ?? '?';
        final code = (r['code'] ?? '').trim();
        final desc = (r['desc'] ?? '').trim();
        if (code.isEmpty || desc.isEmpty) {
          skipped++;
          errors.add('صف $rowNo: كود أو اسم فارغ — تم التخطي');
          continue;
        }
        if (!seen.add(code)) {
          skipped++;
          errors.add('صف $rowNo: كود مكرر داخل الملف: $code');
          continue;
        }
        final ex = await txn
            .query('products', where: 'code=?', whereArgs: [code]);
        final now = AppUtils.nowStr();
        if (ex.isEmpty) {
          await txn.insert('products', {
            'code': code,
            'description': desc,
            'stock': 0,
            'isActive': 1,
            'createdAt': now,
            'updatedAt': now,
          });
          imported++;
        } else {
          await txn.update('products', {'description': desc, 'updatedAt': now},
              where: 'code=?', whereArgs: [code]);
          updated++;
        }
      }
    });
    return ImportSummary(
        imported: imported,
        updated: updated,
        skipped: skipped,
        total: rows.length,
        errors: errors);
  }

  Future<ImportSummary> importSuppliers(File file) =>
      _importPartners(file, 'suppliers', 'المورد');

  Future<ImportSummary> importCustomers(File file) =>
      _importPartners(file, 'customers', 'العميل');

  Future<ImportSummary> _importPartners(
      File file, String table, String label) async {
    final rows = await readRows(file, expectedHeaders: ['code', 'desc']);
    final d = await _db();
    int imported = 0, updated = 0, skipped = 0;
    final errors = <String>[];
    final seen = <String>{};
    await d.transaction((txn) async {
      for (final r in rows) {
        final rowNo = r['_row'] ?? '?';
        final code = (r['code'] ?? '').trim();
        final desc = (r['desc'] ?? '').trim();
        if (code.isEmpty || desc.isEmpty) {
          skipped++;
          errors.add('صف $rowNo: كود أو اسم $label فارغ');
          continue;
        }
        if (!seen.add(code)) {
          skipped++;
          errors.add('صف $rowNo: كود مكرر: $code');
          continue;
        }
        final ex =
            await txn.query(table, where: 'code=?', whereArgs: [code]);
        if (ex.isEmpty) {
          await txn.insert(table, {
            'code': code,
            'description': desc,
            'isActive': 1,
            'createdAt': AppUtils.nowStr(),
          });
          imported++;
        } else {
          await txn.update(table, {'description': desc},
              where: 'code=?', whereArgs: [code]);
          updated++;
        }
      }
    });
    return ImportSummary(
        imported: imported,
        updated: updated,
        skipped: skipped,
        total: rows.length,
        errors: errors);
  }

  /// صفوف الجرد المتوقع: code | desc | qty
  Future<List<Map<String, Object>>> readInventoryExpected(File file) async {
    final rows =
        await readRows(file, expectedHeaders: ['code', 'desc', 'qty']);
    final out = <Map<String, Object>>[];
    for (final r in rows) {
      final code = (r['code'] ?? '').trim();
      if (code.isEmpty) continue;
      final qty = double.tryParse((r['qty'] ?? '0').trim()) ?? 0;
      out.add({
        'code': code,
        'desc': (r['desc'] ?? '').trim(),
        'qty': qty,
      });
    }
    return out;
  }

  // ── استيراد الأذون من شيت Excel ──
  // الأعمدة المطلوبة: party | date | product | qty
  // الاختيارية: voucher (رقم الإذن للتجميع) | weight | price
  // الصفوف بنفس رقم الإذن (أو نفس الطرف+التاريخ) = إذن واحد.

  /// تطبيع التاريخ: يقبل dd/MM/yyyy كما هو، ويحوّل صيغ Excel/ISO
  /// (yyyy-MM-dd[ HH:mm...]) إلى dd/MM/yyyy مثل باقي التطبيق.
  String _normDate(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return v;
    if (RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}$').hasMatch(v)) return v;
    final dt = DateTime.tryParse(v);
    if (dt != null) {
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      return '$dd/$mm/${dt.year}';
    }
    return v;
  }

  /// تجميع صفوف الأذون مع التحقق (طرف + صنف + كمية).
  /// يُرجع المجموعات بالترتيب + عدد المتخطى + الأخطاء.
  Future<({List<_VoucherGroup> groups, int skipped, List<String> errors})>
      _groupVoucherRows(
    File file,
    String partyTable,
    String partyLabel,
  ) async {
    final rows = await readRows(file,
        expectedHeaders: ['party', 'date', 'product', 'qty']);
    final d = await _db();
    final groups = <String, _VoucherGroup>{};
    final order = <String>[];
    var skipped = 0;
    final errors = <String>[];
    for (final r in rows) {
      final rowNo = r['_row'] ?? '?';
      final party = (r['party'] ?? '').trim();
      final date = _normDate(r['date'] ?? '');
      final product = (r['product'] ?? '').trim();
      final qty = double.tryParse((r['qty'] ?? '').trim()) ?? 0;
      final voucher = (r['voucher'] ?? '').trim();
      if (party.isEmpty || date.isEmpty || product.isEmpty) {
        skipped++;
        errors.add('صف $rowNo: الطرف أو التاريخ أو الصنف فارغ — تم التخطي');
        continue;
      }
      if (qty <= 0) {
        skipped++;
        errors.add('صف $rowNo: الكمية يجب أن تكون أكبر من صفر');
        continue;
      }
      final pRows =
          await d.query(partyTable, where: 'code=?', whereArgs: [party]);
      if (pRows.isEmpty) {
        skipped++;
        errors.add('صف $rowNo: $partyLabel غير موجود: $party');
        continue;
      }
      final prodRows =
          await d.query('products', where: 'code=?', whereArgs: [product]);
      if (prodRows.isEmpty) {
        skipped++;
        errors.add('صف $rowNo: الصنف غير موجود: $product');
        continue;
      }
      final partyName = (pRows.first['description'] ??
              pRows.first['name'] ??
              party)
          .toString();
      final productName =
          (prodRows.first['description'] ?? product).toString();
      final weight = double.tryParse((r['weight'] ?? '').trim()) ?? 0;
      final price = double.tryParse((r['price'] ?? '').trim()) ?? 0;
      final key =
          voucher.isNotEmpty ? 'V:$voucher' : 'P:$party|$date';
      var g = groups[key];
      if (g == null) {
        g = _VoucherGroup(party: party, partyName: partyName, date: date);
        groups[key] = g;
        order.add(key);
      }
      g.lines.add(_VoucherLine(
          product: product,
          productName: productName,
          qty: qty,
          weight: weight,
          price: price));
    }
    return (
      groups: [for (final k in order) groups[k]!],
      skipped: skipped,
      errors: errors
    );
  }

  /// استيراد أذون استلام (مشتريات موردين).
  Future<ImportSummary> importReceipts(File file,
      {String byUser = 'استيراد'}) async {
    final g =
        await _groupVoucherRows(file, 'suppliers', 'المورد');
    final repo = ReceiptRepository();
    var vouchers = 0;
    var lines = 0;
    final errors = <String>[...g.errors];
    for (final grp in g.groups) {
      try {
        final id = await repo.createHeader(
          supplierCode: grp.party,
          supplierName: grp.partyName,
          date: grp.date,
          byUser: byUser,
        );
        for (final l in grp.lines) {
          try {
            await repo.addItem(
                id,
                DocLine(
                    productCode: l.product,
                    productName: l.productName,
                    quantity: l.qty,
                    weight: l.weight,
                    price: l.price));
            lines++;
          } catch (e) {
            errors.add('إذن ${grp.party} ${grp.date}: $e');
          }
        }
        vouchers++;
      } catch (e) {
        errors.add('إذن ${grp.party} ${grp.date}: $e');
      }
    }
    final total = g.groups.fold(0, (a, e) => a + e.lines.length) + g.skipped;
    return ImportSummary(
        imported: vouchers,
        updated: lines,
        skipped: g.skipped,
        total: total,
        errors: errors);
  }

  /// استيراد أذون تسليم (مبيعات عملاء).
  Future<ImportSummary> importDeliveries(File file,
      {String byUser = 'استيراد'}) async {
    final g =
        await _groupVoucherRows(file, 'customers', 'العميل');
    final repo = DeliveryRepository();
    var vouchers = 0;
    var lines = 0;
    final errors = <String>[...g.errors];
    for (final grp in g.groups) {
      try {
        final id = await repo.createHeader(
          customerCode: grp.party,
          customerName: grp.partyName,
          date: grp.date,
          byUser: byUser,
        );
        for (final l in grp.lines) {
          try {
            await repo.addItem(
                id,
                DocLine(
                    productCode: l.product,
                    productName: l.productName,
                    quantity: l.qty,
                    weight: l.weight,
                    price: l.price));
            lines++;
          } catch (e) {
            errors.add('إذن ${grp.party} ${grp.date}: $e');
          }
        }
        vouchers++;
      } catch (e) {
        errors.add('إذن ${grp.party} ${grp.date}: $e');
      }
    }
    final total = g.groups.fold(0, (a, e) => a + e.lines.length) + g.skipped;
    return ImportSummary(
        imported: vouchers,
        updated: lines,
        skipped: g.skipped,
        total: total,
        errors: errors);
  }

  /// استيراد مرتجعات: [kind] = 'مرتجع عميل' (الطرف عميل) أو
  /// 'مرتجع مورد' (الطرف مورد).
  Future<ImportSummary> importReturns(File file, String kind,
      {String byUser = 'استيراد'}) async {
    final isCust = kind == 'مرتجع عميل';
    final g = await _groupVoucherRows(
        file, isCust ? 'customers' : 'suppliers', isCust ? 'العميل' : 'المورد');
    final repo = OpsRepo();
    var vouchers = 0;
    var lines = 0;
    final errors = <String>[...g.errors];
    for (final grp in g.groups) {
      try {
        await repo.save(
          kind: kind,
          partyType: isCust ? 'عميل' : 'مورد',
          partyCode: grp.party,
          partyName: grp.partyName,
          date: grp.date,
          byUser: byUser,
          cash: false,
          lines: [
            for (final l in grp.lines)
              DocLine(
                  productCode: l.product,
                  productName: l.productName,
                  quantity: l.qty,
                  weight: l.weight,
                  price: l.price),
          ],
        );
        vouchers++;
        lines += grp.lines.length;
      } catch (e) {
        errors.add('إذن ${grp.party} ${grp.date}: $e');
      }
    }
    final total = g.groups.fold(0, (a, e) => a + e.lines.length) + g.skipped;
    return ImportSummary(
        imported: vouchers,
        updated: lines,
        skipped: g.skipped,
        total: total,
        errors: errors);
  }
}

/// مجموعة صفوف إذن واحد أثناء الاستيراد.
class _VoucherGroup {
  final String party;
  final String partyName;
  final String date;
  final List<_VoucherLine> lines = [];
  _VoucherGroup(
      {required this.party, required this.partyName, required this.date});
}

class _VoucherLine {
  final String product;
  final String productName;
  final double qty;
  final double weight;
  final double price;
  _VoucherLine(
      {required this.product,
      required this.productName,
      required this.qty,
      required this.weight,
      required this.price});
}
