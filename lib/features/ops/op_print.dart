import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/providers.dart';
import 'op_kind.dart';

// النص العربي يُكتب بترتيبه الطبيعي — مكتبة الـ PDF ترسمه من اليمين للشمال
// عبر textDirection: rtl (بدون عكس الكلمات).
String _ar(String s) => s;

String _f(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(3);

/// الوزن برقمين عشريين فقط.
String _f2(double v) => v.toStringAsFixed(2);

/// طباعة العملية PDF — نفس شكل الصور (ترويسة + جدول + تفاصيل + مجموع).
/// التفصيلي والإجمالي كلاهما صف واحد مجمّع لكل صنف (نفس دمج شاشة التفاصيل).
/// الفرق: التفصيلي يعرض عمود وزن الوحدة زيادة — مفيد لأصناف الوزن المتغير.
Future<String> printOperation(WidgetRef ref, OpKind kind, String id,
    {bool detailed = false}) async {
  final d = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
  final font = pw.Font.ttf(d);

  // ── جمع البيانات ──
  String num = '';
  String date = '';
  String partyName = '';
  String partyCode = '';
  String byUser = '';
  double totalQty = 0;
  double totalWeight = 0;
  double totalPrice = 0;
  bool cash = false;
  final items = <({String code, String name, double qty, double weight, double price})>[];

  if (kind == OpKind.delivery) {
    final h = await ref.read(deliveryRepoProvider).find(id);
    if (h == null) throw Exception('غير موجود');
    num = h.number.toString();
    date = h.date;
    partyName = h.customerName;
    partyCode = h.customerCode;
    byUser = h.byUser;
    totalQty = h.totalQty;
    totalWeight = h.totalWeight;
    totalPrice = h.totalPrice;
    cash = h.cash;
    final its = await ref.read(deliveryRepoProvider).items(id);
    for (final it in its) {
      items.add((code: it.productCode, name: it.productName, qty: it.quantity, weight: it.weight, price: it.price));
    }
  } else if (kind == OpKind.receipt) {
    final h = await ref.read(receiptRepoProvider).find(id);
    if (h == null) throw Exception('غير موجود');
    num = h.number.toString();
    date = h.date;
    partyName = h.supplierName;
    partyCode = h.supplierCode;
    byUser = h.byUser;
    totalQty = h.totalQty;
    totalWeight = h.totalWeight;
    totalPrice = h.totalPrice;
    cash = h.cash;
    final its = await ref.read(receiptRepoProvider).items(id);
    for (final it in its) {
      items.add((code: it.productCode, name: it.productName, qty: it.quantity, weight: it.weight, price: it.price));
    }
  } else {
    final h = await ref.read(opsRepoProvider).find(id);
    if (h == null) throw Exception('غير موجود');
    num = h.number.toString();
    date = h.date;
    partyName = h.partyName;
    partyCode = h.partyCode;
    byUser = h.byUser;
    totalQty = h.totalQty;
    totalWeight = h.totalWeight;
    totalPrice = h.totalPrice;
    cash = h.cash;
    final its = await ref.read(opsRepoProvider).items(id);
    for (final it in its) {
      items.add((code: it.productCode, name: it.productName, qty: it.quantity, weight: it.weight, price: it.price));
    }
  }

  final kindAr = _ar(kind == OpKind.delivery
      ? 'تسليمات'
      : kind == OpKind.receipt
          ? 'استلامات'
          : kind.label);
  final partyKindAr = _ar(kind.partyTypes.first);
  final t = pw.TextStyle(font: font, fontSize: 10);
  final tb = pw.TextStyle(font: font, fontSize: 10);
  pw.Widget cell(String s, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(s, style: bold ? tb : t, textAlign: pw.TextAlign.center),
      );

  // ── تجميع لكل صنف (صف واحد لكل صنف في التفصيلي والإجمالي) ──
  final grouped = <String, ({String name, double qty, double weight, double price})>{};
  for (final it in items) {
    final g = grouped[it.code];
    if (g == null) {
      grouped[it.code] =
          (name: it.name, qty: it.qty, weight: it.weight, price: it.price);
    } else {
      grouped[it.code] = (
        name: g.name,
        qty: g.qty + it.qty,
        weight: g.weight + it.weight,
        price: it.price != 0 ? it.price : g.price,
      );
    }
  }

  // قائمة مجمّعة بالترتيب (صف واحد لكل صنف) — تُستخدم في الجدولين.
  final groupedList = grouped.entries.toList();

  final doc = pw.Document();
  // ملحوظة: جدول الـ PDF يرسم الأعمدة من الشمال لليمين دائمًا،
  // لذلك نكتب الأعمدة معكوسة لتظهر بالترتيب العربي (المسلسل والصنف يمين).
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    theme: pw.ThemeData.withFont(base: font, bold: font),
    build: (_) => [
      pw.Table(
        border: pw.TableBorder.all(),
        children: [
          pw.TableRow(children: [
            cell('$date : ${_ar('تاريخ الاذن')}'),
            cell('$kindAr : ${_ar('نوع الاذن')}'),
            cell('$num : ${_ar('رقم الاذن')}'),
          ]),
          pw.TableRow(children: [
            cell('$partyKindAr'),
            cell('${_ar(partyName)} : ${_ar('اسم')} $partyKindAr'),
            cell('$partyCode : ${_ar('كود')} $partyKindAr'),
          ]),
          pw.TableRow(children: [
            cell('${_f(totalPrice)} : ${_ar('اجمالي القيمة المطلوبة')}'),
            cell('${_f2(totalWeight)} : ${_ar('اجمالي الوزن')}'),
            cell('${_f(totalQty)} : ${_ar('اجمالي العدد')}'),
          ]),
          pw.TableRow(children: [
            cell(': ${_ar('اسم السائق')}'),
            cell(': ${_ar('ملاحظات')}'),
            cell('$byUser : ${_ar('اسم المستخدم')}'),
          ]),
        ],
      ),
      pw.SizedBox(height: 8),
      if (!detailed)
        // غير النقدي: لا أعمدة سعر (كلها أصفار) — الوزن يحل محلها.
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(children: [
              if (cash) cell(_ar('القيمة المطلوبة'), bold: true),
              if (cash) cell(_ar('السعر'), bold: true),
              cell(_ar('الوزن'), bold: true),
              cell(_ar('الكمية'), bold: true),
              cell(_ar('الصنف'), bold: true),
              cell(_ar('م'), bold: true),
            ]),
            for (var i = 0; i < groupedList.length; i++)
              pw.TableRow(children: [
                if (cash)
                  cell(_f(groupedList[i].value.qty *
                      groupedList[i].value.price)),
                if (cash) cell(_f(groupedList[i].value.price)),
                cell(_f2(groupedList[i].value.weight)),
                cell(_f(groupedList[i].value.qty)),
                cell(groupedList[i].value.name),
                cell('${i + 1}'),
              ]),
            if (cash)
              pw.TableRow(children: [
                cell(_f(totalPrice)),
                cell(_ar('المجموع'), bold: true),
                cell(_f2(totalWeight)),
                cell(''),
                cell(''),
                cell(''),
              ])
            else
              pw.TableRow(children: [
                cell(_f2(totalWeight)),
                cell(_ar('المجموع'), bold: true),
                cell(''),
                cell(''),
              ]),
          ],
        ),
      // ── التقرير التفصيلي: كل صنف + عدد كراتينه + وزن كل كرتونة + إجمالي الصنف ──
      if (detailed)
        for (var gi = 0; gi < groupedList.length; gi++) ...[
          pw.Text(
            cash
                ? '${_ar('الصنف')}: ${groupedList[gi].value.name} — ${_ar('عدد الكراتين')}: ${_f(groupedList[gi].value.qty)} — ${_ar('السعر')}: ${_f(groupedList[gi].value.price)}'
                : '${_ar('الصنف')}: ${groupedList[gi].value.name} — ${_ar('عدد الكراتين')}: ${_f(groupedList[gi].value.qty)} — ${_ar('الوزن')}: ${_f2(groupedList[gi].value.weight)}',
            style: tb,
            textAlign: pw.TextAlign.right,
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(children: [
                cell(_ar('وزن الكرتونة'), bold: true),
                cell(_ar('م'), bold: true),
              ]),
              for (var i = 0;
                  i <
                      items
                          .where((e) => e.code == groupedList[gi].key)
                          .toList()
                          .length;
                  i++)
                pw.TableRow(children: [
                  cell(_f2(items
                      .where((e) => e.code == groupedList[gi].key)
                      .toList()[i]
                      .weight)),
                  cell('${i + 1}'),
                ]),
              pw.TableRow(children: [
                cell(
                    '${_f2(groupedList[gi].value.weight)} : ${_ar('إجمالي وزن الصنف')}',
                    bold: true),
                cell(''),
              ]),
            ],
          ),
          pw.SizedBox(height: 8),
        ],
      if (detailed)
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(children: [
              cell('${_f(totalPrice)} : ${_ar('إجمالي القيمة')}'),
              cell('${_f2(totalWeight)} : ${_ar('إجمالي الوزن')}'),
              cell('${_f(totalQty)} : ${_ar('إجمالي العدد')}'),
            ]),
          ],
        ),
    ],
  ));

  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory(p.join(dir.path, 'Orders'));
  if (!await folder.exists()) await folder.create(recursive: true);
  final path = p.join(
      folder.path, detailed ? '$num - Order-details.pdf' : '$num - Order.pdf');
  final file = File(path);
  await file.writeAsBytes(await doc.save());
  return path;
}
