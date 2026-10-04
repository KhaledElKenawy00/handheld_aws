import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../products/presentation/products_screen.dart';
import '../../suppliers/presentation/suppliers_screen.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../receipts/presentation/receipts_screen.dart';
import '../../deliveries/presentation/deliveries_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SANAD — سند'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _hero(context),
            const SizedBox(height: 12),
            counts.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ: $e'),
              data: (m) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                children: [
                  _card(context, 'الأصناف', '${m['products']}', Icons.inventory_2, AppTheme.navy, const ProductsScreen()),
                  _card(context, 'الموردين', '${m['suppliers']}', Icons.local_shipping, AppTheme.accent, const SuppliersTab()),
                  _card(context, 'العملاء', '${m['customers']}', Icons.people, Colors.teal, const CustomersTab()),
                  _card(context, 'أذون الاستلام', '${m['receipts']}', Icons.arrow_downward, AppTheme.success, const ReceiptsScreen()),
                  _card(context, 'أذون التسليم', '${m['deliveries']}', Icons.arrow_upward, AppTheme.warning, const DeliveriesScreen()),
                  _card(context, 'عمليات الجرد', '${m['inventory']}', Icons.fact_check, Colors.purple, const InventoryScreen()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('إجراءات سريعة',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _quick(context, Icons.add_box_outlined, '+ صنف', const ProductFormRoute()),
              _quick(context, Icons.add_business_outlined, '+ مورد', const SupplierFormRoute()),
              _quick(context, Icons.person_add_alt, '+ عميل', const CustomerFormRoute()),
              _quick(context, Icons.arrow_downward, 'إذن استلام', const CreateReceiptScreen()),
              _quick(context, Icons.arrow_upward, 'إذن تسليم', const CreateDeliveryScreen()),
              _quick(context, Icons.fact_check_outlined, 'جرد جديد', const CreateInventoryScreen()),
              _quick(context, Icons.upload_file_outlined, 'استيراد Excel', const ImportHubScreen()),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppTheme.navy, AppTheme.navyLight]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(children: [
        CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Text('س',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy))),
        SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('SANAD — سند',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text('نظام مخازن يعمل Offline بالكامل',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
      ]),
    );
  }

  Widget _card(BuildContext context, String t, String v, IconData ic,
      Color c, Widget page) {
    return StatCard(
        title: t,
        value: v,
        icon: ic,
        color: c,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => page)));
  }

  Widget _quick(
      BuildContext context, IconData ic, String label, Widget page) {
    // زر واضح عالي التباين: نص كحلي صريح على خلفية فاتحة
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.accentSoft,
        foregroundColor: AppTheme.navy,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w800),
      ),
      icon: Icon(ic, size: 20, color: AppTheme.navy),
      label: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy)),
      onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => page)),
    );
  }
}
