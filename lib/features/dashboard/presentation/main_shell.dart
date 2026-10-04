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

/// التنقل الرئيسي — BottomNavigation مناسب لشاشة SUNMI L2s Pro
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int idx = 0;

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
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'المخزون'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'المعاملات'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'الأطراف'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'التقارير'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
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
        appBar: AppBar(
          title: const Text('المعاملات'),
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
        appBar: AppBar(
          title: const Text('الأطراف'),
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
