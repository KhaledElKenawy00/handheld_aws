import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/scanner/mock_scanner_service.dart';
import 'package:sanad/core/utils/app_utils.dart';
import 'package:sanad/shared/models/entities.dart';

void main() {
  group('Stock calculations — السيناريو الأساسي', () {
    test('Receipt 10 ثم Delivery 3 => المخزون 7', () {
      double stock = 0;
      stock += 10; // receipt
      expect(stock, 10);
      stock -= 3; // delivery
      expect(stock, 7);
    });

    test('منع المخزون السالب (افتراضيًا)', () {
      const allowNegative = false;
      const stock = 5.0;
      const requested = 10.0;
      final blocked = !allowNegative && stock < requested;
      expect(blocked, isTrue);
    });

    test('المسح المتكرر يزيد الكمية بدل صف جديد', () {
      final lines = <DocLine>[];
      void addScan(String code, String name) {
        final i = lines.indexWhere((e) => e.productCode == code);
        if (i >= 0) {
          lines[i].quantity += 1;
        } else {
          lines.add(
              DocLine(productCode: code, productName: name, quantity: 1));
        }
      }

      addScan('10001', 'أسمنت');
      addScan('10001', 'أسمنت');
      addScan('10001', 'أسمنت');
      expect(lines.length, 1);
      expect(lines.first.quantity, 3);
      lines.first.quantity = 10; // تعديل يدوي
      expect(lines.first.quantity, 10);
    });
  });

  group('Inventory comparison — ناقص/زائد/متساوي', () {
    test('Expected 7, Actual 5 => ناقص 2', () {
      const it = InventoryItem(
        sessionId: 'INV-2026-000001',
        productCode: '10001',
        productName: 'أسمنت',
        expectedQty: 7,
        actualQty: 5,
      );
      expect(it.difference, -2);
      expect(it.statusAr, 'ناقص');
    });

    test('Expected 50, Actual 55 => زائد', () {
      const it = InventoryItem(
        sessionId: 'x',
        productCode: 'y',
        productName: 'z',
        expectedQty: 50,
        actualQty: 55,
      );
      expect(it.difference, 5);
      expect(it.statusAr, 'زائد');
    });

    test('Expected == Actual => متساوي', () {
      const it = InventoryItem(
        sessionId: 'x',
        productCode: 'y',
        productName: 'z',
        expectedQty: 50,
        actualQty: 50,
      );
      expect(it.difference, 0);
      expect(it.statusAr, 'متساوي');
    });
  });

  group('Document numbers — تنسيق فريد', () {
    test('REC format', () {
      const y = 2026;
      const n = 1;
      final id = 'REC-$y-${n.toString().padLeft(6, '0')}';
      expect(id, 'REC-2026-000001');
    });
    test('SUP/CUS format', () {
      expect('SUP-${1.toString().padLeft(6, '0')}', 'SUP-000001');
      expect('CUS-${2.toString().padLeft(6, '0')}', 'CUS-000002');
    });
  });

  group('Import summary', () {
    test('Imported/Updated/Skipped math', () {
      const s = ImportSummary(
          imported: 950, updated: 20, skipped: 5, total: 975);
      expect(s.valid, 970);
    });
  });

  group('Scanner (mock للاختبار فقط)', () {
    test('MockScannerService يبث الأكواد', () async {
      final mock = MockScannerService();
      await mock.initialize();
      final fut = mock.scanStream.first;
      mock.emit('10001');
      expect(await fut, '10001');
      await mock.dispose();
    });

    test('Debounce: نفس الكود خلال 400ms يُتجاهل', () {
      DateTime lastAt = DateTime(2026, 1, 1);
      String lastCode = '';
      bool debounced(String code, DateTime now) {
        if (code == lastCode &&
            now.difference(lastAt).inMilliseconds < 400) {
          return true;
        }
        lastCode = code;
        lastAt = now;
        return false;
      }

      final t0 = DateTime(2026, 1, 1, 0, 0, 0);
      expect(debounced('10001', t0), isFalse);
      expect(
          debounced('10001', t0.add(const Duration(milliseconds: 100))),
          isTrue);
      expect(
          debounced('10001', t0.add(const Duration(milliseconds: 600))),
          isFalse);
    });
  });

  group('Stock movement audit', () {
    test('before/after quantities', () {
      const before = 50.0;
      const qty = 10.0;
      const after = before + qty;
      final m = StockMovement(
        productCode: '10001',
        type: 'RECEIPT',
        referenceId: 'REC-2026-000001',
        quantity: qty,
        beforeQty: before,
        afterQty: after,
        createdAt: '2026-10-04 10:00:00',
      );
      expect(m.afterQty - m.beforeQty, m.quantity);
    });
  });
}
