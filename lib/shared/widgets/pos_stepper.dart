import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/ref_style.dart';

/// خانة "بداية/نهاية" قابلة للكتابة باليد + سهمين زيادة/نقصان.
///
/// - تقبل أرقامًا فقط وبحد أقصى [max] (طول الباركود) — تقف عند الخانة
///   المكتوبة ولا تتجاوز مواضع الباركود.
/// - [allowZero] يسمح بـ 0 = "غير محدد" (تظهر —) كما في مقاطع الوزن/الكود/التاريخ.
/// - [onChanged] يُرجع القيمة المطبّعة (مقصوصة داخل المدى).
class PosStepper extends StatefulWidget {
  final String label;
  final int value;
  final int max;
  final bool allowZero;
  final ValueChanged<int> onChanged;

  const PosStepper({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.allowZero = true,
  });

  @override
  State<PosStepper> createState() => _PosStepperState();
}

class _PosStepperState extends State<PosStepper> {
  late final TextEditingController _c;
  final FocusNode _focus = FocusNode();

  int get _max => widget.max <= 0 ? 99 : widget.max;
  int get _min => widget.allowZero ? 0 : 1;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: _display(widget.value));
  }

  @override
  void didUpdateWidget(covariant PosStepper old) {
    super.didUpdateWidget(old);
    // مزامنة نص الحقل مع القيمة الخارجية (من الأسهم) طول ما مش بيتكتب فيه.
    if (!_focus.hasFocus) {
      final d = _display(widget.value);
      if (_c.text != d) _c.text = d;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  String _display(int v) => v <= 0 ? '' : '$v';

  int _clamp(int v) => v < _min ? _min : (v > _max ? _max : v);

  void _commit(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final v = digits.isEmpty ? 0 : (int.tryParse(digits) ?? 0);
    widget.onChanged(_clamp(v));
  }

  void _step(int delta) {
    final base = widget.value <= 0 ? 0 : widget.value;
    final v = _clamp(base + delta);
    // حدّث نص الحقل مباشرةً حتى لو الحقل مركّز (didUpdateWidget مايزامنش وهو مركّز).
    final d = _display(v);
    if (_c.text != d) {
      _c.text = d;
      _c.selection = TextSelection.collapsed(offset: d.length);
    }
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final maxDigits = '$_max'.length;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: RefColors.fieldBorder),
          ),
          child: Column(
            children: [
              Text(widget.label,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: RefColors.hintGrey)),
              TextField(
                controller: _c,
                focusNode: _focus,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(maxDigits),
                ],
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '—',
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _commit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _arrow(
                icon: Icons.keyboard_arrow_up_rounded,
                color: RefColors.green,
                onTap: () => _step(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _arrow(
                icon: Icons.keyboard_arrow_down_rounded,
                color: RefColors.red,
                onTap: () => _step(-1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _arrow(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, size: 40, color: color),
      ),
    );
  }
}
