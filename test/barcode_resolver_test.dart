import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/services/barcode_parser.dart';
import 'package:sanad/core/services/barcode_resolver.dart';
import 'package:sanad/shared/models/entities.dart';

/// تغطية منطق المطابقة الحرجة للمسح — أي كسر هنا = "الماسح لا يقرأ".
void main() {
  ProductCode tpl({
    required String barcode,
    String productCode = 'P1',
    int wStart = 0,
    int wEnd = 0,
    int cStart = 0,
    int cEnd = 0,
    int dStart = 0,
    int dEnd = 0,
    String mark = '1',
    double weight = 0,
  }) =>
      ProductCode(
        productCode: productCode,
        barcode: barcode,
        wStart: wStart,
        wEnd: wEnd,
        cStart: cStart,
        cEnd: cEnd,
        dStart: dStart,
        dEnd: dEnd,
        mark: mark,
        weight: weight,
      );

  group('matchesTemplate', () {
    test('قالب بلا مقاطع (كود فقط) يطابق المطابق تمامًا فقط', () {
      final t = tpl(barcode: '2001234500789');
      expect(BarcodeResolver.matchesTemplate('2001234500789', t), isTrue);
      expect(BarcodeResolver.matchesTemplate('2001234500799', t), isFalse);
      expect(BarcodeResolver.matchesTemplate('200123450078', t), isFalse);
    });

    test('قالب وزن سليم: يتجاهل مقطع الوزن فقط', () {
      // وزن في 7-11، الباقي ثابت (الموضع 6 ثابت = 3).
      final t = tpl(barcode: '2001234500789', wStart: 7, wEnd: 11);
      expect(BarcodeResolver.matchesTemplate('2001239999789', t), isTrue);
      expect(BarcodeResolver.matchesTemplate('2001239999788', t), isFalse);
    });

    test('قالب منحل (الوزن يغطي الكل) لا يطابق أبدًا', () {
      final t = tpl(barcode: '2001234500789', wStart: 1, wEnd: 13);
      expect(BarcodeResolver.matchesTemplate('2001234500789', t), isFalse);
      expect(BarcodeResolver.matchesTemplate('9999999999999', t), isFalse);
    });

    test('قالب منحل (وزن+تاريخ يغطيان الكل) لا يطابق أبدًا', () {
      final t = tpl(
          barcode: '2001234500789', wStart: 1, wEnd: 7, dStart: 8, dEnd: 13);
      expect(BarcodeResolver.matchesTemplate('2001234500789', t), isFalse);
    });
  });

  group('templateWeight', () {
    test('مقطع كامل = الوزن هو الباركود نفسه → صفر', () {
      final t = tpl(barcode: '2001234500789', wStart: 1, wEnd: 13);
      expect(BarcodeResolver.templateWeight('2001234500789', t), 0);
    });

    test('مقطع سليم يحسب المقطع ÷ العلامة', () {
      final t = tpl(
          barcode: '2001234500789', wStart: 7, wEnd: 11, mark: '1000');
      // المقطع 45007 ÷ 1000
      expect(BarcodeResolver.templateWeight('2001234500789', t),
          closeTo(45.007, 1e-9));
    });

    test('غير مضبوط → صفر', () {
      final t = tpl(barcode: '2001234500789');
      expect(BarcodeResolver.templateWeight('2001234500789', t), 0);
    });
  });

  group('extractCodeCandidates', () {
    test('يستخرج المقطع + بدون أصفار بادئة', () {
      final t = tpl(barcode: '2000012300789', cStart: 4, cEnd: 9);
      final cands =
          BarcodeResolver.extractCodeCandidates('2000099900789', [t]);
      expect(cands.map((c) => c.code), contains('009990'));
      expect(cands.map((c) => c.code), contains('9990'));
    });

    test('غير المضبوط (0) يُتجاهل', () {
      final t = tpl(barcode: '2000012300789');
      expect(BarcodeResolver.extractCodeCandidates('2000012300789', [t]),
          isEmpty);
    });
  });

  group('BarcodeParser.calcValue', () {
    test('المقطع ÷ العلامة', () {
      expect(BarcodeParser.calcValue('2001234500789', 7, 11, '1000'),
          closeTo(45.007, 1e-9));
    });
  });
}
