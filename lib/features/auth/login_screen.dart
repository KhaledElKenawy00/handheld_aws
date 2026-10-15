import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import 'home_screen.dart';

/// تسجيل الدخول — بنفس روح التصميم المرجعي.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final userC = TextEditingController();
  final passC = TextEditingController();
  bool obscure = true;
  bool busy = false;

  @override
  void dispose() {
    userC.dispose();
    passC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (userC.text.trim().isEmpty || passC.text.isEmpty) {
      refError(context, 'ادخل اسم المستخدم وكلمة المرور');
      return;
    }
    setState(() => busy = true);
    try {
      final u = await ref
          .read(usersRepoProvider)
          .login(userC.text.trim(), passC.text);
      if (u == null) {
        if (mounted) refError(context, 'بيانات الدخول غير صحيحة');
        return;
      }
      ref.read(currentUserProvider.notifier).state = u;
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (mounted) refError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'تسجيل الدخول',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: RefColors.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(Icons.warehouse_rounded,
                size: 46, color: RefColors.primary),
          ),
          const SizedBox(height: 18),
          RefField(controller: userC, label: 'اسم المستخدم'),
          const SizedBox(height: 12),
          TextField(
            controller: passC,
            obscureText: obscure,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 21,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              suffixIcon: IconButton(
                icon: Icon(
                    obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: Colors.black54),
                onPressed: () =>
                    setState(() => obscure = !obscure),
              ),
            ),
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 24),
          busy
              ? const Center(child: CircularProgressIndicator())
              : RefButton(label: 'دخول', onPressed: _login),
        ],
      ),
    );
  }
}
