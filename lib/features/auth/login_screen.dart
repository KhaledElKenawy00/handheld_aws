import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import '../license/license_screen.dart';
import 'home_screen.dart';

/// تسجيل الدخول — بنفس روح التصميم المرجعي.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final userC = TextEditingController(text: 'admin');
  final passC = TextEditingController();
  bool obscure = true;
  bool busy = false;
  int _logoTaps = 0;
  DateTime _logoLastTap = DateTime.fromMillisecondsSinceEpoch(0);

  /// 5 ضغطات على اللوجو تفتح صفحة إدخال كود التفعيل
  /// (لتغيير الكود من الدخول المحلي بدون مسح التطبيق).
  void _logoTap() {
    final now = DateTime.now();
    if (now.difference(_logoLastTap).inSeconds > 2) _logoTaps = 0;
    _logoLastTap = now;
    _logoTaps++;
    if (_logoTaps >= 5) {
      _logoTaps = 0;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LicenseScreen()));
    }
  }

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
    return Scaffold(
      backgroundColor: RefColors.headerFrom,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: RefColors.headerGradient),
        child: Stack(
          children: [
            const PositionedDirectional(
                top: -60, start: -50, child: RefDecoCircle(size: 220, alpha: .07)),
            const PositionedDirectional(
                bottom: -80, end: -40, child: RefDecoCircle(size: 260, alpha: .06)),
            const PositionedDirectional(
                top: 140, end: -30, child: RefDecoCircle(size: 90, alpha: .06)),
            SafeArea(
              // بيسكرول فقط لو الكيبورد ظهر وضيّق المساحة.
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _logoTap,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: .20),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8)),
                              ],
                            ),
                            child: const Icon(Icons.warehouse_rounded,
                                size: 52, color: RefColors.primary),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text('SANAD',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 5,
                                color: Colors.white,
                                height: 1.1)),
                        const SizedBox(height: 4),
                        Text('سند — نظام إدارة المخازن',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: .85))),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: .18),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('تسجيل الدخول',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: RefColors.navy)),
                              const SizedBox(height: 18),
                              RefField(
                                  controller: userC, label: 'اسم المستخدم'),
                              const SizedBox(height: 14),
                              TextField(
                                controller: passC,
                                obscureText: obscure,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: RefColors.navy),
                                decoration: InputDecoration(
                                  labelText: 'كلمة المرور',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        obscure
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: RefColors.hintGrey),
                                    onPressed: () =>
                                        setState(() => obscure = !obscure),
                                  ),
                                ),
                                onSubmitted: (_) => _login(),
                              ),
                              const SizedBox(height: 22),
                              busy
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : RefButton(label: 'دخول', onPressed: _login),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
