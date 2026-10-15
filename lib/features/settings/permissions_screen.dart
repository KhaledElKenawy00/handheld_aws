import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/schema.dart';
import '../../core/providers.dart';
import '../../core/theme/ref_style.dart';
import '../../shared/models/entities.dart';

/// تصريحات المستخدم — اختيار المستخدم + الوظيفة + حفظ.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});
  @override
  ConsumerState<PermissionsScreen> createState() => _PermState();
}

class _PermState extends ConsumerState<PermissionsScreen> {
  List<AppUser> users = [];
  String? username;
  String? job;
  Map<String, bool> allowed = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    users = await ref.read(usersRepoProvider).all();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadPerms() async {
    if (username == null) return;
    allowed = await ref.read(usersRepoProvider).permissions(username!);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (username == null || job == null) {
      refError(context, 'اختر المستخدم والوظيفة');
      return;
    }
    try {
      await ref.read(usersRepoProvider).setPermission(username!, job!, allowed[job] ?? true);
      if (mounted) refToast(context, 'تم الحفظ');
    } catch (e) {
      if (mounted) refError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'تصريحات المستخدم',
      bottomButton: RefButton(label: 'حفظ', icon: Icons.save_outlined, onPressed: loading ? null : _save),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                RefDropdown<String>(
                  label: 'اسم المستخدم',
                  value: username,
                  items: [for (final u in users) DropdownMenuItem(value: u.username, child: Text(u.username))],
                  onChanged: (v) {
                    setState(() {
                      username = v;
                      job = null;
                    });
                    _loadPerms();
                  },
                ),
                const SizedBox(height: 12),
                RefDropdown<String>(
                  label: 'وظيفة',
                  value: job,
                  items: [for (final j in Schema.jobs) DropdownMenuItem(value: j, child: Text(j))],
                  onChanged: (v) => setState(() => job = v),
                ),
                if (job != null) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(job!,
                        style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w700)),
                    subtitle: Text((allowed[job] ?? true) ? 'مسموح' : 'محظور',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 15)),
                    value: allowed[job] ?? true,
                    activeThumbColor: RefColors.green,
                    onChanged: (v) => setState(() => allowed[job!] = v),
                  ),
                ],
              ],
            ),
    );
  }
}
