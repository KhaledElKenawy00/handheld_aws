import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'common.dart';

/// صندوق إحصائية كبير واضح
class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const StatBox(
      {super.key,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: color.withValues(alpha: .35), width: 1.5),
      ),
      child: Column(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.inkSoft)),
        const SizedBox(height: 2),
        Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.2)),
      ]),
    );
  }
}

/// أزرار تصدير ملف المورد/العميل: كل الأذون بتفاصيلها.
/// المستخدم يختار PDF أو Excel.
class PartnerExportButtons extends ConsumerStatefulWidget {
  final String partnerCode;
  final String partnerName;
  final bool isSupplier;
  const PartnerExportButtons({
    super.key,
    required this.partnerCode,
    required this.partnerName,
    required this.isSupplier,
  });

  @override
  ConsumerState<PartnerExportButtons> createState() =>
      _PartnerExportButtonsState();
}

class _PartnerExportButtonsState
    extends ConsumerState<PartnerExportButtons> {
  bool busy = false;

  Future<void> _export(bool asPdf) async {
    setState(() => busy = true);
    try {
      final svc = ref.read(fullExportServiceProvider);
      final String path = widget.isSupplier
          ? (asPdf
              ? await svc.supplierDossierPdf(
                  widget.partnerCode, widget.partnerName)
              : await svc.supplierDossierExcel(
                  widget.partnerCode, widget.partnerName))
          : (asPdf
              ? await svc.customerDossierPdf(
                  widget.partnerCode, widget.partnerName)
              : await svc.customerDossierExcel(
                  widget.partnerCode, widget.partnerName));
      if (!mounted) return;
      toast(context, 'تم إنشاء الملف: $path');
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isSupplier ? 'ملف المورد الشامل' : 'ملف العميل الشامل';
    return Card(
      color: AppTheme.accentSoft,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              const Text('كل الأذون بتفاصيل الأصناف — اختر الصيغة',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: FilledButton.icon(
                        onPressed: busy ? null : () => _export(true),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(busy ? '...' : 'PDF'))),
                const SizedBox(width: 8),
                Expanded(
                    child: FilledButton.tonalIcon(
                        onPressed: busy ? null : () => _export(false),
                        icon: const Icon(Icons.table_chart),
                        label: Text(busy ? '...' : 'Excel'))),
              ]),
            ]),
      ),
    );
  }
}
