import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../utils/app_utils.dart';
import 'excel_export_service.dart';
import 'pdf_service.dart';
import 'storage_service.dart';
import '../../shared/models/entities.dart';

/// الباكب الشامل (النوع 2 = PDF / النوع 3 = Excel):
/// يصدّر كل البيانات: أصناف + موردين + عملاء + مخازن + أذون
/// (استلام/تسليم) + عمليات (مرتجع عميل/مورد + تحويل داخلي/خارجي)،
/// + فولدر باسم كل مورد جواه سجل تعاملاته كامل
/// + فولدر باسم كل عميل جواه سجل تعاملاته كامل،
/// ثم يضغط الكل في ZIP واحد للمشاركة/الاحتفاظ.
class FullExportService {
  final StorageService storage;
  final PdfService pdf;
  final ExcelExportService excel;
  FullExportService({
    StorageService? storage,
    PdfService? pdf,
    ExcelExportService? excel,
  })  : storage = storage ?? StorageService(),
        pdf = pdf ?? PdfService(),
        excel = excel ?? ExcelExportService();

  Future<String> _rootDir(String kind) async {
    final docs = await getApplicationDocumentsDirectory();
    final name =
        'SANAD_FULL_${kind}_${AppUtils.todayStr()}_${DateTime.now().millisecondsSinceEpoch}';
    final dir = Directory(p.join(docs.path, 'Exports', name));
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<List<Product>> _allProducts() async {
    final db = await DatabaseHelper.instance.db;
    final rows =
        await db.query('products', where: 'isActive=1', orderBy: 'code ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Supplier>> _allSuppliers() async {
    final db = await DatabaseHelper.instance.db;
    final rows =
        await db.query('suppliers', where: 'isActive=1', orderBy: 'code ASC');
    return rows.map(Supplier.fromMap).toList();
  }

  Future<List<Customer>> _allCustomers() async {
    final db = await DatabaseHelper.instance.db;
    final rows =
        await db.query('customers', where: 'isActive=1', orderBy: 'code ASC');
    return rows.map(Customer.fromMap).toList();
  }

  Future<List<ReceiptHeader>> _allReceipts() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('receipts', orderBy: 'date DESC, id DESC');
    return rows.map(ReceiptHeader.fromMap).toList();
  }

  Future<List<DeliveryHeader>> _allDeliveries() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('deliveries', orderBy: 'date DESC, id DESC');
    return rows.map(DeliveryHeader.fromMap).toList();
  }

  Future<List<Warehouse>> _allWarehouses() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('warehouses', orderBy: 'code ASC');
    return rows.map(Warehouse.fromMap).toList();
  }

  Future<List<OpHeader>> _allOps() async {
    final db = await DatabaseHelper.instance.db;
    final rows = await db.query('op_headers', orderBy: 'date DESC, id DESC');
    return rows.map(OpHeader.fromMap).toList();
  }

  Future<Map<String, List<OpItem>>> _opItemsById(List<String> ids) async {
    final db = await DatabaseHelper.instance.db;
    final map = <String, List<OpItem>>{};
    for (final id in ids) {
      final rows =
          await db.query('op_items', where: 'opId=?', whereArgs: [id]);
      map[id] = rows.map(OpItem.fromMap).toList();
    }
    return map;
  }

  Future<Map<String, List<ReceiptItem>>> _receiptItemsById(
      List<String> ids) async {
    final db = await DatabaseHelper.instance.db;
    final map = <String, List<ReceiptItem>>{};
    for (final id in ids) {
      final rows = await db
          .query('receipt_items', where: 'receiptId=?', whereArgs: [id]);
      map[id] = rows.map(ReceiptItem.fromMap).toList();
    }
    return map;
  }

  Future<Map<String, List<DeliveryItem>>> _deliveryItemsById(
      List<String> ids) async {
    final db = await DatabaseHelper.instance.db;
    final map = <String, List<DeliveryItem>>{};
    for (final id in ids) {
      final rows = await db
          .query('delivery_items', where: 'deliveryId=?', whereArgs: [id]);
      map[id] = rows.map(DeliveryItem.fromMap).toList();
    }
    return map;
  }

  /// اسم فولدر آمن من اسم العميل/المورد (بدون محارف ممنوعة في
  /// الملفات) — مع تجنب التكرار بإضافة الكود عند الحاجة.
  /// عامة وثابتة حتى تستخدمها الأرشفة بنفس التسمية (نفس الفولدرات).
  static String partnerFolderName(
      String desc, String code, Set<String> used) {
    var base = desc
        .trim()
        .replaceAll(RegExp(r'[\\/:\*\?"<>\|]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (base.isEmpty) base = code;
    var out = base;
    if (used.contains(out)) out = '$base ($code)';
    var i = 2;
    while (used.contains(out) && i < 100) {
      out = '$base ($code-$i)';
      i++;
    }
    used.add(out);
    return out;
  }

  String _partnerDirName(String desc, String code, Set<String> used) =>
      partnerFolderName(desc, code, used);

  Future<String> _zipDir(String dirPath) async {
    final zipPath = '$dirPath.zip';
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    await encoder.addDirectory(Directory(dirPath));
    encoder.close();
    // نسخة خارجية للنقل
    try {
      final ext = await storage.externalSanadDir();
      if (ext != null) {
        await File(zipPath).copy(p.join(ext, p.basename(zipPath)));
      }
    } catch (_) {}
    return zipPath;
  }

  /// تصدير شامل PDF — يرجع مسار الـ ZIP
  Future<String> exportAllPdf({void Function(String)? onStep}) async {
    final root = await _rootDir('PDF');
    final products = await _allProducts();
    final suppliers = await _allSuppliers();
    final customers = await _allCustomers();
    final warehouses = await _allWarehouses();
    final receipts = await _allReceipts();
    final deliveries = await _allDeliveries();
    final ops = await _allOps();

    onStep?.call('الأصناف والموردين والعملاء والمخازن...');
    await pdf.productsListPdf(products, root);
    await pdf.suppliersListPdf(suppliers, root);
    await pdf.customersListPdf(customers, root);
    await pdf.warehousesListPdf(warehouses, root);
    await pdf.receiptsListPdf(receipts, root);
    await pdf.deliveriesListPdf(deliveries, root);
    await pdf.opsListPdf(ops, root);

    onStep?.call('ملفات الموردين...');
    final supDir = Directory(p.join(root, 'Suppliers'));
    await supDir.create(recursive: true);
    final usedSup = <String>{};
    for (final s in suppliers) {
      final db = await DatabaseHelper.instance.db;
      final hRows = await db.query('receipts',
          where: 'supplierCode=?',
          whereArgs: [s.code],
          orderBy: 'date DESC, id DESC');
      final headers = hRows.map(ReceiptHeader.fromMap).toList();
      final items =
          await _receiptItemsById(headers.map((e) => e.id).toList());
      // فولدر باسم المورد جواه سجل تعاملاته كامل.
      final dir = Directory(p.join(
          supDir.path, _partnerDirName(s.desc, s.code, usedSup)));
      await dir.create(recursive: true);
      await pdf.supplierDossierPdf(s, headers, items, dir.path);
    }

    onStep?.call('ملفات العملاء...');
    final cusDir = Directory(p.join(root, 'Customers'));
    await cusDir.create(recursive: true);
    final usedCus = <String>{};
    for (final c in customers) {
      final db = await DatabaseHelper.instance.db;
      final hRows = await db.query('deliveries',
          where: 'customerCode=?',
          whereArgs: [c.code],
          orderBy: 'date DESC, id DESC');
      final headers = hRows.map(DeliveryHeader.fromMap).toList();
      final items =
          await _deliveryItemsById(headers.map((e) => e.id).toList());
      // فولدر باسم العميل جواه سجل تعاملاته كامل.
      final dir = Directory(p.join(
          cusDir.path, _partnerDirName(c.desc, c.code, usedCus)));
      await dir.create(recursive: true);
      await pdf.customerDossierPdf(c, headers, items, dir.path);
    }

    onStep?.call('الضغط...');
    return _zipDir(root);
  }

  /// تصدير شامل Excel — يرجع مسار الـ ZIP
  Future<String> exportAllExcel({void Function(String)? onStep}) async {
    final root = await _rootDir('EXCEL');
    final products = await _allProducts();
    final suppliers = await _allSuppliers();
    final customers = await _allCustomers();
    final warehouses = await _allWarehouses();
    final receipts = await _allReceipts();
    final deliveries = await _allDeliveries();
    final ops = await _allOps();

    onStep?.call('الأصناف والموردين والعملاء والمخازن...');
    await excel.exportProductsList(products, root);
    await excel.exportSuppliersList(suppliers, root);
    await excel.exportCustomersList(customers, root);
    await excel.exportWarehousesList(warehouses, root);
    final rItems =
        await _receiptItemsById(receipts.map((e) => e.id).toList());
    await excel.exportReceiptsListWithItems(receipts, rItems, root);
    final dItems =
        await _deliveryItemsById(deliveries.map((e) => e.id).toList());
    await excel.exportDeliveriesListWithItems(deliveries, dItems, root);
    final oItems = await _opItemsById(ops.map((e) => e.id).toList());
    await excel.exportOpsListWithItems(ops, oItems, root);

    onStep?.call('ملفات الموردين...');
    final db = await DatabaseHelper.instance.db;
    final supDir = Directory(p.join(root, 'Suppliers'));
    await supDir.create(recursive: true);
    final usedSupX = <String>{};
    for (final s in suppliers) {
      final hRows = await db.query('receipts',
          where: 'supplierCode=?',
          whereArgs: [s.code],
          orderBy: 'date DESC, id DESC');
      final headers = hRows.map(ReceiptHeader.fromMap).toList();
      final items =
          await _receiptItemsById(headers.map((e) => e.id).toList());
      final dir = Directory(p.join(
          supDir.path, _partnerDirName(s.desc, s.code, usedSupX)));
      await dir.create(recursive: true);
      await excel.supplierDossierExcel(s, headers, items, dir.path);
    }

    onStep?.call('ملفات العملاء...');
    final cusDir = Directory(p.join(root, 'Customers'));
    await cusDir.create(recursive: true);
    final usedCusX = <String>{};
    for (final c in customers) {
      final hRows = await db.query('deliveries',
          where: 'customerCode=?',
          whereArgs: [c.code],
          orderBy: 'date DESC, id DESC');
      final headers = hRows.map(DeliveryHeader.fromMap).toList();
      final items =
          await _deliveryItemsById(headers.map((e) => e.id).toList());
      final dir = Directory(p.join(
          cusDir.path, _partnerDirName(c.desc, c.code, usedCusX)));
      await dir.create(recursive: true);
      await excel.customerDossierExcel(c, headers, items, dir.path);
    }

    onStep?.call('الضغط...');
    return _zipDir(root);
  }

  // ---------- ملف مورد/عميل واحد (من صفحة التفاصيل) ----------

  Future<String> supplierDossierPdf(String code, String name) async {
    final db = await DatabaseHelper.instance.db;
    final sRow =
        await db.query('suppliers', where: 'code=?', whereArgs: [code]);
    final s = sRow.isEmpty
        ? Supplier(code: code, desc: name)
        : Supplier.fromMap(sRow.first);
    final hRows = await db.query('receipts',
        where: 'supplierCode=?',
        whereArgs: [code],
        orderBy: 'date DESC, id DESC');
    final headers = hRows.map(ReceiptHeader.fromMap).toList();
    final items =
        await _receiptItemsById(headers.map((e) => e.id).toList());
    final folder = await storage.supplierReceiptsDir(code, name);
    return pdf.supplierDossierPdf(s, headers, items, folder);
  }

  Future<String> supplierDossierExcel(String code, String name) async {
    final db = await DatabaseHelper.instance.db;
    final sRow =
        await db.query('suppliers', where: 'code=?', whereArgs: [code]);
    final s = sRow.isEmpty
        ? Supplier(code: code, desc: name)
        : Supplier.fromMap(sRow.first);
    final hRows = await db.query('receipts',
        where: 'supplierCode=?',
        whereArgs: [code],
        orderBy: 'date DESC, id DESC');
    final headers = hRows.map(ReceiptHeader.fromMap).toList();
    final items =
        await _receiptItemsById(headers.map((e) => e.id).toList());
    final folder = await storage.supplierReceiptsDir(code, name);
    return excel.supplierDossierExcel(s, headers, items, folder);
  }

  Future<String> customerDossierPdf(String code, String name) async {
    final db = await DatabaseHelper.instance.db;
    final cRow =
        await db.query('customers', where: 'code=?', whereArgs: [code]);
    final c = cRow.isEmpty
        ? Customer(code: code, desc: name)
        : Customer.fromMap(cRow.first);
    final hRows = await db.query('deliveries',
        where: 'customerCode=?',
        whereArgs: [code],
        orderBy: 'date DESC, id DESC');
    final headers = hRows.map(DeliveryHeader.fromMap).toList();
    final items =
        await _deliveryItemsById(headers.map((e) => e.id).toList());
    final folder = await storage.customerDeliveriesDir(code, name);
    return pdf.customerDossierPdf(c, headers, items, folder);
  }

  Future<String> customerDossierExcel(String code, String name) async {
    final db = await DatabaseHelper.instance.db;
    final cRow =
        await db.query('customers', where: 'code=?', whereArgs: [code]);
    final c = cRow.isEmpty
        ? Customer(code: code, desc: name)
        : Customer.fromMap(cRow.first);
    final hRows = await db.query('deliveries',
        where: 'customerCode=?',
        whereArgs: [code],
        orderBy: 'date DESC, id DESC');
    final headers = hRows.map(DeliveryHeader.fromMap).toList();
    final items =
        await _deliveryItemsById(headers.map((e) => e.id).toList());
    final folder = await storage.customerDeliveriesDir(code, name);
    return excel.customerDossierExcel(c, headers, items, folder);
  }
}
