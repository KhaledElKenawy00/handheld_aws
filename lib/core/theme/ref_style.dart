import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ستايل SANAD — هوية بصرية حديثة: أزرق محيطي عميق → تركواز،
/// كروت بيضاء بظلال ناعمة، أزرار gradient، وتلوين مميز لكل قسم.
/// كل الأسماء القديمة محفوظة حتى لا ينكسر أي استخدام موجود.
class RefColors {
  RefColors._();

  // ── الهيدر: كحلي عميق → أزرق محيطي → تركواز ────────────────
  static const Color headerFrom = Color(0xFF0B3A5B);
  static const Color headerMid = Color(0xFF0F6E8C);
  static const Color headerTo = Color(0xFF17A398);
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [headerFrom, headerMid, headerTo],
  );

  /// gradient الأزرار الأساسية.
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF0F7A96), Color(0xFF17A398)],
  );

  /// gradient الزر العائم (+).
  static const LinearGradient fabGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFFFC53D), Color(0xFFFF9F1C)],
  );

  // ── الألوان الأساسية ─────────────────────────────────────
  static const Color primary = Color(0xFF0F7A96); // أزرار / روابط
  static const Color primarySoft = Color(0xFF17A398);
  static const Color accent = Color(0xFFFFB020); // لمسة ذهبية
  static const Color nameOrange = Color(0xFF0F5F7F); // أسماء الأصناف/العملاء
  static const Color green = Color(0xFF1FAA7A); // صح / up
  static const Color red = Color(0xFFE5484D); // حذف / down
  static const Color blue = Color(0xFF2F80ED); // طباعة / روابط
  static const Color navy = Color(0xFF0B3A5B); // نصوص غامقة
  static const Color cellGreen = Color(0xFFE7F6F2); // خلايا الجدول
  static const Color tableHeader = primary;
  static const Color fieldBorder = Color(0xFFD3DEE6);
  static const Color bodyBg = Color(0xFFF1F6F9);
  static const Color hintGrey = Color(0xFF8794A1);
  static const Color titleDark = navy;
  static const Color cardBorder = Color(0xFFE3ECF1);
  static const Color soft = Color(0xFFE6F2F6);

  /// ظل ناعم موحد للكروت البيضاء.
  static const List<BoxShadow> softShadow = [
    BoxShadow(
        color: Color(0x190B3A5B), blurRadius: 14, offset: Offset(0, 5)),
  ];
}

class RefTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: RefColors.bodyBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: RefColors.primary,
        primary: RefColors.primary,
        secondary: RefColors.primarySoft,
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: RefColors.navy, height: 1.35),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: RefColors.navy, height: 1.35),
        bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1B2B38), height: 1.5),
        bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1B2B38), height: 1.5),
        bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: RefColors.hintGrey, height: 1.5),
        labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(fontSize: 16, color: RefColors.hintGrey),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RefColors.hintGrey),
        floatingLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RefColors.primary),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RefColors.fieldBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RefColors.fieldBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RefColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RefColors.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RefColors.red, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: RefColors.primary),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RefColors.primary,
          textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RefColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RefColors.primary,
          side: const BorderSide(color: RefColors.primary, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: RefColors.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

/// دائرة زخرفية شفافة تُستخدم كخلفية للهيدرات والكروت الملونة.
class RefDecoCircle extends StatelessWidget {
  final double size;
  final double alpha;
  const RefDecoCircle({super.key, required this.size, this.alpha = .08});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      ),
    );
  }
}

/// خلفية الهيدر: gradient + دوائر زخرفية + حواف سفلية دائرية.
class RefHeaderBackground extends StatelessWidget {
  final double radius;
  final Widget? child;
  const RefHeaderBackground({super.key, this.radius = 28, this.child});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.only(
      bottomLeft: Radius.circular(radius),
      bottomRight: Radius.circular(radius),
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: RefColors.headerGradient,
        borderRadius: r,
        boxShadow: const [
          BoxShadow(color: Color(0x4D0B3A5B), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            const PositionedDirectional(
                top: -34, start: -24, child: RefDecoCircle(size: 120, alpha: .07)),
            const PositionedDirectional(
                bottom: -46, end: 36, child: RefDecoCircle(size: 100, alpha: .06)),
            const PositionedDirectional(
                top: 10, end: -18, child: RefDecoCircle(size: 64, alpha: .05)),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

/// Scaffold مرجعي: AppBar بـ gradient + دوائر زخرفية + عنوان واضح + زر رجوع زجاجي،
/// وجسم فوق خلفية فاتحة.
class RefScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? headerActions;
  final Widget? fab;
  final Widget? bottomButton;
  final bool showBack;

  const RefScaffold({
    super.key,
    required this.title,
    required this.body,
    this.headerActions,
    this.fab,
    this.bottomButton,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RefColors.bodyBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        toolbarHeight: 66,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 28),
        flexibleSpace: const RefHeaderBackground(radius: 28),
        leading: showBack
            ? Padding(
                padding: const EdgeInsetsDirectional.only(start: 10),
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: .28), width: 1),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 24),
                  ),
                ),
              )
            : null,
        title: Text(title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        actions: [
          ...(headerActions ?? const []),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        width: double.infinity,
        color: Colors.transparent,
        margin: const EdgeInsets.only(top: 10),
        child: body,
      ),
      floatingActionButton: fab,
      bottomNavigationBar: bottomButton == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF0B3A5B).withValues(alpha: .10),
                      blurRadius: 16,
                      offset: const Offset(0, -4)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: SafeArea(top: false, child: bottomButton!),
            ),
    );
  }
}

/// زر عريض بـ gradient (أساسي).
class RefButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const RefButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: enabled ? RefColors.buttonGradient : null,
        color: enabled ? null : const Color(0xFFC5D2DA),
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
                BoxShadow(
                    color: RefColors.primary.withValues(alpha: .32),
                    blurRadius: 12,
                    offset: const Offset(0, 5)),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 24, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// زر أخضر مفرّغ (أضف الكود).
class RefOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const RefOutlineButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: RefColors.green,
          backgroundColor: RefColors.green.withValues(alpha: .08),
          side: const BorderSide(color: RefColors.green, width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label),
          const SizedBox(width: 8),
          const Icon(Icons.add_circle_outline_rounded, size: 26, color: RefColors.green),
        ]),
      ),
    );
  }
}

/// زر طباعة أزرق مفرّغ صغير.
class RefPrintButton extends StatelessWidget {
  final VoidCallback onPressed;
  const RefPrintButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.print_rounded, size: 24, color: RefColors.blue),
      label: const Text('طباعة',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800, color: RefColors.blue)),
      style: OutlinedButton.styleFrom(
        backgroundColor: RefColors.blue.withValues(alpha: .07),
        side: const BorderSide(color: RefColors.blue, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

/// زر + دائري عائم بـ gradient ذهبي.
class RefFab extends StatelessWidget {
  final VoidCallback onPressed;
  const RefFab({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RefColors.fabGradient,
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF9F1C).withValues(alpha: .45),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Icon(Icons.add_rounded, size: 36, color: RefColors.navy),
        ),
      ),
    );
  }
}

/// حقل مرجعي: ليبل صغير فوق + قيمة كبيرة.
class RefField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final TextDirection? textDirection;
  final VoidCallback? onTap;
  final int? maxLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;

  const RefField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.readOnly = false,
    this.keyboardType,
    this.formatters,
    this.textDirection,
    this.onTap,
    this.maxLines = 1,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      textDirection: textDirection,
      textAlign: TextAlign.right,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w700, color: RefColors.navy),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? label,
        suffixIcon: suffixIcon,
        errorText: errorText,
      ),
    );
  }
}

/// دروب داون مرجعي.
class RefDropdown<T> extends StatelessWidget {
  final String? label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const RefDropdown({super.key, this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      // يتمدد على عرض الحاوية مع تقليم النص الطويل بدل overflow أفقي.
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700, color: RefColors.navy),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30, color: RefColors.primary),
      decoration: InputDecoration(labelText: label, hintText: label),
    );
  }
}

/// دايلوج مرجعي: دائرة gradient فوق الحافة + حفظ + إلغاء.
/// [dialogTitle] عنوان اختياري يظهر أعلى المحتوى ليدل على الدايلوج.
Future<T?> refDialog<T>({
  required BuildContext context,
  required Widget content,
  required VoidCallback onSave,
  String saveLabel = 'حفظ',
  String? dialogTitle,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Stack(
      clipBehavior: Clip.none,
      children: [
        AlertDialog(
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 38),
              if (dialogTitle != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(dialogTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: RefColors.navy)),
                ),
                const SizedBox(height: 10),
              ],
              // المحتوى قد يكون طويلًا (مسطرة باركود + ستيبرات + دروبداونات)
              // لذلك نجعله scrollable بحد أقصى حتى لا يحدث overflow.
              Flexible(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: content,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F6F9),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    RefButton(label: saveLabel, onPressed: onSave),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('الغاء',
                          style: TextStyle(
                              fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700, color: RefColors.primary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -28,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: RefColors.buttonGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                      color: RefColors.primary.withValues(alpha: .35),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
            ),
          ),
        ),
      ],
    ),
  );
}

/// ستيبر مرجعي: حقل + زر أخضر ^ وزر أحمر v.
class RefStepper extends StatelessWidget {
  final TextEditingController controller;
  final double step;
  const RefStepper({super.key, required this.controller, this.step = 1});

  void _add(double d) {
    final v = double.tryParse(controller.text.trim()) ?? 0;
    final n = v + d;
    controller.text = n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RefField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _boxBtn(
                icon: Icons.keyboard_arrow_up_rounded,
                color: RefColors.green,
                onTap: () => _add(step),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _boxBtn(
                icon: Icons.keyboard_arrow_down_rounded,
                color: RefColors.red,
                onTap: () => _add(-step),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _boxBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 1.8),
          ),
          child: Icon(icon, size: 36, color: color),
        ),
      ),
    );
  }
}

/// جدول مرجعي: هيدر gradient + صفوف متبادلة الألوان بحدود ناعمة.
class RefTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  const RefTable({super.key, required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Table(
              border: TableBorder.all(color: const Color(0xFFCFE0E8), width: 1),
              columnWidths: {for (var i = 0; i < headers.length; i++) i: const FlexColumnWidth()},
              children: [
                TableRow(
                  decoration: const BoxDecoration(gradient: RefColors.buttonGradient),
                  children: [
                    for (final h in headers)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        child: Text(h,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                  ],
                ),
                for (var ri = 0; ri < rows.length; ri++)
                  TableRow(
                    decoration: BoxDecoration(color: ri.isEven ? RefColors.cellGreen : Colors.white),
                    children: [
                      for (final c in rows[ri])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          child: Text(c,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: RefColors.navy)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// صف نوع الوزن + نقدي.
class RefCashRow extends StatelessWidget {
  final bool cash;
  final ValueChanged<bool> onChanged;
  const RefCashRow({super.key, required this.cash, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text('نوع الوزن',
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w700, color: RefColors.navy)),
        ),
        InkWell(
          onTap: () => onChanged(!cash),
          child: Row(
            children: [
              const Text('نقدي',
                  style:
                      TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w700, color: RefColors.navy)),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: RefColors.green, width: 2.2),
                  color: cash ? RefColors.green : Colors.white,
                ),
                child: cash ? const Icon(Icons.check_rounded, size: 20, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void refToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700))));
}

Future<void> refError(BuildContext context, Object e) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.error_outline_rounded, color: RefColors.red, size: 26),
          SizedBox(width: 8),
          Text('تنبيه', style: TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w800, color: RefColors.navy)),
        ],
      ),
      content: Text(e.toString().replaceAll('Exception: ', ''),
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600, height: 1.6)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// مكونات صفحات الـ Dashboard — بدون سكرول (تتمدد على المساحة المتاحة)
// ═══════════════════════════════════════════════════════════

/// بلاطة ملونة بـ gradient (أيقونة كبيرة + عنوان) — للشبكة الرئيسية.
class RefTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;

  const RefTile({
    super.key,
    required this.title,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(24);
    return Material(
      color: Colors.transparent,
      borderRadius: r,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: colors,
          ),
          borderRadius: r,
          boxShadow: [
            BoxShadow(
                color: colors.last.withValues(alpha: .38),
                blurRadius: 14,
                offset: const Offset(0, 7)),
          ],
        ),
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: ClipRRect(
            borderRadius: r,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const PositionedDirectional(
                    top: -26, end: -22, child: RefDecoCircle(size: 90, alpha: .14)),
                const PositionedDirectional(
                    bottom: -30, start: -20, child: RefDecoCircle(size: 80, alpha: .10)),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .22),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .35),
                                  width: 1.2),
                            ),
                            child: Icon(icon, size: 34, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          Text(title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// كارت قائمة عريض: شارة أيقونة ملونة + عنوان + سهم.
class RefMenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;

  const RefMenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(22);
    return Material(
      color: Colors.transparent,
      borderRadius: r,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: r,
          border: Border.all(color: RefColors.cardBorder, width: 1),
          boxShadow: RefColors.softShadow,
        ),
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: colors,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: colors.last.withValues(alpha: .35),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(icon, size: 30, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: RefColors.navy,
                          height: 1.25)),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.last.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_left_rounded,
                      size: 24, color: colors.last),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// يوزّع الكروت على الارتفاع المتاح بدون أي سكرول: كل كارت يأخذ حصة متساوية
/// (بحد أدنى/أقصى)، وعند ضيق المساحة جدًا يتصغر المحتوى كله بدل ما يعمل overflow.
class RefFitList extends StatelessWidget {
  final List<Widget> children;
  final Widget? footer;
  final double gap;
  final double maxItemHeight;
  final double minItemHeight;

  const RefFitList({
    super.key,
    required this.children,
    this.footer,
    this.gap = 14,
    this.maxItemHeight = 112,
    this.minItemHeight = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final n = children.length;
                final raw =
                    n == 0 ? 0.0 : (box.maxHeight - gap * (n - 1)) / n;
                final h = raw.clamp(minItemHeight, maxItemHeight).toDouble();
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: box.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < n; i++) ...[
                          if (i > 0) SizedBox(height: gap),
                          SizedBox(height: h, child: children[i]),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            footer!,
          ],
        ],
      ),
    );
  }
}
