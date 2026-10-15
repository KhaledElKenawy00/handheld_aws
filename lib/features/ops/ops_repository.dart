import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/services/barcode_resolver.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/app_utils.dart';
import '../../shared/models/entities.dart';
import '../receipts/voucher_repositories.dart' show nextOpNum;

/// مستخدمو النظام + الصلاحيات (ادارة المستخدمين / تصريحات المستخدم).
class UsersRepo {
  Future<Database> _db() => DatabaseHelper.instance.db;

  Future<AppUser?> login(String username, String password) async {
    final d = await _db();
    final r = await d.query('users',
        where: 'username=? AND password=?',
        whereArgs: [username.trim(), password]);
    if (r.isEmpty) return null;
    return AppUser.fromMap(r.first);
  }

  Future<List<AppUser>> all() async {
    final d = await _db();
    final r = await d.query('users', orderBy: 'id ASC');
    return r.map(AppUser.fromMap).toList();
  }

  Future<void> create(AppUser u) async {
    if (u.username.trim().isEmpty) throw const AppFailure('ادخل اسم المستخدم');
    if (u.password.isEmpty) throw const AppFailure('ادخل كلمة المرور');
    final d = await _db();
    try {
      await d.transaction((txn) async {
        await txn.insert('users', {
          'username': u.username.trim(),
          'password': u.password,
          'type': u.type,
        });
        for (final j in ['تسليمات', 'استلامات', 'مرتجعات للعميل', 'مرتجعات للمورد', 'تحويلات خارجية', 'تحويلات داخلية', 'اخرى']) {
          await txn.insert('user_permissions',
              {'username': u.username.trim(), 'job': j, 'allowed': 1});
        }
      });
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE')) {
        throw AppFailure('اسم المستخدم موجود بالفعل: ${u.username}');
      }
      rethrow;
    }
  }

  Future<void> deleteUser(String username) async {
    if (username == 'admin') throw const AppFailure('لا يمكن حذف admin');
    final d = await _db();
    await d.transaction((txn) async {
      await txn.delete('user_permissions', where: 'username=?', whereArgs: [username]);
      await txn.delete('users', where: 'username=?', whereArgs: [username]);
    });
  }

  Future<Map<String, bool>> permissions(String username) async {
    final d = await _db();
    final r = await d.query('user_permissions', where: 'username=?', whereArgs: [username]);
    return {for (final m in r) (m['job'] as String): ((m['allowed'] as num).toInt() == 1)};
  }

  Future<void> setPermission(String username, String job, bool allowed) async {
    final d = await _db();
    final r = await d.query('user_permissions',
        where: 'username=? AND job=?', whereArgs: [username, job]);
    if (r.isEmpty) {
      await d.insert('user_permissions',
          {'username': username, 'job': job, 'allowed': allowed ? 1 : 0});
    } else {
      await d.update('user_permissions', {'allowed': allowed ? 1 : 0},
          where: 'username=? AND job=?', whereArgs: [username, job]);
    }
  }
}

/// المخازن (الرمز + الاسم).
class WarehouseRepo {
  Future<Database> _db() => DatabaseHelper.instance.db;

  Future<void> create(Warehouse w) async {
    if (w.code.trim().isEmpty) throw const AppFailure('ادخل الرمز');
    if (w.name.trim().isEmpty) throw const AppFailure('ادخل الاسم');
    final d = await _db();
    try {
      await d.insert('warehouses', {
        'code': w.code.trim(),
        'name': w.name.trim(),
        'createdAt': AppUtils.nowStr(),
      });
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE')) throw AppFailure('الرمز موجود بالفعل: ${w.code}');
      rethrow;
    }
  }

  Future<List<Warehouse>> search(String q,
      {int limit = 10, int offset = 0}) async {
    final d = await _db();
    if (q.trim().isEmpty) {
      final r = await d.query('warehouses',
          orderBy: 'code ASC', limit: limit, offset: offset);
      return r.map(Warehouse.fromMap).toList();
    }
    final like = '%${q.trim()}%';
    final r = await d.query('warehouses',
        where: 'code LIKE ? OR name LIKE ?',
        whereArgs: [like, like],
        orderBy: 'code ASC',
        limit: limit,
        offset: offset);
    return r.map(Warehouse.fromMap).toList();
  }

  Future<int> count({String q = ''}) async {
    final d = await _db();
    if (q.trim().isEmpty) {
      final r =
          await d.rawQuery('SELECT COUNT(*) c FROM warehouses');
      return (r.first['c'] as num).toInt();
    }
    final like = '%${q.trim()}%';
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM warehouses WHERE code LIKE ? OR name LIKE ?',
        [like, like]);
    return (r.first['c'] as num).toInt();
  }

  Future<void> delete(String code) async {
    final d = await _db();
    await d.delete('warehouses', where: 'code=?', whereArgs: [code]);
  }
}

/// أكواد الباركود التابعة للصنف (دايلوج إضافة كود).
class ProductCodeRepo {
  Future<Database> _db() => DatabaseHelper.instance.db;

  /// كاش القوالب في الذاكرة — المسح المتتالي السريع كان يعيد تحميل
  /// الجدول كله (حتى 2000 صف) مع كل مسحة. يُبطل عند أي تعديل.
  List<ProductCode>? _allCache;

  void _invalidateCache() => _allCache = null;

  Future<void> add(ProductCode c) async {
    final bc = _cleanBarcode(c.barcode);
    if (bc.isEmpty) throw const AppFailure('ادخل الباركود');
    _invalidateCache();
    final d = await _db();
    await d.insert('product_codes', {
      'productCode': c.productCode.trim(),
      'barcode': bc,
      'qty': c.qty,
      'weight': c.weight,
      'unit': c.unit,
      'mark': c.mark,
      'dateFmt': c.dateFmt,
      'value': c.value,
      'wStart': c.wStart,
      'wEnd': c.wEnd,
      'cStart': c.cStart,
      'cEnd': c.cEnd,
      'dStart': c.dStart,
      'dEnd': c.dEnd,
      'mStart': c.mStart,
      'mEnd': c.mEnd,
    });
  }

  Future<List<ProductCode>> forProduct(String productCode) async {
    final d = await _db();
    final r = await d.query('product_codes',
        where: 'productCode=?', whereArgs: [productCode], orderBy: 'id ASC');
    return r.map(ProductCode.fromMap).toList();
  }

  static String _cleanBarcode(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200B\u200C\u200D\uFEFF]'), '');
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s.trim();
  }

  Future<ProductCode?> findByBarcode(String barcode) async {
    final d = await _db();
    final b = _cleanBarcode(barcode);
    if (b.isEmpty) return null;
    // عند تكرار نفس الباركود (قالب قديم لصنف محذوف/موقوف + قالب جديد
    // لصنف نشط) فضّل قالب الصنف النشط حتى لا تظهر "الصنف موقوف" بالخطأ.
    Future<ProductCode?> byValue(String v) async {
      final r = await d.rawQuery(
        'SELECT pc.* FROM product_codes pc '
        'LEFT JOIN products p ON p.code = pc.productCode '
        'WHERE pc.barcode = ? '
        'ORDER BY COALESCE(p.isActive, 1) DESC, pc.id DESC',
        [v],
      );
      if (r.isEmpty) return null;
      return ProductCode.fromMap(r.first);
    }
    final hit = await byValue(b);
    if (hit != null) return hit;
    // fallback متسامح: جرّب القيمة الخام بعد trim فقط (صفوف قديمة قبل التوحيد).
    final t = barcode.trim();
    if (t.isNotEmpty && t != b) {
      return byValue(t);
    }
    return null;
  }

  Future<void> delete(int id) async {
    _invalidateCache();
    final d = await _db();
    await d.delete('product_codes', where: 'id=?', whereArgs: [id]);
  }

  /// كل القوالب المحفوظة — تُستخدم لمطابقة الباركود المتغير
  /// (نفس الطول + نفس الأجزاء الثابتة خارج مقطع الوزن).
  /// تُقرأ من الكاش بعد أول تحميل لسرعة المسح المتتالي.
  Future<List<ProductCode>> all() async {
    final hit = _allCache;
    if (hit != null) return hit;
    final d = await _db();
    final r = await d.query('product_codes', orderBy: 'id ASC', limit: 2000);
    return _allCache = r.map(ProductCode.fromMap).toList();
  }

  Future<void> update(ProductCode c) async {
    if (c.id == null) throw const AppFailure('الكود غير موجود');
    final bc = _cleanBarcode(c.barcode);
    if (bc.isEmpty) throw const AppFailure('ادخل الباركود');
    _invalidateCache();
    final d = await _db();
    await d.update(
        'product_codes',
        {
          'productCode': c.productCode.trim(),
          'barcode': bc,
          'qty': c.qty,
          'weight': c.weight,
          'unit': c.unit,
          'mark': c.mark,
          'dateFmt': c.dateFmt,
          'value': c.value,
          'wStart': c.wStart,
          'wEnd': c.wEnd,
          'cStart': c.cStart,
          'cEnd': c.cEnd,
          'dStart': c.dStart,
          'dEnd': c.dEnd,
          'mStart': c.mStart,
          'mEnd': c.mEnd,
        },
        where: 'id=?',
        whereArgs: [c.id]);
  }

  /// حل الممسوح عبر مقطع الكود: يستخرج الكود من داخل الباركود حسب
  /// cStart..cEnd المحدد من المستخدم، ثم يبحث عن صنف بهذا الكود.
  /// يُرجع القالب + أول صنف **نشط** مطابق — المرشحات الموقوفة (أصناف
  /// محذوفة سابقًا) تُتخطى ولا توقف البحث، لأن مقطعًا قديمًا/خاطئًا قد
  /// يستخرج كود صنف محذوف فيظهر "الصنف موقوف" بالخطأ رغم وجود الصنف الصحيح.
  /// لو لا يوجد أي مرشح نشط يُرجع الموقوف (إن وجد) لعرض رسالة دقيقة،
  /// وإلا null فيكمل المسح بباقي الطرق.
  Future<({ProductCode template, Product product})?>
      resolveByCodeSegment(String scanned) async {
    final d = await _db();
    final templates = await all();
    ({ProductCode template, Product product})? inactiveHit;
    for (final cand
        in BarcodeResolver.extractCodeCandidates(scanned, templates)) {
      final r = await d.query('products',
          where: 'code=?', whereArgs: [cand.code], limit: 1);
      if (r.isEmpty) continue;
      final p = Product.fromMap(r.first);
      if (p.isActive) {
        return (
          template: cand.template,
          product: p,
        );
      }
      inactiveHit ??= (template: cand.template, product: p);
    }
    return inactiveHit;
  }
}

/// عمليات مرتجع عميل / مرتجع مورد / تحويل داخلي / تحويل خارجي.
/// نفس شكل الفواتير + تأثير مخزني حسب النوع.
class OpsRepo {
  final _settings = SettingsService();
  Future<Database> _db() => DatabaseHelper.instance.db;

  /// +1 للمخزن: مرتجع عميل + تحويل داخلي (وارد) | -1: مرتجع مورد + تحويل خارجي
  int _sign(String kind) {
    if (kind == 'مرتجع عميل' || kind == 'تحويل داخلي') return 1;
    return -1;
  }

  String _moveType(String kind) {
    switch (kind) {
      case 'مرتجع عميل':
        return 'RETURN_CUST';
      case 'مرتجع مورد':
        return 'RETURN_SUP';
      case 'تحويل داخلي':
        return 'TRANSFER_IN';
      default:
        return 'TRANSFER_OUT';
    }
  }

  Future<String> save({
    required String kind,
    required String partyType,
    required String partyCode,
    required String partyName,
    required String date,
    required String byUser,
    required bool cash,
    required List<DocLine> lines,
    double reqQty = 0,
    double reqWeight = 0,
    String? fixedId,
    int? fixedNum,
  }) async {
    if (lines.isEmpty) throw const AppFailure('أضف صنفًا واحدًا على الأقل');
    final d = await _db();
    return d.transaction((txn) async {
      for (final l in lines) {
        if (l.quantity <= 0) throw AppFailure('الكمية يجب أن تكون أكبر من صفر: ${l.productCode}');
      }
      final n = fixedNum ?? await nextOpNum(txn, 'op_headers');
      final id = fixedId ?? '$kind-$n-${DateTime.now().millisecondsSinceEpoch}';
      final now = AppUtils.nowStr();
      final totalQty = lines.fold(0.0, (a, b) => a + b.quantity);
      final totalWeight = lines.fold(0.0, (a, b) => a + b.weight);
      final totalPrice = lines.fold(0.0, (a, b) => a + b.quantity * b.price);
      await txn.insert('op_headers', {
        'id': id,
        'kind': kind,
        'partyType': partyType,
        'partyCode': partyCode,
        'partyName': partyName,
        'num': n,
        'date': date,
        'createdAt': now,
        'byUser': byUser,
        'totalQty': totalQty,
        'totalWeight': totalWeight,
        'totalPrice': totalPrice,
        'totalItems': lines.length,
        'cash': cash ? 1 : 0,
        'reqQty': reqQty,
        'reqWeight': reqWeight,
      });
      for (final l in lines) {
        await txn.insert('op_items', {
          'opId': id,
          'productCode': l.productCode,
          'productName': l.productName,
          'quantity': l.quantity,
          'weight': l.weight,
          'price': l.price,
        });
        final prow = await txn.query('products', where: 'code=?', whereArgs: [l.productCode]);
        if (prow.isNotEmpty) {
          final before = ((prow.first['stock'] ?? 0) as num).toDouble();
          final after = before + _sign(kind) * l.quantity;
          await txn.update('products', {'stock': after, 'updatedAt': now},
              where: 'code=?', whereArgs: [l.productCode]);
          await txn.insert('stock_movements', {
            'productCode': l.productCode,
            'type': _moveType(kind),
            'referenceId': id,
            'quantity': _sign(kind) * l.quantity,
            'beforeQty': before,
            'afterQty': after,
            'createdAt': now,
          });
        }
      }
      return id;
    });
  }

  Future<String> createHeader({
    required String kind,
    required String partyType,
    required String partyCode,
    required String partyName,
    required String date,
    required String byUser,
    required bool cash,
    required double reqQty,
    required double reqWeight,
  }) async {
    final d = await _db();
    return d.transaction((txn) async {
      final n = await nextOpNum(txn, 'op_headers');
      final id = '$kind-$n-${DateTime.now().millisecondsSinceEpoch}';
      await txn.insert('op_headers', {
        'id': id,
        'kind': kind,
        'partyType': partyType,
        'partyCode': partyCode,
        'partyName': partyName,
        'num': n,
        'date': date,
        'createdAt': AppUtils.nowStr(),
        'byUser': byUser,
        'totalQty': 0,
        'totalWeight': 0,
        'totalPrice': 0,
        'totalItems': 0,
        'cash': cash ? 1 : 0,
        'reqQty': reqQty,
        'reqWeight': reqWeight,
      });
      return id;
    });
  }

  Future<void> updateHeader({
    required String id,
    required String partyCode,
    required String partyName,
    required String date,
    required bool cash,
    required double reqQty,
    required double reqWeight,
  }) async {
    final d = await _db();
    await d.update(
        'op_headers',
        {
          'partyCode': partyCode,
          'partyName': partyName,
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
  Future<void> addItem(String opId, DocLine l) async {
    if (l.quantity <= 0) throw AppFailure('الكمية يجب أن تكون أكبر من صفر: ${l.productCode}');
    final d = await _db();
    await d.transaction((txn) async {
      final h = await txn.query('op_headers', where: 'id=?', whereArgs: [opId]);
      if (h.isEmpty) throw const AppFailure('العملية غير موجودة');
      final kind = (h.first['kind'] ?? '').toString();
      await txn.insert('op_items', {
        'opId': opId,
        'productCode': l.productCode,
        'productName': l.productName,
        'quantity': l.quantity,
        'weight': l.weight,
        'price': l.price,
      });
      final prow = await txn.query('products', where: 'code=?', whereArgs: [l.productCode]);
      if (prow.isNotEmpty) {
        final before = ((prow.first['stock'] ?? 0) as num).toDouble();
        final after = before + _sign(kind) * l.quantity;
        final now = AppUtils.nowStr();
        await txn.update('products', {'stock': after, 'updatedAt': now},
            where: 'code=?', whereArgs: [l.productCode]);
        await txn.insert('stock_movements', {
          'productCode': l.productCode,
          'type': _moveType(kind),
          'referenceId': opId,
          'quantity': _sign(kind) * l.quantity,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': now,
        });
      }
      final m = h.first;
      await txn.update(
          'op_headers',
          {
            'totalQty': ((m['totalQty'] ?? 0) as num).toDouble() + l.quantity,
            'totalWeight': ((m['totalWeight'] ?? 0) as num).toDouble() + l.weight,
            'totalPrice': ((m['totalPrice'] ?? 0) as num).toDouble() + l.quantity * l.price,
            'totalItems': ((m['totalItems'] ?? 0) as num).toInt() + 1,
          },
          where: 'id=?',
          whereArgs: [opId]);
    });
  }

  /// حذف سطر واحد (مسحة) مع عكس أثره المخزني وتحديث الإجماليات.
  Future<void> deleteItem(String opId, int itemId) async {
    final allowNeg = await _settings.allowNegativeStock();
    final d = await _db();
    await d.transaction((txn) async {
      final h = await txn.query('op_headers', where: 'id=?', whereArgs: [opId]);
      if (h.isEmpty) throw const AppFailure('العملية غير موجودة');
      final kind = (h.first['kind'] ?? '').toString();
      final its = await txn.query('op_items',
          where: 'id=? AND opId=?', whereArgs: [itemId, opId]);
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
        final after = before - _sign(kind) * qty;
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
          'quantity': -_sign(kind) * qty,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': now,
        });
      }
      await txn.delete('op_items', where: 'id=?', whereArgs: [itemId]);
      final m = h.first;
      await txn.update(
          'op_headers',
          {
            'totalQty': ((m['totalQty'] ?? 0) as num).toDouble() - qty,
            'totalWeight': ((m['totalWeight'] ?? 0) as num).toDouble() - w,
            'totalPrice':
                ((m['totalPrice'] ?? 0) as num).toDouble() - qty * pr,
            'totalItems': ((m['totalItems'] ?? 0) as num).toInt() - 1,
          },
          where: 'id=?',
          whereArgs: [opId]);
    });
  }

  /// تعديل سطر (كمية/وزن/سعر) مع ضبط المخزون بالفرق وتحديث الإجماليات.
  Future<void> updateItem(String opId, int itemId,
      {required double quantity,
      required double weight,
      required double price}) async {
    if (quantity <= 0) {
      throw const AppFailure('الكمية يجب أن تكون أكبر من صفر');
    }
    final allowNeg = await _settings.allowNegativeStock();
    final d = await _db();
    await d.transaction((txn) async {
      final h = await txn.query('op_headers', where: 'id=?', whereArgs: [opId]);
      if (h.isEmpty) throw const AppFailure('العملية غير موجودة');
      final kind = (h.first['kind'] ?? '').toString();
      final its = await txn.query('op_items',
          where: 'id=? AND opId=?', whereArgs: [itemId, opId]);
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
        final after = before + _sign(kind) * dQty;
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
          'quantity': _sign(kind) * dQty,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': now,
        });
      }
      await txn.update(
          'op_items',
          {'quantity': quantity, 'weight': weight, 'price': price},
          where: 'id=?',
          whereArgs: [itemId]);
      final m = h.first;
      await txn.update(
          'op_headers',
          {
            'totalQty': ((m['totalQty'] ?? 0) as num).toDouble() + dQty,
            'totalWeight':
                ((m['totalWeight'] ?? 0) as num).toDouble() + (weight - oldW),
            'totalPrice': ((m['totalPrice'] ?? 0) as num).toDouble() +
                (quantity * price - oldQty * oldPr),
          },
          where: 'id=?',
          whereArgs: [opId]);
    });
  }

  Future<List<OpHeader>> list(String kind, {String q = '', int limit = 10, int offset = 0}) async {
    final d = await _db();
    if (q.trim().isEmpty) {
      final rows = await d.query('op_headers',
          where: 'kind=?', whereArgs: [kind], orderBy: 'num DESC', limit: limit, offset: offset);
      return rows.map(OpHeader.fromMap).toList();
    }
    final like = '%${q.trim()}%';
    final rows = await d.query('op_headers',
        where: 'kind=? AND (partyName LIKE ? OR partyCode LIKE ?)',
        whereArgs: [kind, like, like],
        orderBy: 'num DESC',
        limit: limit,
        offset: offset);
    return rows.map(OpHeader.fromMap).toList();
  }

  Future<List<OpItem>> items(String opId) async {
    final d = await _db();
    final rows = await d.query('op_items', where: 'opId=?', whereArgs: [opId]);
    return rows.map(OpItem.fromMap).toList();
  }

  Future<OpHeader?> find(String id) async {
    final d = await _db();
    final r = await d.query('op_headers', where: 'id=?', whereArgs: [id]);
    if (r.isEmpty) return null;
    return OpHeader.fromMap(r.first);
  }

  Future<int> count(String kind, {String q = ''}) async {
    final d = await _db();
    if (q.trim().isEmpty) {
      final r = await d.rawQuery(
          'SELECT COUNT(*) c FROM op_headers WHERE kind=?', [kind]);
      return (r.first['c'] as num).toInt();
    }
    final like = '%${q.trim()}%';
    final r = await d.rawQuery(
        'SELECT COUNT(*) c FROM op_headers WHERE kind=? AND (partyName LIKE ? OR partyCode LIKE ?)',
        [kind, like, like]);
    return (r.first['c'] as num).toInt();
  }

  Future<void> delete(String id) async {
    final d = await _db();
    final allowNeg = await _settings.allowNegativeStock();
    await d.transaction((txn) async {
      final h = await txn.query('op_headers', where: 'id=?', whereArgs: [id]);
      if (h.isEmpty) return;
      final kind = (h.first['kind'] ?? '').toString();
      final its = await txn.query('op_items', where: 'opId=?', whereArgs: [id]);
      for (final it in its) {
        final code = it['productCode'].toString();
        final qty = ((it['quantity'] ?? 0) as num).toDouble();
        final prow = await txn.query('products', where: 'code=?', whereArgs: [code]);
        if (prow.isEmpty) continue;
        final before = ((prow.first['stock'] ?? 0) as num).toDouble();
        final after = before - _sign(kind) * qty;
        if (after < 0 && !allowNeg) {
          throw const AppFailure('لا يمكن حذف العملية: سيصبح المخزون سالبًا.');
        }
        await txn.update('products', {'stock': after}, where: 'code=?', whereArgs: [code]);
        await txn.insert('stock_movements', {
          'productCode': code,
          'type': 'ADJUSTMENT',
          'referenceId': 'DELETE-$id',
          'quantity': -_sign(kind) * qty,
          'beforeQty': before,
          'afterQty': after,
          'createdAt': AppUtils.nowStr(),
        });
      }
      await txn.delete('op_headers', where: 'id=?', whereArgs: [id]);
    });
  }

  /// مسح عمليات بأنواع محددة (مرتجع عميل/مرتجع مورد) مع بنودها (للأرشفة) —
  /// بدون عكس المخزون وبدون مساس بالأصناف/الأطراف. يُرجع عدد المحذوفة.
  Future<int> deleteByKinds(List<String> kinds) async {
    if (kinds.isEmpty) return 0;
    final d = await _db();
    return d.transaction((txn) async {
      final ph = List.filled(kinds.length, '?').join(',');
      final h = await txn.rawQuery(
          'SELECT COUNT(*) c FROM op_headers WHERE kind IN ($ph)', kinds);
      final count = (h.first['c'] as num).toInt();
      final ids = await txn.query('op_headers',
          columns: ['id'], where: 'kind IN ($ph)', whereArgs: kinds);
      for (final r in ids) {
        final id = r['id'].toString();
        await txn.delete('op_items', where: 'opId=?', whereArgs: [id]);
      }
      await txn.delete('op_headers',
          where: 'kind IN ($ph)', whereArgs: kinds);
      return count;
    });
  }
}
