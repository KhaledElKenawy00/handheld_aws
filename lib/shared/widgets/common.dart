import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../models/entities.dart';
import 'app_ui.dart';

/// عناصر مشتركة — تحافظ على نفس الـ API القديم
/// لكن بتصميم Meadow Green Enterprise الجديد.
/// الشاشات الجديدة يُفضّل أن تستخدم [app_ui.dart] مباشرة.

// ── Icon mapping الموحد ──────────────────────────────
class AppIcons {
  AppIcons._();
  static const IconData products = Icons.inventory_2_rounded;
  static const IconData customers = Icons.people_rounded;
  static const IconData suppliers = Icons.local_shipping_rounded;
  static const IconData warehouse = Icons.warehouse_rounded;
  static const IconData deliveries = Icons.local_shipping_rounded;
  static const IconData receipts = Icons.receipt_long_rounded;
  static const IconData returns = Icons.undo_rounded;
  static const IconData transfers = Icons.swap_horiz_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData users = Icons.manage_accounts_rounded;
  static const IconData print = Icons.print_rounded;
  static const IconData export = Icons.file_download_rounded;
  static const IconData import = Icons.file_upload_rounded;
  static const IconData stock = Icons.inventory_rounded;
  static const IconData reports = Icons.bar_chart_rounded;
}

class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  const SearchField(
      {super.key, required this.hint, required this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) {
    Timer? t;
    return TextField(
      controller: controller,
      style: const TextStyle(
          fontFamily: AppTextStyles.family,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon:
            const Icon(Icons.search_rounded, size: 22),
      ),
      onChanged: (v) {
        t?.cancel();
        t = Timer(const Duration(milliseconds: 300), () => onChanged(v));
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppStatCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

/// شارة كمية عالية التباين
class QtyBadge extends StatelessWidget {
  final double qty;
  final bool isReceipt;
  const QtyBadge({super.key, required this.qty, this.isReceipt = true});

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.qtyFg(isReceipt);
    final bg = AppColors.qtyBg(isReceipt);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusBadge),
        border:
            Border.all(color: fg.withValues(alpha: .35), width: 1.2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_fmt(qty),
            textDirection: TextDirection.ltr,
            style: TextStyle(
                fontFamily: AppTextStyles.family,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: fg,
                height: 1.1)),
        Text('كمية',
            style: TextStyle(
                fontFamily: AppTextStyles.family,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg)),
      ]),
    );
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}

/// كارت إذن موحد: العنوان = اسم المورد/العميل
/// + رقم الإذن والتاريخ وعدد الأصناف + شارة كمية.
class VoucherCard extends StatelessWidget {
  final String partnerName;
  final String voucherId;
  final String date;
  final int totalItems;
  final double totalQty;
  final bool isReceipt;
  final VoidCallback onTap;
  const VoucherCard({
    super.key,
    required this.partnerName,
    required this.voucherId,
    required this.date,
    required this.totalItems,
    required this.totalQty,
    required this.isReceipt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTransactionCard(
      partnerName: partnerName,
      voucherId: voucherId,
      date: date,
      totalItems: totalItems,
      totalQty: totalQty,
      isReceipt: isReceipt,
      onTap: onTap,
    );
  }
}

/// سطر صنف داخل إذن: اسم + كمية واضحة
class VoucherLineCard extends StatelessWidget {
  final String productName;
  final String productCode;
  final double quantity;
  final bool isReceipt;
  final Widget? stepper;
  final VoidCallback? onDelete;
  const VoucherLineCard({
    super.key,
    required this.productName,
    required this.productCode,
    required this.quantity,
    this.isReceipt = true,
    this.stepper,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('كود: $productCode',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                if (stepper != null) ...[
                  const SizedBox(height: 6),
                  stepper!,
                ],
              ]),
        ),
        const SizedBox(width: 8),
        QtyBadge(qty: quantity, isReceipt: isReceipt),
        if (onDelete != null)
          IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger, size: 22),
              onPressed: onDelete),
      ]),
    );
  }
}

/// لوحة مسح — Meadow Green hero.
class ScanPanel extends StatelessWidget {
  final VoidCallback onTriggerScan;
  final int scannedCount;
  final String message;
  const ScanPanel({
    super.key,
    required this.onTriggerScan,
    this.scannedCount = 0,
    this.message = 'لإضافة الأصناف ابدأ بالمسح مباشرة بالضغط على زر المسح',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.document_scanner_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(height: 10),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: AppTextStyles.family,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.5)),
        const SizedBox(height: 4),
        Text('امسح بالزر الفيزيائي أو زر البدء — يسمع تلقائيًا بدون كتابة',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppTextStyles.family,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: .85))),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
              minimumSize: const Size(64, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onTriggerScan,
            icon: const Icon(Icons.qr_code_scanner_rounded,
                size: 22),
            label: Text(
                scannedCount > 0
                    ? 'مسح صنف آخر ($scannedCount ممسوح)'
                    : 'ابدأ المسح الآن',
                style: const TextStyle(
                    fontFamily: AppTextStyles.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(message: message, icon: icon);
  }
}

class QtyStepper extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const QtyStepper({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = TextEditingController(text: _fmt(value));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _stepBtn(
        icon: Icons.remove_rounded,
        color: AppColors.primaryDark,
        onTap: () =>
            onChanged((value - 1).clamp(0, 9999999).toDouble()),
      ),
      const SizedBox(width: 4),
      SizedBox(
        width: 72,
        child: TextField(
          controller: c,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
              fontFamily: AppTextStyles.family,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11)),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          ],
          onSubmitted: (v) =>
              onChanged(double.tryParse(v) ?? value),
        ),
      ),
      const SizedBox(width: 4),
      _stepBtn(
        icon: Icons.add_rounded,
        color: AppColors.successStrong,
        onTap: () => onChanged(value + 1),
      ),
    ]);
  }

  Widget _stepBtn(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(11),
          border:
              Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}

/// شريط المسح الموحد: زر مسح + حقل يدوي
class ScanBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onTriggerScan;
  final ValueChanged<String> onSubmit;
  final String hint;
  const ScanBar({
    super.key,
    required this.controller,
    required this.onTriggerScan,
    required this.onSubmit,
    this.hint = 'امسح أو أدخل الكود ثم Enter',
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: false,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
                fontFamily: AppTextStyles.family,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
            decoration: InputDecoration(
                hintText: hint,
                prefixIcon:
                    const Icon(Icons.qr_code_rounded, size: 21)),
            onSubmitted: onSubmit,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onTriggerScan,
          icon: const Icon(Icons.document_scanner_outlined,
              size: 20),
          label: const Text('مسح',
              style: TextStyle(
                  fontFamily: AppTextStyles.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(88, 48),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
          ),
        ),
      ]),
    );
  }
}

Future<void> showError(BuildContext context, Object e) {
  return showDialog(
    context: context,
    builder: (_) => AppDialog(
      title: 'تنبيه',
      content: Text(
          e.toString().replaceAll('Exception: ', ''),
          style: const TextStyle(
              fontFamily: AppTextStyles.family,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.6)),
      actions: [
        AppButton(
            label: 'حسنًا',
            onPressed: () => Navigator.pop(context),
            expanded: false),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String msg,
    {String title = 'تأكيد'}) async {
  final isDelete = title.contains('حذف') || msg.contains('حذف');
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: isDelete ? 'تأكيد الحذف' : title,
      content: Text(msg,
          style: const TextStyle(
              fontFamily: AppTextStyles.family,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.6)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
        isDelete
            ? AppButton.danger(
                label: 'حذف',
                onPressed: () => Navigator.pop(context, true),
                expanded: false)
            : AppButton(
                label: 'تأكيد',
                onPressed: () => Navigator.pop(context, true),
                expanded: false),
      ],
    ),
  );
  return r ?? false;
}

/// حوار "الصنف غير موجود" مع زر إضافة
Future<bool> productNotFoundDialog(
    BuildContext context, String barcode) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: 'الصنف غير موجود',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الباركود: $barcode',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                  fontFamily: AppTextStyles.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('هل تريد إضافة هذا الصنف؟',
              style: TextStyle(
                  fontFamily: AppTextStyles.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.6)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
        AppButton(
            label: 'إضافة صنف',
            onPressed: () => Navigator.pop(context, true),
            expanded: false,
            icon: Icons.add_rounded),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              fontFamily: AppTextStyles.family,
              fontSize: 13,
              fontWeight: FontWeight.w700))));
}

/// صف خلية واحد لجدول الأصناف (نظام الخلايا بدل الكروت).
class CellLineData {
  final String code;
  final String name;
  final double qty;
  final double weight;
  final double price;
  const CellLineData({
    required this.code,
    required this.name,
    required this.qty,
    this.weight = 0,
    this.price = 0,
  });
}

/// جدول خلايا: الصنف | كمية | وزن | سعر | حذف.
/// - المسح المتكرر لنفس الصنف يدمج في نفس الصف (المنطق في الـ repo / _pushLine).
/// - الخلايا الرقمية قابلة للتعديل المباشر (تحدّث الكمية/الوزن/السعر).
class LinesCellTable extends StatelessWidget {
  final List<CellLineData> rows;
  final ValueChanged<int>? onDelete;
  final ValueChanged<int>? onEdit;
  final void Function(int index, double value)? onQtyChanged;
  final void Function(int index, double value)? onWeightChanged;
  final void Function(int index, double value)? onPriceChanged;
  /// يُستدعى عند التقاط مسحة باركود ضلّت طريقها لخلية رقمية (الماسح
  /// بوضع wedge يكتب في الحقل المركّز). يُرجع true لو استُهلكت كمسحة.
  final Future<bool> Function(String code)? onScanRedirect;
  final bool showPrice;
  final bool editable;
  const LinesCellTable({
    super.key,
    required this.rows,
    this.onDelete,
    this.onEdit,
    this.onQtyChanged,
    this.onWeightChanged,
    this.onPriceChanged,
    this.onScanRedirect,
    this.showPrice = true,
    this.editable = true,
  });

  String _f(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  String _f2(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // هيدر الخلايا
        Container(
          color: AppColors.primaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(children: [
            const Expanded(
                flex: 4,
                child: Text('الصنف',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white))),
            const Expanded(
                flex: 2,
                child: Text('كمية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white))),
            const Expanded(
                flex: 2,
                child: Text('وزن',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white))),
            if (showPrice)
              const Expanded(
                  flex: 2,
                  child: Text('سعر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: AppTextStyles.family,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white))),
            if (onDelete != null || onEdit != null)
              SizedBox(
                  width: (onDelete != null && onEdit != null) ? 72 : 36,
                  child: const Text('',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white))),
          ]),
        ),
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          return Container(
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : const Color(0xFFF6F8F6),
              border: const Border(
                  top: BorderSide(color: AppColors.border, width: .6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // خلية الصنف: اسم + كود
              Expanded(
                flex: 4,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: AppTextStyles.family,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      Text(r.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontFamily: AppTextStyles.family,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ]),
              ),
              // خلية الكمية
              Expanded(
                  flex: 2,
                  child: _NumCell(
                    key: ValueKey('q-$i-${r.qty}'),
                    initial: _f(r.qty),
                    editable: editable && onQtyChanged != null,
                    onSubmit: (v) => onQtyChanged?.call(i, v),
                    onScanRedirect: onScanRedirect,
                  )),
              // خلية الوزن
              Expanded(
                  flex: 2,
                  child: _NumCell(
                    key: ValueKey('w-$i-${r.weight}'),
                    initial: _f2(r.weight),
                    editable: editable && onWeightChanged != null,
                    onSubmit: (v) => onWeightChanged?.call(i, v),
                    onScanRedirect: onScanRedirect,
                  )),
              // خلية السعر
              if (showPrice)
                Expanded(
                    flex: 2,
                    child: _NumCell(
                      key: ValueKey('p-$i-${r.price}'),
                      initial: _f(r.price),
                      editable: editable && onPriceChanged != null,
                      onSubmit: (v) => onPriceChanged?.call(i, v),
                      onScanRedirect: onScanRedirect,
                    )),
              if (onEdit != null)
                SizedBox(
                  width: 36,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                      icon: const Icon(Icons.edit_outlined,
                          color: AppColors.primaryDark, size: 20),
                      onPressed: () => onEdit!(i)),
                ),
              if (onDelete != null)
                SizedBox(
                  width: 36,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 20),
                      onPressed: () => onDelete!(i)),
                ),
            ]),
          );
        }),
      ]),
    );
  }
}

/// خلية رقمية قابلة للتحرير المباشر داخل الجدول.
/// - مع حراسة المسحات الضالة: الماسح بوضع wedge يكتب في الحقل المركّز،
///   فلو دخلت دفعة سريعة بمواصفات باركود (≥4 محارف بمتوسط <50ms) تُعاد
///   عبر [onScanRedirect] بدل حفظها كرقم. الكتابة اليدوية لا تتأثر.
class _NumCell extends StatefulWidget {
  final String initial;
  final bool editable;
  final ValueChanged<double> onSubmit;
  final Future<bool> Function(String code)? onScanRedirect;
  const _NumCell(
      {super.key,
      required this.initial,
      required this.editable,
      required this.onSubmit,
      this.onScanRedirect});
  @override
  State<_NumCell> createState() => _NumCellState();
}

class _NumCellState extends State<_NumCell> {
  late final TextEditingController c =
      TextEditingController(text: widget.initial);
  String _prev = '';
  DateTime _burstStart = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastChange = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _settleT;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _prev = widget.initial;
  }

  @override
  void dispose() {
    _settleT?.cancel();
    c.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    if (_redirecting) return;
    final now = DateTime.now();
    if (text.length < _prev.length) {
      // حذف يدوي — بداية جديدة وليست مسحة.
      _prev = text;
      _burstStart = now;
      _lastChange = now;
      _settleT?.cancel();
      return;
    }
    if (now.difference(_lastChange).inMilliseconds > 120) {
      _burstStart = now;
    }
    _prev = text;
    _lastChange = now;
    _settleT?.cancel();
    if (widget.onScanRedirect == null || text.trim().length < 4) return;
    _settleT = Timer(const Duration(milliseconds: 250), _fireSettle);
  }

  /// هل النص الحالي دفعة ماسح (سريعة وطويلة) أم كتابة يدوية؟
  bool _isScanBurst(String text) {
    final t = text.trim();
    if (t.length < 4) return false;
    final ms = _lastChange.difference(_burstStart).inMilliseconds;
    return ms < t.length * 50;
  }

  Future<bool> _tryRedirect(String text) async {
    final h = widget.onScanRedirect;
    if (h == null || !_isScanBurst(text)) return false;
    _redirecting = true;
    bool consumed = false;
    try {
      consumed = await h(text);
    } catch (_) {
      consumed = false;
    }
    _redirecting = false;
    if (!mounted) return true;
    if (consumed) {
      c.text = widget.initial;
      _prev = widget.initial;
      final now = DateTime.now();
      _burstStart = now;
      _lastChange = now;
    }
    return consumed;
  }

  void _fireSettle() {
    _tryRedirect(c.text);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.editable) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(widget.initial,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: AppTextStyles.family,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: TextField(
        controller: c,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: const TextStyle(
            fontFamily: AppTextStyles.family,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
        ],
        onChanged: _onChanged,
        onSubmitted: (v) async {
          _settleT?.cancel();
          if (_redirecting) return;
          // wedge غالبًا يختم بـ Enter: لو النص دفعة ماسح أعد توجيهه أولًا.
          if (await _tryRedirect(v)) return;
          if (!mounted) return;
          final n = double.tryParse(v.trim()) ?? -1;
          if (n < 0) {
            c.text = widget.initial;
            return;
          }
          widget.onSubmit(n);
        },
      ),
    );
  }
}

/// تجميع سطور مسح خام (كل مسحة عنصر) إلى صف واحد لكل صنف.
/// يُستخدم في شاشات الإنشاء قبل الحفظ (العناصر [DocLine] حية وقابلة للتعديل).
class MergedDocLine {
  final String code;
  String name;
  double qty = 0;
  double weight = 0;
  double price = 0;
  final List<DocLine> scans = [];
  MergedDocLine({required this.code, required this.name});
}

/// تجميع قائمة [DocLine] خام (كل مسحة عنصر مستقل) إلى صف واحد لكل صنف:
/// كمية = المجموع، وزن = المجموع، سعر = الأحدث.
List<MergedDocLine> mergeDocLines(List<DocLine> lines) {
  final map = <String, MergedDocLine>{};
  final order = <String>[];
  for (final l in lines) {
    var g = map[l.productCode];
    if (g == null) {
      g = MergedDocLine(code: l.productCode, name: l.productName);
      map[l.productCode] = g;
      order.add(l.productCode);
    }
    g.qty += l.quantity;
    g.weight += l.weight;
    g.price = l.price;
    if (l.productName.isNotEmpty) g.name = l.productName;
    g.scans.add(l);
  }
  return [for (final c in order) map[c]!];
}

/// حوار تفصيلة مسحات صنف (قبل الحفظ): كل مسحة في صف مستقل بوزنها
/// (للأوزان المتغيرة كل كرتونة في صف) مع تعديل الوزن/السعر وحذف أي مسحة.
/// يعمل على نفس كائنات [DocLine] الحية — أي تعديل ينعكس على قائمة الأب
/// عبر [onChanged]، والحذف عبر [onDelete].
class ScansBreakdownDialog extends StatefulWidget {
  final String productName;
  final String productCode;
  final List<DocLine> scans;
  final VoidCallback onChanged;
  final void Function(DocLine scan) onDelete;
  const ScansBreakdownDialog({
    super.key,
    required this.productName,
    required this.productCode,
    required this.scans,
    required this.onChanged,
    required this.onDelete,
  });
  @override
  State<ScansBreakdownDialog> createState() => _ScansBreakdownDialogState();
}

class _ScansBreakdownDialogState extends State<ScansBreakdownDialog> {
  late List<DocLine> scans = [...widget.scans];
  final priceAllC = TextEditingController();

  @override
  void dispose() {
    priceAllC.dispose();
    super.dispose();
  }

  String _f(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  String _f2(double v) => v.toStringAsFixed(2);

  void _onDeleteScan(DocLine s) {
    widget.onDelete(s); // الأب يحذف من قائمته
    setState(() => scans.remove(s));
    widget.onChanged(); // الأب يعيد البناء
  }

  void _onScanChanged() {
    setState(() {}); // إعادة حساب الإجماليات
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final totalQty = scans.fold(0.0, (a, b) => a + b.quantity);
    final totalWeight = scans.fold(0.0, (a, b) => a + b.weight);
    return AlertDialog(
      title: Text('${widget.productName} (${scans.length} مسحات)',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: AppTextStyles.family,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        child: scans.isEmpty
            ? const Text('لا توجد مسحات — احذف الصنف من الجدول',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppTextStyles.family, fontSize: 14))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        'الإجمالي: كمية ${_f(totalQty)} — وزن ${_f2(totalWeight)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: AppTextStyles.family,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: priceAllC,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                              labelText: 'سعر موحد للكل', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                          onPressed: () {
                            final np =
                                AppUtils.parseNum(priceAllC.text);
                            if (np <= 0) return;
                            for (final s in scans) {
                              s.price = np;
                            }
                            priceAllC.clear();
                            _onScanChanged();
                          },
                          child: const Text('توحيد')),
                    ]),
                    const SizedBox(height: 8),
                    ...scans.asMap().entries.map((e) {
                      final i = e.key;
                      final s = e.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? const Color(0xFFF6F8F6)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFD9E2E3)),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('مسحة #${i + 1}',
                                    style: const TextStyle(
                                        fontFamily:
                                            AppTextStyles.family,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800)),
                                Text(
                                    'كمية ${_f(s.quantity)} | سعر ${_f(s.price)}',
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                        fontFamily:
                                            AppTextStyles.family,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 84,
                            child: TextFormField(
                              key: ValueKey(
                                  'w-${widget.productCode}-$i-${s.weight}'),
                              initialValue: _f2(s.weight),
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                  fontFamily: AppTextStyles.family,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800),
                              decoration: const InputDecoration(
                                  labelText: 'الوزن',
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 8)),
                              onFieldSubmitted: (v) {
                                final n =
                                    AppUtils.parseNum(v);
                                if (n < 0) return;
                                s.weight = n;
                                _onScanChanged();
                              },
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.danger,
                                    size: 20),
                                onPressed: () =>
                                    _onDeleteScan(s)),
                          ),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم')),
      ],
    );
  }
}
