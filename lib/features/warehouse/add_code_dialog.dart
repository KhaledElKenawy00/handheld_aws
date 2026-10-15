import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/scanner/scanner_providers.dart';
import '../../core/services/barcode_parser.dart';
import '../../core/theme/ref_style.dart';
import '../../core/utils/app_utils.dart';
import '../../shared/models/entities.dart';

const List<String> refMarks = ['1', '10', '100', '1000', '10000'];
const List<String> refUnits = ['KG', 'LB'];
const List<String> refDateFmts = [
  'DD/MM/YYYY',
  'MM/DD/YYYY',
  'DD/YYYY/MM',
  'MM/YYYY/DD',
  'YYYY/MM/DD',
  'YYYY/DD/MM',
  'DD/MM/YY',
  'MM/DD/YY',
  'DD/YY/MM',
  'MM/YY/DD',
  'YY/MM/DD',
  'YY/DD/MM',
];

/// دايلوج إضافة كود — نفس صورة المستخدم:
/// الباركود + سهمين (بداية/نهاية من الأسهم) + العلامة + الوحدة + القيمة تلقائي.
/// يدعم ماسح SUNMI L2s Pro (Broadcast + زر فيزيائي wedge) لحقل الباركود.
///
/// المنطق: حدّد الرقم بين البداية والنهاية بالأسهم، نحط الوزن بينهم،
/// وبناء عليه نحدد العلامة (10/100/1000/...) والوحدة (KG/LB)،
/// والقيمة تظهر تلقائي = المقطع / العلامة.
Future<void> showAddCodeDialog(
    BuildContext context, WidgetRef ref, Product p) async {
  final barcodeC = TextEditingController();
  // كنترولر ثابت لحقل القيمة — يُحدَّث نصه يدويًا بدل إنشائه في كل build
  // (إنشاؤه داخل build يسبب استخدام كنترولر بعد dispose).
  final valueC = TextEditingController();
  String mark = '1';
  String unit = 'KG';
  String dateFmt = 'DD/MM/YYYY';
  int wStart = 1;
  int wEnd = 1;
  // مقطع كود الصنف داخل الباركود (0 = غير محدد = الباركود كله هو الكود).
  int cStart = 0;
  int cEnd = 0;
  // مقطع التاريخ داخل الباركود (0 = غير محدد = يُتجاهل عند المطابقة).
  int dStart = 0;
  int dEnd = 0;

  int clampCodePos(int v, int len) {
    if (v < 0) return 0;
    if (len <= 0) return v > 99 ? 99 : v;
    if (v > len) return len;
    return v;
  }

  void refreshValue() {
    final barcode = BarcodeParser.clean(barcodeC.text);
    final v = barcode.isEmpty
        ? ''
        : BarcodeParser.fmt(
            BarcodeParser.calcValue(barcode, wStart, wEnd, mark));
    if (valueC.text != v) valueC.text = v;
  }

  // املأ الباركود تلقائيًا من أي مسح SUNMI أثناء فتح الدايلوج.
  StreamSubscription? scanSub;
  // setS الخاص بالدايلوج — يُضبط داخل StatefulBuilder لتحديث المعاينة
  // عند وصول مسح جديد.
  void Function(VoidCallback)? dialogSetS;
  var dialogOpen = true;
  try {
    scanSub = ref.read(scannerServiceProvider).scanStream.listen((raw) {
      if (!dialogOpen) return;
      final code = BarcodeParser.clean(raw);
      if (code.isEmpty) return;
      HapticFeedback.lightImpact();
      barcodeC.text = code;
      final len = code.length;
      if (len > 0) {
        wStart = BarcodeParser.clampPos(wStart, len);
        wEnd = BarcodeParser.clampPos(wEnd == 1 && len > 1 ? len : wEnd, len);
        cStart = clampCodePos(cStart, len);
        cEnd = clampCodePos(cEnd, len);
        dStart = clampCodePos(dStart, len);
        dEnd = clampCodePos(dEnd, len);
      }
      refreshValue();
      try {
        dialogSetS?.call(() {});
      } catch (_) {}
    });
  } catch (_) {}

  Future<void> triggerScan() async {
    try {
      await ref.read(scannerServiceProvider).triggerScan();
    } catch (_) {
      if (context.mounted) {
        refToast(context,
            'اضغط زر المسح الفيزيائي في جهاز SUNMI — الحقل جاهز');
      }
    }
  }

  await refDialog(
    context: context,
    dialogTitle: 'أضف الكود',
    onSave: () async {
      try {
        final barcode = BarcodeParser.clean(barcodeC.text);
        if (barcode.isEmpty) throw const AppFailure('ادخل الباركود');
        final calc = BarcodeParser.calcValue(barcode, wStart, wEnd, mark);
        await ref.read(productCodeRepoProvider).add(ProductCode(
              productCode: p.code,
              barcode: barcode,
              qty: 0,
              weight: calc,
              unit: unit,
              mark: mark,
              dateFmt: dateFmt,
              value: calc,
              wStart: wStart,
              wEnd: wEnd,
              cStart: cStart,
              cEnd: cEnd,
              dStart: dStart,
              dEnd: dEnd,
            ));
        if (context.mounted) {
          Navigator.pop(context);
          refToast(context, 'تم حفظ الكود');
        }
      } catch (e) {
        if (context.mounted) refError(context, e);
      }
    },
    content: StatefulBuilder(
      builder: (ctx, setS) {
        dialogSetS = setS;
        final barcode = BarcodeParser.clean(barcodeC.text);
        final len = barcode.length;
        if (len > 0) {
          wStart = BarcodeParser.clampPos(wStart, len);
          wEnd = BarcodeParser.clampPos(wEnd, len);
          cStart = clampCodePos(cStart, len);
          cEnd = clampCodePos(cEnd, len);
          dStart = clampCodePos(dStart, len);
          dEnd = clampCodePos(dEnd, len);
        }
        final slice = len == 0
            ? ''
            : BarcodeParser.slice(barcode, wStart, wEnd);
        final codeSlice = (len == 0 || cStart <= 0 || cEnd <= 0)
            ? ''
            : BarcodeParser.slice(barcode, cStart, cEnd);
        final dateSlice = (len == 0 || dStart <= 0 || dEnd <= 0)
            ? ''
            : BarcodeParser.formatDateSlice(
                BarcodeParser.slice(barcode, dStart, dEnd), dateFmt);
        refreshValue();

        Widget codeStepper(String label, int value, ValueChanged<int> onCh) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RefColors.fieldBorder),
                ),
                child: Column(
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: RefColors.hintGrey)),
                    Text(value == 0 ? '—' : '$value',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _arrowBtn(
                      icon: Icons.keyboard_arrow_up_rounded,
                      color: RefColors.green,
                      onTap: () => setS(() =>
                          onCh(clampCodePos(value + 1, len == 0 ? 99 : len))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _arrowBtn(
                      icon: Icons.keyboard_arrow_down_rounded,
                      color: RefColors.red,
                      onTap: () => setS(() =>
                          onCh(clampCodePos(value - 1, len == 0 ? 99 : len))),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        Widget stepper(String label, int value, ValueChanged<int> onCh) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RefColors.fieldBorder),
                ),
                child: Column(
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: RefColors.hintGrey)),
                    Text('$value',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _arrowBtn(
                      icon: Icons.keyboard_arrow_up_rounded,
                      color: RefColors.green,
                      onTap: () => setS(() => onCh(
                          BarcodeParser.clampPos(
                              value + 1, len == 0 ? 99 : len))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _arrowBtn(
                      icon: Icons.keyboard_arrow_down_rounded,
                      color: RefColors.red,
                      onTap: () => setS(() => onCh(
                          BarcodeParser.clampPos(
                              value - 1, len == 0 ? 99 : len))),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RefField(
                        controller: barcodeC,
                        label: 'الباركود',
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setS(() {
                              final l = barcodeC.text.trim().length;
                              if (l > 0) {
                                wStart =
                                    BarcodeParser.clampPos(wStart, l);
                                wEnd = BarcodeParser.clampPos(wEnd, l);
                              }
                            }),
                        suffixIcon: IconButton(
                          icon: const Icon(
                              Icons.document_scanner_outlined),
                          tooltip: 'مسح بالـ Scanner',
                          onPressed: triggerScan,
                        )),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: triggerScan,
                    icon:
                        const Icon(Icons.document_scanner_outlined),
                    label: const Text('مسح'),
                  ),
                ],
              ),
              if (len > 0) ...[
                const SizedBox(height: 8),
                Text('طول الباركود: $len — حدّد الوزن بين البداية والنهاية',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: RefColors.hintGrey)),
                const SizedBox(height: 4),
                _barcodeRuler(barcode, wStart, wEnd),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: stepper('البداية', wStart,
                          (v) => wStart = v)),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          stepper('النهاية', wEnd, (v) => wEnd = v)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RefColors.fieldBorder),
                ),
                child: Text(
                  slice.isEmpty
                      ? 'المقطع: — امسح الباركود أولًا'
                      : 'المقطع [$wStart-$wEnd]: $slice',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RefDropdown<String>(
                      label: 'العلامة',
                      value: mark,
                      items: [
                        for (final m in refMarks)
                          DropdownMenuItem(
                              value: m,
                              child: Text(m,
                                  textDirection:
                                      TextDirection.ltr)),
                      ],
                      onChanged: (v) =>
                          setS(() => mark = v ?? mark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RefDropdown<String>(
                      label: 'الوحدة',
                      value: unit,
                      items: [
                        for (final u in refUnits)
                          DropdownMenuItem(
                              value: u,
                              child: Text(u,
                                  textDirection:
                                      TextDirection.ltr)),
                      ],
                      onChanged: (v) =>
                          setS(() => unit = v ?? unit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RefDropdown<String>(
                label: 'صيغة التاريخ',
                value: dateFmt,
                items: [
                  for (final f in refDateFmts)
                    DropdownMenuItem(
                        value: f,
                        child: Text(f,
                            textDirection: TextDirection.ltr)),
                ],
                onChanged: (v) =>
                    setS(() => dateFmt = v ?? dateFmt),
              ),
              const SizedBox(height: 12),
              RefField(
                controller: valueC,
                label: 'القيمة (تلقائي = المقطع ÷ العلامة)',
                readOnly: true,
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RefColors.fieldBorder),
                ),
                child: const Text(
                  'مقطع كود الصنف (اختياري) — لو كود الصنف جزء من الباركود حدّد بدايته ونهايته، وعند المسح في الطلب سيُحدد الصنف تلقائيًا بدون اختيار يدوي. اتركهما (—) لو الباركود كله هو الكود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: RefColors.hintGrey),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: codeStepper('بداية الكود', cStart,
                          (v) => cStart = v)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: codeStepper(
                          'نهاية الكود', cEnd, (v) => cEnd = v)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RefColors.fieldBorder),
                ),
                child: Text(
                  codeSlice.isEmpty
                      ? 'الكود: — (غير محدد)'
                      : 'الكود [$cStart-$cEnd]: $codeSlice',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RefColors.fieldBorder),
                ),
                child: const Text(
                  'مقطع التاريخ (اختياري) — حدّد بدايته ونهايته مع الصيغة بالأعلى. التاريخ يُتجاهل عند مطابقة المسح لأنه يتغير من ملصق لآخر. اتركهما (—) لو لا يوجد تاريخ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: RefColors.hintGrey),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: codeStepper('بداية التاريخ', dStart,
                          (v) => dStart = v)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: codeStepper(
                          'نهاية التاريخ', dEnd, (v) => dEnd = v)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RefColors.fieldBorder),
                ),
                child: Text(
                  dateSlice.isEmpty
                      ? 'التاريخ: — (غير محدد)'
                      : 'التاريخ [$dStart-$dEnd]: $dateSlice',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  dialogOpen = false;
  dialogSetS = null;
  await scanSub?.cancel();
  // مهلة لاكتمال أنيميشن خروج الحوار قبل التخلص من الكنترولرات —
  // وإلا أي إعادة بناء أثناء الخروج (مثل الكيبورد) تكراش
  // (TextEditingController was used after being disposed).
  await Future.delayed(const Duration(milliseconds: 500));
  barcodeC.dispose();
  valueC.dispose();
}

Widget _arrowBtn(
    {required IconData icon,
    required Color color,
    required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, size: 40, color: color),
    ),
  );
}

/// مسطرة الباركود: كل رقم تحته ترقيمه، والمحدد بين البداية/النهاية مظلل.
Widget _barcodeRuler(String barcode, int wStart, int wEnd) {
  var s = wStart;
  var e = wEnd;
  if (s > e) {
    final t = s;
    s = e;
    e = t;
  }
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < barcode.length; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                color: (i + 1 >= s && i + 1 <= e)
                    ? RefColors.primary.withValues(alpha: .2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (i + 1 >= s && i + 1 <= e)
                      ? RefColors.primary
                      : RefColors.fieldBorder,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(barcode[i],
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  Text('${i + 1}',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: (i + 1 >= s && i + 1 <= e)
                              ? RefColors.primary
                              : RefColors.hintGrey)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
