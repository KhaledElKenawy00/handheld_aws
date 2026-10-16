import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/backup_service.dart';
import '../core/services/code_generator_service.dart';
import '../core/services/excel_export_service.dart';
import '../core/services/full_export_service.dart';
import '../core/services/archive_service.dart';
import '../core/services/import_service.dart';
import '../core/services/license_service.dart';
import '../core/services/pc_export_service.dart';
import '../core/services/pdf_service.dart';
import '../core/services/settings_service.dart';
import '../core/services/storage_service.dart';
import '../features/products/product_repositories.dart';
import '../features/receipts/voucher_repositories.dart';
import '../features/ops/ops_repository.dart';
import '../shared/models/entities.dart';
import 'pagination/pagination.dart';

/// مزودو الخدمات والمستودعات
final productRepoProvider = Provider((_) => ProductRepository());
final supplierRepoProvider = Provider((_) => SupplierRepository());
final customerRepoProvider = Provider((_) => CustomerRepository());
final receiptRepoProvider = Provider((_) => ReceiptRepository());
final deliveryRepoProvider = Provider((_) => DeliveryRepository());
final inventoryRepoProvider = Provider((_) => InventoryRepository());
final importServiceProvider = Provider((_) => ImportService());
final pdfServiceProvider = Provider((_) => PdfService());
final excelServiceProvider = Provider((_) => ExcelExportService());
final storageServiceProvider = Provider((_) => StorageService());
final fullExportServiceProvider = Provider((ref) => FullExportService(
      storage: ref.watch(storageServiceProvider),
      pdf: ref.watch(pdfServiceProvider),
      excel: ref.watch(excelServiceProvider),
    ));
final backupServiceProvider =
    Provider((ref) => BackupService(storage: ref.watch(storageServiceProvider)));
final settingsServiceProvider = Provider((_) => SettingsService());
final pcExportServiceProvider = Provider((_) => PcExportService());
final archiveServiceProvider = Provider((_) => ArchiveService());
final licenseServiceProvider = Provider((_) => LicenseService());
final docNumberServiceProvider = Provider((_) => DocumentNumberService());
final usersRepoProvider = Provider((_) => UsersRepo());
final warehouseRepoProvider = Provider((_) => WarehouseRepo());
final productCodeRepoProvider = Provider((_) => ProductCodeRepo());
final opsRepoProvider = Provider((_) => OpsRepo());

/// المستخدم الحالي بعد الدخول (null = غير مسجل).
final currentUserProvider = StateProvider<AppUser?>((_) => null);

/// Dashboard counts
final dashboardProvider = FutureProvider<Map<String, int>>((ref) async {
  final p = ref.watch(productRepoProvider);
  final s = ref.watch(supplierRepoProvider);
  final c = ref.watch(customerRepoProvider);
  final r = ref.watch(receiptRepoProvider);
  final d = ref.watch(deliveryRepoProvider);
  final i = ref.watch(inventoryRepoProvider);
  return {
    'products': await p.count(),
    'suppliers': await s.count(),
    'customers': await c.count(),
    'receipts': await r.count(),
    'deliveries': await d.count(),
    'inventory': await i.count(),
  };
});

/// بحث الأصناف — paginated: البحث يتم في قاعدة البيانات (SQL WHERE)
/// قبل LIMIT/OFFSET، فيشمل كل الصفوف وليس الصفحة الحالية فقط.
/// عند تغيير البحث يجب تصفير الصفحة (page=0) من الواجهة.
/// كل قائمة تُرجع PagedResult (عناصر الصفحة + الإجمالي معًا) في
/// Provider واحد — أي invalidate موجود يُحدّث الاثنين معًا.
final productQueryProvider = StateProvider<String>((_) => '');
final productPageProvider = StateProvider<int>((_) => 0);
final productListProvider =
    FutureProvider<PagedResult<dynamic>>((ref) async {
  final q = ref.watch(productQueryProvider);
  final page = ref.watch(productPageProvider);
  final repo = ref.watch(productRepoProvider);
  final res = await Future.wait([
    repo.search(q,
        limit: Pagination.defaultPageSize,
        offset: Pagination.offsetFor(page)),
    repo.count(q: q),
  ]);
  return PagedResult(items: res[0] as List<dynamic>, total: res[1] as int);
});

final supplierQueryProvider = StateProvider<String>((_) => '');
final supplierPageProvider = StateProvider<int>((_) => 0);
final supplierListProvider =
    FutureProvider<PagedResult<dynamic>>((ref) async {
  final q = ref.watch(supplierQueryProvider);
  final page = ref.watch(supplierPageProvider);
  final repo = ref.watch(supplierRepoProvider);
  final res = await Future.wait([
    repo.search(q,
        limit: Pagination.defaultPageSize,
        offset: Pagination.offsetFor(page)),
    repo.count(q: q),
  ]);
  return PagedResult(items: res[0] as List<dynamic>, total: res[1] as int);
});

final customerQueryProvider = StateProvider<String>((_) => '');
final customerPageProvider = StateProvider<int>((_) => 0);
final customerListProvider =
    FutureProvider<PagedResult<dynamic>>((ref) async {
  final q = ref.watch(customerQueryProvider);
  final page = ref.watch(customerPageProvider);
  final repo = ref.watch(customerRepoProvider);
  final res = await Future.wait([
    repo.search(q,
        limit: Pagination.defaultPageSize,
        offset: Pagination.offsetFor(page)),
    repo.count(q: q),
  ]);
  return PagedResult(items: res[0] as List<dynamic>, total: res[1] as int);
});

final receiptQueryProvider = StateProvider<String>((_) => '');
final receiptPageProvider = StateProvider<int>((_) => 0);
final receiptListProvider =
    FutureProvider<PagedResult<dynamic>>((ref) async {
  final q = ref.watch(receiptQueryProvider);
  final page = ref.watch(receiptPageProvider);
  final repo = ref.watch(receiptRepoProvider);
  final res = await Future.wait([
    repo.list(
        q: q,
        limit: Pagination.defaultPageSize,
        offset: Pagination.offsetFor(page)),
    repo.count(q: q),
  ]);
  return PagedResult(items: res[0] as List<dynamic>, total: res[1] as int);
});

final deliveryQueryProvider = StateProvider<String>((_) => '');
final deliveryPageProvider = StateProvider<int>((_) => 0);
final deliveryListProvider =
    FutureProvider<PagedResult<dynamic>>((ref) async {
  final q = ref.watch(deliveryQueryProvider);
  final page = ref.watch(deliveryPageProvider);
  final repo = ref.watch(deliveryRepoProvider);
  final res = await Future.wait([
    repo.list(
        q: q,
        limit: Pagination.defaultPageSize,
        offset: Pagination.offsetFor(page)),
    repo.count(q: q),
  ]);
  return PagedResult(items: res[0] as List<dynamic>, total: res[1] as int);
});

final inventoryQueryProvider = StateProvider<String>((_) => '');
final inventoryPageProvider = StateProvider<int>((_) => 0);
final inventoryListProvider =
    FutureProvider<PagedResult<dynamic>>((ref) async {
  final q = ref.watch(inventoryQueryProvider);
  final page = ref.watch(inventoryPageProvider);
  final repo = ref.watch(inventoryRepoProvider);
  final res = await Future.wait([
    repo.list(
        q: q,
        limit: Pagination.defaultPageSize,
        offset: Pagination.offsetFor(page)),
    repo.count(q: q),
  ]);
  return PagedResult(items: res[0] as List<dynamic>, total: res[1] as int);
});

final settingsMapProvider = FutureProvider<Map<String, String>>((ref) async {
  return ref.watch(settingsServiceProvider).all();
});
