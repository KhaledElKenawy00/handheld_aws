import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/app_utils.dart';
import '../../shared/models/entities.dart';

/// مستودع الأصناف — كل العمليات Transactional + بحث مفهرس + Pagination
class ProductRepository {
  Future<Database> _db() => DatabaseHelper.instance.db;

  static String cleanBarcode(String? raw) {
    if (raw == null) return '';
    var s = raw.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200B\u200C\u200D\uFEFF]'), '');
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s.trim();
  }

  Future<void> create(Product p) async {
    if (p.code.trim().isEmpty) throw const AppFailure('كود الصنف مطلوب');
    if (p.desc.trim().isEmpty) throw const AppFailure('اسم الصنف مطلوب');
    final d = await _db();
    try {
      final bc = cleanBarcode(p.barcode);
      await d.insert('products', {
        ...p.toMap(),
        'code': p.code.trim(),
        'barcode': bc.isEmpty ? null : bc,
        'createdAt': AppUtils.nowStr(),
        'updatedAt': AppUtils.nowStr(),
      });
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE')) {
        throw AppFailure('الكود موجود بالفعل: ${p.code}');
      }
      rethrow;
    }
  }

  Future<void> update(Product p) async {
    final d = await _db();
    final bc = cleanBarcode(p.barcode);
    await d.update(
        'products',
        {
          'description': p.desc.trim(),
          'updatedAt': AppUtils.nowStr(),
          'weightType': p.weightType,
          'fixedWeight': p.fixedWeight,
          'barcode': bc.isEmpty ? null : bc,
          'price': p.price,
          'hasCode': p.hasCode ? 1 : 0,
          'hasWeight': p.hasWeight ? 1 : 0,
          'hasDate': p.hasDate ? 1 : 0,
          'hasMazraa': p.hasMazraa ? 1 : 0,
        },
        where: 'code=?',
        whereArgs: [p.code]);
  }

  /// حذف ناعم — يحافظ على History
  Future<void> softDelete(String code) async {
    final d = await _db();
    final usedRec = await d.rawQuery(
        'SELECT COUNT(*) c FROM receipt_items WHERE productCode=?', [code]);
    final usedDel = await d.rawQuery(
        'SELECT COUNT(*) c FROM delivery_items WHERE productCode=?', [code]);
    final used = ((usedRec.first['c'] as num).toInt() +
        (usedDel.first['c'] as num).toInt());
    if (used > 0) {
      await d.update('products', {'isActive': 0},
          where: 'code=?', whereArgs: [code]);
      return;
    }
    await d.update('products', {'isActive': 0},
        where: 'code=?', whereArgs: [code]);
  }

  Future<Product?> findByCode(String code) async {
    final d = await _db();
    final r =
        await d.query('products', where: 'code=?', whereArgs: [code.trim()]);
    if (r.isEmpty) return null;
    return Product.fromMap(r.first);
  }

  /// بحث بالباركود المسجل في حقل الصنف نفسه (products.barcode).
  /// هذا الحقل كان يُحفظ عند إضافة الصنف لكن لم يُبحث عنه أبدًا عند المسح
  /// — وهو سبب "المسح لا يسمع الصنف في الطلب".
  /// عند تكرار الباركود فضّل الصنف النشط (صف محذوف/موقوف لا يحجب الجديد).
  Future<Product?> findByBarcode(String barcode) async {
    final d = await _db();
    final b = cleanBarcode(barcode);
    if (b.isEmpty) return null;
    var r = await d.query('products',
        where: 'barcode=?',
        whereArgs: [b],
        orderBy: 'isActive DESC',
        limit: 1);
    if (r.isNotEmpty) return Product.fromMap(r.first);
    // fallback: القيمة الخام بعد trim (صفوف قديمة قبل التوحيد).
    final t = barcode.trim();
    if (t.isNotEmpty && t != b) {
      r = await d.query('products',
          where: 'barcode=?',
          whereArgs: [t],
          orderBy: 'isActive DESC',
          limit: 1);
      if (r.isNotEmpty) return Product.fromMap(r.first);
    }
    return null;
  }

  /// حل شامل لأي مسح: كود صنف مباشر أو باركود حقل الصنف.
  /// يُرجع الصنف لو وُجد بأي من الطريقتين.
  Future<Product?> findByCodeOrBarcode(String scanned) async {
    final s = scanned.trim();
    if (s.isEmpty) return null;
    final byCode = await findByCode(s);
    if (byCode != null) return byCode;
    return findByBarcode(s);
  }

  /// بحث سريع بالكود أو الاسم أو الباركود — debounced من الواجهة
  Future<List<Product>> search(String q,
      {int limit = 10, int offset = 0, bool activeOnly = true}) async {
    final d = await _db();
    final like = '%${q.trim()}%';
    final where = q.trim().isEmpty
        ? (activeOnly ? 'isActive=1' : '1=1')
        : (activeOnly
            ? '(code LIKE ? OR description LIKE ? OR barcode LIKE ?) AND isActive=1'
            : '(code LIKE ? OR description LIKE ? OR barcode LIKE ?)');
    final args =
        q.trim().isEmpty ? <Object>[] : <Object>[like, like, like];
    final rows = await d.query('products',
        where: where,
        whereArgs: args,
        orderBy: 'code ASC',
        limit: limit,
        offset: offset);
    return rows.map(Product.fromMap).toList();
  }

  Future<int> count({String q = '', bool activeOnly = true}) async {
    final d = await _db();
    final like = '%${q.trim()}%';
    final where = q.trim().isEmpty
        ? (activeOnly ? 'isActive=1' : '1=1')
        : (activeOnly
            ? '(code LIKE ? OR description LIKE ? OR barcode LIKE ?) AND isActive=1'
            : '(code LIKE ? OR description LIKE ? OR barcode LIKE ?)');
    final args = q.trim().isEmpty ? <Object>[] : <Object>[like, like, like];
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM products WHERE $where', args);
    return (r.first['c'] as num).toInt();
  }

  Future<List<StockMovement>> movements(String productCode,
      {int limit = 10, int offset = 0}) async {
    final d = await _db();
    final rows = await d.query('stock_movements',
        where: 'productCode=?',
        whereArgs: [productCode],
        orderBy: 'id DESC',
        limit: limit,
        offset: offset);
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<int> movementsCount(String productCode) async {
    final d = await _db();
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM stock_movements WHERE productCode=?',
        [productCode]);
    return (r.first['c'] as num).toInt();
  }

  /// إجماليات المخزون عبر SQL مباشرة — بدون تحميل كل الأصناف في الذاكرة
  /// (كانت التقارير تحمّل limit: 100000 صفًا — سبب رئيسي للتهنيج).
  Future<Map<String, num>> stockTotals() async {
    final d = await _db();
    final r = await d.rawQuery(
        'SELECT COUNT(*) c, COALESCE(SUM(stock),0) total, '
        'COALESCE(SUM(CASE WHEN stock<=0 THEN 1 ELSE 0 END),0) zero '
        'FROM products WHERE isActive=1');
    return {
      'count': (r.first['c'] as num).toInt(),
      'total': ((r.first['total'] ?? 0) as num).toDouble(),
      'zero': (r.first['zero'] as num).toInt(),
    };
  }
}

/// مستودع الموردين
class SupplierRepository {
  Future<Database> _db() => DatabaseHelper.instance.db;

  Future<void> create(Supplier s) async {
    if (s.code.trim().isEmpty) throw const AppFailure('كود المورد مطلوب');
    if (s.desc.trim().isEmpty) throw const AppFailure('اسم المورد مطلوب');
    final d = await _db();
    try {
      await d.insert('suppliers', {
        ...s.toMap(),
        'code': s.code.trim(),
        'createdAt': AppUtils.nowStr(),
      });
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE')) {
        throw AppFailure('كود المورد موجود بالفعل: ${s.code}');
      }
      rethrow;
    }
  }

  Future<void> update(Supplier s) async {
    final d = await _db();
    await d.update('suppliers', {'description': s.desc.trim()},
        where: 'code=?', whereArgs: [s.code]);
  }

  Future<void> softDelete(String code) async {
    final d = await _db();
    await d.update('suppliers', {'isActive': 0},
        where: 'code=?', whereArgs: [code]);
  }

  Future<Supplier?> findByCode(String code) async {
    final d = await _db();
    final r = await d.query('suppliers',
        where: 'code=?', whereArgs: [code.trim()]);
    if (r.isEmpty) return null;
    return Supplier.fromMap(r.first);
  }

  Future<List<Supplier>> search(String q,
      {int limit = 10, int offset = 0, bool activeOnly = true}) async {
    final d = await _db();
    final like = '%${q.trim()}%';
    final where = q.trim().isEmpty
        ? (activeOnly ? 'isActive=1' : '1=1')
        : (activeOnly
            ? '(code LIKE ? OR description LIKE ?) AND isActive=1'
            : '(code LIKE ? OR description LIKE ?)');
    final args = q.trim().isEmpty ? <Object>[] : <Object>[like, like];
    final rows = await d.query('suppliers',
        where: where,
        whereArgs: args,
        orderBy: 'code ASC',
        limit: limit,
        offset: offset);
    return rows.map(Supplier.fromMap).toList();
  }

  Future<int> count({String q = '', bool activeOnly = true}) async {
    final d = await _db();
    final like = '%${q.trim()}%';
    final where = q.trim().isEmpty
        ? (activeOnly ? 'isActive=1' : '1=1')
        : (activeOnly
            ? '(code LIKE ? OR description LIKE ?) AND isActive=1'
            : '(code LIKE ? OR description LIKE ?)');
    final args = q.trim().isEmpty ? <Object>[] : <Object>[like, like];
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM suppliers WHERE $where', args);
    return (r.first['c'] as num).toInt();
  }

  Future<List<ReceiptHeader>> history(String supplierCode,
      {int limit = 10, int offset = 0}) async {
    final d = await _db();
    final rows = await d.query('receipts',
        where: 'supplierCode=?',
        whereArgs: [supplierCode],
        orderBy: 'date DESC, id DESC',
        limit: limit,
        offset: offset);
    return rows.map(ReceiptHeader.fromMap).toList();
  }

  Future<int> historyCount(String supplierCode) async {
    final d = await _db();
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM receipts WHERE supplierCode=?',
        [supplierCode]);
    return (r.first['c'] as num).toInt();
  }

  Future<Map<String, Object>> stats(String supplierCode) async {
    final d = await _db();
    final r = await d.rawQuery(
        'SELECT COUNT(*) c, COALESCE(SUM(totalQty),0) q, MAX(date) lastD FROM receipts WHERE supplierCode=?',
        [supplierCode]);
    return {
      'count': (r.first['c'] as num).toInt(),
      'totalQty': ((r.first['q'] ?? 0) as num).toDouble(),
      'lastDate': (r.first['lastD'] ?? '').toString(),
    };
  }
}

/// مستودع العملاء
class CustomerRepository {
  Future<Database> _db() => DatabaseHelper.instance.db;

  Future<void> create(Customer c) async {
    if (c.code.trim().isEmpty) throw const AppFailure('كود العميل مطلوب');
    if (c.desc.trim().isEmpty) throw const AppFailure('اسم العميل مطلوب');
    final d = await _db();
    try {
      await d.insert('customers', {
        ...c.toMap(),
        'code': c.code.trim(),
        'createdAt': AppUtils.nowStr(),
      });
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE')) {
        throw AppFailure('كود العميل موجود بالفعل: ${c.code}');
      }
      rethrow;
    }
  }

  Future<void> update(Customer c) async {
    final d = await _db();
    await d.update('customers', {'description': c.desc.trim()},
        where: 'code=?', whereArgs: [c.code]);
  }

  Future<void> softDelete(String code) async {
    final d = await _db();
    await d.update('customers', {'isActive': 0},
        where: 'code=?', whereArgs: [code]);
  }

  Future<Customer?> findByCode(String code) async {
    final d = await _db();
    final r = await d.query('customers',
        where: 'code=?', whereArgs: [code.trim()]);
    if (r.isEmpty) return null;
    return Customer.fromMap(r.first);
  }

  Future<List<Customer>> search(String q,
      {int limit = 10, int offset = 0, bool activeOnly = true}) async {
    final d = await _db();
    final like = '%${q.trim()}%';
    final where = q.trim().isEmpty
        ? (activeOnly ? 'isActive=1' : '1=1')
        : (activeOnly
            ? '(code LIKE ? OR description LIKE ?) AND isActive=1'
            : '(code LIKE ? OR description LIKE ?)');
    final args = q.trim().isEmpty ? <Object>[] : <Object>[like, like];
    final rows = await d.query('customers',
        where: where,
        whereArgs: args,
        orderBy: 'code ASC',
        limit: limit,
        offset: offset);
    return rows.map(Customer.fromMap).toList();
  }

  Future<int> count({String q = '', bool activeOnly = true}) async {
    final d = await _db();
    final like = '%${q.trim()}%';
    final where = q.trim().isEmpty
        ? (activeOnly ? 'isActive=1' : '1=1')
        : (activeOnly
            ? '(code LIKE ? OR description LIKE ?) AND isActive=1'
            : '(code LIKE ? OR description LIKE ?)');
    final args = q.trim().isEmpty ? <Object>[] : <Object>[like, like];
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM customers WHERE $where', args);
    return (r.first['c'] as num).toInt();
  }

  Future<List<DeliveryHeader>> history(String customerCode,
      {int limit = 10, int offset = 0}) async {
    final d = await _db();
    final rows = await d.query('deliveries',
        where: 'customerCode=?',
        whereArgs: [customerCode],
        orderBy: 'date DESC, id DESC',
        limit: limit,
        offset: offset);
    return rows.map(DeliveryHeader.fromMap).toList();
  }

  Future<int> historyCount(String customerCode) async {
    final d = await _db();
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM deliveries WHERE customerCode=?',
        [customerCode]);
    return (r.first['c'] as num).toInt();
  }

  Future<Map<String, Object>> stats(String customerCode) async {
    final d = await _db();
    final r = await d.rawQuery(
        'SELECT COUNT(*) c, COALESCE(SUM(totalQty),0) q, MAX(date) lastD FROM deliveries WHERE customerCode=?',
        [customerCode]);
    return {
      'count': (r.first['c'] as num).toInt(),
      'totalQty': ((r.first['q'] ?? 0) as num).toDouble(),
      'lastDate': (r.first['lastD'] ?? '').toString(),
    };
  }
}
