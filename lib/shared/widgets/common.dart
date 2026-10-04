import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';

/// عناصر مشتركة: بحث + بطاقات + حوارات + عدّاد كمية + شريط مسح
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
          fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: .14),
                foregroundColor: color,
                child: Icon(icon, size: 22)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.inkSoft)),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink)),
                ])),
          ]),
        ),
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.qtyBg(isReceipt),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppTheme.qtyFg(isReceipt).withValues(alpha: .4),
            width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(AppUtils.fmtQty(qty),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.qtyFg(isReceipt),
                height: 1.1)),
        Text('كمية',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.qtyFg(isReceipt))),
      ]),
    );
  }
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
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isReceipt
                      ? AppTheme.successBg
                      : AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReceipt
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 22,
                  color: isReceipt
                      ? AppTheme.success
                      : AppTheme.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // عنوان الكارد: اسم المورد / العميل
                    Text(partnerName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                            height: 1.3)),
                    const SizedBox(height: 3),
                    Text('$voucherId  •  $date',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.inkSoft)),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('الأصناف: $totalItems',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              QtyBadge(qty: totalQty, isReceipt: isReceipt),
            ],
          ),
        ),
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink)),
                  Text('كود: $productCode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.inkSoft)),
                  if (stepper != null) ...[
                    const SizedBox(height: 4),
                    stepper!,
                  ],
                ]),
          ),
          const SizedBox(width: 6),
          QtyBadge(qty: quantity, isReceipt: isReceipt),
          if (onDelete != null)
            IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.danger, size: 22),
                onPressed: onDelete),
        ]),
      ),
    );
  }
}

/// لوحة مسح بدون حقل إدخال: رسالة + زر مسح فقط.
/// المسح يصل تلقائيًا عبر scanStream — المستخدم يضغط زر المسح
/// في الجهاز أو زر "ابدأ المسح" ثم يمسح فيسمع مباشرة.
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
    return Card(
      color: AppTheme.navy,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.document_scanner_rounded,
              color: Colors.white, size: 32),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.5)),
          const SizedBox(height: 3),
          Text('امسح بالزر الفيزيائي أو زر البدء — يسمع تلقائيًا بدون كتابة',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .85))),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.navy,
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onTriggerScan,
              icon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 22),
              label: Text(
                  scannedCount > 0
                      ? 'مسح صنف آخر ($scannedCount ممسوح)'
                      : 'ابدأ المسح الآن',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkSoft,
                  height: 1.6)),
        ]),
      ),
    );
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
      IconButton(
          icon: const Icon(Icons.remove_circle_outline,
              size: 22, color: AppTheme.navy),
          onPressed: () => onChanged((value - 1).clamp(0, 9999999).toDouble())),
      SizedBox(
        width: 64,
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          ],
          onSubmitted: (v) =>
              onChanged(double.tryParse(v) ?? value),
        ),
      ),
      IconButton(
          icon: const Icon(Icons.add_circle_outline,
              size: 22, color: AppTheme.success),
          onPressed: () => onChanged(value + 1)),
    ]);
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}

/// شريط المسح الموحد: زر مسح + حقل يدوي (keyboard-wedge يدخل هنا تلقائيًا)
/// ملاحظة: شاشات الأذون الجديدة تستخدم ScanPanel (بدون حقل) —
/// هذا الشريط باقٍ للجرد والبحث فقط.
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: false,
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink),
              decoration: InputDecoration(
                  hintText: hint, prefixIcon: const Icon(Icons.qr_code, size: 20)),
              onSubmitted: onSubmit,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onTriggerScan,
            icon: const Icon(Icons.document_scanner_outlined, size: 20),
            label: const Text('مسح',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

Future<void> showError(BuildContext context, Object e) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('تنبيه',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      content: Text(e.toString().replaceAll('Exception: ', ''),
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, height: 1.6)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسنًا'))
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String msg) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('تأكيد',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      content: Text(msg,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, height: 1.6)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد')),
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
    builder: (_) => AlertDialog(
      title: const Text('الصنف غير موجود',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      content: Text('الباركود: $barcode\n\nهل تريد إضافة هذا الصنف؟',
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, height: 1.6)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إضافة صنف')),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))));
}
