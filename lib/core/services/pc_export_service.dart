import 'dart:io';
import 'dart:typed_data';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';
import '../utils/app_utils.dart';
import 'settings_service.dart';

/// بيانات الاتصال بالكمبيوتر عبر الشبكة المحلية (SMB).
/// يعمل مع ويندوز (مشاركة ملفات مدمجة) ولينكس (Samba) بنفس الإعدادات.
class PcSettings {
  final String host; // IP الكمبيوتر مثلا 192.168.1.50
  final String share; // اسم المشاركة مثلا sanad
  final String user;
  final String password;
  final String folder; // مجلد فرعي داخل المشاركة (اختياري) مثلا invoices
  const PcSettings({
    this.host = '',
    this.share = '',
    this.user = '',
    this.password = '',
    this.folder = '',
  });

  bool get isConfigured =>
      host.trim().isNotEmpty && share.trim().isNotEmpty;

  PcSettings copyWith({
    String? host,
    String? share,
    String? user,
    String? password,
    String? folder,
  }) =>
      PcSettings(
        host: host ?? this.host,
        share: share ?? this.share,
        user: user ?? this.user,
        password: password ?? this.password,
        folder: folder ?? this.folder,
      );
}

/// الإرسال للكمبيوتر عبر الشبكة المحلية (SMB2/3) — أوفلاين تمامًا،
/// بدون أي برنامج وسيط: الملف يترمي مباشرة في فولدر الكمبيوتر.
class PcExportService {
  final _settings = SettingsService();

  Future<PcSettings> load() async {
    final s = _settings;
    return PcSettings(
      host: (await s.get(AppConstants.kPcHost)) ?? '',
      share: (await s.get(AppConstants.kPcShare)) ?? '',
      user: (await s.get(AppConstants.kPcUser)) ?? '',
      password: (await s.get(AppConstants.kPcPass)) ?? '',
      folder: (await s.get(AppConstants.kPcFolder)) ?? '',
    );
  }

  Future<void> save(PcSettings c) async {
    final s = _settings;
    await s.set(AppConstants.kPcHost, c.host.trim());
    await s.set(AppConstants.kPcShare, c.share.trim());
    await s.set(AppConstants.kPcUser, c.user.trim());
    await s.set(AppConstants.kPcPass, c.password);
    await s.set(AppConstants.kPcFolder, c.folder.trim());
  }

  /// تطبيع مسار بعيد: شرطات أمامية فقط وبدون / بادئة.
  String _remote(String folder, String name) {
    final f = folder.trim().replaceAll('\\', '/');
    final clean = f.replaceAll(RegExp(r'^/+|/+$'), '');
    return clean.isEmpty ? name : '$clean/$name';
  }

  Future<Smb2Pool> _connect(PcSettings c) async {
    late final Smb2Pool pool;
    try {
      pool = await Smb2Pool.connect(
        host: c.host.trim(),
        share: c.share.trim(),
        user: c.user.trim().isEmpty ? null : c.user.trim(),
        password: c.password.isEmpty ? null : c.password,
        workers: 1,
        timeoutSeconds: 12,
      );
    } catch (e) {
      throw _friendly(e, phase: 'connect');
    }
    return pool;
  }

  /// اختبار الاتصال: اتصال + قراءة جذر المشاركة.
  Future<void> testConnection(PcSettings c) async {
    if (!c.isConfigured) {
      throw const AppFailure('ادخل IP الكمبيوتر واسم المشاركة أولًا');
    }
    final pool = await _connect(c);
    try {
      await pool.listDirectory('');
    } catch (e) {
      throw _friendly(e, phase: 'list');
    } finally {
      await pool.disconnect();
    }
  }

  /// رفع ملف محلي إلى فولدر الكمبيوتر (ينشئ المجلد الفرعي لو ناقص).
  /// يُرجع المسار البعيد.
  Future<String> uploadFile(File local,
      {String? remoteName, String? folder}) async {
    if (!await local.exists()) {
      throw AppFailure('الملف غير موجود: ${local.path}');
    }
    final c = await load();
    if (!c.isConfigured) {
      throw const AppFailure(
          'إعدادات الكمبيوتر ناقصة — ادخلها من شاشة الإعدادات أولًا');
    }
    final name = remoteName ?? p.basename(local.path);
    final dest = _remote(folder ?? c.folder, name);
    // المجلد الأب (لو فيه مجلد فرعي).
    final parent =
        dest.contains('/') ? dest.substring(0, dest.lastIndexOf('/')) : '';
    final pool = await _connect(c);
    try {
      if (parent.isNotEmpty) await ensureDir(pool, parent);
      final bytes = await local.readAsBytes();
      try {
        await pool.writeFile(
            dest, Uint8List.fromList(bytes));
      } catch (e) {
        throw _friendly(e, phase: 'write');
      }
    } finally {
      await pool.disconnect();
    }
    return '${c.share}/$dest';
  }

  /// إنشاء مجلد بعيد بمستوياته (Suppliers/الاسم) — يتخطى الموجود.
  static Future<void> ensureDir(Smb2Pool pool, String dir) async {
    final parts =
        dir.split('/').where((e) => e.trim().isNotEmpty).toList();
    var cur = '';
    for (final part in parts) {
      cur = cur.isEmpty ? part : '$cur/$part';
      try {
        if (!await pool.exists(cur)) await pool.mkdir(cur);
      } catch (_) {
        try {
          await pool.mkdir(cur);
        } catch (_) {}
      }
    }
  }

  /// رفع عدة ملفات باتصال واحد (للأرشفة) — [remoteToLocal] من
  /// المسار البعيد إلى الملف المحلي. الكتابة فوق الموجود (override).
  /// يُرجع عدد الملفات المرفوعة.
  Future<int> uploadFiles(
    Map<String, File> remoteToLocal, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (remoteToLocal.isEmpty) return 0;
    final c = await load();
    if (!c.isConfigured) {
      throw const AppFailure(
          'إعدادات الكمبيوتر ناقصة — ادخلها من شاشة الإعدادات أولًا');
    }
    final pool = await _connect(c);
    var done = 0;
    try {
      for (final e in remoteToLocal.entries) {
        final parent = e.key.contains('/')
            ? e.key.substring(0, e.key.lastIndexOf('/'))
            : '';
        if (parent.isNotEmpty) await ensureDir(pool, parent);
        final bytes = await e.value.readAsBytes();
        try {
          await pool.writeFile(
              e.key, Uint8List.fromList(bytes));
        } catch (err) {
          throw _friendly(err, phase: 'write');
        }
        done++;
        onProgress?.call(done, remoteToLocal.length);
      }
    } finally {
      await pool.disconnect();
    }
    return done;
  }

  AppFailure _friendly(Object e, {required String phase}) {
    if (e is Smb2Exception) {
      switch (e.type) {
        case Smb2ErrorType.auth:
          return AppFailure(
              'فشل الدخول للكمبيوتر — راجع اليوزر والباسورد (${e.message})');
        case Smb2ErrorType.timeout:
        case Smb2ErrorType.connection:
          return AppFailure(
              'تعذر الوصول للكمبيوتر — تأكد أنهما على نفس الشبكة وأن الـ IP صحيح وأن المشاركة مفعلة (${e.message})');
        case Smb2ErrorType.accessDenied:
          return const AppFailure(
              'مرفوض: اليوزر لا يملك صلاحية الكتابة على المشاركة');
        case Smb2ErrorType.diskFull:
          return const AppFailure('لا توجد مساحة على الكمبيوتر');
        case Smb2ErrorType.fileNotFound:
          if (phase == 'list') {
            return AppFailure(
                'المشاركة غير موجودة — راجع اسم المشاركة (${e.message})');
          }
          return AppFailure('مسار غير موجود (${e.message})');
        default:
          return AppFailure('خطأ شبكة: ${e.message}');
      }
    }
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('Connection refused') ||
        s.contains('Network is unreachable')) {
      return AppFailure(
          'تعذر الوصول للكمبيوتر — تأكد من الشبكة والـ IP ($s)');
    }
    return AppFailure('تعذر الإرسال للكمبيوتر: $s');
  }
}
