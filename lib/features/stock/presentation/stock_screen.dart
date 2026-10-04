import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pagination/pagination.dart';
import '../../../core/providers.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/scan_input.dart';

/// شاشة المخزون الحالية + حركة صنف — paginated وتشترك مع الأصناف
/// في نفس البحث والصفحة (نفس مصدر البيانات).
class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(productQueryProvider);
    final page = ref.watch(productPageProvider);
    final list = ref.watch(productListProvider);
    final total = list.valueOrNull?.total ?? 0;
    final lastPage = Pagination.totalPages(total) - 1;
    if (total > 0 && page > lastPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(productPageProvider.notifier).state = lastPage;
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('المخزون')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: ScanTextField(
                hint: 'بحث في المخزون — اكتب أو امسح',
                onChanged: (v) {
                  ref.read(productQueryProvider.notifier).state = v;
                  ref.read(productPageProvider.notifier).state = 0;
                })),
        Expanded(
            child: list.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (paged) {
                  final ps = paged.items.cast<Product>();
                  if (ps.isEmpty) {
                    return const EmptyState(message: 'لا توجد أصناف');
                  }
                  return ListView.builder(
                      key: ValueKey('stock-$q-$page'),
                      itemCount: ps.length,
                      itemBuilder: (_, i) {
                        final p = ps[i];
                        final low = p.stock <= 0;
                        final qtyColor = low
                            ? const Color(0xFFB71C1C)
                            : const Color(0xFF1B7A2B);
                        final qtyBg = low
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFE6F4EA);
                        final qtyStr = p.stock ==
                                p.stock.truncateToDouble()
                            ? p.stock.toInt().toString()
                            : p.stock.toString();
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: low
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Icon(
                                    low
                                        ? Icons.warning_rounded
                                        : Icons.inventory_rounded,
                                    size: 22,
                                    color: low
                                        ? Colors.red.shade700
                                        : Colors.green.shade700),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(p.desc,
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF101A2E))),
                                    const SizedBox(height: 2),
                                    Text('كود: ${p.code}',
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF3A4763))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // كمية المخزون — ظاهرة دائمًا بخط واضح
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7),
                                decoration: BoxDecoration(
                                  color: qtyBg,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                      color: qtyColor.withValues(
                                          alpha: .45),
                                      width: 1.5),
                                ),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(qtyStr,
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.w800,
                                              color: qtyColor,
                                              height: 1.1)),
                                      Text('مخزون',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: qtyColor)),
                                    ]),
                              ),
                            ]),
                          ),
                        );
                      });
                })),
        PaginationBar(
          currentPage: page,
          total: total,
          isLoading: list.isLoading,
          onPageChanged: (p) =>
              ref.read(productPageProvider.notifier).state = p,
        ),
      ]),
    );
  }
}
