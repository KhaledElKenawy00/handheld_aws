import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'common.dart';

/// سؤال مكان التصدير: على الجهاز (التدفق المعتاد: حفظ + مشاركة)
/// ولا إرسال مباشر للكمبيوتر. يُرجع true لو اختار الكمبيوتر.
Future<bool> askPcOrDevice(BuildContext context) async {
  final sel = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('مكان التصدير',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'device'),
            icon: const Icon(Icons.smartphone_outlined),
            label: const Text('على الجهاز'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(ctx, 'pc'),
            icon: const Icon(Icons.lan_outlined),
            label: const Text('إرسال للكمبيوتر مباشرة'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء')),
      ],
    ),
  );
  return sel == 'pc';
}

/// توليد ملف ثم رفعه للكمبيوتر مع حوار تقدم — يُظهر النتيجة أو الخطأ بنفسه.
Future<void> generateAndSendToPc({
  required BuildContext context,
  required WidgetRef ref,
  required Future<String> Function() generate,
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 14),
        Expanded(child: Text('جارٍ التوليد والإرسال للكمبيوتر...')),
      ]),
    ),
  );
  try {
    final localPath = await generate();
    final remote = await ref
        .read(pcExportServiceProvider)
        .uploadFile(File(localPath));
    if (context.mounted) {
      Navigator.pop(context);
      toast(context, 'تم الإرسال للكمبيوتر: $remote');
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      showError(context, e);
    }
  }
}

/// حوار اختيار الصيغة (PDF / Excel) ثم توليد الملف ورفعه مباشرة
/// إلى فولدر الكمبيوتر عبر الشبكة المحلية (SMB) — أوفلاين تمامًا.
Future<void> askAndSendToPc({
  required BuildContext context,
  required WidgetRef ref,
  required Future<String> Function() makePdf,
  required Future<String> Function() makeExcel,
}) async {
  final sel = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('إرسال للكمبيوتر',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'pdf'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('إرسال PDF'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(ctx, 'excel'),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('إرسال Excel'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء')),
      ],
    ),
  );
  if (sel == null || !context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 14),
        Expanded(child: Text('جارٍ التوليد والإرسال للكمبيوتر...')),
      ]),
    ),
  );
  try {
    final localPath =
        sel == 'pdf' ? await makePdf() : await makeExcel();
    final remote = await ref
        .read(pcExportServiceProvider)
        .uploadFile(File(localPath));
    if (context.mounted) {
      Navigator.pop(context);
      toast(context, 'تم الإرسال للكمبيوتر: $remote');
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      showError(context, e);
    }
  }
}
