import 'dart:io';

import 'package:excel/excel.dart';
import 'package:sqflite/sqflite.dart';

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
}
