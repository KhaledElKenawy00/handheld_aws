import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import '../../../core/scanner/scanner_providers.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/pc_send.dart';
import '../pc_export_screen.dart';

/// الإعدادات: بيانات المنشأة + المخزون السالب + Scanner + نسخ احتياطي
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SS();
}

class _SS extends ConsumerState<SettingsScreen> {
  final storeC = TextEditingController();
  final companyC = TextEditingController();
  final addrC = TextEditingController();
  final phoneC = TextEditingController();
  bool allowNeg = false;
  bool beep = true;
  bool vibrate = true;
  int debounce = 400;
  bool loaded = false;
  bool busyBackup = false;
  bool busyPdf = false;
  bool busyExcel = false;
  String exportStep = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = ref.read(settingsServiceProvider);
    final m = await s.all();
    storeC.text = m[AppConstants.kStoreName] ?? '';
    companyC.text = m[AppConstants.kCompanyName] ?? '';
    addrC.text = m[AppConstants.kAddress] ?? '';
    phoneC.text = m[AppConstants.kPhone] ?? '';
    allowNeg = (m[AppConstants.kAllowNegativeStock] ?? '0') == '1';
    beep = (m[AppConstants.kScannerBeep] ?? '1') == '1';
    vibrate = (m[AppConstants.kScannerVibrate] ?? '1') == '1';
    debounce = int.tryParse(
            m[AppConstants.kScannerDebounce] ?? '400') ??
        400;
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _save() async {
    final s = ref.read(settingsServiceProvider);
    await s.set(AppConstants.kStoreName, storeC.text.trim());
    await s.set(AppConstants.kCompanyName, companyC.text.trim());
    await s.set(AppConstants.kAddress, addrC.text.trim());
    await s.set(AppConstants.kPhone, phoneC.text.trim());
    await s.set(
        AppConstants.kAllowNegativeStock, allowNeg ? '1' : '0');
    await s.set(AppConstants.kScannerBeep, beep ? '1' : '0');
    await s.set(AppConstants.kScannerVibrate, vibrate ? '1' : '0');
    await s.set(
        AppConstants.kScannerDebounce, debounce.toString());
    ref.invalidate(settingsMapProvider);
    if (mounted) toast(context, 'تم حفظ الإعدادات');
  }

  /// دايلوج اختيارات التصدير الـ 3: شامل PDF / شامل Excel / نسخة كاملة (.sanad)
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
            const SizedBox(height: 6),
            const Text(
              'النسخة الكاملة تُستخدم للباك اب والاستعادة على نفس الجهاز أو جهاز آخر.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.6),
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
      await _exportAllPdf();
    } else if (sel == 'excel') {
      await _exportAllExcel();
    } else if (sel == 'sanad') {
      await _backup();
    }
  }

  Future<void> _backup() async {
    if (await askPcOrDevice(context)) {
      if (!mounted) return;
      setState(() => busyBackup = true);
      try {
        await generateAndSendToPc(
          context: context,
          ref: ref,
          generate: () =>
              ref.read(backupServiceProvider).createBackup(),
        );
      } finally {
        if (mounted) setState(() => busyBackup = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => busyBackup = true);
    try {
      await Permission.storage.request();
      final path =
          await ref.read(backupServiceProvider).createBackup();
      if (!mounted) return;
      toast(context, 'تم إنشاء نسخة النظام: $path');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم إنشاء نسخة النظام (.sanad)',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          content: Text(
              '$path\n\nاحتفظ بهذا الملف — بعد تحديث التطبيق اعمل "استعادة" وارفع نفس الملف وسيعمل معك عادي.',
              style: const TextStyle(fontSize: 12, height: 1.6)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق')),
            FilledButton(
                onPressed: () {
                  Share.shareXFiles([XFile(path)],
                      text: 'نسخة SANAD الاحتياطية');
                },
                child: const Text('مشاركة / نقل لجهاز آخر')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busyBackup = false);
    }
  }

  Future<void> _exportAllPdf() async {
    if (await askPcOrDevice(context)) {
      if (!mounted) return;
      setState(() {
        busyPdf = true;
        exportStep = 'جارٍ الإرسال للكمبيوتر...';
      });
      try {
        await generateAndSendToPc(
          context: context,
          ref: ref,
          generate: () =>
              ref.read(fullExportServiceProvider).exportAllPdf(),
        );
      } finally {
        if (mounted) {
          setState(() {
            busyPdf = false;
            exportStep = '';
          });
        }
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      busyPdf = true;
      exportStep = 'جارٍ التجهيز...';
    });
    try {
      final path = await ref.read(fullExportServiceProvider).exportAllPdf(
          onStep: (s) {
            if (mounted) setState(() => exportStep = s);
          });
      if (!mounted) return;
      toast(context, 'تم إنشاء الباكب الشامل PDF: $path');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('الباكب الشامل PDF',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          content: Text(
              '$path\n\nيشمل: الأصناف + الموردين + العملاء + المخازن + الأذون (استلام/تسليم) + العمليات (مرتجعات/تحويلات) + ملف مستقل لكل مورد وعميل بكل أذونه.',
              style: const TextStyle(fontSize: 12, height: 1.6)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق')),
            FilledButton(
                onPressed: () {
                  Share.shareXFiles([XFile(path)],
                      text: 'الباكب الشامل SANAD - PDF');
                },
                child: const Text('مشاركة')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          busyPdf = false;
          exportStep = '';
        });
      }
    }
  }

  Future<void> _exportAllExcel() async {
    if (await askPcOrDevice(context)) {
      if (!mounted) return;
      setState(() {
        busyExcel = true;
        exportStep = 'جارٍ الإرسال للكمبيوتر...';
      });
      try {
        await generateAndSendToPc(
          context: context,
          ref: ref,
          generate: () =>
              ref.read(fullExportServiceProvider).exportAllExcel(),
        );
      } finally {
        if (mounted) {
          setState(() {
            busyExcel = false;
            exportStep = '';
          });
        }
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      busyExcel = true;
      exportStep = 'جارٍ التجهيز...';
    });
    try {
      final path = await ref.read(fullExportServiceProvider).exportAllExcel(
          onStep: (s) {
            if (mounted) setState(() => exportStep = s);
          });
      if (!mounted) return;
      toast(context, 'تم إنشاء الباكب الشامل Excel: $path');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('الباكب الشامل Excel',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          content: Text(
              '$path\n\nيشمل: الأصناف + الموردين + العملاء + المخازن + الأذون بتفاصيل الأصناف + العمليات (مرتجعات/تحويلات) + ملف مستقل لكل مورد وعميل.',
              style: const TextStyle(fontSize: 12, height: 1.6)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق')),
            FilledButton(
                onPressed: () {
                  Share.shareXFiles([XFile(path)],
                      text: 'الباكب الشامل SANAD - Excel');
                },
                child: const Text('مشاركة')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          busyExcel = false;
          exportStep = '';
        });
      }
    }
  }

  Future<void> _restore() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['sanad', 'zip']);
    if (r == null || r.files.single.path == null) return;
    if (!await confirm(
        context, 'استعادة النسخة ستحل محل البيانات الحالية. متابعة؟')) {
      return;
    }
    try {
      await ref
          .read(backupServiceProvider)
          .restoreBackup(File(r.files.single.path!));
      ref.invalidate(dashboardProvider);
      if (mounted) toast(context, 'تمت الاستعادة بنجاح — أعد تشغيل التطبيق');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        const AppHero(
          title: 'الإعدادات',
          subtitle: 'بيانات المنشأة والماسح والنسخ الاحتياطي',
        ),
        const SizedBox(height: 12),
        const AppSectionTitle(title: 'بيانات المنشأة'),
        const SizedBox(height: 8),
        TextField(
            controller: storeC,
            decoration:
                const InputDecoration(labelText: 'اسم المخزن')),
        const SizedBox(height: 8),
        TextField(
            controller: companyC,
            decoration:
                const InputDecoration(labelText: 'اسم الشركة')),
        const SizedBox(height: 8),
        TextField(
            controller: addrC,
            decoration: const InputDecoration(labelText: 'العنوان')),
        const SizedBox(height: 8),
        TextField(
            controller: phoneC,
            decoration:
                const InputDecoration(labelText: 'رقم الهاتف')),
        const SizedBox(height: 12),
        SwitchListTile(
            title: const Text('السماح بالمخزون السالب'),
            subtitle: const Text('مغلق افتراضيًا — يمنع التسليم الزائد'),
            value: allowNeg,
            onChanged: (v) => setState(() => allowNeg = v)),
        const Divider(),
        const AppSectionTitle(title: 'إعدادات الماسح (SUNMI L2s Pro)'),
        SwitchListTile(
            title: const Text('صوت تنبيه عند المسح (Beep)'),
            value: beep,
            onChanged: (v) => setState(() => beep = v)),
        SwitchListTile(
            title: const Text('اهتزاز عند المسح (Vibrate)'),
            value: vibrate,
            onChanged: (v) => setState(() => vibrate = v)),
        ListTile(
          title: const Text('منع التكرار (Debounce)'),
          subtitle: Text('$debounce ms — نفس الباركود خلالها يُتجاهل'),
          trailing: SizedBox(
            width: 120,
            child: DropdownButtonFormField<int>(
              initialValue: [300, 400, 500, 800].contains(debounce)
                  ? debounce
                  : 400,
              items: const [300, 400, 500, 800]
                  .map((e) => DropdownMenuItem(
                      value: e, child: Text('$e ms')))
                  .toList(),
              onChanged: (v) =>
                  setState(() => debounce = v ?? 400),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.document_scanner),
          title: const Text('اختبار الماسح'),
          subtitle: const Text(
              'اضغط زر المسح الفيزيائي — يجب أن يظهر الكود هنا'),
          trailing: FilledButton(
              child: const Text('مسح'),
              onPressed: () async {
                try {
                  final svc =
                      ref.read(scannerServiceProvider);
                  await svc.triggerScan();
                  if (context.mounted) {
                    toast(context, 'تم إرسال أمر المسح للجهاز');
                  }
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              }),
        ),
        const Divider(),
        const AppSectionTitle(title: 'الإرسال للكمبيوتر (شبكة محلية)'),
        ListTile(
          leading: const Icon(Icons.lan_outlined),
          title: const Text('إعدادات الكمبيوتر (SMB)'),
          subtitle: const Text(
              'IP + مشاركة ويندوز أو Samba لينكس — ثم زرار الإرسال في التفاصيل'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PcExportScreen())),
        ),
        const Divider(),
        FilledButton(
            onPressed: _save, child: const Text('حفظ الإعدادات')),
        const SizedBox(height: 12),
        const AppSectionTitle(title: 'النسخ الاحتياطي (Offline) — تصدير واستعادة'),
        const SizedBox(height: 8),
        // زر تصدير واحد يفتح الـ 3 اختيارات: PDF / Excel / نسخة كاملة (.sanad)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تصدير البيانات',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text(
                      'يصدر كل حاجة: أصناف + موردين + عملاء + مخازن + أذون (استلام/تسليم) + عمليات (مرتجعات/تحويلات)، وملف مستقل لكل مورد بكل أذونه ولكل عميل بكل أذونه.',
                      style: TextStyle(fontSize: 12, height: 1.6)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        icon: const Icon(Icons.file_download_outlined,
                            size: 20),
                        label: Text(
                            (busyPdf || busyExcel || busyBackup)
                                ? 'جارٍ التصدير...'
                                : 'تصدير',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                        onPressed: (busyPdf || busyExcel || busyBackup)
                            ? null
                            : _exportChoice),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                        icon: const Icon(Icons.restore, size: 20),
                        label: const Text('استعادة نسخة',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                        onPressed: (busyPdf || busyExcel || busyBackup)
                            ? null
                            : _restore),
                  ),
                  if (busyPdf || busyExcel || busyBackup) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 3)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              busyBackup ? 'جارٍ إنشاء نسخة النظام...' : exportStep,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))),
                    ]),
                  ],
                ]),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
            child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'SANAD v1.0.0 — سند\nيعمل Offline بالكامل بدون إنترنت.\nالماسح: SUNMI L2s Pro (SDK + Broadcast + زر فيزيائي).',
                    style: TextStyle(fontSize: 11, height: 1.6)))),
      ]),
    );
  }
}
