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
      },
      onUpgrade: (d, oldV, newV) async {
        for (final s in Schema.createStatements()) {
          await d.execute(s);
        }
      },
    );
  }

  Future<void> _seedDefaults(DatabaseExecutor d) async {
    await d.insert('app_settings', {
      'key': 'allow_negative_stock',
      'value': '0',
    });
    await d.insert('app_settings', {'key': 'store_name', 'value': ''});
    await d.insert('app_settings', {'key': 'company_name', 'value': 'SANAD سند'});
    await d.insert('app_settings', {'key': 'scanner_beep', 'value': '1'});
    await d.insert('app_settings', {'key': 'scanner_vibrate', 'value': '1'});
    await d.insert('app_settings', {
      'key': 'scanner_debounce_ms',
      'value': '400',
    });
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
