import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/services/code_generator_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/app_utils.dart';
import '../../shared/models/entities.dart';

/// أذون الاستلام — حفظ Header + Items + Stock + Movements في Transaction واحدة
class ReceiptRepository {
  final _docs = DocumentNumberService();
  final _settings = SettingsService();

  Future<Database> _db() => DatabaseHelper.instance.db;

  /// save: تُستخدم من الشاشة مع DocLine list
  Future<String> save({
    required String supplierCode,
    required String supplierName,
    required String date,
    required List<DocLine> lines,
  }) async {
    if (lines.isEmpty) throw const AppFailure('أضف صنفًا واحدًا على الأقل');
    final d = await _db();
    return d.transaction((txn) async {
      final id = await _docs.nextReceiptNumber(txn: txn);
      final now = AppUtils.nowStr();
      final totalQty = lines.fold(0.0, (a, b) => a + b.quantity);
      await txn.insert('receipts', {
        'id': id,
        'supplierCode': supplierCode,
        'supplierName': supplierName,
        'date': date,
        'createdAt': now,
        'totalQty': totalQty,
        'totalItems': lines.length,
      });
      for (final l in lines) {
        if (l.quantity <= 0) {
          throw AppFailure('الكمية يجب أن تكون أكبر من صفر: ${l.productCode}');
        }
        await txn.insert('receipt_items', {
          'receiptId': id,
          'productCode': l.productCode,
          'productName': l.productName,
          'quantity': l.quantity,
        });
        final prow = await txn
            .query('products', where: 'code=?', whereArgs: [l.productCode]);
        if (prow.isEmpty) {
          throw AppFailure('الصنف غير موجود: ${l.productCode}');
        }
        final before = ((prow.first['stock'] ?? 0) as num).toDouble();
        final after = before + l.quantity;
        await txn.update('products', {'stock': after, 'updatedAt': now},
            where: 'code=?', whereArgs: [l.productCode]);
        await txn.insert('stock_movements', {
          'productCode': l.productCode,
          'type': 'RECEIPT',
          'referenceId': id,
          'quantity': l.quantity,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': now,
        });
      }
      return id;
    });
  }

  Future<List<ReceiptHeader>> list(
      {String q = '', int limit = 30, int offset = 0}) async {
    final d = await _db();
    if (q.trim().isEmpty) {
      final rows = await d.query('receipts',
          orderBy: 'date DESC, id DESC', limit: limit, offset: offset);
      return rows.map(ReceiptHeader.fromMap).toList();
    }
    final like = '%${q.trim()}%';
    final rows = await d.query('receipts',
        where: 'id LIKE ? OR supplierName LIKE ? OR supplierCode LIKE ?',
        whereArgs: [like, like, like],
        orderBy: 'date DESC, id DESC',
        limit: limit,
        offset: offset);
    return rows.map(ReceiptHeader.fromMap).toList();
  }

  Future<List<ReceiptItem>> items(String receiptId) async {
    final d = await _db();
    final rows = await d.query('receipt_items',
        where: 'receiptId=?', whereArgs: [receiptId]);
    return rows.map(ReceiptItem.fromMap).toList();
  }

  Future<ReceiptHeader?> find(String id) async {
    final d = await _db();
    final r = await d.query('receipts', where: 'id=?', whereArgs: [id]);
    if (r.isEmpty) return null;
    return ReceiptHeader.fromMap(r.first);
  }

  Future<int> count({String q = ''}) async {
    final d = await _db();
    if (q.trim().isEmpty) {
      final r = await d.rawQuery('SELECT COUNT(*) c FROM receipts');
      return (r.first['c'] as num).toInt();
    }
    final like = '%${q.trim()}%';
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM receipts WHERE id LIKE ? OR supplierName LIKE ? OR supplierCode LIKE ?',
        [like, like, like]);
    return (r.first['c'] as num).toInt();
  }

  /// حذف إذن: يعكس المخزون (إن أمكن) ثم يحذف — الرقم لا يُعاد استخدامه
  Future<void> delete(String id) async {
    final d = await _db();
    final allowNeg = await _settings.allowNegativeStock();
    await d.transaction((txn) async {
      final its = await txn
          .query('receipt_items', where: 'receiptId=?', whereArgs: [id]);
      for (final it in its) {
        final code = it['productCode'].toString();
        final qty = ((it['quantity'] ?? 0) as num).toDouble();
        final prow =
            await txn.query('products', where: 'code=?', whereArgs: [code]);
        if (prow.isEmpty) continue;
        final before = ((prow.first['stock'] ?? 0) as num).toDouble();
        final after = before - qty;
        if (after < 0 && !allowNeg) {
          throw const AppFailure(
              'لا يمكن حذف الإذن: سيصبح المخزون سالبًا. فعّل السماح بالمخزون السالب أولًا.');
        }
        final now = AppUtils.nowStr();
        await txn.update('products', {'stock': after},
            where: 'code=?', whereArgs: [code]);
        await txn.insert('stock_movements', {
          'productCode': code,
          'type': 'ADJUSTMENT',
          'referenceId': 'DELETE-$id',
          'quantity': -qty,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': now,
        });
      }
      await txn.delete('receipts', where: 'id=?', whereArgs: [id]);
    });
  }
}

/// أذون التسليم — مع منع السالب
class DeliveryRepository {
  final _docs = DocumentNumberService();
  final _settings = SettingsService();

  Future<Database> _db() => DatabaseHelper.instance.db;

  Future<String> save({
    required String customerCode,
    required String customerName,
    required String date,
    required List<DocLine> lines,
  }) async {
    if (lines.isEmpty) throw const AppFailure('أضف صنفًا واحدًا على الأقل');
    final allowNeg = await _settings.allowNegativeStock();
    final d = await _db();
    return d.transaction((txn) async {
      // تحقق مسبق من الأرصدة
      for (final l in lines) {
        if (l.quantity <= 0) {
          throw AppFailure('الكمية يجب أن تكون أكبر من صفر: ${l.productCode}');
        }
        final prow = await txn
            .query('products', where: 'code=?', whereArgs: [l.productCode]);
        if (prow.isEmpty) {
          throw AppFailure('الصنف غير موجود: ${l.productCode}');
        }
        final stock = ((prow.first['stock'] ?? 0) as num).toDouble();
        if (!allowNeg && stock < l.quantity) {
          throw AppFailure(
              'الكمية المتاحة ${AppUtils.fmtQty(stock)} فقط للصنف ${l.productCode}');
        }
      }
      final id = await _docs.nextDeliveryNumber(txn: txn);
      final now = AppUtils.nowStr();
      final totalQty = lines.fold(0.0, (a, b) => a + b.quantity);
      await txn.insert('deliveries', {
        'id': id,
        'customerCode': customerCode,
        'customerName': customerName,
        'date': date,
        'createdAt': now,
        'totalQty': totalQty,
        'totalItems': lines.length,
      });
      for (final l in lines) {
        await txn.insert('delivery_items', {
          'deliveryId': id,
          'productCode': l.productCode,
          'productName': l.productName,
          'quantity': l.quantity,
        });
        final prow = await txn
            .query('products', where: 'code=?', whereArgs: [l.productCode]);
        final before = ((prow.first['stock'] ?? 0) as num).toDouble();
        final after = before - l.quantity;
        await txn.update('products', {'stock': after, 'updatedAt': now},
            where: 'code=?', whereArgs: [l.productCode]);
        await txn.insert('stock_movements', {
          'productCode': l.productCode,
          'type': 'DELIVERY',
          'referenceId': id,
          'quantity': -l.quantity,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': now,
        });
      }
      return id;
    });
  }

  Future<List<DeliveryHeader>> list(
      {String q = '', int limit = 30, int offset = 0}) async {
    final d = await _db();
    if (q.trim().isEmpty) {
      final rows = await d.query('deliveries',
          orderBy: 'date DESC, id DESC', limit: limit, offset: offset);
      return rows.map(DeliveryHeader.fromMap).toList();
    }
    final like = '%${q.trim()}%';
    final rows = await d.query('deliveries',
        where: 'id LIKE ? OR customerName LIKE ? OR customerCode LIKE ?',
        whereArgs: [like, like, like],
        orderBy: 'date DESC, id DESC',
        limit: limit,
        offset: offset);
    return rows.map(DeliveryHeader.fromMap).toList();
  }

  Future<List<DeliveryItem>> items(String deliveryId) async {
    final d = await _db();
    final rows = await d.query('delivery_items',
        where: 'deliveryId=?', whereArgs: [deliveryId]);
    return rows.map(DeliveryItem.fromMap).toList();
  }

  Future<DeliveryHeader?> find(String id) async {
    final d = await _db();
    final r = await d.query('deliveries', where: 'id=?', whereArgs: [id]);
    if (r.isEmpty) return null;
    return DeliveryHeader.fromMap(r.first);
  }

  Future<int> count({String q = ''}) async {
    final d = await _db();
    if (q.trim().isEmpty) {
      final r = await d.rawQuery('SELECT COUNT(*) c FROM deliveries');
      return (r.first['c'] as num).toInt();
    }
    final like = '%${q.trim()}%';
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM deliveries WHERE id LIKE ? OR customerName LIKE ? OR customerCode LIKE ?',
        [like, like, like]);
    return (r.first['c'] as num).toInt();
  }

  Future<void> delete(String id) async {
    final d = await _db();
    await d.transaction((txn) async {
      final its = await txn
          .query('delivery_items', where: 'deliveryId=?', whereArgs: [id]);
      for (final it in its) {
        final code = it['productCode'].toString();
        final qty = ((it['quantity'] ?? 0) as num).toDouble();
        final prow =
            await txn.query('products', where: 'code=?', whereArgs: [code]);
        if (prow.isEmpty) continue;
        final before = ((prow.first['stock'] ?? 0) as num).toDouble();
        final after = before + qty;
        await txn.update('products', {'stock': after},
            where: 'code=?', whereArgs: [code]);
        await txn.insert('stock_movements', {
          'productCode': code,
          'type': 'ADJUSTMENT',
          'referenceId': 'DELETE-$id',
          'quantity': qty,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': AppUtils.nowStr(),
        });
      }
      await txn.delete('deliveries', where: 'id=?', whereArgs: [id]);
    });
  }
}

/// الجرد
class InventoryRepository {
  final _docs = DocumentNumberService();
  Future<Database> _db() => DatabaseHelper.instance.db;

  Future<String> createSession(
      {required String date, List<Map<String, Object>>? expected}) async {
    final d = await _db();
    return d.transaction((txn) async {
      final id = await _docs.nextInventoryNumber(txn: txn);
      final now = AppUtils.nowStr();
      await txn.insert('inventory_sessions',
          {'id': id, 'date': date, 'createdAt': now, 'status': 'open'});
      if (expected != null) {
        for (final e in expected) {
          await txn.insert(
              'inventory_items',
              {
                'sessionId': id,
                'productCode': e['code'].toString(),
                'productName': (e['desc'] ?? e['code']).toString(),
                'expectedQty': (e['qty'] as num).toDouble(),
                'actualQty': 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      return id;
    });
  }

  /// مسح صنف داخل الجرد: يزيد Actual + يسجل/ينشئ السطر
  Future<void> scanOrAdd(String sessionId, String productCode,
      {double qty = 1}) async {
    final d = await _db();
    await d.transaction((txn) async {
      final prow = await txn
          .query('products', where: 'code=?', whereArgs: [productCode]);
      if (prow.isEmpty) {
        throw AppFailure('الصنف غير موجود: $productCode');
      }
      final name = (prow.first['description'] ?? productCode).toString();
      final stock = ((prow.first['stock'] ?? 0) as num).toDouble();
      final ex = await txn.query('inventory_items',
          where: 'sessionId=? AND productCode=?',
          whereArgs: [sessionId, productCode]);
      if (ex.isEmpty) {
        await txn.insert('inventory_items', {
          'sessionId': sessionId,
          'productCode': productCode,
          'productName': name,
          'expectedQty': stock,
          'actualQty': qty,
        });
      } else {
        final cur =
            ((ex.first['actualQty'] ?? 0) as num).toDouble() + qty;
        await txn.update('inventory_items', {'actualQty': cur},
            where: 'sessionId=? AND productCode=?',
            whereArgs: [sessionId, productCode]);
      }
    });
  }

  Future<void> setActual(
      String sessionId, String productCode, double actual) async {
    final d = await _db();
    await d.update('inventory_items', {'actualQty': actual},
        where: 'sessionId=? AND productCode=?',
        whereArgs: [sessionId, productCode]);
  }

  Future<void> close(String sessionId) async {
    final d = await _db();
    await d.update('inventory_sessions', {'status': 'closed'},
        where: 'id=?', whereArgs: [sessionId]);
  }

  Future<List<InventorySession>> list(
      {String q = '', int limit = 30, int offset = 0}) async {
    final d = await _db();
    if (q.trim().isEmpty) {
      final rows = await d.query('inventory_sessions',
          orderBy: 'date DESC, id DESC', limit: limit, offset: offset);
      return rows.map(InventorySession.fromMap).toList();
    }
    final like = '%${q.trim()}%';
    final rows = await d.query('inventory_sessions',
        where: 'id LIKE ? OR date LIKE ? OR status LIKE ?',
        whereArgs: [like, like, like],
        orderBy: 'date DESC, id DESC',
        limit: limit,
        offset: offset);
    return rows.map(InventorySession.fromMap).toList();
  }

  /// بنود جلسة جرد — البحث والفلترة على مستوى SQL قبل LIMIT/OFFSET
  /// فلتر الفرق: shortage (فعلي < متوقع) | excess (فعلي > متوقع) | matched (متساوي)
  Future<List<InventoryItem>> items(String sessionId,
      {String q = '',
      String filter = 'all',
      int limit = 30,
      int offset = 0}) async {
    final d = await _db();
    final conds = <String>['sessionId=?'];
    final args = <Object>[sessionId];
    final qq = q.trim();
    if (qq.isNotEmpty) {
      conds.add('(productCode LIKE ? OR productName LIKE ?)');
      final like = '%$qq%';
      args.addAll([like, like]);
    }
    if (filter == 'shortage') {
      conds.add('actualQty < expectedQty');
    } else if (filter == 'excess') {
      conds.add('actualQty > expectedQty');
    } else if (filter == 'matched') {
      conds.add('actualQty = expectedQty');
    }
    final rows = await d.query('inventory_items',
        where: conds.join(' AND '),
        whereArgs: args,
        orderBy: 'productCode ASC',
        limit: limit,
        offset: offset);
    return rows.map(InventoryItem.fromMap).toList();
  }

  /// عدد البنود المطابقة لنفس شروط items — يغذّي شريط الصفحات
  Future<int> itemsCount(String sessionId,
      {String q = '', String filter = 'all'}) async {
    final d = await _db();
    final conds = <String>['sessionId=?'];
    final args = <Object>[sessionId];
    final qq = q.trim();
    if (qq.isNotEmpty) {
      conds.add('(productCode LIKE ? OR productName LIKE ?)');
      final like = '%$qq%';
      args.addAll([like, like]);
    }
    if (filter == 'shortage') {
      conds.add('actualQty < expectedQty');
    } else if (filter == 'excess') {
      conds.add('actualQty > expectedQty');
    } else if (filter == 'matched') {
      conds.add('actualQty = expectedQty');
    }
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM inventory_items WHERE ${conds.join(' AND ')}',
        args);
    return (r.first['c'] as num).toInt();
  }

  /// إحصائيات الجلسة (كل البنود — بدون بحث/فلتر) باستعلام واحد
  Future<Map<String, int>> itemsStats(String sessionId) async {
    final d = await _db();
    final r = await d.rawQuery(
        'SELECT COUNT(*) total, '
        'COALESCE(SUM(CASE WHEN actualQty < expectedQty THEN 1 ELSE 0 END),0) shortage, '
        'COALESCE(SUM(CASE WHEN actualQty > expectedQty THEN 1 ELSE 0 END),0) excess, '
        'COALESCE(SUM(CASE WHEN actualQty = expectedQty THEN 1 ELSE 0 END),0) matched '
        'FROM inventory_items WHERE sessionId=?',
        [sessionId]);
    return {
      'total': (r.first['total'] as num).toInt(),
      'shortage': (r.first['shortage'] as num).toInt(),
      'excess': (r.first['excess'] as num).toInt(),
      'matched': (r.first['matched'] as num).toInt(),
    };
  }

  Future<InventorySession?> find(String id) async {
    final d = await _db();
    final r =
        await d.query('inventory_sessions', where: 'id=?', whereArgs: [id]);
    if (r.isEmpty) return null;
    return InventorySession.fromMap(r.first);
  }

  Future<int> count({String q = ''}) async {
    final d = await _db();
    if (q.trim().isEmpty) {
      final r =
          await d.rawQuery('SELECT COUNT(*) c FROM inventory_sessions');
      return (r.first['c'] as num).toInt();
    }
    final like = '%${q.trim()}%';
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM inventory_sessions WHERE id LIKE ? OR date LIKE ? OR status LIKE ?',
        [like, like, like]);
    return (r.first['c'] as num).toInt();
  }
}
