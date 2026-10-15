import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/common.dart';
import '../../products/presentation/products_screen.dart';
import '../../suppliers/presentation/suppliers_screen.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../receipts/presentation/receipts_screen.dart';
import '../../deliveries/presentation/deliveries_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../stock/presentation/stock_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../settings/presentation/settings_screen.dart';

/// Dashboard احترافي — Meadow Green Enterprise.
/// مرحباً + إحصائيات + عمليات سريعة + آخر العمليات.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppHeader.appBar(
        'SANAD — سند',
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.padPage),
          children: [
            _welcomeCard(context),
            const SizedBox(height: 16),
            const AppSectionTitle(title: 'نظرة عامة'),
            const SizedBox(height: 8),
            counts.when(
              loading: () => const AppLoading(),
              error: (e, _) => AppErrorState(
                  message: '$e',
                  onRetry: () =>
                      ref.invalidate(dashboardProvider)),
              data: (m) => LayoutBuilder(
                builder: (ctx, c) {
                  final cols =
                      AppDimensions.gridColumns(context, wide: 2);
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio:
                        AppDimensions.gridAspect(context),
                    children: [
                      AppStatCard(
                          title: 'إجمالي الأصناف',
                          value: '${m['products']}',
                          icon: AppIcons.products,
                          color: AppColors.primary,
                          onTap: () => _go(context,
                              const ProductsScreen())),
                      AppStatCard(
                          title: 'عدد العملاء',
                          value: '${m['customers']}',
                          icon: AppIcons.customers,
                          color: AppColors.secondary,
                          onTap: () => _go(
                              context, const CustomersTab())),
                      AppStatCard(
                          title: 'عدد الموردين',
                          value: '${m['suppliers']}',
                          icon: AppIcons.suppliers,
                          color: AppColors.meadow800,
                          onTap: () => _go(context,
                              const SuppliersTab())),
                      AppStatCard(
                          title: 'أذون الاستلام',
                          value: '${m['receipts']}',
                          icon: AppIcons.receipts,
                          color: AppColors.successStrong,
                          onTap: () => _go(context,
                              const ReceiptsScreen())),
                      AppStatCard(
                          title: 'أذون التسليم',
                          value: '${m['deliveries']}',
                          icon: AppIcons.deliveries,
                          color: AppColors.warning,
                          onTap: () => _go(context,
                              const DeliveriesScreen())),
                      AppStatCard(
                          title: 'عمليات الجرد',
                          value: '${m['inventory']}',
                          icon: Icons.fact_check_rounded,
                          color: AppColors.meadow900,
                          onTap: () => _go(context,
                              const InventoryScreen())),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const AppSectionTitle(title: 'العمليات السريعة'),
            const SizedBox(height: 8),
            _quickGrid(context),
            const SizedBox(height: 16),
            const AppSectionTitle(title: 'آخر العمليات'),
            const SizedBox(height: 8),
            _recentOps(context, ref),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget page) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _welcomeCard(BuildContext context) {
    return AppHero(
      title: 'مرحباً!',
      subtitle: 'نظام مخازن يعمل Offline بالكامل',
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Text('س',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ),
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.offline_bolt_rounded,
                  size: 15, color: Colors.white),
              SizedBox(width: 4),
              Text('Offline',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickGrid(BuildContext context) {
    final items = [
      (
        'تسليمات',
        'إذن تسليم جديد',
        AppIcons.deliveries,
        AppColors.warning,
        const CreateDeliveryScreen()
      ),
      (
        'استلامات',
        'إذن استلام جديد',
        AppIcons.receipts,
        AppColors.successStrong,
        const CreateReceiptScreen()
      ),
      (
        'إدارة المخزن',
        'المخزون والأصناف',
        AppIcons.stock,
        AppColors.primary,
        const StockScreen()
      ),
      (
        'الأصناف',
        'بحث وإضافة صنف',
        AppIcons.products,
        AppColors.meadow800,
        const ProductsScreen()
      ),
      (
        'الجرد',
        'جلسة جرد جديدة',
        Icons.fact_check_rounded,
        AppColors.meadow900,
        const CreateInventoryScreen()
      ),
      (
        'الإعدادات',
        'النسخ والتصدير',
        AppIcons.settings,
        AppColors.textSecondary,
        const SettingsScreen()
      ),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        final cols = AppDimensions.gridColumns(context, wide: 2);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: [
            for (final it in items)
              AppActionCard(
                title: it.$1,
                subtitle: it.$2,
                icon: it.$3,
                color: it.$4,
                onTap: () => _go(context, it.$5),
              ),
          ],
        );
      },
    );
  }

  Widget _recentOps(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: Future.wait([
        ref.read(receiptRepoProvider).list(limit: 4),
        ref.read(deliveryRepoProvider).list(limit: 4),
      ]),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppCard(
              child: AppLoading(message: 'جارٍ تحميل آخر العمليات...'));
        }
        if (snap.hasError) {
          return AppErrorState(message: '${snap.error}');
        }
        final receipts =
            (snap.data![0] as List).cast<ReceiptHeader>();
        final deliveries =
            (snap.data![1] as List).cast<DeliveryHeader>();
        if (receipts.isEmpty && deliveries.isEmpty) {
          return const AppEmptyState(
            message: 'ابدأ بإضافة أول إذن استلام أو تسليم',
            icon: Icons.receipt_long_rounded,
          );
        }
        return Column(
          children: [
            for (final r in receipts)
              AppTransactionCard(
                partnerName: r.supplierName,
                voucherId: r.id,
                date: r.date,
                totalItems: r.totalItems,
                totalQty: r.totalQty,
                isReceipt: true,
                status: 'استلام',
                onTap: () => _go(context,
                    ReceiptDetailsScreen(id: r.id)),
              ),
            for (final d in deliveries)
              AppTransactionCard(
                partnerName: d.customerName,
                voucherId: d.id,
                date: d.date,
                totalItems: d.totalItems,
                totalQty: d.totalQty,
                isReceipt: false,
                status: 'تسليم',
                onTap: () => _go(context,
                    DeliveryDetailsScreen(id: d.id)),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(
                        Icons.arrow_downward_rounded,
                        size: 19),
                    label: const Text('كل الاستلامات'),
                    onPressed: () =>
                        _go(context, const ReceiptsScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 19),
                    label: const Text('كل التسليمات'),
                    onPressed: () =>
                        _go(context, const DeliveriesScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // تقارير سريعة — نفس روح التصميم المرجعي
            AppCard(
              onTap: () => _go(context, const ReportsScreen()),
              child: const Row(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('عرض التقارير والملخص',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ),
                  Icon(Icons.arrow_back_ios_rounded,
                      size: 17, color: AppColors.textMuted),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
