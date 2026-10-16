import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/ref_style.dart';
import '../../shared/widgets/common.dart';

/// دخول الإدارة (يُفتح بـ 5 ضغطات على لوجو شاشة التفعيل).
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginState();
}

class _AdminLoginState extends ConsumerState<AdminLoginScreen> {
  final emailC =
      TextEditingController(text: 'hossam@yad.tech');
  final passC = TextEditingController();
  bool obscure = true;
  bool busy = false;

  @override
  void dispose() {
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (emailC.text.trim().isEmpty || passC.text.isEmpty) {
      showError(context, 'ادخل الإيميل والباسورد');
      return;
    }
    setState(() => busy = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailC.text.trim(),
        password: passC.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
    } on AuthException catch (e) {
      if (mounted) showError(context, 'الدخول غلط: ${e.message}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'دخول الإدارة',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          RefField(
              controller: emailC,
              label: 'الإيميل',
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          RefField(
            controller: passC,
            label: 'الباسورد',
            suffixIcon: IconButton(
              icon: Icon(obscure
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded),
              onPressed: () =>
                  setState(() => obscure = !obscure),
            ),
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

/// لوحة الإدارة: الأجهزة والتراخيص (كود/عميل/سيريال/تفعيل/انتهاء)
/// + إنشاء كود (تجربة/مؤقت/مدى الحياة) + إيقاف/تفعيل + حذف.
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelState();
}

class _AdminPanelState extends ConsumerState<AdminPanelScreen> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  final searchC = TextEditingController();
  String q = '';

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  /// بحث بالسيريال أو الكود أو اسم العميل.
  List<Map<String, dynamic>> get filtered {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows.where((r) {
      final serial = (r['serial'] ?? '').toString().toLowerCase();
      final code = (r['code'] ?? '').toString().toLowerCase();
      final customer = (r['customer'] ?? '').toString().toLowerCase();
      return serial.contains(query) ||
          code.contains(query) ||
          customer.contains(query);
    }).toList();
  }

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await _sb
          .from('licenses')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          rows = (res as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showError(context, e);
      }
    }
  }

  String _fmtDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _code() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    final part = (int n) =>
        List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
    return 'SANAD-${part(4)}-${part(4)}';
  }

  Future<void> _create() async {
    final nameC = TextEditingController();
    final numC = TextEditingController(text: '7');
    String unit = 'days';
    const units = {
      'minutes': 'دقائق',
      'hours': 'ساعات',
      'days': 'أيام',
      'life': 'مدى الحياة',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('كود جديد',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameC,
                  decoration: const InputDecoration(
                      labelText: 'اسم العميل')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: unit,
                    items: [
                      for (final e in units.entries)
                        DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value)),
                    ],
                    onChanged: (v) =>
                        setD(() => unit = v ?? unit),
                    decoration: const InputDecoration(
                        labelText: 'المدة'),
                  ),
                ),
                if (unit != 'life') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                        controller: numC,
                        keyboardType:
                            TextInputType.number,
                        textDirection:
                            TextDirection.ltr,
                        textAlign: TextAlign.center,
                        decoration:
                            const InputDecoration(
                                labelText: 'العدد')),
                  ),
                ],
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إنشاء')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final n = int.tryParse(numC.text.trim()) ?? 0;
    if (unit != 'life' && n <= 0) {
      if (mounted) showError(context, 'ادخل عدد صحيح أكبر من صفر');
      return;
    }
    DateTime? exp;
    final now = DateTime.now();
    if (unit == 'minutes') {
      exp = now.add(Duration(minutes: n));
    } else if (unit == 'hours') {
      exp = now.add(Duration(hours: n));
    } else if (unit == 'days') {
      exp = now.add(Duration(days: n));
    }
    try {
      final code = _code();
      await _sb.from('licenses').insert({
        'code': code,
        'customer': nameC.text.trim(),
        'status': 'unused',
        'expires_at': exp?.toIso8601String(),
      });
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) toast(context, 'اتعمل الكود واتنسخ: $code');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _toggle(Map<String, dynamic> r) async {
    final next =
        (r['status'] == 'disabled') ? 'active' : 'disabled';
    try {
      await _sb
          .from('licenses')
          .update({'status': next}).eq('code', r['code']);
      await _load();
      if (mounted) {
        toast(context,
            next == 'disabled' ? 'اتوقف (هيفصل مع أول نت)' : 'اتفعل');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final ok = await confirm(
        context, 'حذف الكود ${r['code']} نهائيًا؟');
    if (!ok || !mounted) return;
    try {
      await _sb.from('licenses').delete().eq('code', r['code']);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _logout() async {
    await _sb.auth.signOut();
    if (mounted) Navigator.pop(context);
  }

  Color _stColor(String s) {
    switch (s) {
      case 'active':
        return RefColors.green;
      case 'disabled':
        return RefColors.red;
      default:
        return RefColors.hintGrey;
    }
  }

  String _stAr(String s) {
    switch (s) {
      case 'active':
        return 'مفعل';
      case 'disabled':
        return 'موقوف';
      default:
        return 'غير مستخدم';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأجهزة والتراخيص'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load),
          IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('كود جديد'),
        onPressed: _create,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(child: Text('لا توجد أكواد بعد'))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        12, 12, 12, 4),
                    child: TextField(
                      controller: searchC,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: 'بحث بالسيريال أو الكود أو العميل...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) =>
                          setState(() => q = v),
                    ),
                  ),
                  Expanded(
                    child: Builder(builder: (context) {
                      final list = filtered;
                      if (list.isEmpty) {
                        return const Center(
                            child: Text('لا توجد نتائج مطابقة'));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final r = list[i];
                    final st = (r['status'] ?? '').toString();
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                    (r['customer'] ?? '').toString().isEmpty
                                        ? (r['code'] ?? '').toString()
                                        : '${r['customer']} (${r['code']})',
                                    style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.w800)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _stColor(st).withValues(
                                      alpha: .14),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Text(_stAr(st),
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.w800,
                                        color: _stColor(st))),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                                'سيريال: ${(r['serial'] ?? '—').toString()}',
                                textDirection:
                                    TextDirection.ltr,
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12)),
                            Text(
                                'اتفعل: ${_fmtDate(r['activated_at'])} • ينتهي: ${r['expires_at'] == null ? 'مدى الحياة' : _fmtDate(r['expires_at'])}',
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12)),
                            const SizedBox(height: 6),
                            Wrap(spacing: 8, children: [
                              OutlinedButton.icon(
                                icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 18),
                                label: const Text('نسخ الكود'),
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(
                                          text: (r['code'] ?? '')
                                              .toString()));
                                  if (context.mounted) {
                                    toast(context,
                                        'اتنسخ الكود');
                                  }
                                },
                              ),
                              OutlinedButton.icon(
                                icon: Icon(
                                    st == 'disabled'
                                        ? Icons.play_arrow_rounded
                                        : Icons.stop_rounded,
                                    size: 18),
                                label: Text(st == 'disabled'
                                    ? 'تفعيل'
                                    : 'إيقاف'),
                                onPressed: () => _toggle(r),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18),
                                label: const Text('حذف'),
                                onPressed: () => _delete(r),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                          },
                        );
                      }),
                  ),
                ]),
    );
  }
}
