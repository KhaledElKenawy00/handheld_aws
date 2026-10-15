import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/pc_export_service.dart';
import '../../shared/widgets/common.dart';

/// إعدادات الإرسال للكمبيوتر عبر الشبكة المحلية (SMB).
/// يعمل مع ويندوز (مشاركة ملفات) ولينكس (Samba) بنفس الإعدادات —
/// المهم أن الهاند هيلد والكمبيوتر على نفس الشبكة.
class PcExportScreen extends ConsumerStatefulWidget {
  const PcExportScreen({super.key});
  @override
  ConsumerState<PcExportScreen> createState() => _PcExportState();
}

class _PcExportState extends ConsumerState<PcExportScreen> {
  final hostC = TextEditingController();
  final shareC = TextEditingController();
  final userC = TextEditingController();
  final passC = TextEditingController();
  final folderC = TextEditingController();
  bool loaded = false;
  bool saving = false;
  bool testing = false;
  bool archiving = false;
  String archiveStep = '';
  bool showPass = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    hostC.dispose();
    shareC.dispose();
    userC.dispose();
    passC.dispose();
    folderC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await ref.read(pcExportServiceProvider).load();
    if (!mounted) return;
    setState(() {
      hostC.text = c.host;
      shareC.text = c.share;
      userC.text = c.user;
      passC.text = c.password;
      folderC.text = c.folder;
      loaded = true;
    });
  }

  PcSettings _current() => PcSettings(
        host: hostC.text,
        share: shareC.text,
        user: userC.text,
        password: passC.text,
        folder: folderC.text,
      );

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await ref.read(pcExportServiceProvider).save(_current());
      if (mounted) toast(context, 'تم حفظ إعدادات الكمبيوتر');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => testing = true);
    try {
      await ref
          .read(pcExportServiceProvider)
          .testConnection(_current());
      if (mounted) {
        toast(context, 'الاتصال ناجح — المشاركة متاحة للكتابة');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الإرسال للكمبيوتر')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        const Card(
            child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الإرسال عبر الشبكة المحلية (SMB)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                          'الهاند هيلد والكمبيوتر لازم يكونوا على نفس الشبكة (نفس الواي فاي). الملف بيترمي مباشرة في فولدر الكمبيوتر بدون برامج — أوفلاين تمامًا.',
                          style: TextStyle(fontSize: 12, height: 1.6)),
                      SizedBox(height: 4),
                      Text('ويندوز: كليك يمين على الفولدر ← مشاركة (Share) ليوزر بباسورد.',
                          style: TextStyle(fontSize: 12, height: 1.6)),
                      Text('لينكس: ثبّت Samba وشارك الفولدر (sudo apt install samba) بنفس اليوزر والباسورد.',
                          style: TextStyle(fontSize: 12, height: 1.6)),
                    ]))),
        const SizedBox(height: 8),
        TextField(
            controller: hostC,
            textDirection: TextDirection.ltr,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'IP الكمبيوتر (مثال: 192.168.1.50)',
                prefixIcon: Icon(Icons.computer_outlined))),
        const SizedBox(height: 8),
        TextField(
            controller: shareC,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'اسم المشاركة (مثال: sanad)',
                prefixIcon: Icon(Icons.folder_shared_outlined))),
        const SizedBox(height: 8),
        TextField(
            controller: userC,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'اليوزر',
                prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 8),
        TextField(
            controller: passC,
            textDirection: TextDirection.ltr,
            obscureText: !showPass,
            decoration: InputDecoration(
                labelText: 'الباسورد',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                    icon: Icon(showPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => showPass = !showPass)))),
        const SizedBox(height: 8),
        TextField(
            controller: folderC,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'مجلد فرعي داخل المشاركة (اختياري: invoices)',
                prefixIcon:
                    Icon(Icons.create_new_folder_outlined))),
        const SizedBox(height: 12),
        FilledButton.icon(
            icon: testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.wifi_tethering_outlined),
            label: const Text('اختبار الاتصال'),
            onPressed: testing ? null : _test),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ الإعدادات'),
            onPressed: saving ? null : _save),
        const SizedBox(height: 12),
        const Card(
            child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الأرشفة الأسبوعية التلقائية',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                          'كل 7 أيام: تُرفع دوسيهات العملاء والموردين (PDF + Excel) فوق فولدراتهم على الكمبيوتر (بدون ZIP)، ثم تُمسح أذون التسليم والاستلام والمرتجعات فقط — الأصناف والعملاء والمخزون لا يُمسون.',
                          style: TextStyle(fontSize: 12, height: 1.6)),
                    ]))),
        const SizedBox(height: 8),
        FilledButton.icon(
            icon: archiving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(archiving && archiveStep.isNotEmpty
                ? archiveStep
                : 'أرشفة الآن'),
            onPressed: archiving ? null : _archiveNow),
      ]),
    );
  }

  Future<void> _archiveNow() async {
    final ok = await confirm(
        context,
        'سيتم رفع الدوسيهات للكمبيوتر فوق الفولدرات الحالية ثم مسح كل أذون التسليم والاستلام والمرتجعات نهائيًا. متابعة؟');
    if (!ok) return;
    setState(() {
      archiving = true;
      archiveStep = 'بدء الأرشفة...';
    });
    try {
      final sum = await ref.read(archiveServiceProvider).runNow(
          onStep: (s) {
            if (mounted) setState(() => archiveStep = s);
          });
      ref.invalidate(deliveryListProvider);
      ref.invalidate(receiptListProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        toast(context,
            'تمت الأرشفة: ${sum.files} ملف — اتمسح ${sum.deliveries + sum.receipts + sum.returns} إذن');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          archiving = false;
          archiveStep = '';
        });
      }
    }
  }
}
