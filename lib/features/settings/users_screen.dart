import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import '../../shared/models/entities.dart';

/// ادارة المستخدمين — كارت admin + دايلوج إضافة (اسم/كلمة مرور/النوع).
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});
  @override
  ConsumerState<UsersScreen> createState() => _UsersState();
}

class _UsersState extends ConsumerState<UsersScreen> {
  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'ادارة المستخدمين',
      fab: RefFab(onPressed: _showAdd),
      body: FutureBuilder(
        future: ref.read(usersRepoProvider).all(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: users.length,
            itemBuilder: (_, i) => _card(users[i], i + 1),
          );
        },
      ),
    );
  }

  Widget _card(AppUser u, int n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0x190B3A5B), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () async {
                  try {
                    await ref.read(usersRepoProvider).deleteUser(u.username);
                    setState(() {});
                  } catch (e) {
                    if (mounted) refError(context, e);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded, size: 32, color: RefColors.red),
                ),
              ),
              Expanded(
                child: Text(u.username,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: RefColors.nameOrange)),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: Color(0xFFE3E3E3), shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, size: 36, color: Color(0xFF8A8A8A)),
              ),
            ],
          ),
          Text('#$n  ${u.type}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, color: Colors.black87)),
        ],
      ),
    );
  }

  void _showAdd() {
    final nameC = TextEditingController();
    final passC = TextEditingController();
    String type = 'مستخدم';
    bool obscure = true;
    refDialog(
      context: context,
      dialogTitle: 'إضافة مستخدم',
      onSave: () async {
        try {
          await ref
              .read(usersRepoProvider)
              .create(AppUser(username: nameC.text.trim(), password: passC.text, type: type));
          if (mounted) {
            Navigator.pop(context);
            refToast(context, 'تم الحفظ');
            setState(() {});
          }
        } catch (e) {
          if (mounted) refError(context, e);
        }
      },
      content: StatefulBuilder(
        builder: (ctx, setS) => Column(
          children: [
            RefField(controller: nameC, label: 'ادخل اسم المستخدم'),
            const SizedBox(height: 12),
            TextField(
              controller: passC,
              obscureText: obscure,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 20),
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: Colors.black54),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            RefDropdown<String>(
              label: 'النوع',
              value: type,
              items: const [
                DropdownMenuItem(value: 'مستخدم', child: Text('مستخدم')),
                DropdownMenuItem(value: 'مدير', child: Text('مدير')),
              ],
              onChanged: (v) => setS(() => type = v ?? type),
            ),
          ],
        ),
      ),
    );
  }
}
