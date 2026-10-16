import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/license_service.dart';
import '../../core/theme/ref_style.dart';
import '../../shared/widgets/common.dart';
import '../auth/login_screen.dart';
import 'license_screen.dart';

/// شاشة القفل: انتهت المدة أو إيقاف من الإدارة.
/// يعرض رقم التجديد ويعيد الفحص بزرار (ينفع أونلاين).
class LockScreen extends ConsumerStatefulWidget {
  final LicenseState reason;
  const LockScreen({super.key, required this.reason});
  @override
  ConsumerState<LockScreen> createState() => _LockState();
}

class _LockState extends ConsumerState<LockScreen> {
  bool busy = false;

  Future<void> _retry() async {
    setState(() => busy = true);
    try {
      final st =
          await ref.read(licenseServiceProvider).evaluate();
      if (!mounted) return;
      if (st == LicenseState.ok) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      } else if (st == LicenseState.noLicense) {
        toast(context, 'لا يوجد ترخيص — تواصل مع الإدارة');
      } else {
        toast(context, 'ما زال النظام مغلقًا');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'النظام مغلق',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: RefColors.red.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(Icons.lock_rounded,
                size: 46, color: RefColors.red),
          ),
          const SizedBox(height: 16),
          Text(
              widget.reason == LicenseState.disabled
                  ? 'تم إيقاف الترخيص من الإدارة'
                  : 'تم اغلاق النظام للتجديد اتصل ب 01018774748',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: RefColors.navy,
                  height: 1.6)),
          const SizedBox(height: 8),
          const Text('لو جددت اشتراكك دوس إعادة المحاولة (تحتاج نت)',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: RefColors.hintGrey)),
          const SizedBox(height: 24),
          busy
              ? const Center(child: CircularProgressIndicator())
              : RefButton(
                  label: 'إعادة المحاولة', onPressed: _retry),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LicenseScreen())),
            child: const Text('عندي كود تفعيل جديد',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
