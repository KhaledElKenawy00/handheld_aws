import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../utils/app_utils.dart';

/// تنظيم المجلدات المنطقي + مسارات آمنة عبر path_provider
/// Suppliers/SUP-000001_الاسم/Receipts/...
class StorageService {
  Future<Directory> _docs() => getApplicationDocumentsDirectory();

  String _safe(String code, String name) =>
      AppUtils.sanitizeFileName('${code}_${name.trim()}');

  Future<String> supplierReceiptsDir(String code, String name) async {
    final base = await _docs();
    final dir = Directory(p.join(base.path, AppConstants.dirSuppliers,
        _safe(code, name), AppConstants.dirReceipts));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> customerDeliveriesDir(String code, String name) async {
    final base = await _docs();
    final dir = Directory(p.join(base.path, AppConstants.dirCustomers,
        _safe(code, name), AppConstants.dirDeliveries));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> inventoryDir(String date) async {
    final base = await _docs();
    final dir = Directory(p.join(
        base.path, AppConstants.dirInventory, AppUtils.sanitizeFileName(date)));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> backupsDir() async {
    final base = await _docs();
    final dir =
        Directory(p.join(base.path, AppConstants.dirBackups));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// مسار خارجي للمشاركة/النقل إلى جهاز SUNMI آخر (Download/SANAD)
  Future<String?> externalSanadDir() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext == null) return null;
      // /storage/emulated/0/Android/data/<pkg>/files -> نستخدمه مباشرة
      final dir = Directory(p.join(ext.path, 'SANAD'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    } catch (_) {
      return null;
    }
  }
}
