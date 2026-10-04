import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/app_utils.dart';
import '../../receipts/presentation/receipts_screen.dart';
import '../../deliveries/presentation/deliveries_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';

/// التقارير: ملخص + فتح المستندات + تصدير
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        dash.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (m) => Card(
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ملخص النشاط',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        Text('الأصناف: ${m['products']}'),
                        Text('الموردون: ${m['suppliers']}'),
                        Text('العملاء: ${m['customers']}'),
                        Text('أذون الاستلام: ${m['receipts']}'),
                        Text('أذون التسليم: ${m['deliveries']}'),
                        Text('الجرد: ${m['inventory']}'),
                      ]))),
        ),
        const SizedBox(height: 8),
        _tile(context, 'أذون الاستلام', Icons.arrow_downward,
            const ReceiptsScreen()),
        _tile(context, 'أذون التسليم', Icons.arrow_upward,
            const DeliveriesScreen()),
        _tile(context, 'تقارير الجرد', Icons.fact_check,
            const InventoryScreen()),
        const SizedBox(height: 8),
        const Text('إجمالي قيمة المخزون (كمية فقط — بدون أسعار في V1)',
            style: TextStyle(color: Colors.grey)),
        FutureBuilder(
          future: ref.read(productRepoProvider).stockTotals(),
          builder: (_, snap) {
            if (!snap.hasData) return const SizedBox();
            final t = snap.data!;
            final total = t['total'] ?? 0;
            final zero = (t['zero'] ?? 0).toInt();
            final count = (t['count'] ?? 0).toInt();
            return Card(
                child: ListTile(
              title:
                  Text('إجمالي الوحدات بالمخزن: ${AppUtils.fmtQty(total)}'),
              subtitle: Text('أصناف نفدت: $zero من $count'),
            ));
          },
        ),
      ]),
    );
  }

  Widget _tile(
      BuildContext context, String t, IconData ic, Widget page) {
    return Card(
        child: ListTile(
      leading: Icon(ic),
      title: Text(t),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => page)),
    ));
  }
}
