import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
import '../../settings/presentation/settings_screen.dart';

/// الرئيسية — مضغوطة لتظهر كاملة بدون سكرول على شاشات الهاند هيلد:
/// إحصائيات 3 أعمدة + عمليات سريعة مضغوطة + آخر عمليتين فقط.
/// كل الوجهات متاحة كما هي (الكروت → القوائم الكاملة).
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
          padding: const EdgeInsets.all(10),
          children: [
            const AppSectionTitle(title: 'نظرة عامة'),
            const SizedBox(height: 4),
            counts.when(
              loading: () => const AppLoading(),
              error: (e, _) => AppErrorState(
                  message: '$e',
                  onRetry: () =>
                      ref.invalidate(dashboardProvider)),
                      data: (m) => GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.9,
                        children: [
                          AppStatCard(
                              title: 'الأصناف',
                              value: '${m['products']}',
                              icon: AppIcons.products,
                              color: const Color(0xFF1E88E5),
                              bg: const Color(0xFFE3F2FD),
                              onTap: () => _go(context,
                                  const ProductsScreen())),
                          AppStatCard(
                              title: 'العملاء',
                              value: '${m['customers']}',
                              icon: AppIcons.customers,
                              color: const Color(0xFF009688),
                              bg: const Color(0xFFE0F2F1),
                              onTap: () => _go(
                                  context, const CustomersTab())),
                          AppStatCard(
                              title: 'الموردين',
                              value: '${m['suppliers']}',
                              icon: AppIcons.suppliers,
                              color: const Color(0xFF8E24AA),
                              bg: const Color(0xFFF3E5F5),
                              onTap: () => _go(context,
                                  const SuppliersTab())),
                          AppStatCard(
                              title: 'استلام',
                              value: '${m['receipts']}',
                              icon: AppIcons.receipts,
                              color: const Color(0xFF43A047),
                              bg: const Color(0xFFE8F5E9),
                              onTap: () => _go(context,
                                  const ReceiptsScreen())),
                          AppStatCard(
                              title: 'تسليم',
                              value: '${m['deliveries']}',
                              icon: AppIcons.deliveries,
                              color: const Color(0xFFE53935),
                              bg: const Color(0xFFFFEBEE),
                              onTap: () => _go(context,
                                  const DeliveriesScreen())),
                          AppStatCard(
                              title: 'الجرد',
                              value: '${m['inventory']}',
                              icon: Icons.fact_check_rounded,
                              color: const Color(0xFF3949AB),
                              bg: const Color(0xFFE8EAF6),
                              onTap: () => _go(context,
                                  const InventoryScreen())),
                        ],
                      ),
            ),
            const SizedBox(height: 8),
            const AppSectionTitle(title: 'العمليات السريعة'),
            const SizedBox(height: 4),
            _quickGrid(context),
            const SizedBox(height: 8),
            const AppSectionTitle(title: 'آخر العمليات'),
            const SizedBox(height: 4),
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

  /// صف أخير مضغوط: أيقونة صغيرة + اسم/بيان + شارة كمية.
  Widget _recentRow(
    BuildContext context, {
    required String name,
    required String info,
    required double qty,
    required bool isReceipt,
    required VoidCallback onTap,
  }) {
    final accent =
        isReceipt ? const Color(0xFF43A047) : const Color(0xFFE53935);
    final accentBg = isReceipt
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFEBEE);
    final qtyStr =
        qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();
    return AppCard(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isReceipt
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 15,
              color: accent,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                Text(info,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              qtyStr,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontFamily: AppTextStyles.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: accent),
            ),
          ),
        ],
      ),
    );
  }

  /// شبكة مضغوطة 3×2 (أيقونة ملونة + اسم فقط) لتوفير المساحة.
  Widget _quickGrid(BuildContext context) {
    const blue = Color(0xFF1E88E5);
    const blueBg = Color(0xFFE3F2FD);
    const green = Color(0xFF43A047);
    const greenBg = Color(0xFFE8F5E9);
    const orange = Color(0xFFFB8C00);
    const orangeBg = Color(0xFFFFF3E0);
    const purple = Color(0xFF8E24AA);
    const purpleBg = Color(0xFFF3E5F5);
    const red = Color(0xFFE53935);
    const redBg = Color(0xFFFFEBEE);
    const slate = Color(0xFF546E7A);
    const slateBg = Color(0xFFECEFF1);
    final items = [
      (
        'تسليم',
        AppIcons.deliveries,
        red,
        redBg,
        const CreateDeliveryScreen()
      ),
      (
        'استلام',
        AppIcons.receipts,
        green,
        greenBg,
        const CreateReceiptScreen()
      ),
      (
        'المخزن',
        AppIcons.stock,
        blue,
        blueBg,
        const StockScreen()
      ),
      (
        'صنف',
        AppIcons.products,
        purple,
        purpleBg,
        const ProductsScreen()
      ),
      (
        'جرد',
        Icons.fact_check_rounded,
        orange,
        orangeBg,
        const CreateInventoryScreen()
      ),
      (
        'الإعدادات',
        AppIcons.settings,
        slate,
        slateBg,
        const SettingsScreen()
      ),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.7,
      children: [
        for (final it in items)
          AppCard(
            padding: const EdgeInsets.symmetric(
                horizontal: 4, vertical: 8),
            onTap: () => _go(context, it.$5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: it.$4,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(it.$2, size: 15, color: it.$3),
                ),
                const SizedBox(height: 3),
                Text(it.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
      ],
    );
  }

  /// آخر عمليتين فقط (استلام + تسليم) — القوائم الكاملة من كروت
  /// الإحصائيات أو تبويب المعاملات.
  Widget _recentOps(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: Future.wait([
        ref.read(receiptRepoProvider).list(limit: 2),
        ref.read(deliveryRepoProvider).list(limit: 2),
      ]),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const AppCard(
              child: AppLoading(message: 'جارٍ التحميل...'));
        }
        if (snap.hasError) {
          return AppErrorState(message: '${snap.error}');
        }
        final receipts =
            (snap.data![0] as List).cast<ReceiptHeader>();
        final deliveries =
            (snap.data![1] as List).cast<DeliveryHeader>();
        final cards = <Widget>[];
        void addReceipt(ReceiptHeader r) => cards.add(_recentRow(
              context,
              name: r.supplierName,
              info: '${r.id} • ${r.date}',
              qty: r.totalQty,
              isReceipt: true,
              onTap: () =>
                  _go(context, ReceiptDetailsScreen(id: r.id)),
            ));
        void addDelivery(DeliveryHeader d) => cards.add(_recentRow(
              context,
              name: d.customerName,
              info: '${d.id} • ${d.date}',
              qty: d.totalQty,
              isReceipt: false,
              onTap: () =>
                  _go(context, DeliveryDetailsScreen(id: d.id)),
            ));
        if (receipts.isNotEmpty) addReceipt(receipts.first);
        if (deliveries.isNotEmpty && cards.length < 2) {
          addDelivery(deliveries.first);
        }
        if (cards.length < 2 && receipts.length > 1) {
          addReceipt(receipts[1]);
        }
        if (cards.length < 2 && deliveries.length > 1) {
          addDelivery(deliveries[1]);
        }
        if (cards.isEmpty) {
          return const AppEmptyState(
            message: 'ابدأ بإضافة أول إذن استلام أو تسليم',
            icon: Icons.receipt_long_rounded,
          );
        }
        return Column(children: cards);
      },
    );
  }
}
