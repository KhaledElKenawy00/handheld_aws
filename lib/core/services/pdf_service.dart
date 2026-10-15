import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/models/entities.dart';
import '../utils/app_utils.dart';

/// تصدير PDF احترافي A4 مع دعم العربية RTL.
/// ملاحظة: حزمة pdf لا تشكّل النص العربي تلقائيًا — لذلك نعكس ترتيب
/// الكلمات العربية سطرًا بسطر (حل offline شائع) مع خط Cairo المضمّن.
class PdfService {
  pw.Font? _arFont;
  pw.Font? _arBold;

  Future<void> _loadFonts() async {
    if (_arFont != null) return;
    try {
      final d = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      _arFont = pw.Font.ttf(d);
      _arBold = pw.Font.ttf(d);
    } catch (_) {
      _arFont = pw.Font.helvetica();
      _arBold = pw.Font.helveticaBold();
    }
  }

  /// عكس بسيط للعربية للعرض الصحيح في PDF بدون مكتبة bidi
  String ar(String s) {
    if (!RegExp(r'[\u0600-\u06FF]').hasMatch(s)) return s;
    // نعكس ترتيب المقاطع للحفاظ على قراءة RTL داخل خلايا LTR
    final words = s.split(' ');
    return words.reversed.join(' ');
  }

  pw.Widget _header(String titleAr, String sub) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SANAD',
                    style: pw.TextStyle(
                        font: _arBold, fontSize: 22)),
                pw.Text(ar('سند لإدارة المخازن'),
                    style: pw.TextStyle(font: _arFont, fontSize: 11)),
              ]),
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(ar(titleAr),
                    style: pw.TextStyle(
                        font: _arBold, fontSize: 18)),
                pw.Text(sub, style: const pw.TextStyle(fontSize: 10)),
              ]),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
            'SANAD - ${ar('سند')} | Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      );

  // ---------- تنسيقات الطباعة الموحدة (نفس شكل صورة الأوردر) ----------
  /// 3 أرقام عشرية للإجماليات (31.000).
  String _f3(double v) => v.toStringAsFixed(3);

  /// الكمية بدون كسور لو صحيحة (5).
  String _fq(double v) => AppUtils.fmtQty(v);

  pw.Widget _ocell(String s, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(s,
            style: pw.TextStyle(
                font: bold ? _arBold : _arFont, fontSize: 10),
            textAlign: pw.TextAlign.center),
      );

  /// طباعة أوردر موحدة بنفس شكل الصورة تمامًا:
  /// ترويسة 3×3 (رقم/نوع/تاريخ — كود/اسم الطرف/إجمالي القيمة —
  /// إجمالي الكمية/إجمالي الوزن/المستخدم) + جدول (م/الصنف/الكمية/
  /// الوزن/السعر/القيمة) بترتيب: أولًا صف مدمج لكل صنف (كل الأصناف
  /// بكمياتها)، ثم — في التفصيلي فقط — تفصيلة كل صنف (صف عنوان +
  /// صف لكل مسحة بوزنها تحت عمود الصنف)، ثم صف المجموع.
  /// الإجمالي: الأصناف المدمجة فقط (صنف + كمية + وزن إجمالي)
  /// بدون تفصيل المسحات.
  /// النص العربي بترتيبه الطبيعي ويُرسم RTL عبر textDirection
  /// (بدون عكس كلمات).
  Future<String> orderPdf({
    required String kindLabel,
    required String partyKindLabel,
    required String num,
    required String date,
    required String partyCode,
    required String partyName,
    required String byUser,
    required double totalPrice,
    required double totalQty,
    required double totalWeight,
    required List<DocLine> rawItems,
    required String folderPath,
    required String fileName,
    bool detailed = true,
  }) async {
    await _loadFonts();
    // تجميع بنفس ترتيب الظهور.
    final order = <String>[];
    final groups = <String, List<DocLine>>{};
    for (final it in rawItems) {
      if (!groups.containsKey(it.productCode)) {
        groups[it.productCode] = [];
        order.add(it.productCode);
      }
      groups[it.productCode]!.add(it);
    }
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: _arFont!, bold: _arBold!),
      build: (_) => [
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(children: [
              _ocell('$date : تاريخ الاذن'),
              _ocell('$kindLabel : نوع الاذن'),
              _ocell('$num : رقم الاذن'),
            ]),
            pw.TableRow(children: [
              _ocell('${_f3(totalPrice)} : اجمالي القيمة'),
              _ocell('$partyName : اسم ال$partyKindLabel'),
              _ocell('$partyCode : كود ال$partyKindLabel'),
            ]),
            pw.TableRow(children: [
              _ocell('$byUser : اسم المستخدم'),
              _ocell('${_f3(totalWeight)} : اجمالي الوزن'),
              _ocell('${_fq(totalQty)} : اجمالي الكمية'),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(children: [
              _ocell('القيمة الإجمالية', bold: true),
              _ocell('السعر', bold: true),
              _ocell('الوزن', bold: true),
              _ocell('الكمية', bold: true),
              _ocell('الصنف', bold: true),
              _ocell('م', bold: true),
            ]),
            // القسم الأول: صف مدمج لكل صنف (كل الأصناف بكمياتها).
            for (var gi = 0; gi < order.length; gi++)
              _mergedRow(order[gi], groups[order[gi]]!, gi + 1),
            // القسم الثاني (تفصيلي فقط): تفصيلة كل صنف — صف عنوان
            // (الصنف + اسمه) ثم صف لكل مسحة (وزنها تحت عمود الصنف
            // + رقمها). الإجمالي يتخطى التفصيلة.
            if (detailed)
              for (var gi = 0; gi < order.length; gi++)
                ..._detailRows(order[gi], groups[order[gi]]!),
            // صف المجموع: في التفصيلي (زي الصورة) إجمالي الوزن +
            // المجموع فقط، وفي الإجمالي إجمالي القيمة والوزن والكمية.
            if (detailed)
              pw.TableRow(children: [
                _ocell(''),
                _ocell(''),
                _ocell(''),
                _ocell(''),
                _ocell(_f3(totalWeight)),
                _ocell('المجموع', bold: true),
              ])
            else
              pw.TableRow(children: [
                _ocell(_f3(totalPrice)),
                _ocell(''),
                _ocell(_f3(totalWeight)),
                _ocell(_fq(totalQty)),
                _ocell('المجموع', bold: true),
                _ocell(''),
              ]),
          ],
        ),
      ],
    ));
    return _save(doc, folderPath, fileName);
  }

  String _groupName(String code, List<DocLine> scans) {
    final name = scans
        .lastWhere((e) => e.productName.isNotEmpty,
            orElse: () => scans.first)
        .productName;
    return name.isEmpty ? code : name;
  }

  /// الصف المدمج لصنف واحد (كمية/وزن مجموع + أحدث سعر).
  pw.TableRow _mergedRow(String code, List<DocLine> scans, int n) {
    final qty = scans.fold(0.0, (a, b) => a + b.quantity);
    final weight = scans.fold(0.0, (a, b) => a + b.weight);
    final price = scans.last.price;
    return pw.TableRow(children: [
      _ocell(_f3(qty * price)),
      _ocell(price.toString()),
      _ocell(_f3(weight)),
      _ocell(_fq(qty)),
      _ocell(_groupName(code, scans)),
      _ocell('$n'),
    ]);
  }

  /// تفصيلة صنف واحد بنفس شكل الصورة: صف عنوان (الصنف + اسمه)
  /// ثم صف لكل مسحة (وزنها تحت عمود الصنف + رقم المسحة).
  List<pw.TableRow> _detailRows(String code, List<DocLine> scans) {
    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        _ocell(''),
        _ocell(''),
        _ocell(''),
        _ocell(''),
        _ocell('الصنف: ${_groupName(code, scans)}', bold: true),
        _ocell('مسلسل', bold: true),
      ]),
      for (var i = 0; i < scans.length; i++)
        pw.TableRow(children: [
          _ocell(''),
          _ocell(''),
          _ocell(''),
          _ocell(''),
          _ocell(scans[i].weight.toString()),
          _ocell('${i + 1}'),
        ]),
    ];
    return rows;
  }

  /// زر PDF في شاشة تفاصيل الاستلام — نفس شكل صورة الأوردر.
  Future<String> receiptPdf(
      ReceiptHeader h, List<ReceiptItem> items, String folderPath) {
    return orderPdf(
      kindLabel: 'استلامات',
      partyKindLabel: 'مورد',
      num: h.number.toString(),
      date: h.date,
      partyCode: h.supplierCode,
      partyName: h.supplierName,
      byUser: h.byUser,
      totalPrice: h.totalPrice,
      totalQty: h.totalQty,
      totalWeight: h.totalWeight,
      rawItems: [
        for (final e in items)
          DocLine(
              productCode: e.productCode,
              productName: e.productName,
              quantity: e.quantity,
              weight: e.weight,
              price: e.price),
      ],
      folderPath: folderPath,
      fileName: '${h.id}.pdf',
    );
  }

  /// زر PDF في شاشة تفاصيل التسليم — نفس شكل صورة الأوردر.
  Future<String> deliveryPdf(
      DeliveryHeader h, List<DeliveryItem> items, String folderPath) {
    return orderPdf(
      kindLabel: 'تسليمات',
      partyKindLabel: 'عميل',
      num: h.number.toString(),
      date: h.date,
      partyCode: h.customerCode,
      partyName: h.customerName,
      byUser: h.byUser,
      totalPrice: h.totalPrice,
      totalQty: h.totalQty,
      totalWeight: h.totalWeight,
      rawItems: [
        for (final e in items)
          DocLine(
              productCode: e.productCode,
              productName: e.productName,
              quantity: e.quantity,
              weight: e.weight,
              price: e.price),
      ],
      folderPath: folderPath,
      fileName: '${h.id}.pdf',
    );
  }

  Future<String> inventoryPdf(InventorySession s, List<InventoryItem> items,
      String folderPath) async {
    await _loadFonts();
    final doc = pw.Document();
    final shortage = items.where((e) => e.difference < 0).length;
    final excess = items.where((e) => e.difference > 0).length;
    final matched = items.where((e) => e.difference == 0).length;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: _arFont!, bold: _arBold!),
      header: (_) => _header('تقرير الجرد', s.id),
      footer: _footer,
      build: (_) => [
        _infoRow('رقم الجرد:', s.id),
        _infoRow('التاريخ:', s.date),
        pw.SizedBox(height: 10),
        _table(
          ['Code', ar('الوصف'), 'Exp', 'Act', 'Diff', ar('الحالة')],
          items
              .map((e) => [
                    e.productCode,
                    ar(e.productName),
                    AppUtils.fmtQty(e.expectedQty),
                    AppUtils.fmtQty(e.actualQty),
                    AppUtils.fmtQty(e.difference),
                    ar(e.statusAr),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          '${ar('الإجمالي')}: ${items.length} | ${ar('ناقص')}: $shortage | ${ar('زائد')}: $excess | ${ar('متساوي')}: $matched',
          style: pw.TextStyle(font: _arBold, fontSize: 12),
        ),
      ],
    ));
    return _save(doc, folderPath, '${s.id}.pdf');
  }

  pw.Widget _infoRow(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Text(ar(k),
              style: pw.TextStyle(font: _arBold, fontSize: 11)),
          pw.SizedBox(width: 6),
          pw.Expanded(
              child: pw.Text(v,
                  style: pw.TextStyle(font: _arFont, fontSize: 11))),
        ]),
      );

  pw.Widget _table(List<String> head, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: head,
        data: rows,
        headerStyle: pw.TextStyle(font: _arBold, fontSize: 10),
        cellStyle: pw.TextStyle(font: _arFont, fontSize: 10),
        headerDecoration:
            const pw.BoxDecoration(color: PdfColors.blueGrey100),
        cellAlignment: pw.Alignment.center,
      );

  // ---------- قوائم شاملة (للباكب الكامل) ----------

  Future<String> _listDoc(
      String title, List<String> head, List<List<String>> rows,
      String folder, String name) async {
    await _loadFonts();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: _arFont!, bold: _arBold!),
      header: (_) => _header(title, '${rows.length}'),
      footer: _footer,
      build: (_) => [
        pw.SizedBox(height: 8),
        if (rows.isEmpty)
          pw.Text(ar('لا توجد بيانات'),
              style: pw.TextStyle(font: _arFont, fontSize: 12))
        else
          _table(head, rows),
      ],
    ));
    return _save(doc, folder, name);
  }

  Future<String> productsListPdf(
          List<Product> ps, String folder) =>
      _listDoc('الأصناف',
          ['Code', ar('الوصف'), ar('المخزون')],
          ps
              .map((e) => [
                    e.code,
                    ar(e.desc),
                    AppUtils.fmtQty(e.stock)
                  ])
              .toList(),
          folder, 'products.pdf');

  Future<String> suppliersListPdf(
          List<Supplier> ss, String folder) =>
      _listDoc('الموردون',
          ['Code', ar('الاسم')],
          ss.map((e) => [e.code, ar(e.desc)]).toList(),
          folder, 'suppliers.pdf');

  Future<String> customersListPdf(
          List<Customer> cs, String folder) =>
      _listDoc('العملاء',
          ['Code', ar('الاسم')],
          cs.map((e) => [e.code, ar(e.desc)]).toList(),
          folder, 'customers.pdf');

  Future<String> warehousesListPdf(
          List<Warehouse> ws, String folder) =>
      _listDoc('المخازن',
          ['Code', ar('الاسم')],
          ws.map((e) => [e.code, ar(e.name)]).toList(),
          folder, 'warehouses.pdf');

  Future<String> opsListPdf(List<OpHeader> hs, String folder) =>
      _listDoc('العمليات (مرتجعات / تحويلات)',
          [ar('النوع'), ar('الرقم'), ar('الطرف'), ar('التاريخ'), ar('أصناف'), ar('كمية')],
          hs
              .map((h) => [
                    ar(h.kind),
                    '${h.number}',
                    ar(h.partyName),
                    h.date,
                    '${h.totalItems}',
                    AppUtils.fmtQty(h.totalQty)
                  ])
              .toList(),
          folder, 'operations.pdf');

  Future<String> receiptsListPdf(
          List<ReceiptHeader> hs, String folder) =>
      _listDoc('أذون الاستلام',
          [ar('الرقم'), ar('المورد'), ar('التاريخ'), ar('أصناف'), ar('كمية')],
          hs
              .map((h) => [
                    h.id,
                    ar(h.supplierName),
                    h.date,
                    '${h.totalItems}',
                    AppUtils.fmtQty(h.totalQty)
                  ])
              .toList(),
          folder, 'receipts.pdf');

  Future<String> deliveriesListPdf(
          List<DeliveryHeader> hs, String folder) =>
      _listDoc('أذون التسليم',
          [ar('الرقم'), ar('العميل'), ar('التاريخ'), ar('أصناف'), ar('كمية')],
          hs
              .map((h) => [
                    h.id,
                    ar(h.customerName),
                    h.date,
                    '${h.totalItems}',
                    AppUtils.fmtQty(h.totalQty)
                  ])
              .toList(),
          folder, 'deliveries.pdf');

  Future<String> inventorySessionsPdf(
          List<InventorySession> ss, String folder) =>
      _listDoc('جلسات الجرد',
          [ar('الرقم'), ar('التاريخ'), ar('الحالة')],
          ss
              .map((s) => [
                    s.id,
                    s.date,
                    ar(s.status == 'closed' ? 'مغلق' : 'مفتوح')
                  ])
              .toList(),
          folder, 'inventory_sessions.pdf');

  /// ملف المورد الشامل: بياناته + كل أذون الاستلام بتفاصيل الأصناف
  Future<String> supplierDossierPdf(
    Supplier s,
    List<ReceiptHeader> headers,
    Map<String, List<ReceiptItem>> itemsByReceipt,
    String folder,
  ) async {
    await _loadFonts();
    final totalQty =
        headers.fold(0.0, (a, h) => a + h.totalQty);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: _arFont!, bold: _arBold!),
      header: (_) => _header('ملف مورد', s.code),
      footer: _footer,
      build: (_) => [
        pw.SizedBox(height: 8),
        pw.Text(ar('اسم المورد:'),
            style: pw.TextStyle(font: _arBold, fontSize: 14)),
        pw.Text(ar(s.desc),
            style: pw.TextStyle(font: _arBold, fontSize: 18)),
        _infoRow('الكود:', s.code),
        pw.SizedBox(height: 6),
        pw.Text(
            '${ar('عدد الأذون')}: ${headers.length} | ${ar('إجمالي الكميات')}: ${AppUtils.fmtQty(totalQty)}',
            style: pw.TextStyle(font: _arBold, fontSize: 12)),
        pw.SizedBox(height: 10),
        if (headers.isEmpty)
          pw.Text(ar('لا توجد أذون لهذا المورد'),
              style: pw.TextStyle(font: _arFont, fontSize: 12)),
        for (final h in headers) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey100,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Text(
                '${h.id} | ${h.date} | ${ar('أصناف')}: ${h.totalItems} | ${ar('كمية')}: ${AppUtils.fmtQty(h.totalQty)}',
                style: pw.TextStyle(font: _arBold, fontSize: 11)),
          ),
          pw.SizedBox(height: 4),
          _table(
            ['Code', ar('الوصف'), ar('الكمية')],
            (itemsByReceipt[h.id] ?? const <ReceiptItem>[])
                .map((e) => [
                      e.productCode,
                      ar(e.productName),
                      AppUtils.fmtQty(e.quantity)
                    ])
                .toList(),
          ),
        ],
      ],
    ));
    return _save(doc, folder, 'مورد_${s.code}.pdf');
  }

  /// ملف العميل الشامل: بياناته + كل أذون التسليم بتفاصيل الأصناف
  Future<String> customerDossierPdf(
    Customer c,
    List<DeliveryHeader> headers,
    Map<String, List<DeliveryItem>> itemsByDelivery,
    String folder,
  ) async {
    await _loadFonts();
    final totalQty =
        headers.fold(0.0, (a, h) => a + h.totalQty);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: _arFont!, bold: _arBold!),
      header: (_) => _header('ملف عميل', c.code),
      footer: _footer,
      build: (_) => [
        pw.SizedBox(height: 8),
        pw.Text(ar('اسم العميل:'),
            style: pw.TextStyle(font: _arBold, fontSize: 14)),
        pw.Text(ar(c.desc),
            style: pw.TextStyle(font: _arBold, fontSize: 18)),
        _infoRow('الكود:', c.code),
        pw.SizedBox(height: 6),
        pw.Text(
            '${ar('عدد الأذون')}: ${headers.length} | ${ar('إجمالي الكميات')}: ${AppUtils.fmtQty(totalQty)}',
            style: pw.TextStyle(font: _arBold, fontSize: 12)),
        pw.SizedBox(height: 10),
        if (headers.isEmpty)
          pw.Text(ar('لا توجد أذون لهذا العميل'),
              style: pw.TextStyle(font: _arFont, fontSize: 12)),
        for (final h in headers) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey100,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Text(
                '${h.id} | ${h.date} | ${ar('أصناف')}: ${h.totalItems} | ${ar('كمية')}: ${AppUtils.fmtQty(h.totalQty)}',
                style: pw.TextStyle(font: _arBold, fontSize: 11)),
          ),
          pw.SizedBox(height: 4),
          _table(
            ['Code', ar('الوصف'), ar('الكمية')],
            (itemsByDelivery[h.id] ?? const <DeliveryItem>[])
                .map((e) => [
                      e.productCode,
                      ar(e.productName),
                      AppUtils.fmtQty(e.quantity)
                    ])
                .toList(),
          ),
        ],
      ],
    ));
    return _save(doc, folder, 'عميل_${c.code}.pdf');
  }

  Future<String> _save(pw.Document doc, String folder, String name) async {
    final dir = Directory(folder);
    if (!await dir.exists()) await dir.create(recursive: true);
    final f = File(p.join(dir.path, name));
    await f.writeAsBytes(await doc.save());
    return f.path;
  }
}
