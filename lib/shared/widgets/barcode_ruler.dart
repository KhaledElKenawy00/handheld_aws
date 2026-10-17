import 'package:flutter/material.dart';

import '../../core/theme/ref_style.dart';

/// مسطرة أرقام الباركود: كل رقم في خانة مستقلة، والمقطع
/// [start]-[end] مظلّل مع إبراز خانتي الطرفين.
///
/// الأهم للباركود الطويل (50-60 خانة): عند تحريك البداية/النهاية بالأسهم
/// يُمرَّر [focusPos] تلقائيًا للمسطرة حتى تظهر الخانة التي يقف عليها
/// المستخدم — بدل سحب المسطرة يدويًا للبحث عن موضع التوقف.
class BarcodeRuler extends StatefulWidget {
  final String barcode;
  final int start;
  final int end;

  /// الموضع (1-based) الذي تُمرَّر إليه المسطرة تلقائيًا — 0 = بلا تمرير.
  final int focusPos;

  const BarcodeRuler({
    super.key,
    required this.barcode,
    required this.start,
    required this.end,
    this.focusPos = 0,
  });

  @override
  State<BarcodeRuler> createState() => _BarcodeRulerState();
}

class _BarcodeRulerState extends State<BarcodeRuler> {
  final ScrollController _scroll = ScrollController();

  // عرض الخانة ثابت ليُحسب موضع التمرير مباشرة: العرض + الهوامش (3).
  static const double _cellWidth = 38;
  static const double _step = _cellWidth + 3;

  @override
  void initState() {
    super.initState();
    _scheduleReveal(widget.focusPos);
  }

  @override
  void didUpdateWidget(covariant BarcodeRuler old) {
    super.didUpdateWidget(old);
    if (widget.focusPos != old.focusPos) {
      _scheduleReveal(widget.focusPos);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scheduleReveal(int pos) {
    if (pos <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(pos));
  }

  /// يُمرِّر المسطرة أقل قدر لازم حتى تظهر الخانة [pos] داخل نافذة العرض.
  void _reveal(int pos) {
    if (!mounted || pos <= 0 || !_scroll.hasClients) return;
    final left = (pos - 1) * _step;
    final right = left + _cellWidth;
    final viewport = _scroll.position.viewportDimension;
    final current = _scroll.offset;
    const pad = 14.0;
    var target = current;
    if (left - pad < current) {
      target = left - pad;
    } else if (right + pad > current + viewport) {
      target = right + pad - viewport;
    }
    target = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if ((target - current).abs() < 1) return;
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final barcode = widget.barcode;
    final hasS = widget.start > 0;
    final hasE = widget.end > 0;
    final unset = !hasS && !hasE;
    var a = hasS ? widget.start : widget.end;
    var b = hasE ? widget.end : widget.start;
    if (a > b) {
      final t = a;
      a = b;
      b = t;
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < barcode.length; i++)
              _cell(
                barcode[i],
                inRange: !unset && i + 1 >= a && i + 1 <= b,
                boundary: !unset && (i + 1 == a || i + 1 == b),
                active: widget.focusPos == i + 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String ch,
      {required bool inRange, required bool boundary, required bool active}) {
    return Container(
      width: _cellWidth,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: inRange
            ? RefColors.primary.withValues(alpha: boundary ? .42 : .18)
            : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: inRange ? RefColors.primary : RefColors.fieldBorder,
          width: boundary || active ? 2.4 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                    color: RefColors.primary.withValues(alpha: .38),
                    blurRadius: 8,
                    spreadRadius: 1),
              ]
            : null,
      ),
      child: Center(
        child: Text(ch,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}
