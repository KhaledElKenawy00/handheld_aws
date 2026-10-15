import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import '../../shared/widgets/pc_send.dart';
import '../products/presentation/products_screen.dart';
import 'permissions_screen.dart';
import 'pc_export_screen.dart';
import 'users_screen.dart';

/// الاعدادات — 5 كروت مثل الصورة.
/// - تصدير قاعدة البيانات → دايلوج بـ 3 اختيارات: شامل PDF / شامل Excel /
///   نسخة كاملة (.sanad) للباك اب.
/// - استيراد قاعدة البيانات → مركز الاستيراد (أصناف/موردين/عملاء
///   من شيت Excel).
class RefSettingsScreen extends ConsumerStatefulWidget {
  const RefSettingsScreen({super.key});
  @override
  ConsumerState<RefSettingsScreen> createState() => _RefSettingsState();
}

class _RefSettingsState extends ConsumerState<RefSettingsScreen> {
  bool busy = false;
  String step = '';

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'الاعدادات',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          _card(context, 'ادارة المستخدمين', Icons.groups_rounded, const UsersScreen()),
          _card(context, 'تصريحات المستخدم', Icons.edit_document, const PermissionsScreen()),
          _card(context, 'الإرسال للكمبيوتر', Icons.lan_outlined, const PcExportScreen()),
          _card(context, 'تصدير قاعدة البيانات', Icons.save_alt_rounded, null,
              onTap: busy ? null : _exportChoice),
          _card(context, 'استيراد قاعدة البيانات', Icons.add_rounded, null,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ImportHubScreen()))),
          if (busy) ...[
            const SizedBox(height: 4),
            Row(children: [
              const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(step,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, IconData icon, Widget? page, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap ??
            (page == null
                ? null
                : () => Navigator.push(context, MaterialPageRoute(builder: (_) => page))),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 21, fontWeight: FontWeight.w800, color: RefColors.navy)),
              ),
              Icon(icon, size: 46, color: RefColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  /// دايلوج اختيارات التصدير الـ 3.
  Future<void> _exportChoice() async {
    final sel = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('اختر صيغة التصدير',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 19,
                fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'pdf'),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
              label: const Text('شامل PDF',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: RefColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'excel'),
              icon: const Icon(Icons.table_chart_outlined, size: 22),
              label: const Text('شامل Excel',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'sanad'),
              icon: const Icon(Icons.backup_outlined, size: 22),
              label: const Text('نسخة كاملة (.sanad) للباك اب',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
        ],
      ),
    );
    if (sel == 'pdf') {
      await _runExportPdf();
    } else if (sel == 'excel') {
      await _runExportExcel();
    } else if (sel == 'sanad') {
      await _runBackup();
    }
  }

  Future<void> _runExportPdf() async {
    if (await askPcOrDevice(context)) {
      if (!mounted) return;
      await generateAndSendToPc(
        context: context,
        ref: ref,
        generate: () =>
            ref.read(fullExportServiceProvider).exportAllPdf(),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      step = 'جارٍ تجهيز ملفات PDF...';
    });
    try {
      final path = await ref.read(fullExportServiceProvider).exportAllPdf(
          onStep: (s) {
            if (mounted) setState(() => step = s);
          });
      if (!mounted) return;
      setState(() {
        busy = false;
        step = '';
      });
      refToast(context, 'تم إنشاء الباكب الشامل PDF');
      await Share.shareXFiles([XFile(path)], text: 'الباكب الشامل SANAD - PDF');
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          step = '';
        });
        refError(context, e);
      }
    }
  }

  Future<void> _runExportExcel() async {
    if (await askPcOrDevice(context)) {
      if (!mounted) return;
      await generateAndSendToPc(
        context: context,
        ref: ref,
        generate: () =>
            ref.read(fullExportServiceProvider).exportAllExcel(),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      step = 'جارٍ تجهيز ملفات Excel...';
    });
    try {
      final path = await ref.read(fullExportServiceProvider).exportAllExcel(
          onStep: (s) {
            if (mounted) setState(() => step = s);
          });
      if (!mounted) return;
      setState(() {
        busy = false;
        step = '';
      });
      refToast(context, 'تم إنشاء الباكب الشامل Excel');
      await Share.shareXFiles([XFile(path)], text: 'الباكب الشامل SANAD - Excel');
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          step = '';
        });
        refError(context, e);
      }
    }
  }

  Future<void> _runBackup() async {
    if (await askPcOrDevice(context)) {
      if (!mounted) return;
      await generateAndSendToPc(
        context: context,
        ref: ref,
        generate: () =>
            ref.read(backupServiceProvider).createBackup(),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      step = 'جارٍ إنشاء نسخة النظام...';
    });
    try {
      final path = await ref.read(backupServiceProvider).createBackup();
      if (!mounted) return;
      setState(() {
        busy = false;
        step = '';
      });
      refToast(context, 'تم التصدير: $path');
      await Share.shareXFiles([XFile(path)], text: 'نسخة قاعدة البيانات');
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          step = '';
        });
        refError(context, e);
      }
    }
  }
}
