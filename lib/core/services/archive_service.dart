import 'dart:io';

import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../utils/app_utils.dart';
import '../../features/ops/ops_repository.dart';
import '../../features/receipts/voucher_repositories.dart';
import '../../shared/models/entities.dart';
import 'full_export_service.dart';
import 'pc_export_service.dart';
import 'settings_service.dart';

/// ملخص عملية أرشفة واحدة.
class ArchiveSummary {
  final int suppliers;
  final int customers;
  final int files;
  final int deliveries;
  final int receipts;
  final int returns;
  const ArchiveSummary({
    this.suppliers = 0,
    this.customers = 0,
    this.files = 0,
    this.deliveries = 0,
    this.receipts = 0,
    this.returns = 0,
  });
}

/// الأرشفة الأسبوعية التلقائية:
/// بعد ربط الكمبيوتر، كل 7 أيام تُرفع دوسيهات العملاء والموردين
/// (PDF + Excel) فوق فولدراتهم الموجودة على الكمبيوتر (override —
/// بدون ZIP، والبروفايل يفضل كاملًا)، ثم تُمسح أذون التسليم
/// والاستلام والمرتجعات فقط (بدون عكس المخزون وبدون مساس
/// بالأصناف/العملاء/الموردين/التحويلات).
class ArchiveService {
  final FullExportService full;
  final PcExportService pc;
  final SettingsService settings;
  final DeliveryRepository deliveries;
  final ReceiptRepository receipts;
  final OpsRepo ops;
  ArchiveService({
    FullExportService? full,
    PcExportService? pc,
    SettingsService? settings,
    DeliveryRepository? deliveries,
    ReceiptRepository? receipts,
    OpsRepo? ops,
  })  : full = full ?? FullExportService(),
        pc = pc ?? PcExportService(),
        settings = settings ?? SettingsService(),
        deliveries = deliveries ?? DeliveryRepository(),
        receipts = receipts ?? ReceiptRepository(),
        ops = ops ?? OpsRepo();

  bool _running = false;

  /// هل حان موعد الأرشفة؟ (إعدادات الكمبيوتر مربوطة + مر 7 أيام).
  /// أول تشغيل بعد الربط يؤرّخ اليوم كبداية بدون تنفيذ.
  Future<bool> isDue() async {
    final c = await pc.load();
    if (!c.isConfigured) return false;
    final last =
        (await settings.get(AppConstants.kLastAutoArchive))?.trim() ?? '';
    if (last.isEmpty) {
      await settings.set(
          AppConstants.kLastAutoArchive, AppUtils.todayStr());
      return false;
    }
    final prev = DateTime.tryParse(last);
    if (prev == null) return false;
    return DateTime.now().difference(prev).inDays >=
        AppConstants.autoArchiveEveryDays;
  }

  /// تنفيذ عند الاستحقاق فقط — يُرجع null لو لا شيء يُعمل.
  Future<ArchiveSummary?> runIfDue(
      {void Function(String step)? onStep}) async {
    if (_running) return null;
    if (!await isDue()) return null;
    return runNow(onStep: onStep);
  }

  /// تنفيذ فوري (لزرار "أرشفة الآن").
  Future<ArchiveSummary> runNow(
      {void Function(String step)? onStep}) async {
    if (_running) {
      throw const AppFailure('الأرشفة شغالة بالفعل');
    }
    final c = await pc.load();
    if (!c.isConfigured) {
      throw const AppFailure(
          'اظبط إعدادات الإرسال للكمبيوتر أولًا');
    }
    _running = true;
    try {
      final db = await DatabaseHelper.instance.db;
      final supRows = await db.query('suppliers',
          where: 'isActive=1', orderBy: 'code ASC');
      final cusRows = await db.query('customers',
          where: 'isActive=1', orderBy: 'code ASC');
      final sups = supRows.map(Supplier.fromMap).toList();
      final cuss = cusRows.map(Customer.fromMap).toList();

      // 1) توليد الدوسيهات (PDF + Excel) لكل طرف.
      final files = <String, File>{};
      final usedSup = <String>{};
      final usedCus = <String>{};
      var i = 0;
      for (final s in sups) {
        onStep?.call(
            'تجهيز ${s.desc} (${++i}/${sups.length + cuss.length})...');
        final folder =
            'Suppliers/${FullExportService.partnerFolderName(s.desc, s.code, usedSup)}';
        final pdfPath = await full.supplierDossierPdf(s.code, s.desc);
        files['$folder/${p.basename(pdfPath)}'] = File(pdfPath);
        final xlsPath =
            await full.supplierDossierExcel(s.code, s.desc);
        files['$folder/${p.basename(xlsPath)}'] = File(xlsPath);
      }
      for (final cu in cuss) {
        onStep?.call(
            'تجهيز ${cu.desc} (${++i}/${sups.length + cuss.length})...');
        final folder =
            'Customers/${FullExportService.partnerFolderName(cu.desc, cu.code, usedCus)}';
        final pdfPath = await full.customerDossierPdf(cu.code, cu.desc);
        files['$folder/${p.basename(pdfPath)}'] = File(pdfPath);
        final xlsPath =
            await full.customerDossierExcel(cu.code, cu.desc);
        files['$folder/${p.basename(xlsPath)}'] = File(xlsPath);
      }

      // 2) الرفع فوق الفولدرات الموجودة (override — بدون ZIP).
      onStep?.call('الرفع للكمبيوتر...');
      await pc.uploadFiles(files,
          onProgress: (done, total) =>
              onStep?.call('الرفع للكمبيوتر... ($done/$total)'));

      // 3) مسح الأذون فقط (تسليمات + استلامات + مرتجعات).
      onStep?.call('مسح الأذون المؤرشفة...');
      final delCount = await deliveries.deleteAllVouchers();
      final recCount = await receipts.deleteAllVouchers();
      final retCount =
          await ops.deleteByKinds(['مرتجع عميل', 'مرتجع مورد']);

      await settings.set(
          AppConstants.kLastAutoArchive, AppUtils.todayStr());
      return ArchiveSummary(
        suppliers: sups.length,
        customers: cuss.length,
        files: files.length,
        deliveries: delCount,
        receipts: recCount,
        returns: retCount,
      );
    } finally {
      _running = false;
    }
  }
}
