import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../constants/app_constants.dart';

/// إعدادات التطبيق المخزنة محليًا
class SettingsService {
  Future<Database> _db() => DatabaseHelper.instance.db;

  Future<String?> get(String key) async {
    final d = await _db();
    final r = await d.query('app_settings', where: 'key=?', whereArgs: [key]);
    if (r.isEmpty) return null;
    return r.first['value']?.toString();
  }

  Future<void> set(String key, String value) async {
    final d = await _db();
    await d.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String key) async {
    final d = await _db();
    await d.delete('app_settings', where: 'key=?', whereArgs: [key]);
  }

  Future<bool> allowNegativeStock() async =>
      (await get(AppConstants.kAllowNegativeStock)) == '1';

  Future<Map<String, String>> all() async {
    final d = await _db();
    final rows = await d.query('app_settings');
    return {for (final r in rows) r['key'].toString(): (r['value'] ?? '').toString()};
  }
}
