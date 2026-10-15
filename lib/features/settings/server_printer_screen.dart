import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';

/// إعداد الخادم والطابعة — حفظ محلي.
class ServerPrinterScreen extends ConsumerStatefulWidget {
  const ServerPrinterScreen({super.key});
  @override
  ConsumerState<ServerPrinterScreen> createState() => _SPState();
}

class _SPState extends ConsumerState<ServerPrinterScreen> {
  final serverC = TextEditingController();
  final ipC = TextEditingController();
  final portC = TextEditingController(text: '9100');
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = ref.read(settingsServiceProvider);
    final m = await s.all();
    serverC.text = m['server_url'] ?? '';
    ipC.text = m['printer_ip'] ?? '';
    portC.text = m['printer_port'] ?? '9100';
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    serverC.dispose();
    ipC.dispose();
    portC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(settingsServiceProvider);
    await s.set('server_url', serverC.text.trim());
    await s.set('printer_ip', ipC.text.trim());
    await s.set('printer_port', portC.text.trim());
    if (mounted) refToast(context, 'تم الحفظ');
  }

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'إعداد الخادم والطابعة',
      bottomButton: RefButton(label: 'حفظ', onPressed: loading ? null : _save),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                RefField(controller: serverC, label: 'عنوان الخادم', textDirection: TextDirection.ltr),
                const SizedBox(height: 12),
                RefField(controller: ipC, label: 'IP الطابعة', textDirection: TextDirection.ltr),
                const SizedBox(height: 12),
                RefField(
                    controller: portC,
                    label: 'المنفذ',
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr),
              ],
            ),
    );
  }
}
