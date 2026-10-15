import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import '../ops/op_list_screen.dart';
import '../ops/op_kind.dart';
import '../settings/ref_settings_screen.dart';
import '../warehouse/warehouse_home_screen.dart';
import 'login_screen.dart';

/// الرئيسية — مطابقة للصورة: مرحبا + كارت المستخدم + 6 كروت + خروج.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: RefColors.bodyBg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration:
                const BoxDecoration(gradient: RefColors.headerGradient),
            child: const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(top: 22, bottom: 52),
                child: Text('مرحبا!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: RefColors.bodyBg,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4)),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  // كارت المستخدم
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: .08),
                            blurRadius: 10,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(user?.username ?? '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: RefColors.nameOrange)),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E8E8),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.person_rounded,
                              size: 34, color: Color(0xFF9A9A9A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.02,
                    children: [
                      _card(context, ref, 'استلامات',
                          Icons.move_to_inbox_rounded, RefColors.navy,
                          () => _openKind(context, ref, OpKind.receipt)),
                      _card(context, ref, 'تسليمات',
                          Icons.local_shipping_outlined, RefColors.primary,
                          () => _openKind(context, ref, OpKind.delivery)),
                      _card(context, ref, 'مرتجعات',
                          Icons.assignment_return_rounded, RefColors.navy,
                          () => _openSub(context, 'مرتجعات', const [
                                ('مرتجع عميل', Icons.person_rounded),
                                ('مرتجع مورد', Icons.local_shipping_rounded),
                              ])),
                      _card(context, ref, 'تحويلات',
                          Icons.swap_horiz_rounded, RefColors.primary,
                          () => _openSub(context, 'تحويلات', const [
                                ('تحويل داخلي', Icons.warehouse_rounded),
                                ('تحويل خارجي', Icons.local_shipping_rounded),
                              ])),
                      _card(context, ref, 'الاعدادات',
                          Icons.settings_rounded, RefColors.navy,
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const RefSettingsScreen()))),
                      _card(context, ref, 'إدارة المخزن',
                          Icons.warehouse_rounded, RefColors.primary,
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const WarehouseHomeScreen()))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: SizedBox(
                      width: 200,
                      child: _card(context, ref, 'تسجيل خروج',
                          Icons.logout_rounded, RefColors.navy, () {
                        ref
                            .read(currentUserProvider.notifier)
                            .state = null;
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const LoginScreen()));
                      }),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, String title,
      IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.chevron_left_rounded,
                  size: 30, color: Color(0xFF9A9A9A)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Icon(icon, size: 52, color: color),
            ),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Future<void> _openKind(BuildContext context, WidgetRef ref, OpKind kind) async {
    final user = ref.read(currentUserProvider);
    if (user != null && user.type != 'مدير') {
      final perms = await ref.read(usersRepoProvider).permissions(user.username);
      if ((perms[kind.job] ?? true) == false) {
        if (context.mounted) refError(context, 'غير مصرح لك: ${kind.job}');
        return;
      }
    }
    if (context.mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OpListScreen(kind: kind)));
    }
  }

  void _openSub(BuildContext context, String title,
      List<(String, IconData)> subs) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _SubChooser(title: title, subs: subs)));
  }
}

/// اختيار النوع الفرعي (مرتجع عميل/مورد — تحويل داخلي/خارجي).
class _SubChooser extends ConsumerWidget {
  final String title;
  final List<(String, IconData)> subs;
  const _SubChooser({required this.title, required this.subs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          for (final s in subs) ...[
            InkWell(
              onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          OpListScreen(kind: opKindFrom(s.$1)))),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFE3E3E3)),
                  boxShadow: [
                    BoxShadow(
                        color:
                            Colors.black.withValues(alpha: .06),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(s.$1,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: RefColors.navy)),
                    ),
                    Icon(s.$2,
                        size: 44, color: RefColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
