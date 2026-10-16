import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/license_service.dart';
import '../../core/theme/ref_style.dart';
import '../../shared/widgets/common.dart';
import '../license/license_screen.dart';
import '../license/lock_screen.dart';
import '../ops/op_list_screen.dart';
import '../ops/op_kind.dart';
import '../settings/ref_settings_screen.dart';
import '../warehouse/warehouse_home_screen.dart';
import 'login_screen.dart';

// ألوان البلاطات — لكل قسم هوية لونية خاصة.
const List<Color> _kReceipt = [Color(0xFF0FA968), Color(0xFF45D69B)];
const List<Color> _kDelivery = [Color(0xFFF76B1C), Color(0xFFFFA94D)];
const List<Color> _kReturn = [Color(0xFF7C3AED), Color(0xFFB794F6)];
const List<Color> _kTransfer = [Color(0xFF1D6FE0), Color(0xFF5DB0FF)];
const List<Color> _kSettings = [Color(0xFF475569), Color(0xFF8196AB)];
const List<Color> _kWarehouse = [Color(0xFF0E8C97), Color(0xFF38D1C4)];

/// الرئيسية — هيدر ترحيبي + شبكة 2×3 بتتمدد على الشاشة كلها (بدون سكرول) + خروج.
/// + فحص الترخيص الدوري والأرشفة الأسبوعية في الخلفية.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  StreamSubscription? _connSub;
  Timer? _licenseTimer;
  bool _lockPushed = false;

  @override
  void initState() {
    super.initState();
    // الأرشفة الأسبوعية التلقائية (عند الاستحقاق، في الخلفية).
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoArchive());
    // مع أول اتصال بالنت: فحص الترخيص من السيرفر (الإيقاف يفصل فورًا).
    try {
      _connSub =
          Connectivity().onConnectivityChanged.listen((c) {
        if (!c.contains(ConnectivityResult.none)) {
          _recheckLicense();
        }
      });
    } catch (_) {}
    // تايمر محلي كل دقيقة: يلقط انتهاء المدة أثناء التشغيل
    // (أونلاين أو أوفلاين) بدون انتظار إعادة الفتح.
    _licenseTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _licenseTick());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _licenseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheckLicense();
  }

  Future<void> _autoArchive() async {
    try {
      final sum =
          await ref.read(archiveServiceProvider).runIfDue();
      if (sum == null || !mounted) return;
      ref.invalidate(deliveryListProvider);
      ref.invalidate(receiptListProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        toast(context,
            'تمت الأرشفة الأسبوعية: ${sum.files} ملف على الكمبيوتر — اتمسح ${sum.deliveries + sum.receipts + sum.returns} إذن');
      }
    } catch (e) {
      if (mounted) showError(context, 'تعذرت الأرشفة الأسبوعية: $e');
    }
  }

  /// فحص محلي سريع دوري (بدون نت).
  Future<void> _licenseTick() async {
    if (_lockPushed || !mounted) return;
    try {
      final st =
          await ref.read(licenseServiceProvider).checkLocal();
      if (!mounted || _lockPushed) return;
      if (st == LicenseState.expired ||
          st == LicenseState.disabled) {
        _pushLock(st);
      }
    } catch (_) {}
  }

  /// فحص كامل من السيرفر (لو متصل).
  /// منتهي/موقوف → قفل، ممسوح من السيرفر → صفحة التفعيل.
  Future<void> _recheckLicense() async {
    if (_lockPushed || !mounted) return;
    try {
      final st =
          await ref.read(licenseServiceProvider).evaluate();
      if (!mounted || _lockPushed) return;
      if (st == LicenseState.expired ||
          st == LicenseState.disabled) {
        _pushLock(st);
      } else if (st == LicenseState.noLicense) {
        _lockPushed = true;
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const LicenseScreen()));
      }
    } catch (_) {}
  }

  void _pushLock(LicenseState st) {
    if (_lockPushed || !mounted) return;
    _lockPushed = true;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => LockScreen(reason: st)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: RefColors.bodyBg,
      body: Column(
        children: [
          _header(user?.username ?? '', user?.type),
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _row(
                            RefTile(
                                title: 'استلامات',
                                icon: Icons.move_to_inbox_rounded,
                                colors: _kReceipt,
                                onTap: () =>
                                    _openKind(context, ref, OpKind.receipt)),
                            RefTile(
                                title: 'تسليمات',
                                icon: Icons.local_shipping_outlined,
                                colors: _kDelivery,
                                onTap: () =>
                                    _openKind(context, ref, OpKind.delivery)),
                          ),
                          const SizedBox(height: 14),
                          _row(
                            RefTile(
                                title: 'مرتجعات',
                                icon: Icons.assignment_return_rounded,
                                colors: _kReturn,
                                onTap: () => _openSub(context, 'مرتجعات', const [
                                      ('مرتجع عميل', Icons.person_rounded),
                                      ('مرتجع مورد',
                                          Icons.local_shipping_rounded),
                                    ])),
                            RefTile(
                                title: 'تحويلات',
                                icon: Icons.swap_horiz_rounded,
                                colors: _kTransfer,
                                onTap: () => _openSub(context, 'تحويلات', const [
                                      ('تحويل داخلي', Icons.warehouse_rounded),
                                      ('تحويل خارجي',
                                          Icons.local_shipping_rounded),
                                    ])),
                          ),
                          const SizedBox(height: 14),
                          _row(
                            RefTile(
                                title: 'الاعدادات',
                                icon: Icons.settings_rounded,
                                colors: _kSettings,
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const RefSettingsScreen()))),
                            RefTile(
                                title: 'إدارة المخزن',
                                icon: Icons.warehouse_rounded,
                                colors: _kWarehouse,
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const WarehouseHomeScreen()))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _logoutButton(context, ref),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// صف من بلاطتين بنفس الارتفاع — Expanded عشان الشبكة تملأ المساحة.
  Widget _row(Widget a, Widget b) {
    return Expanded(
      child: Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 14),
          Expanded(child: b),
        ],
      ),
    );
  }

  /// هيدر ترحيبي: أفاتار + اسم المستخدم + شارة الصلاحية.
  Widget _header(String username, String? type) {
    return RefHeaderBackground(
      radius: 34,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .55), width: 2),
                ),
                child: const Icon(Icons.person_rounded,
                    size: 34, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('مرحبا!',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: .85))),
                    Text(username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2)),
                  ],
                ),
              ),
              if (type != null && type.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: RefColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(type,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: RefColors.navy)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// زر تسجيل الخروج — نفس المنطق القديم بالظبط.
  Widget _logoutButton(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: RefColors.red.withValues(alpha: .35), width: 1.4),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            ref.read(currentUserProvider.notifier).state = null;
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 24, color: RefColors.red),
              SizedBox(width: 10),
              Text('تسجيل خروج',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: RefColors.red)),
            ],
          ),
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
    // تلوين حسب الأب: مرتجعات = بنفسجي، تحويلات = أزرق.
    final palette = title == 'مرتجعات'
        ? const [_kReturn, [Color(0xFFB5179E), Color(0xFFE879F9)]]
        : const [_kTransfer, [Color(0xFF0E8C97), Color(0xFF38D1C4)]];
    return RefScaffold(
      title: title,
      body: RefFitList(
        maxItemHeight: 124,
        children: [
          for (var i = 0; i < subs.length; i++)
            RefMenuCard(
              title: subs[i].$1,
              icon: subs[i].$2,
              colors: palette[i % palette.length],
              onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          OpListScreen(kind: opKindFrom(subs[i].$1)))),
            ),
        ],
      ),
    );
  }
}
