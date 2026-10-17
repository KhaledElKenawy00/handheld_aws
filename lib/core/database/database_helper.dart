import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Singleton لإدارة SQLite — Local-First بالكامل
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  Future<Database> get db async {
    final d = _db;
    if (d != null) return d;
    return _db = await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'sanad.db');
    return openDatabase(
      path,
      version: Schema.version,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (d, v) async {
        for (final s in Schema.createStatements()) {
          await d.execute(s);
        }
        await _seedDefaults(d);
        await _seedAdmin(d);
        await _backfillNums(d);
      },
      onUpgrade: (d, oldV, newV) async {
        for (final s in Schema.createStatements()) {
          await d.execute(s);
        }
        if (oldV < 2) {
          await _applyAlters(d, Schema.v2Alters());
          await _seedAdmin(d);
          await _backfillNums(d);
        }
        if (oldV < 3) {
          await _applyAlters(d, Schema.v3Alters());
        }
        if (oldV < 4) {
          await _healAutoWeightSegments(d);
        }
        if (oldV < 5) {
          await _applyAlters(d, Schema.v5Alters());
        }
        if (oldV < 6) {
          await _migrateAdminPassword(d);
        }
      },
    );
  }

  /// v6: كلمة مرور admin الافتراضية بقت '123' — نحدّث الحساب لو لسه
  /// على الافتراضي القديم 'admin' فقط (لو المستخدم غيّرها لا نلمسها).
  Future<void> _migrateAdminPassword(DatabaseExecutor d) async {
    try {
      await d.update(
        'users',
        {'password': '123'},
        where: 'username=? AND password=?',
        whereArgs: ['admin', 'admin'],
      );
    } catch (_) {}
  }

  /// تنظيف مقاطع الوزن الوهمية (v4): مقطع وزن يغطي الباركود كله من
  /// الأول للآخر مع علامة 1 يعني "الوزن = رقم الباركود نفسه" — وهذا كان
  /// يُضبط تلقائيًا عند المسح دون أن يحدده المستخدم، فيظهر الوزن هو هو
  /// الباركود. يُصفّر المقطع والوزن/القيمة المخزنة ليصبح "غير محدد".
  /// (الباركودات القصيرة جدًا ≤2 وعلامات غير 1 تُترك كما هي للأمان —
  /// يمكن تصفيرها يدويًا من أسهم الدايلوج حتى "—").
  Future<void> _healAutoWeightSegments(DatabaseExecutor d) async {
    try {
      await d.execute(
        "UPDATE product_codes SET wStart=0, wEnd=0, weight=0, value=0 "
        "WHERE wStart=1 AND wEnd=LENGTH(barcode) AND mark='1' "
        "AND LENGTH(barcode) > 2",
      );
    } catch (_) {}
  }

  /// يضيف الأعمدة الناقصة فقط (يفحص PRAGMA أولًا — بدون duplicate column noise).
  Future<void> _applyAlters(
      DatabaseExecutor d, Map<String, List<String>> alters) async {
    for (final e in alters.entries) {
      List<Map<String, Object?>> cols;
      try {
        cols = await d.rawQuery('PRAGMA table_info(${e.key})');
      } catch (_) {
        continue;
      }
      final existing = {for (final c in cols) (c['name'] ?? '').toString()};
      for (final ddl in e.value) {
        final m = RegExp(r'ADD COLUMN (\w+)').firstMatch(ddl);
        if (m != null && existing.contains(m.group(1))) continue;
        try {
          await d.execute(ddl);
        } catch (_) {}
      }
    }
  }

  Future<void> _seedDefaults(DatabaseExecutor d) async {
    Future<void> put(String k, String v) async {
      final r = await d.query('app_settings', where: 'key=?', whereArgs: [k]);
      if (r.isEmpty) await d.insert('app_settings', {'key': k, 'value': v});
    }

    await put('allow_negative_stock', '0');
    await put('store_name', '');
    await put('company_name', 'SANAD سند');
    await put('scanner_beep', '1');
    await put('scanner_vibrate', '1');
    await put('scanner_debounce_ms', '400');
    await put('printer_ip', '');
    await put('printer_port', '9100');
    await put('server_url', '');
  }

  /// مستخدم افتراضي admin + كل الصلاحيات (مثل الصور).
  Future<void> _seedAdmin(DatabaseExecutor d) async {
    final r = await d.query('users', where: 'username=?', whereArgs: ['admin']);
    if (r.isEmpty) {
      await d.insert('users', {'username': 'admin', 'password': '123', 'type': 'مدير'});
    }
    for (final j in Schema.jobs) {
      final p = await d.query('user_permissions',
          where: 'username=? AND job=?', whereArgs: ['admin', j]);
      if (p.isEmpty) {
        await d.insert('user_permissions', {'username': 'admin', 'job': j, 'allowed': 1});
      }
    }
  }

  /// ترقيم #N للأذون القديمة حسب الأقدمية.
  Future<void> _backfillNums(DatabaseExecutor d) async {
    for (final t in ['receipts', 'deliveries']) {
      try {
        final rows = await d.query(t, columns: ['id', 'num'], orderBy: 'createdAt ASC, id ASC');
        var n = 0;
        for (final row in rows) {
          if (((row['num'] ?? 0) as num).toInt() == 0) {
            n++;
            await d.update(t, {'num': n}, where: 'id=?', whereArgs: [row['id']]);
          } else {
            final v = ((row['num'] ?? 0) as num).toInt();
            if (v > n) n = v;
          }
        }
        final s = await d.query('sequences', where: 'key=?', whereArgs: ['num_$t']);
        if (s.isEmpty) {
          await d.insert('sequences', {'key': 'num_$t', 'lastNumber': n});
        }
      } catch (_) {}
    }
  }

  String get dbPathHint => 'sanad.db';

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// للاختبارات: قاعدة in-memory
  static Future<Database> openTestDb() async {
    final d = await openDatabase(
      inMemoryDatabasePath,
      version: Schema.version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        for (final s in Schema.createStatements()) {
          await db.execute(s);
        }
      },
    );
    return d;
  }
}
