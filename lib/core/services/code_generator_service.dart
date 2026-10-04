import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/app_utils.dart';
import '../constants/app_constants.dart';

/// مولد مركزي للأكواد وأرقام المستندات — لا يعيد استخدام القديم أبدًا.
/// يعتمد على جدول sequences (lastNumber فقط يزيد).
class DocumentNumberService {
  final Database Function()? dbGetter;
  DocumentNumberService({this.dbGetter});

  Future<Database> _db() async =>
      dbGetter != null ? dbGetter!() : DatabaseHelper.instance.db;

  Future<int> _nextSeq(DatabaseExecutor txn, String key) async {
    final rows = await txn.query('sequences',
        where: 'key = ?', whereArgs: [key]);
    final cur = rows.isEmpty ? 0 : ((rows.first['lastNumber'] as num).toInt());
    final nxt = cur + 1;
    if (rows.isEmpty) {
      await txn.insert('sequences', {'key': key, 'lastNumber': nxt});
    } else {
      await txn.update('sequences', {'lastNumber': nxt},
          where: 'key = ?', whereArgs: [key]);
    }
    return nxt;
  }

  Future<String> nextReceiptNumber({DatabaseExecutor? txn}) async {
    if (txn != null) {
      final n = await _nextSeq(txn, AppConstants.seqReceipt);
      final y = DateTime.now().year;
      return '${AppConstants.recPrefix}-$y-${n.toString().padLeft(6, '0')}';
    }
    final d = await _db();
    return d.transaction((t) async {
      final n = await _nextSeq(t, AppConstants.seqReceipt);
      final y = DateTime.now().year;
      return '${AppConstants.recPrefix}-$y-${n.toString().padLeft(6, '0')}';
    });
  }

  Future<String> nextDeliveryNumber({DatabaseExecutor? txn}) async {
    if (txn != null) {
      final n = await _nextSeq(txn, AppConstants.seqDelivery);
      final y = DateTime.now().year;
      return '${AppConstants.delPrefix}-$y-${n.toString().padLeft(6, '0')}';
    }
    final d = await _db();
    return d.transaction((t) async {
      final n = await _nextSeq(t, AppConstants.seqDelivery);
      final y = DateTime.now().year;
      return '${AppConstants.delPrefix}-$y-${n.toString().padLeft(6, '0')}';
    });
  }

  Future<String> nextInventoryNumber({DatabaseExecutor? txn}) async {
    if (txn != null) {
      final n = await _nextSeq(txn, AppConstants.seqInventory);
      final y = DateTime.now().year;
      return '${AppConstants.invPrefix}-$y-${n.toString().padLeft(6, '0')}';
    }
    final d = await _db();
    return d.transaction((t) async {
      final n = await _nextSeq(t, AppConstants.seqInventory);
      final y = DateTime.now().year;
      return '${AppConstants.invPrefix}-$y-${n.toString().padLeft(6, '0')}';
    });
  }

  /// SUP-000001 — يتحقق من عدم وجوده فعليًا قبل الاعتماد.
  Future<String> nextSupplierCode() async {
    final d = await _db();
    return d.transaction((t) async {
      int n = await _nextSeq(t, AppConstants.seqSupplier);
      String code() =>
          '${AppConstants.supPrefix}-${n.toString().padLeft(6, '0')}';
      while ((await t.query('suppliers',
              where: 'code = ?', whereArgs: [code()]))
          .isNotEmpty) {
        n = await _nextSeq(t, AppConstants.seqSupplier);
      }
      return code();
    });
  }

  Future<String> nextCustomerCode() async {
    final d = await _db();
    return d.transaction((t) async {
      int n = await _nextSeq(t, AppConstants.seqCustomer);
      String code() =>
          '${AppConstants.cusPrefix}-${n.toString().padLeft(6, '0')}';
      while ((await t.query('customers',
              where: 'code = ?', whereArgs: [code()]))
          .isNotEmpty) {
        n = await _nextSeq(t, AppConstants.seqCustomer);
      }
      return code();
    });
  }

  /// فحص عام لعدم التكرار
  Future<void> assertUnique(
      String table, String code, String labelAr) async {
    final d = await _db();
    final r = await d.query(table, where: 'code = ?', whereArgs: [code.trim()]);
    if (r.isNotEmpty) throw AppFailure('$labelAr موجود بالفعل: $code');
  }
}
