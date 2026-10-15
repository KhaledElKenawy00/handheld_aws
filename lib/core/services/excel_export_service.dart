import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/models/entities.dart';

/// تصدير أي مستند إلى Excel مرتب
class ExcelExportService {
  Future<Directory> _baseDir() async {
    final d = await getApplicationDocumentsDirectory();
    return d;
  }

  Future<String> exportReceipt(
      ReceiptHeader h, List<ReceiptItem> items, String folderPath) async {
    final xls = Excel.createExcel();
    final s = xls['Receipt'];
    s.appendRow([
      TextCellValue('Document Number'),
      TextCellValue(h.id),
    ]);
    s.appendRow([TextCellValue('Date'), TextCellValue(h.date)]);
    s.appendRow([TextCellValue('Partner Code'), TextCellValue(h.supplierCode)]);
    s.appendRow([TextCellValue('Partner Name'), TextCellValue(h.supplierName)]);
    s.appendRow([TextCellValue('Type'), TextCellValue('Receipt - إذن استلام')]);
    s.appendRow([]);
    s.appendRow([
      TextCellValue('Product Code'),
      TextCellValue('Product Name'),
      TextCellValue('Quantity'),
    ]);
    for (final it in items) {
      s.appendRow([
        TextCellValue(it.productCode),
        TextCellValue(it.productName),
        DoubleCellValue(it.quantity.toDouble()),
      ]);
    }
    s.appendRow([]);
    s.appendRow([
      TextCellValue('Total Items'),
      IntCellValue(items.length),
      DoubleCellValue(items.fold(0.0, (a, b) => a + b.quantity)),
    ]);
    final dir = Directory(folderPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${h.id}.xlsx'));
    await file.writeAsBytes(xls.encode()!);
    return file.path;
  }

  Future<String> exportDelivery(
      DeliveryHeader h, List<DeliveryItem> items, String folderPath) async {
    final xls = Excel.createExcel();
    final s = xls['Delivery'];
    s.appendRow([TextCellValue('Document Number'), TextCellValue(h.id)]);
    s.appendRow([TextCellValue('Date'), TextCellValue(h.date)]);
    s.appendRow([TextCellValue('Partner Code'), TextCellValue(h.customerCode)]);
    s.appendRow([TextCellValue('Partner Name'), TextCellValue(h.customerName)]);
    s.appendRow([TextCellValue('Type'), TextCellValue('Delivery - إذن تسليم')]);
    s.appendRow([]);
    s.appendRow([
      TextCellValue('Product Code'),
      TextCellValue('Product Name'),
      TextCellValue('Quantity'),
    ]);
    for (final it in items) {
      s.appendRow([
        TextCellValue(it.productCode),
        TextCellValue(it.productName),
        DoubleCellValue(it.quantity.toDouble()),
      ]);
    }
    final dir = Directory(folderPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${h.id}.xlsx'));
    await file.writeAsBytes(xls.encode()!);
    return file.path;
  }

  Future<String> exportInventory(InventorySession s, List<InventoryItem> items,
      String folderPath) async {
    final xls = Excel.createExcel();
    final sh = xls['Inventory'];
    sh.appendRow([TextCellValue('Inventory Number'), TextCellValue(s.id)]);
    sh.appendRow([TextCellValue('Date'), TextCellValue(s.date)]);
    sh.appendRow([]);
    sh.appendRow([
      TextCellValue('Code'),
      TextCellValue('Description'),
      TextCellValue('Expected'),
      TextCellValue('Actual'),
      TextCellValue('Difference'),
      TextCellValue('Status'),
    ]);
    for (final it in items) {
      sh.appendRow([
        TextCellValue(it.productCode),
        TextCellValue(it.productName),
        DoubleCellValue(it.expectedQty),
        DoubleCellValue(it.actualQty),
        DoubleCellValue(it.difference),
        TextCellValue(it.statusAr),
      ]);
    }
    final dir = Directory(folderPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${s.id}.xlsx'));
    await file.writeAsBytes(xls.encode()!);
    return file.path;
  }

  Future<String> _saveXls(Excel xls, String folder, String name) async {
    final dir = Directory(folder);
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(xls.encode()!);
    return file.path;
  }

  /// قوائم شاملة للباكب الكامل
  Future<String> exportProductsList(
          List<Product> ps, String folder) async {
    final xls = Excel.createExcel();
    final s = xls['Products'];
    s.appendRow([
      TextCellValue('Code'),
      TextCellValue('Name'),
      TextCellValue('Stock'),
    ]);
    for (final e in ps) {
      s.appendRow([
        TextCellValue(e.code),
        TextCellValue(e.desc),
        DoubleCellValue(e.stock),
      ]);
    }
    return _saveXls(xls, folder, 'products.xlsx');
  }

  Future<String> exportSuppliersList(
          List<Supplier> ss, String folder) async {
    final xls = Excel.createExcel();
    final s = xls['Suppliers'];
    s.appendRow([TextCellValue('Code'), TextCellValue('Name')]);
    for (final e in ss) {
      s.appendRow([TextCellValue(e.code), TextCellValue(e.desc)]);
    }
    return _saveXls(xls, folder, 'suppliers.xlsx');
  }

  Future<String> exportCustomersList(
          List<Customer> cs, String folder) async {
    final xls = Excel.createExcel();
    final s = xls['Customers'];
    s.appendRow([TextCellValue('Code'), TextCellValue('Name')]);
    for (final e in cs) {
      s.appendRow([TextCellValue(e.code), TextCellValue(e.desc)]);
    }
    return _saveXls(xls, folder, 'customers.xlsx');
  }

  Future<String> exportWarehousesList(
          List<Warehouse> ws, String folder) async {
    final xls = Excel.createExcel();
    final s = xls['Warehouses'];
    s.appendRow([TextCellValue('Code'), TextCellValue('Name')]);
    for (final e in ws) {
      s.appendRow([TextCellValue(e.code), TextCellValue(e.name)]);
    }
    return _saveXls(xls, folder, 'warehouses.xlsx');
  }

  Future<String> exportOpsListWithItems(
    List<OpHeader> hs,
    Map<String, List<OpItem>> itemsById,
    String folder,
  ) async {
    final xls = Excel.createExcel();
    final s = xls['Operations'];
    s.appendRow([
      TextCellValue('Kind'),
      TextCellValue('Number'),
      TextCellValue('Party Type'),
      TextCellValue('Party Code'),
      TextCellValue('Party Name'),
      TextCellValue('Date'),
      TextCellValue('Items'),
      TextCellValue('Total Qty'),
    ]);
    for (final h in hs) {
      s.appendRow([
        TextCellValue(h.kind),
        IntCellValue(h.number),
        TextCellValue(h.partyType),
        TextCellValue(h.partyCode),
        TextCellValue(h.partyName),
        TextCellValue(h.date),
        IntCellValue(h.totalItems),
        DoubleCellValue(h.totalQty),
      ]);
    }
    final det = xls['OpItems'];
    det.appendRow([
      TextCellValue('Operation'),
      TextCellValue('Product Code'),
      TextCellValue('Product Name'),
      TextCellValue('Qty'),
    ]);
    for (final h in hs) {
      for (final it in (itemsById[h.id] ?? const <OpItem>[])) {
        det.appendRow([
          TextCellValue(h.id),
          TextCellValue(it.productCode),
          TextCellValue(it.productName),
          DoubleCellValue(it.quantity),
        ]);
      }
    }
    return _saveXls(xls, folder, 'operations.xlsx');
  }

  Future<String> exportReceiptsList(
          List<ReceiptHeader> hs, String folder) async {
    final xls = Excel.createExcel();
    final s = xls['Receipts'];
    s.appendRow([
      TextCellValue('Number'),
      TextCellValue('Supplier Code'),
      TextCellValue('Supplier Name'),
      TextCellValue('Date'),
      TextCellValue('Items'),
      TextCellValue('Total Qty'),
    ]);
    for (final h in hs) {
      s.appendRow([
        TextCellValue(h.id),
        TextCellValue(h.supplierCode),
        TextCellValue(h.supplierName),
        TextCellValue(h.date),
        IntCellValue(h.totalItems),
        DoubleCellValue(h.totalQty),
      ]);
    }
    final det = xls['ReceiptItems'];
    det.appendRow([
      TextCellValue('Receipt'),
      TextCellValue('Product Code'),
      TextCellValue('Product Name'),
      TextCellValue('Qty'),
    ]);
    return _saveXls(xls, folder, 'receipts.xlsx');
  }

  Future<String> exportReceiptsListWithItems(
    List<ReceiptHeader> hs,
    Map<String, List<ReceiptItem>> itemsById,
    String folder,
  ) async {
    final xls = Excel.createExcel();
    final s = xls['Receipts'];
    s.appendRow([
      TextCellValue('Number'),
      TextCellValue('Supplier Code'),
      TextCellValue('Supplier Name'),
      TextCellValue('Date'),
      TextCellValue('Items'),
      TextCellValue('Total Qty'),
    ]);
    for (final h in hs) {
      s.appendRow([
        TextCellValue(h.id),
        TextCellValue(h.supplierCode),
        TextCellValue(h.supplierName),
        TextCellValue(h.date),
        IntCellValue(h.totalItems),
        DoubleCellValue(h.totalQty),
      ]);
    }
    final det = xls['ReceiptItems'];
    det.appendRow([
      TextCellValue('Receipt'),
      TextCellValue('Product Code'),
      TextCellValue('Product Name'),
      TextCellValue('Qty'),
    ]);
    for (final h in hs) {
      for (final it in (itemsById[h.id] ?? const <ReceiptItem>[])) {
        det.appendRow([
          TextCellValue(h.id),
          TextCellValue(it.productCode),
          TextCellValue(it.productName),
          DoubleCellValue(it.quantity),
        ]);
      }
    }
    return _saveXls(xls, folder, 'receipts.xlsx');
  }

  Future<String> exportDeliveriesListWithItems(
    List<DeliveryHeader> hs,
    Map<String, List<DeliveryItem>> itemsById,
    String folder,
  ) async {
    final xls = Excel.createExcel();
    final s = xls['Deliveries'];
    s.appendRow([
      TextCellValue('Number'),
      TextCellValue('Customer Code'),
      TextCellValue('Customer Name'),
      TextCellValue('Date'),
      TextCellValue('Items'),
      TextCellValue('Total Qty'),
    ]);
    for (final h in hs) {
      s.appendRow([
        TextCellValue(h.id),
        TextCellValue(h.customerCode),
        TextCellValue(h.customerName),
        TextCellValue(h.date),
        IntCellValue(h.totalItems),
        DoubleCellValue(h.totalQty),
      ]);
    }
    final det = xls['DeliveryItems'];
    det.appendRow([
      TextCellValue('Delivery'),
      TextCellValue('Product Code'),
      TextCellValue('Product Name'),
      TextCellValue('Qty'),
    ]);
    for (final h in hs) {
      for (final it in (itemsById[h.id] ?? const <DeliveryItem>[])) {
        det.appendRow([
          TextCellValue(h.id),
          TextCellValue(it.productCode),
          TextCellValue(it.productName),
          DoubleCellValue(it.quantity),
        ]);
      }
    }
    return _saveXls(xls, folder, 'deliveries.xlsx');
  }

  Future<String> exportInventorySessions(
      List<InventorySession> ss,
      Map<String, List<InventoryItem>> itemsBySession,
      String folder) async {
    final xls = Excel.createExcel();
    final s = xls['Sessions'];
    s.appendRow([
      TextCellValue('Number'),
      TextCellValue('Date'),
      TextCellValue('Status'),
    ]);
    for (final e in ss) {
      s.appendRow([
        TextCellValue(e.id),
        TextCellValue(e.date),
        TextCellValue(e.status),
      ]);
    }
    final det = xls['Items'];
    det.appendRow([
      TextCellValue('Session'),
      TextCellValue('Code'),
      TextCellValue('Name'),
      TextCellValue('Expected'),
      TextCellValue('Actual'),
      TextCellValue('Diff'),
    ]);
    itemsBySession.forEach((sid, items) {
      for (final it in items) {
        det.appendRow([
          TextCellValue(sid),
          TextCellValue(it.productCode),
          TextCellValue(it.productName),
          DoubleCellValue(it.expectedQty),
          DoubleCellValue(it.actualQty),
          DoubleCellValue(it.difference),
        ]);
      }
    });
    return _saveXls(xls, folder, 'inventory.xlsx');
  }

  /// ملف المورد الشامل Excel: ملخص + كل الأذون + كل الأصناف
  Future<String> supplierDossierExcel(
    Supplier s,
    List<ReceiptHeader> headers,
    Map<String, List<ReceiptItem>> itemsByReceipt,
    String folder,
  ) async {
    final xls = Excel.createExcel();
    final sum = xls['Summary'];
    sum.appendRow([TextCellValue('Supplier Code'), TextCellValue(s.code)]);
    sum.appendRow([TextCellValue('Supplier Name'), TextCellValue(s.desc)]);
    sum.appendRow(
        [TextCellValue('Receipts Count'), IntCellValue(headers.length)]);
    sum.appendRow([
      TextCellValue('Total Qty'),
      DoubleCellValue(headers.fold(0.0, (a, h) => a + h.totalQty))
    ]);
    sum.appendRow([]);
    final h = xls['Receipts'];
    h.appendRow([
      TextCellValue('Number'),
      TextCellValue('Date'),
      TextCellValue('Items'),
      TextCellValue('Total Qty'),
    ]);
    for (final r in headers) {
      h.appendRow([
        TextCellValue(r.id),
        TextCellValue(r.date),
        IntCellValue(r.totalItems),
        DoubleCellValue(r.totalQty),
      ]);
    }
    final det = xls['Items'];
    det.appendRow([
      TextCellValue('Receipt'),
      TextCellValue('Date'),
      TextCellValue('Product Code'),
      TextCellValue('Product Name'),
      TextCellValue('Qty'),
    ]);
    for (final r in headers) {
      for (final it in (itemsByReceipt[r.id] ?? const <ReceiptItem>[])) {
        det.appendRow([
          TextCellValue(r.id),
          TextCellValue(r.date),
          TextCellValue(it.productCode),
          TextCellValue(it.productName),
          DoubleCellValue(it.quantity),
        ]);
      }
    }
    return _saveXls(xls, folder, 'مورد_${s.code}.xlsx');
  }

  /// ملف العميل الشامل Excel
  Future<String> customerDossierExcel(
    Customer c,
    List<DeliveryHeader> headers,
    Map<String, List<DeliveryItem>> itemsByDelivery,
    String folder,
  ) async {
    final xls = Excel.createExcel();
    final sum = xls['Summary'];
    sum.appendRow([TextCellValue('Customer Code'), TextCellValue(c.code)]);
    sum.appendRow([TextCellValue('Customer Name'), TextCellValue(c.desc)]);
    sum.appendRow(
        [TextCellValue('Deliveries Count'), IntCellValue(headers.length)]);
    sum.appendRow([
      TextCellValue('Total Qty'),
      DoubleCellValue(headers.fold(0.0, (a, h) => a + h.totalQty))
    ]);
    sum.appendRow([]);
    final h = xls['Deliveries'];
    h.appendRow([
      TextCellValue('Number'),
      TextCellValue('Date'),
      TextCellValue('Items'),
      TextCellValue('Total Qty'),
    ]);
    for (final r in headers) {
      h.appendRow([
        TextCellValue(r.id),
        TextCellValue(r.date),
        IntCellValue(r.totalItems),
        DoubleCellValue(r.totalQty),
      ]);
    }
    final det = xls['Items'];
    det.appendRow([
      TextCellValue('Delivery'),
      TextCellValue('Date'),
      TextCellValue('Product Code'),
      TextCellValue('Product Name'),
      TextCellValue('Qty'),
    ]);
    for (final r in headers) {
      for (final it in (itemsByDelivery[r.id] ?? const <DeliveryItem>[])) {
        det.appendRow([
          TextCellValue(r.id),
          TextCellValue(r.date),
          TextCellValue(it.productCode),
          TextCellValue(it.productName),
          DoubleCellValue(it.quantity),
        ]);
      }
    }
    return _saveXls(xls, folder, 'عميل_${c.code}.xlsx');
  }

  /// قالب Excel جاهز للتحميل (code,desc) أو (code,desc,qty)
  Future<String> template({bool withQty = false}) async {
    final xls = Excel.createExcel();
    final s = xls['Template'];
    if (withQty) {
      s.appendRow([
        TextCellValue('code'),
        TextCellValue('desc'),
        TextCellValue('qty')
      ]);
      s.appendRow([
        TextCellValue('10001'),
        TextCellValue('شيكارة أسمنت'),
        IntCellValue(50)
      ]);
    } else {
      s.appendRow([TextCellValue('code'), TextCellValue('desc')]);
      s.appendRow([TextCellValue('10001'), TextCellValue('شيكارة أسمنت')]);
    }
    final d = await _baseDir();
    final f = File(p.join(d.path,
        withQty ? 'inventory_template.xlsx' : 'products_template.xlsx'));
    await f.writeAsBytes(xls.encode()!);
    return f.path;
  }

  /// قالب شيت استيراد الأذون (استلام/تسليم/مرتجعات):
  /// party | date | product | qty (+ voucher | weight | price اختياري).
  /// الصفوف بنفس voucher (أو نفس party + date) = إذن واحد.
  Future<String> voucherTemplate() async {
    final xls = Excel.createExcel();
    final s = xls['Vouchers'];
    s.appendRow([
      TextCellValue('voucher'),
      TextCellValue('party'),
      TextCellValue('date'),
      TextCellValue('product'),
      TextCellValue('qty'),
      TextCellValue('weight'),
      TextCellValue('price'),
    ]);
    s.appendRow([
      TextCellValue('1'),
      TextCellValue('S001'),
      TextCellValue('07/10/2026'),
      TextCellValue('10001'),
      IntCellValue(10),
      IntCellValue(0),
      IntCellValue(0),
    ]);
    s.appendRow([
      TextCellValue('1'),
      TextCellValue('S001'),
      TextCellValue('07/10/2026'),
      TextCellValue('10002'),
      IntCellValue(5),
      IntCellValue(0),
      IntCellValue(0),
    ]);
    final d = await _baseDir();
    final f = File(p.join(d.path, 'vouchers_template.xlsx'));
    await f.writeAsBytes(xls.encode()!);
    return f.path;
  }
}
