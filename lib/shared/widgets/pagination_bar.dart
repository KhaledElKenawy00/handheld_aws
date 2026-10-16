import 'package:flutter/material.dart';

import '../../core/pagination/pagination.dart';

/// شريط تنقل الصفحات الموحد — يُستخدم في كل القوائم.
/// يعرض: إجمالي النتائج + رقم الصفحة الحالية + أزرار الأولى/السابق/التالي/الأخيرة.
/// ملاحظة: البحث يتم في قاعدة البيانات (SQL WHERE) قبل التقطيع،
/// لذلك إجمالي النتائج والتنقل يشملان كل الصفوف المطابقة للبحث.
class PaginationBar extends StatelessWidget {
  /// الصفحة الحالية (0-based)
  final int currentPage;
  /// إجمالي الصفوف المطابقة (من COUNT بنفس شروط البحث)
  final int total;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  /// true أثناء تحميل الصفحة — يعطّل الأزرار ويعرض مؤشرًا
  final bool isLoading;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.total,
    required this.onPageChanged,
    this.pageSize = Pagination.defaultPageSize,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final pages = Pagination.totalPages(total, pageSize);
    final page = Pagination.clampPage(currentPage, total, pageSize);
    final canPrev = page > 0 && !isLoading;
    final canNext = page < pages - 1 && !isLoading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x140B3A5B), blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.layers_outlined, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'إجمالي: $total • صفحة ${page + 1} من $pages',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.first_page),
            tooltip: 'الأولى',
            onPressed: canPrev ? () => onPageChanged(0) : null,
          ),
          IconButton(
            // في RTL: السابق يتجه يمينًا
            icon: const Icon(Icons.chevron_right),
            tooltip: 'السابق',
            onPressed: canPrev ? () => onPageChanged(page - 1) : null,
          ),
          IconButton(
            // في RTL: التالي يتجه يسارًا
            icon: const Icon(Icons.chevron_left),
            tooltip: 'التالي',
            onPressed: canNext ? () => onPageChanged(page + 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            tooltip: 'الأخيرة',
            onPressed: canNext ? () => onPageChanged(pages - 1) : null,
          ),
        ],
      ),
    );
  }
}
