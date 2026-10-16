import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import '../../shared/widgets/common.dart';
import '../auth/login_screen.dart';
import 'license_admin.dart';

/// شاشة التفعيل — أول ما يفتح التطبيق: إدخال كود الليسنس.
/// التفعيل أول مرة يحتاج نت، وبعده يعمل أوفلاين.
/// 5 ضغطات على اللوجو تفتح دخول الإدارة (سري).
class LicenseScreen extends ConsumerStatefulWidget {
  const LicenseScreen({super.key});
  @override
  ConsumerState<LicenseScreen> createState() => _LicenseState();
}

class _LicenseState extends ConsumerState<LicenseScreen> {
  final codeC = TextEditingController();
  bool busy = false;
  int _taps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    codeC.dispose();
    super.dispose();
  }

  void _logoTap() {
    final now = DateTime.now();
    if (now.difference(_lastTap).inSeconds > 2) _taps = 0;
    _lastTap = now;
    _taps++;
    if (_taps >= 5) {
      _taps = 0;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
    }
  }

  Future<void> _activate() async {
    setState(() => busy = true);
    try {
      await ref.read(licenseServiceProvider).activate(codeC.text);
      if (!mounted) return;
      toast(context, 'تم التفعيل بنجاح');
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'تفعيل النظام',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          InkWell(
            onTap: _logoTap,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: RefColors.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.verified_user_rounded,
                  size: 46, color: RefColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          const Text('ادخل كود التفعيل',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: RefColors.navy)),
          const SizedBox(height: 4),
          const Text('التفعيل أول مرة يحتاج إنترنت — بعده يعمل بدون نت',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: RefColors.hintGrey)),
          const SizedBox(height: 18),
          RefField(
            controller: codeC,
            label: 'كود الليسنس',
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _activate(),
          ),
          const SizedBox(height: 24),
          busy
              ? const Center(child: CircularProgressIndicator())
              : RefButton(label: 'تفعيل', onPressed: _activate),
        ],
      ),
    );
  }
}
