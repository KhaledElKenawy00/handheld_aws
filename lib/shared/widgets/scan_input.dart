import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/scanner/scanner_providers.dart';
import 'common.dart';

/// حقل موحد لأي إدخال مرتبط بصنف: يدوي + ماسح SUNMI معًا.
/// - الكتابة اليدوية تعمل دائمًا (كيبورد / لمس).
/// - أي مسح من الماسح المدمج يملأ الحقل تلقائيًا.
/// - زر المسح يشغّل رأس المسح برمجيًا، وزر الجهاز الفيزيائي يعمل أيضًا.
class ScanTextField extends ConsumerStatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final TextInputAction textInputAction;
  final String? helperText;
  final bool debounce;
  const ScanTextField({
    super.key,
    this.controller,
    this.hint = 'امسح أو أدخل الكود يدويًا',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.search,
    this.helperText,
    this.debounce = true,
  });

  @override
  ConsumerState<ScanTextField> createState() => _ScanTextFieldState();
}

class _ScanTextFieldState extends ConsumerState<ScanTextField> {
  late final TextEditingController _c;
  late final bool _ownsController;
  StreamSubscription? _sub;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _c = widget.controller ?? TextEditingController();
    try {
      _sub = ref.read(scannerServiceProvider).scanStream.listen(_onScan);
    } catch (_) {}
  }

  void _onScan(String raw) {
    if (!mounted || !widget.enabled) return;
    final code = raw.trim();
    if (code.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _c.text = code);
    widget.onChanged?.call(code);
    widget.onSubmitted?.call(code);
  }

  Future<void> _trigger() async {
    try {
      await ref.read(scannerServiceProvider).triggerScan();
    } catch (_) {
      if (mounted) {
        toast(context,
            'اضغط زر المسح الفيزيائي في الجهاز أو اكتب الكود يدويًا');
      }
    }
  }

  void _changed(String v) {
    if (widget.onChanged == null) return;
    if (!widget.debounce) {
      widget.onChanged!(v);
      return;
    }
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 300), () {
      if (mounted) widget.onChanged!(v);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _t?.cancel();
    if (_ownsController) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction,
      onChanged: _changed,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hint,
        helperText: widget.helperText ??
            'يدوي بالكتابة أو تلقائي بزر المسح',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_c.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'مسح النص',
                onPressed: () {
                  _c.clear();
                  widget.onChanged?.call('');
                },
              ),
            IconButton(
              icon: const Icon(Icons.document_scanner_outlined),
              tooltip: 'مسح بالـ Scanner',
              onPressed: _trigger,
            ),
          ],
        ),
      ),
    );
  }
}
