/// نتيجة صفحة واحدة: عناصر الصفحة + إجمالي الصفوف المطابقة.
/// يُجلب الاثنان معًا بنفس شروط البحث (items عبر search و total عبر count)
/// في Invalidate واحدة، فلا يحدث تعارض بينهما أبدًا.
class PagedResult<T> {
  final List<T> items;
  final int total;
  const PagedResult({required this.items, required this.total});
}

/// ثوابت ومساعدات الـ Pagination — كل القوائم تقرأ من قاعدة البيانات
/// بحد أقصى pageSize صف في الصفحة، والبحث يتم على مستوى SQL
/// (WHERE ... LIKE) قبل LIMIT/OFFSET، فالبحث يشمل كل الصفوف
/// وليس الصفحة المعروضة فقط.
class Pagination {
  /// عدد الصفوف في الصفحة — 10 كحد أقصى لتخفيف الحمل على أجهزة SUNMI الضعيفة
  /// ومنع التهنيج بدل تحميل الكل مرة واحدة.
  static const int defaultPageSize = 10;

  /// عدد الصفحات لإجمالي معين (صفحة واحدة على الأقل حتى لو فارغ)
  static int totalPages(int total, [int pageSize = defaultPageSize]) {
    if (total <= 0) return 1;
    return (total + pageSize - 1) ~/ pageSize;
  }

  /// إزاحة SQL لصفحة معينة (0-based)
  static int offsetFor(int page, [int pageSize = defaultPageSize]) =>
      (page < 0 ? 0 : page) * pageSize;

  /// تثبيت رقم الصفحة داخل المدى الصحيح
  static int clampPage(int page, int total,
      [int pageSize = defaultPageSize]) {
    final pages = totalPages(total, pageSize);
    if (page < 0) return 0;
    if (page > pages - 1) return pages - 1;
    return page;
  }
}
