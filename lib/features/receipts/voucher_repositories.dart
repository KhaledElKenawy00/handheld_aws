import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/services/barcode_resolver.dart';
import '../../core/services/code_generator_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/app_utils.dart';
import '../../shared/models/entities.dart';

/// ترقيم #N متسلسل لكل جدول عمليات (مثل الصور: #1).
Future<int> nextOpNum(DatabaseExecutor txn, String table) async {
  final key = 'num_$table';
  final rows =
      await txn.query('sequences', where: 'key=?', whereArgs: [key]);
  var cur = 0;
  if (rows.isEmpty) {
    final r = await txn.rawQuery('SELECT COALESCE(MAX(num),0) m FROM $table');
    cur = ((r.first['m'] ?? 0) as num).toInt();
  } else {
    cur = ((rows.first['lastNumber'] ?? 0) as num).toInt();
  }
  final nxt = cur + 1;
  if (rows.isEmpty) {
    await txn.insert('sequences', {'key': key, 'lastNumber': nxt});
  } else {
    await txn.update('sequences', {'lastNumber': nxt},
        where: 'key=?', whereArgs: [key]);
  }
  return nxt;
}

Future<int> _nextNum(DatabaseExecutor txn, String table) =>
    nextOpNum(txn, table);

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
    bool cash = false,
    String byUser = '',
    double reqQty = 0,
    double reqWeight = 0,
  }) async {
    if (lines.isEmpty) throw const AppFailure('أضف صنفًا واحدًا على الأقل');
    final d = await _db();
    return d.transaction((txn) async {
      final id = await _docs.nextReceiptNumber(txn: txn);
      final opNum = await _nextNum(txn, 'receipts');
      final now = AppUtils.nowStr();
      final totalQty = lines.fold(0.0, (a, b) => a + b.quantity);
      final totalWeight = lines.fold(0.0, (a, b) => a + b.weight);
      final totalPrice =
          lines.fold(0.0, (a, b) => a + b.quantity * b.price);
      await txn.insert('receipts', {
        'id': id,
        'supplierCode': supplierCode,
        'supplierName': supplierName,
        'date': date,
        'createdAt': now,
        'totalQty': totalQty,
        'totalItems': lines.length,
        'totalWeight': totalWeight,
        'totalPrice': totalPrice,
        'cash': cash ? 1 : 0,
        'byUser': byUser,
        'num': opNum,
        'reqQty': reqQty,
        'reqWeight': reqWeight,
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
          'weight': l.weight,
          'price': l.price,
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

  /// ترويسة أولًا (معلومات عملية) ثم أصناف من التفاصيل.
  Future<String> createHeader({
    required String supplierCode,
    required String supplierName,
    required String date,
    String byUser = '',
    bool cash = false,
    double reqQty = 0,
    double reqWeight = 0,
  }) async {
    final d = await _db();
    return d.transaction((txn) async {
      final id = await _docs.nextReceiptNumber(txn: txn);
      final opNum = await _nextNum(txn, 'receipts');
      await txn.insert('receipts', {
        'id': id,
        'supplierCode': supplierCode,
        'supplierName': supplierName,
        'date': date,
        'createdAt': AppUtils.nowStr(),
        'totalQty': 0,
        'totalItems': 0,
        'totalWeight': 0,
        'totalPrice': 0,
        'cash': cash ? 1 : 0,
        'byUser': byUser,
        'num': opNum,
        'reqQty': reqQty,
        'reqWeight': reqWeight,
      });
      return id;
    });
  }

  Future<void> updateHeader({
    required String id,
    required String supplierCode,
    required String supplierName,
    required String date,
    required bool cash,
    required double reqQty,
    required double reqWeight,
  }) async {
    final d = await _db();
    await d.update(
        'receipts',
        {
          'supplierCode': supplierCode,
          'supplierName': supplierName,
          'date': date,
          'cash': cash ? 1 : 0,
          'reqQty': reqQty,
          'reqWeight': reqWeight,
        },
        where: 'id=?',
        whereArgs: [id]);
  }

  /// إضافة صنف من التفاصيل مع تحديث المخزون والإجماليات (بدون التقيد بالرصيد).
  /// كل مسحة سطر مستقل بوزنها (للحفاظ على تفصيلة الأوزان المتغيرة) —
  /// الدمج للعرض فقط في الجدول (صف واحد لكل صنف)، والتعديل يعرض كل مسحة في صف.
  Future<void> addItem(String receiptId, DocLine l) async {
    if (l.quantity <= 0) throw AppFailure('الكمية يجب أن تكون أكبر من صفر: ${l.productCode}');
    final d = await _db();
    await d.transaction((txn) async {
      await txn.insert('receipt_items', {
        'receiptId': receiptId,
        'productCode': l.productCode,
        'productName': l.productName,
        'quantity': l.quantity,
        'weight': l.weight,
        'price': l.price,
      });
      final prow = await txn.query('products', where: 'code=?', whereArgs: [l.productCode]);
      if (prow.isEmpty) throw AppFailure('الصنف غير موجود: ${l.productCode}');
      final before = ((prow.first['stock'] ?? 0) as num).toDouble();
      final after = before + l.quantity;
      final now = AppUtils.nowStr();
      await txn.update('products', {'stock': after, 'updatedAt': now},
          where: 'code=?', whereArgs: [l.productCode]);
      await txn.insert('stock_movements', {
        'productCode': l.productCode,
        'type': 'RECEIPT',
        'referenceId': receiptId,
        'quantity': l.quantity,
        'beforeQty': before,
        'afterQty': after,
        'createdAt': now,
      });
      final h = await txn.query('receipts', where: 'id=?', whereArgs: [receiptId]);
      if (h.isNotEmpty) {
        final m = h.first;
        await txn.update(
            'receipts',
            {
              'totalQty': ((m['totalQty'] ?? 0) as num).toDouble() + l.quantity,
              'totalWeight': ((m['totalWeight'] ?? 0) as num).toDouble() + l.weight,
              'totalPrice': ((m['totalPrice'] ?? 0) as num).toDouble() + l.quantity * l.price,
              'totalItems': ((m['totalItems'] ?? 0) as num).toInt() + 1,
            },
            where: 'id=?',
            whereArgs: [receiptId]);
      }
    });
  }

  /// حذف سطر واحد (مسحة) مع عكس أثره المخزني وتحديث الإجماليات.
  Future<void> deleteItem(String receiptId, int itemId) async {
    final allowNeg = await _settings.allowNegativeStock();
    final d = await _db();
    await d.transaction((txn) async {
      final h =
          await txn.query('receipts', where: 'id=?', whereArgs: [receiptId]);
      if (h.isEmpty) throw const AppFailure('الإذن غير موجود');
      final its = await txn.query('receipt_items',
          where: 'id=? AND receiptId=?', whereArgs: [itemId, receiptId]);
      if (its.isEmpty) throw const AppFailure('السطر غير موجود');
      final it = its.first;
      final code = it['productCode'].toString();
      final qty = ((it['quantity'] ?? 0) as num).toDouble();
      final w = ((it['weight'] ?? 0) as num).toDouble();
      final pr = ((it['price'] ?? 0) as num).toDouble();
      final prow =
          await txn.query('products', where: 'code=?', whereArgs: [code]);
      if (prow.isNotEmpty) {
        final before = ((prow.first['stock'] ?? 0) as num).toDouble();
        final after = before - qty;
        if (after < 0 && !allowNeg) {
          throw const AppFailure('لا يمكن حذف السطر: سيصبح المخزون سالبًا.');
        }
        final now = AppUtils.nowStr();
        await txn.update('products', {'stock': after, 'updatedAt': now},
            where: 'code=?', whereArgs: [code]);
        await txn.insert('stock_movements', {
          'productCode': code,
          'type': 'ADJUSTMENT',
          'referenceId': 'DEL-ITEM-$itemId',
          'quantity': -qty,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': now,
        });
      }
      await txn.delete('receipt_items', where: 'id=?', whereArgs: [itemId]);
      final m = h.first;
      await txn.update(
          'receipts',
          {
            'totalQty': ((m['totalQty'] ?? 0) as num).toDouble() - qty,
            'totalWeight': ((m['totalWeight'] ?? 0) as num).toDouble() - w,
            'totalPrice':
                ((m['totalPrice'] ?? 0) as num).toDouble() - qty * pr,
            'totalItems': ((m['totalItems'] ?? 0) as num).toInt() - 1,
          },
          where: 'id=?',
          whereArgs: [receiptId]);
    });
  }

  /// تعديل سطر (كمية/وزن/سعر) مع ضبط المخزون بالفرق وتحديث الإجماليات.
  Future<void> updateItem(String receiptId, int itemId,
      {required double quantity,
      required double weight,
      required double price}) async {
    if (quantity <= 0) {
      throw const AppFailure('الكمية يجب أن تكون أكبر من صفر');
    }
    final allowNeg = await _settings.allowNegativeStock();
    final d = await _db();
    await d.transaction((txn) async {
      final h =
          await txn.query('receipts', where: 'id=?', whereArgs: [receiptId]);
      if (h.isEmpty) throw const AppFailure('الإذن غير موجود');
      final its = await txn.query('receipt_items',
          where: 'id=? AND receiptId=?', whereArgs: [itemId, receiptId]);
      if (its.isEmpty) throw const AppFailure('السطر غير موجود');
      final it = its.first;
      final code = it['productCode'].toString();
      final oldQty = ((it['quantity'] ?? 0) as num).toDouble();
      final oldW = ((it['weight'] ?? 0) as num).toDouble();
      final oldPr = ((it['price'] ?? 0) as num).toDouble();
      final dQty = quantity - oldQty;
      final prow =
          await txn.query('products', where: 'code=?', whereArgs: [code]);
      if (prow.isNotEmpty && dQty != 0) {
        final before = ((prow.first['stock'] ?? 0) as num).toDouble();
        final after = before + dQty;
        if (after < 0 && !allowNeg) {
          throw const AppFailure('لا يمكن التعديل: سيصبح المخزون سالبًا.');
        }
        final now = AppUtils.nowStr();
        await txn.update('products', {'stock': after, 'updatedAt': now},
            where: 'code=?', whereArgs: [code]);
        await txn.insert('stock_movements', {
          'productCode': code,
          'type': 'ADJUSTMENT',
          'referenceId': 'EDIT-ITEM-$itemId',
          'quantity': dQty,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': now,
        });
      }
      await txn.update(
          'receipt_items',
          {'quantity': quantity, 'weight': weight, 'price': price},
          where: 'id=?',
          whereArgs: [itemId]);
      final m = h.first;
      await txn.update(
          'receipts',
          {
            'totalQty': ((m['totalQty'] ?? 0) as num).toDouble() + dQty,
            'totalWeight':
                ((m['totalWeight'] ?? 0) as num).toDouble() + (weight - oldW),
            'totalPrice': ((m['totalPrice'] ?? 0) as num).toDouble() +
                (quantity * price - oldQty * oldPr),
          },
          where: 'id=?',
          whereArgs: [receiptId]);
    });
  }

  Future<List<ReceiptHeader>> list(
      {String q = '', int limit = 10, int offset = 0}) async {
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

  /// مسح كل أذون الاستلام وبنودها (للأرشفة) — بدون عكس المخزون
  /// (البضاعة دخلت فعلًا والرصيد سليم) وبدون مساس بالأصناف/العملاء.
  /// يُرجع عدد الأذون المحذوفة.
  Future<int> deleteAllVouchers() async {
    final d = await _db();
    return d.transaction((txn) async {
      final h =
          await txn.rawQuery('SELECT COUNT(*) c FROM receipts');
      final count = (h.first['c'] as num).toInt();
      await txn.delete('receipt_items');
      await txn.delete('receipts');
      return count;
    });
  }
}

/// أذون التسليم — مع منع السالب
class DeliveryRepository {
  final _docs = DocumentNumberService();

  Future<Database> _db() => DatabaseHelper.instance.db;

  Future<String> save({
    required String customerCode,
    required String customerName,
    required String date,
    required List<DocLine> lines,
    bool cash = false,
    String byUser = '',
    double reqQty = 0,
    double reqWeight = 0,
  }) async {
    if (lines.isEmpty) throw const AppFailure('أضف صنفًا واحدًا على الأقل');
    final d = await _db();
    return d.transaction((txn) async {
      // تحقق من وجود الأصناف فقط — بدون التقيد برصيد المخزون.
      for (final l in lines) {
        if (l.quantity <= 0) {
          throw AppFailure('الكمية يجب أن تكون أكبر من صفر: ${l.productCode}');
        }
        final prow = await txn
            .query('products', where: 'code=?', whereArgs: [l.productCode]);
        if (prow.isEmpty) {
          throw AppFailure('الصنف غير موجود: ${l.productCode}');
        }
      }
      final id = await _docs.nextDeliveryNumber(txn: txn);
      final opNum = await _nextNum(txn, 'deliveries');
      final now = AppUtils.nowStr();
      final totalQty = lines.fold(0.0, (a, b) => a + b.quantity);
      final totalWeight = lines.fold(0.0, (a, b) => a + b.weight);
      final totalPrice =
          lines.fold(0.0, (a, b) => a + b.quantity * b.price);
      await txn.insert('deliveries', {
        'id': id,
        'customerCode': customerCode,
        'customerName': customerName,
        'date': date,
        'createdAt': now,
        'totalQty': totalQty,
        'totalItems': lines.length,
        'totalWeight': totalWeight,
        'totalPrice': totalPrice,
        'cash': cash ? 1 : 0,
        'byUser': byUser,
        'num': opNum,
        'reqQty': reqQty,
        'reqWeight': reqWeight,
      });
      for (final l in lines) {
        await txn.insert('delivery_items', {
          'deliveryId': id,
          'productCode': l.productCode,
          'productName': l.productName,
          'quantity': l.quantity,
          'weight': l.weight,
          'price': l.price,
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

  /// ترويسة أولًا (معلومات عملية) ثم أصناف من التفاصيل.
  Future<String> createHeader({
    required String customerCode,
    required String customerName,
    required String date,
    String byUser = '',
    bool cash = false,
    double reqQty = 0,
    double reqWeight = 0,
  }) async {
    final d = await _db();
    return d.transaction((txn) async {
      final id = await _docs.nextDeliveryNumber(txn: txn);
      final opNum = await _nextNum(txn, 'deliveries');
      await txn.insert('deliveries', {
        'id': id,
        'customerCode': customerCode,
        'customerName': customerName,
        'date': date,
        'createdAt': AppUtils.nowStr(),
        'totalQty': 0,
        'totalItems': 0,
        'totalWeight': 0,
        'totalPrice': 0,
        'cash': cash ? 1 : 0,
        'byUser': byUser,
        'num': opNum,
        'reqQty': reqQty,
        'reqWeight': reqWeight,
      });
      return id;
    });
  }

  Future<void> updateHeader({
    required String id,
    required String customerCode,
    required String customerName,
    required String date,
    required bool cash,
    required double reqQty,
    required double reqWeight,
  }) async {
    final d = await _db();
    await d.update(
        'deliveries',
        {
          'customerCode': customerCode,
          'customerName': customerName,
          'date': date,
          'cash': cash ? 1 : 0,
          'reqQty': reqQty,
          'reqWeight': reqWeight,
        },
        where: 'id=?',
        whereArgs: [id]);
  }

  /// إضافة صنف من التفاصيل مع تحديث المخزون والإجماليات (بدون التقيد بالرصيد).
  /// إضافة صنف من التفاصيل مع تحديث المخزون والإجماليات (بدون التقيد بالرصيد).
  /// كل مسحة سطر مستقل بوزنها (للحفاظ على تفصيلة الأوزان المتغيرة) —
  /// الدمج للعرض فقط في الجدول (صف واحد لكل صنف)، والتعديل يعرض كل مسحة في صف.
  Future<void> addItem(String deliveryId, DocLine l) async {
    if (l.quantity <= 0) throw AppFailure('الكمية يجب أن تكون أكبر من صفر: ${l.productCode}');
    final d = await _db();
    await d.transaction((txn) async {
      final prow = await txn.query('products', where: 'code=?', whereArgs: [l.productCode]);
      if (prow.isEmpty) throw AppFailure('الصنف غير موجود: ${l.productCode}');
      final stock = ((prow.first['stock'] ?? 0) as num).toDouble();
      await txn.insert('delivery_items', {
        'deliveryId': deliveryId,
        'productCode': l.productCode,
        'productName': l.productName,
        'quantity': l.quantity,
        'weight': l.weight,
        'price': l.price,
      });
      final before = stock;
      final after = before - l.quantity;
      final now = AppUtils.nowStr();
      await txn.update('products', {'stock': after, 'updatedAt': now},
          where: 'code=?', whereArgs: [l.productCode]);
      await txn.insert('stock_movements', {
        'productCode': l.productCode,
        'type': 'DELIVERY',
        'referenceId': deliveryId,
        'quantity': -l.quantity,
        'beforeQty': before,
        'afterQty': after,
        'createdAt': now,
      });
      final h = await txn.query('deliveries', where: 'id=?', whereArgs: [deliveryId]);
      if (h.isNotEmpty) {
        final m = h.first;
        await txn.update(
            'deliveries',
            {
              'totalQty': ((m['totalQty'] ?? 0) as num).toDouble() + l.quantity,
              'totalWeight': ((m['totalWeight'] ?? 0) as num).toDouble() + l.weight,
              'totalPrice': ((m['totalPrice'] ?? 0) as num).toDouble() + l.quantity * l.price,
              'totalItems': ((m['totalItems'] ?? 0) as num).toInt() + 1,
            },
            where: 'id=?',
            whereArgs: [deliveryId]);
      }
    });
  }

  /// حذف سطر واحد (مسحة) مع عكس أثره المخزني وتحديث الإجماليات.
  Future<void> deleteItem(String deliveryId, int itemId) async {
    final d = await _db();
    await d.transaction((txn) async {
      final h = await txn.query('deliveries',
          where: 'id=?', whereArgs: [deliveryId]);
      if (h.isEmpty) throw const AppFailure('الإذن غير موجود');
      final its = await txn.query('delivery_items',
          where: 'id=? AND deliveryId=?', whereArgs: [itemId, deliveryId]);
      if (its.isEmpty) throw const AppFailure('السطر غير موجود');
      final it = its.first;
      final code = it['productCode'].toString();
      final qty = ((it['quantity'] ?? 0) as num).toDouble();
      final w = ((it['weight'] ?? 0) as num).toDouble();
      final pr = ((it['price'] ?? 0) as num).toDouble();
      final prow =
          await txn.query('products', where: 'code=?', whereArgs: [code]);
      if (prow.isNotEmpty) {
        final before = ((prow.first['stock'] ?? 0) as num).toDouble();
        final after = before + qty;
        final now = AppUtils.nowStr();
        await txn.update('products', {'stock': after, 'updatedAt': now},
            where: 'code=?', whereArgs: [code]);
        await txn.insert('stock_movements', {
          'productCode': code,
          'type': 'ADJUSTMENT',
          'referenceId': 'DEL-ITEM-$itemId',
          'quantity': qty,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': now,
        });
      }
      await txn.delete('delivery_items', where: 'id=?', whereArgs: [itemId]);
      final m = h.first;
      await txn.update(
          'deliveries',
          {
            'totalQty': ((m['totalQty'] ?? 0) as num).toDouble() - qty,
            'totalWeight': ((m['totalWeight'] ?? 0) as num).toDouble() - w,
            'totalPrice':
                ((m['totalPrice'] ?? 0) as num).toDouble() - qty * pr,
            'totalItems': ((m['totalItems'] ?? 0) as num).toInt() - 1,
          },
          where: 'id=?',
          whereArgs: [deliveryId]);
    });
  }

  /// تعديل سطر (كمية/وزن/سعر) مع ضبط المخزون بالفرق وتحديث الإجماليات.
  Future<void> updateItem(String deliveryId, int itemId,
      {required double quantity,
      required double weight,
      required double price}) async {
    if (quantity <= 0) {
      throw const AppFailure('الكمية يجب أن تكون أكبر من صفر');
    }
    final d = await _db();
    await d.transaction((txn) async {
      final h = await txn.query('deliveries',
          where: 'id=?', whereArgs: [deliveryId]);
      if (h.isEmpty) throw const AppFailure('الإذن غير موجود');
      final its = await txn.query('delivery_items',
          where: 'id=? AND deliveryId=?', whereArgs: [itemId, deliveryId]);
      if (its.isEmpty) throw const AppFailure('السطر غير موجود');
      final it = its.first;
      final code = it['productCode'].toString();
      final oldQty = ((it['quantity'] ?? 0) as num).toDouble();
      final oldW = ((it['weight'] ?? 0) as num).toDouble();
      final oldPr = ((it['price'] ?? 0) as num).toDouble();
      final dQty = quantity - oldQty;
      final prow =
          await txn.query('products', where: 'code=?', whereArgs: [code]);
      if (prow.isNotEmpty && dQty != 0) {
        final before = ((prow.first['stock'] ?? 0) as num).toDouble();
        final after = before - dQty;
        final now = AppUtils.nowStr();
        await txn.update('products', {'stock': after, 'updatedAt': now},
            where: 'code=?', whereArgs: [code]);
        await txn.insert('stock_movements', {
          'productCode': code,
          'type': 'ADJUSTMENT',
          'referenceId': 'EDIT-ITEM-$itemId',
          'quantity': -dQty,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': now,
        });
      }
      await txn.update(
          'delivery_items',
          {'quantity': quantity, 'weight': weight, 'price': price},
          where: 'id=?',
          whereArgs: [itemId]);
      final m = h.first;
      await txn.update(
          'deliveries',
          {
            'totalQty': ((m['totalQty'] ?? 0) as num).toDouble() + dQty,
            'totalWeight':
                ((m['totalWeight'] ?? 0) as num).toDouble() + (weight - oldW),
            'totalPrice': ((m['totalPrice'] ?? 0) as num).toDouble() +
                (quantity * price - oldQty * oldPr),
          },
          where: 'id=?',
          whereArgs: [deliveryId]);
    });
  }

  Future<List<DeliveryHeader>> list(
      {String q = '', int limit = 10, int offset = 0}) async {
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

  /// مسح كل أذون التسليم وبنودها (للأرشفة) — بدون عكس المخزون
  /// (البضاعة خرجت فعلًا والرصيد سليم) وبدون مساس بالأصناف/العملاء.
  /// يُرجع عدد الأذون المحذوفة.
  Future<int> deleteAllVouchers() async {
    final d = await _db();
    return d.transaction((txn) async {
      final h =
          await txn.rawQuery('SELECT COUNT(*) c FROM deliveries');
      final count = (h.first['c'] as num).toInt();
      await txn.delete('delivery_items');
      await txn.delete('deliveries');
      return count;
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

  /// حل أي مسح (كود صنف / حقل باركود / product_codes / قالب وزن متغير)
  /// إلى كود صنف فعلي داخل نفس الـ transaction.
  static String _clean(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200B\u200C\u200D\uFEFF]'), '');
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s.trim();
  }

  Future<String> _resolveScanned(
      DatabaseExecutor txn, String scanned) async {
    final s = _clean(scanned);
    if (s.isEmpty) throw AppFailure('الصنف غير موجود: $scanned');
    // 1) كود صنف مباشر
    var r = await txn.query('products', where: 'code=?', whereArgs: [s], limit: 1);
    if (r.isNotEmpty) return (r.first['code'] ?? s).toString();
    // 2) حقل باركود الصنف نفسه (products.barcode)
    r = await txn.query('products', where: 'barcode=?', whereArgs: [s], limit: 1);
    if (r.isNotEmpty) return (r.first['code'] ?? s).toString();
    // 3) باركود مسجل في product_codes
    r = await txn.query('product_codes', where: 'barcode=?', whereArgs: [s], limit: 1);
    if (r.isNotEmpty) return (r.first['productCode'] ?? s).toString();
    // 4) مقطع الكود داخل الباركود (cStart..cEnd) — تحديد تلقائي بدون اختيار يدوي
    try {
      final ts = await txn.query('product_codes', orderBy: 'id ASC', limit: 2000);
      final tms = [for (final t in ts) ProductCode.fromMap(t)];
      for (final cand in BarcodeResolver.extractCodeCandidates(s, tms)) {
        final pr = await txn.query('products',
            where: 'code=?', whereArgs: [cand.code], limit: 1);
        if (pr.isNotEmpty) return (pr.first['code'] ?? s).toString();
      }
    } catch (_) {}
    // 5) قالب وزن متغير: نفس الطول + ثبات خارج مقطع الوزن/التاريخ
    try {
      final ts = await txn.query('product_codes', orderBy: 'id ASC', limit: 2000);
      for (final t in ts) {
        final pc = ProductCode.fromMap(t);
        if (pc.wStart <= 0 || pc.wEnd <= 0) continue;
        if (BarcodeResolver.matchesTemplate(s, pc)) {
          return pc.productCode;
        }
      }
    } catch (_) {}
    return s;
  }

  /// مسح صنف داخل الجرد: يزيد Actual + يسجل/ينشئ السطر
  Future<void> scanOrAdd(String sessionId, String scanned,
      {double qty = 1}) async {
    final d = await _db();
    await d.transaction((txn) async {
      final productCode = await _resolveScanned(txn, _clean(scanned));
      final prow = await txn
          .query('products', where: 'code=?', whereArgs: [productCode]);
      if (prow.isEmpty) {
        throw AppFailure('الصنف غير موجود: $scanned');
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
      {String q = '', int limit = 10, int offset = 0}) async {
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
      int limit = 10,
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
