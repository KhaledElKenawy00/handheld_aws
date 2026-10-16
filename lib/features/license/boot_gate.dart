import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/license_service.dart';
import '../auth/login_screen.dart';
import 'license_screen.dart';
import 'lock_screen.dart';

/// بوابة الإقلاع: تفعيل → قفل → دخول، حسب حالة الترخيص.
class BootGate extends ConsumerStatefulWidget {
  const BootGate({super.key});
  @override
  ConsumerState<BootGate> createState() => _BootGateState();
}

class _BootGateState extends ConsumerState<BootGate> {
  late final Future<LicenseState> _check =
      ref.read(licenseServiceProvider).evaluate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LicenseState>(
      future: _check,
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        switch (snap.data!) {
          case LicenseState.noLicense:
            return const LicenseScreen();
          case LicenseState.expired:
          case LicenseState.disabled:
            return LockScreen(reason: snap.data!);
          case LicenseState.ok:
            return const LoginScreen();
        }
      },
    );
  }
}
