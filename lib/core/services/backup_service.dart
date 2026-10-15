import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/schema.dart';
import '../utils/app_utils.dart';
import 'storage_service.dart';

/// النسخ الاحتياطي (النوع 1 — نسخة النظام):
/// ملف واحد SANAD_BACKUP_*.sanad (zip) يحتوي sanad.db + settings + meta.
/// مصمم ليعمل بعد تحديث التطبيق: الاستعادة تتسامح مع اختلاف الإصدار
/// وتعيد تطبيق الـ schema الحالي (IF NOT EXISTS) بعد نسخ القاعدة.
class BackupService {
  final StorageService storage;
  BackupService({StorageService? storage})
      : storage = storage ?? StorageService();

  Future<String> createBackup() async {
    final db = await DatabaseHelper.instance.db;
    final seqs = await db.query('sequences');
    final settings = await db.query('app_settings');
    final counts = <String, int>{};
    for (final t in [
      'products',
      'suppliers',
      'customers',
      'warehouses',
      'receipts',
      'deliveries',
      'op_headers'
    ]) {
      final r = await db.rawQuery('SELECT COUNT(*) c FROM $t');
      counts[t] = (r.first['c'] as num).toInt();
    }
    final meta = {
      'app': 'SANAD',
      'createdAt': AppUtils.nowStr(),
      'version': 1,
      'schemaVersion': Schema.version,
      'counts': counts,
    };
    final tmp = await Directory.systemTemp.createTemp('sanad_backup');
    final dbPath = p.join(await getDatabasesPath(), 'sanad.db');
    await File(dbPath).copy(p.join(tmp.path, 'sanad.db'));
    await File(p.join(tmp.path, 'settings.json'))
        .writeAsString(jsonEncode(settings));
    await File(p.join(tmp.path, 'sequences.json'))
        .writeAsString(jsonEncode(seqs));
    await File(p.join(tmp.path, 'meta.json'))
        .writeAsString(jsonEncode(meta));

    final dir = await storage.backupsDir();
    final name =
        'SANAD_BACKUP_${AppUtils.todayStr()}_${DateTime.now().millisecondsSinceEpoch}.sanad';
    final outPath = p.join(dir, name);
    final encoder = ZipFileEncoder();
    encoder.create(outPath);
    await encoder.addFile(File(p.join(tmp.path, 'sanad.db')), 'sanad.db');
    await encoder.addFile(
        File(p.join(tmp.path, 'settings.json')), 'settings.json');
    await encoder.addFile(
        File(p.join(tmp.path, 'sequences.json')), 'sequences.json');
    await encoder.addFile(File(p.join(tmp.path, 'meta.json')), 'meta.json');
    encoder.close();
    // نسخة خارجية للنقل لجهاز آخر
    final ext = await storage.externalSanadDir();
    if (ext != null) {
      try {
        await File(outPath).copy(p.join(ext, name));
      } catch (_) {}
    }
    return outPath;
  }

  Future<void> restoreBackup(File backupFile) async {
    final tmp = await Directory.systemTemp.createTemp('sanad_restore');
    final bytes = await backupFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final f in archive) {
      if (!f.isFile) continue;
      final out = File(p.join(tmp.path, f.name));
      await out.create(recursive: true);
      await out.writeAsBytes(f.content as List<int>);
    }
    final dbFile = File(p.join(tmp.path, 'sanad.db'));
    if (!await dbFile.exists()) {
      throw const AppFailure('ملف النسخة الاحتياطية غير صالح');
    }
    await DatabaseHelper.instance.close();
    final dbPath = p.join(await getDatabasesPath(), 'sanad.db');
    // نسخة أمان من القاعدة الحالية قبل الاستبدال
    try {
      final cur = File(dbPath);
      if (await cur.exists()) {
        await cur.copy('$dbPath.pre_restore_bak');
      }
    } catch (_) {}
    await dbFile.copy(dbPath);
    // أعد الفتح + طبّق schema الإصدار الحالي (ترحيل للأمام بعد التحديث:
    // جداول جديدة تُنشأ بـ IF NOT EXISTS والبيانات القديمة تبقى).
    final db = await DatabaseHelper.instance.db;
    try {
      for (final s in Schema.createStatements()) {
        try {
          await db.execute(s);
        } catch (_) {}
      }
      for (final t in ['products', 'receipts', 'deliveries']) {
        await db.rawQuery('SELECT COUNT(*) c FROM $t LIMIT 1');
      }
    } catch (e) {
      throw AppFailure(
          'تعذرت الاستعادة بعد التحديث — النسخة قد تكون تالفة: $e');
    }
  }
}
