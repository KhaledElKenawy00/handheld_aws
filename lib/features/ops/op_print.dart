import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/providers.dart';
import '../../core/services/pdf_service.dart';
import '../../shared/models/entities.dart';
import 'op_kind.dart';

/// طباعة العملية PDF — نفس شكل صورة الأوردر بالظبط:
/// ترويسة 3×3 + جدول (م/الصنف/الكمية/الوزن/السعر/القيمة) + صف مدمج
/// لكل صنف وتحته صفوف مسحاته (وزن كل كرتونة) + صف المجموع.
/// التفصيلي والإجمالي نفس الشكل (الصورة نفسها ملف إجمالي بتفصيلة).
Future<String> printOperation(WidgetRef ref, OpKind kind, String id,
    {bool detailed = false}) async {
  // ── جمع البيانات ──
  String num = '';
  String date = '';
  String partyName = '';
  String partyCode = '';
  String byUser = '';
  double totalQty = 0;
  double totalWeight = 0;
  double totalPrice = 0;
  final rawItems = <DocLine>[];

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
    final its = await ref.read(deliveryRepoProvider).items(id);
    for (final it in its) {
      rawItems.add(DocLine(
          productCode: it.productCode,
          productName: it.productName,
          quantity: it.quantity,
          weight: it.weight,
          price: it.price));
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
    final its = await ref.read(receiptRepoProvider).items(id);
    for (final it in its) {
      rawItems.add(DocLine(
          productCode: it.productCode,
          productName: it.productName,
          quantity: it.quantity,
          weight: it.weight,
          price: it.price));
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
    final its = await ref.read(opsRepoProvider).items(id);
    for (final it in its) {
      rawItems.add(DocLine(
          productCode: it.productCode,
          productName: it.productName,
          quantity: it.quantity,
          weight: it.weight,
          price: it.price));
    }
  }

  final kindLabel = kind == OpKind.delivery
      ? 'تسليمات'
      : kind == OpKind.receipt
          ? 'استلامات'
          : kind.label;

  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory(p.join(dir.path, 'Orders'));
  if (!await folder.exists()) await folder.create(recursive: true);
  return PdfService().orderPdf(
    kindLabel: kindLabel,
    partyKindLabel: kind.partyTypes.first,
    num: num,
    date: date,
    partyCode: partyCode,
    partyName: partyName,
    byUser: byUser,
    totalPrice: totalPrice,
    totalQty: totalQty,
    totalWeight: totalWeight,
    rawItems: rawItems,
    folderPath: folder.path,
    fileName: detailed ? '$num - Order-details.pdf' : '$num - Order.pdf',
  );
}
