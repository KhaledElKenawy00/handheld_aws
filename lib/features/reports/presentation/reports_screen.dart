import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../receipts/presentation/receipts_screen.dart';
import '../../deliveries/presentation/deliveries_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';

/// التقارير: ملخص + فتح المستندات + تصدير — Meadow Green.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppHeader.appBar('التقارير'),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.padPage),
        children: [
          dash.when(
            loading: () => const AppCard(child: AppLoading()),
            error: (e, _) => AppErrorState(
                message: '$e',
                onRetry: () =>
                    ref.invalidate(dashboardProvider)),
            data: (m) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle(title: 'ملخص النشاط'),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: AppDimensions.gridColumns(
                      context,
                      wide: 2),
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio:
                      AppDimensions.gridAspect(context),
                  children: [
                    AppStatCard(
                        title: 'الأصناف',
                        value: '${m['products']}',
                        icon: Icons.inventory_2_rounded,
                        color: AppColors.primary),
                    AppStatCard(
                        title: 'الموردون',
                        value: '${m['suppliers']}',
                        icon:
                            Icons.local_shipping_rounded,
                        color: AppColors.meadow800),
                    AppStatCard(
                        title: 'العملاء',
                        value: '${m['customers']}',
                        icon: Icons.people_rounded,
                        color: AppColors.secondary),
                    AppStatCard(
                        title: 'أذون الاستلام',
                        value: '${m['receipts']}',
                        icon: Icons.arrow_downward_rounded,
                        color: AppColors.successStrong),
                    AppStatCard(
                        title: 'أذون التسليم',
                        value: '${m['deliveries']}',
                        icon: Icons.arrow_upward_rounded,
                        color: AppColors.warning),
                    AppStatCard(
                        title: 'الجرد',
                        value: '${m['inventory']}',
                        icon: Icons.fact_check_rounded,
                        color: AppColors.meadow900),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const AppSectionTitle(title: 'المستندات'),
          const SizedBox(height: 8),
          AppActionCard(
              title: 'أذون الاستلام',
              subtitle: 'عرض وطباعة وتصدير',
              icon: Icons.arrow_downward_rounded,
              color: AppColors.successStrong,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ReceiptsScreen()))),
          AppActionCard(
              title: 'أذون التسليم',
              subtitle: 'عرض وطباعة وتصدير',
              icon: Icons.arrow_upward_rounded,
              color: AppColors.warning,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const DeliveriesScreen()))),
          AppActionCard(
              title: 'تقارير الجرد',
              subtitle: 'الجلسات والفروقات',
              icon: Icons.fact_check_rounded,
              color: AppColors.meadow900,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const InventoryScreen()))),
          const SizedBox(height: 16),
          const AppSectionTitle(title: 'المخزون'),
          const SizedBox(height: 8),
          FutureBuilder(
            future: ref.read(productRepoProvider).stockTotals(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const AppCard(child: AppLoading());
              }
              final t = snap.data!;
              final total = t['total'] ?? 0;
              final zero = (t['zero'] ?? 0).toInt();
              final count = (t['count'] ?? 0).toInt();
              return AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: const Icon(
                          Icons.inventory_rounded,
                          color: AppColors.primary,
                          size: 25),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                              'إجمالي الوحدات: ${AppUtils.fmtQty(total)}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w800,
                                  color:
                                      AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                              'أصناف نفدت: $zero من $count',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors
                                      .textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
              'إجمالي قيمة المخزون (كمية فقط — بدون أسعار في V1)',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
