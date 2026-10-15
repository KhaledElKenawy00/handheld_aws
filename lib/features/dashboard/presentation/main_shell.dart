import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../products/presentation/products_screen.dart';
import '../../receipts/presentation/receipts_screen.dart';
import '../../deliveries/presentation/deliveries_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'dashboard_screen.dart';
import '../../stock/presentation/stock_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../suppliers/presentation/suppliers_screen.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/common.dart';

/// التنقل الرئيسي — BottomNavigation مناسب لشاشة SUNMI L2s Pro.
/// RTL + Meadow Green indicator.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int idx = 0;

  @override
  void initState() {
    super.initState();
    // الأرشفة الأسبوعية التلقائية للكمبيوتر (تعمل في الخلفية عند الاستحقاق).
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoArchive());
  }

  Future<void> _autoArchive() async {
    try {
      final sum = await ref
          .read(archiveServiceProvider)
          .runIfDue();
      if (sum == null || !mounted) return;
      ref.invalidate(deliveryListProvider);
      ref.invalidate(receiptListProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        toast(context,
            'تمت الأرشفة الأسبوعية: ${sum.files} ملف على الكمبيوتر — اتمسح ${sum.deliveries + sum.receipts + sum.returns} إذن');
      }
    } catch (e) {
      if (mounted) showError(context, 'تعذرت الأرشفة الأسبوعية: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      DashboardScreen(),
      StockScreen(),
      TransactionsTabs(),
      PartiesTabs(),
      ReportsScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: idx, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'المخزون'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'المعاملات'),
          NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'الأطراف'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'التقارير'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'الإعدادات'),
        ],
      ),
    );
  }
}

class TransactionsTabs extends StatelessWidget {
  const TransactionsTabs({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppHeader.appBar(
          'المعاملات',
          bottom: const TabBar(tabs: [
            Tab(text: 'استلام'),
            Tab(text: 'تسليم'),
            Tab(text: 'الجرد'),
          ]),
        ),
        body: const TabBarView(children: [
          ReceiptsScreen(),
          DeliveriesScreen(),
          InventoryScreen(),
        ]),
      ),
    );
  }
}

class PartiesTabs extends StatelessWidget {
  const PartiesTabs({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppHeader.appBar(
          'الأطراف',
          bottom: const TabBar(tabs: [
            Tab(text: 'الأصناف'),
            Tab(text: 'الموردين'),
            Tab(text: 'العملاء'),
          ]),
        ),
        body: const TabBarView(children: [
          ProductsScreen(),
          SuppliersTab(),
          CustomersTab(),
        ]),
      ),
    );
  }
}
