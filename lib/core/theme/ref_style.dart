import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ستايل التطبيق المرجعي — مطابق للصور المرفقة (pic/) بالظبط.
/// هيدر gradient + كروت بيضاء + أزرار pill.
/// الألوان من باليتة Meadow Green المعتمدة.
class RefColors {
  RefColors._();

  // هيدر: تركواز → أزرق عميق (من الشمال لليمين)
  static const Color headerFrom = Color(0xFF34A0A4);
  static const Color headerTo = Color(0xFF1A759F);
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [headerFrom, headerTo],
  );

  static const Color primary = Color(0xFF168AAD); // teal الأزرار
  static const Color primarySoft = Color(0xFF52B69A);
  static const Color nameOrange = Color(0xFF1E6091); // أسماء الأصناف/العملاء
  static const Color green = Color(0xFF52B69A); // حدود خضرا / صح / up
  static const Color red = Color(0xFFD32F2F); // حذف / down / ثابت
  static const Color blue = Color(0xFF168AAD); // طباعة / روابط
  static const Color navy = Color(0xFF184E77); // نصوص غامقة + حدود جدول
  static const Color cellGreen = Color(0xFFD9ED92); // خلايا الجدول
  static const Color tableHeader = primary;
  static const Color fieldBorder = Color(0xFFD9E2E3);
  static const Color bodyBg = Color(0xFFF8FAF9);
  static const Color hintGrey = Color(0xFF8A8A8A);
  static const Color titleDark = Color(0xFF184E77);
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
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: RefColors.navy, height: 1.35),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: RefColors.navy, height: 1.35),
        bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.5),
        bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.5),
        bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: RefColors.hintGrey, height: 1.5),
        labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(fontSize: 17, color: RefColors.hintGrey),
        labelStyle: const TextStyle(fontSize: 14, color: RefColors.hintGrey),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RefColors.fieldBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RefColors.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: RefColors.primary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: RefColors.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Scaffold مرجعي: AppBar حقيقي بـ gradient + عنوان واضح + زر رجوع،
/// وجسم بحواف علوية دائرية فوق خلفية فاتحة.
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
        toolbarHeight: 68,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme:
            const IconThemeData(color: Colors.white, size: 28),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: RefColors.headerGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
            boxShadow: [
              BoxShadow(
                  color: Color(0x3326A0B4),
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
        ),
        leading: showBack
            ? Padding(
                padding:
                    const EdgeInsetsDirectional.only(start: 10),
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 26),
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
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        actions: [
          ...(headerActions ?? const []),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        width: double.infinity,
        // شفاف ليُظهر خلفية الصفحة الفاتحة فتبرز الكروت البيضاء.
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
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: .08),
                      blurRadius: 12,
                      offset: const Offset(0, -3)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SafeArea(top: false, child: bottomButton!),
            ),
    );
  }
}

/// زر pill عريض بلون الثيم.
class RefButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const RefButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: RefColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 21, fontWeight: FontWeight.w800),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 26, color: Colors.white), const SizedBox(width: 8)],
          Text(label),
        ]),
      ),
    );
  }
}

/// زر أخضر مفرّغ pill (أضف الكود).
class RefOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const RefOutlineButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: RefColors.green,
          side: const BorderSide(color: RefColors.green, width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w800),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label),
          const SizedBox(width: 10),
          const Icon(Icons.add_rounded, size: 28, color: RefColors.green),
        ]),
      ),
    );
  }
}

/// زر طباعة أزرق مفرّغ pill صغير.
class RefPrintButton extends StatelessWidget {
  final VoidCallback onPressed;
  const RefPrintButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.print_rounded, size: 30, color: RefColors.blue),
      label: const Text('طباعة',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w800, color: RefColors.blue)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: RefColors.blue, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      ),
    );
  }
}

/// زر + دائري برتقالي عائم (أسفل الشمال مثل الصور).
class RefFab extends StatelessWidget {
  final VoidCallback onPressed;
  const RefFab({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: RefColors.primary,
      foregroundColor: Colors.black,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 34, color: Colors.black),
    );
  }
}

/// حقل مرجعي: ليبل صغير رمادي فوق يمين + قيمة كبيرة.
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
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 21, fontWeight: FontWeight.w600, color: Colors.black),
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
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30, color: Colors.black54),
      decoration: InputDecoration(labelText: label, hintText: label),
    );
  }
}

/// دايلوج مرجعي: دائرة + برتقالية فوق الحافة + حفظ + إلغاء.
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
              const SizedBox(height: 34),
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
                  color: Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    RefButton(label: saveLabel, onPressed: onSave),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('الغاء',
                          style: TextStyle(
                              fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w600, color: RefColors.primary)),
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
              decoration: const BoxDecoration(color: RefColors.primary, shape: BoxShape.circle),
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

/// جدول مرجعي: هيدر برتقالي + خلايا خضرا بحدود كحلي.
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
          child: Table(
            border: TableBorder.all(color: RefColors.navy, width: 1.4),
            columnWidths: {for (var i = 0; i < headers.length; i++) i: const FlexColumnWidth()},
            children: [
              TableRow(
                decoration: const BoxDecoration(color: RefColors.tableHeader),
                children: [
                  for (final h in headers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      child: Text(h,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                ],
              ),
              for (final r in rows)
                TableRow(
                  decoration: const BoxDecoration(color: RefColors.cellGreen),
                  children: [
                    for (final c in r)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        child: Text(c,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف نوع الوزن + نقدي (مثل الصور).
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
              style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
        ),
        InkWell(
          onTap: () => onChanged(!cash),
          child: Row(
            children: [
              const Text('نقدي',
                  style:
                      TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
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
      title: const Text('تنبيه', style: TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w800)),
      content: Text(e.toString().replaceAll('Exception: ', ''),
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600, height: 1.6)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
    ),
  );
}
