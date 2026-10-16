import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';

/// ── Design System الموحد ─────────────────────────────
/// AppHeader / AppCard / AppButton / AppTextField / AppDropdown
/// AppSearchField / AppDialog / AppEmptyState / AppLoading
/// AppStatCard / AppTransactionCard / AppActionCard
///
/// كل الشاشات الجديدة يجب أن تستخدم هذه المكونات فقط.

// ── Header ────────────────────────────────────────────

/// هيدر موحد: gradient خفيف + عنوان + back + actions.
/// يُستخدم داخل body (تحت AppBar) أو كبديل كامل عبر [asAppBar].
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = false,
    this.onBack,
  });

  /// AppBar موحد بكل التطبيق — كحلي داكن + عنوان أبيض.
  static PreferredSizeWidget appBar(
    String title, {
    List<Widget>? actions,
    bool centerTitle = true,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      title: Text(title),
      actions: actions,
      centerTitle: centerTitle,
      bottom: bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Row(
        children: [
          if (showBack)
            InkWell(
              onTap: onBack ?? () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          if (showBack) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: AppTextStyles.onPrimary(size: 19)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: AppTextStyles.onPrimary(
                          size: 13, weight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// شريط gradient كامل العرض أعلى الصفحة (Hero section).
class AppHero extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;

  const AppHero({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: TextStyle(
                          fontFamily: AppTextStyles.family,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .9))),
                ],
              ],
            ),
          ),
          if (actions != null)
            Row(mainAxisSize: MainAxisSize.min, children: actions!),
        ],
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppDimensions.cardPadding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusCard),
        border:
            Border.all(color: AppColors.borderSoft, width: 1),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return InkWell(
      borderRadius:
          BorderRadius.circular(AppDimensions.radiusCard),
      onTap: onTap,
      child: body,
    );
  }
}

// ── Buttons ───────────────────────────────────────────

enum AppButtonKind { primary, secondary, danger, tonal }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;
  final bool expanded;
  final bool loading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.expanded = true,
    this.loading = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.loading = false,
  }) : kind = AppButtonKind.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.loading = false,
  }) : kind = AppButtonKind.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.loading = false,
  }) : kind = AppButtonKind.danger;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? cb = loading ? null : onPressed;
    final content = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kind == AppButtonKind.secondary
                            ? AppColors.primary
                            : kind == AppButtonKind.danger
                                ? Colors.white
                                : Colors.white)),
              ),
            ],
          );

    ButtonStyle style;
    switch (kind) {
      case AppButtonKind.secondary:
        style = OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(
              color: AppColors.primary, width: 1.4),
          minimumSize:
              const Size(64, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  AppDimensions.radiusButton)),
        );
        break;
      case AppButtonKind.danger:
        style = ElevatedButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
          minimumSize:
              const Size(64, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  AppDimensions.radiusButton)),
          elevation: 0,
        );
        break;
      case AppButtonKind.tonal:
        style = FilledButton.styleFrom(
          backgroundColor: AppColors.accentSoft,
          foregroundColor: AppColors.primaryDark,
          minimumSize:
              const Size(64, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  AppDimensions.radiusButton)),
        );
        break;
      case AppButtonKind.primary:
        style = ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize:
              const Size(64, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  AppDimensions.radiusButton)),
          elevation: 0,
        );
        break;
    }

    final btn = kind == AppButtonKind.secondary
        ? OutlinedButton(
            onPressed: cb, style: style, child: content)
        : ElevatedButton(
            onPressed: cb, style: style, child: content);

    if (!expanded) return btn;
    return SizedBox(width: double.infinity, child: btn);
  }
}

// ── Fields ────────────────────────────────────────────

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextDirection? textDirection;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.prefixIcon,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.onSubmitted,
    this.onChanged,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      obscureText: obscure,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textDirection: textDirection,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: const TextStyle(
          fontFamily: AppTextStyles.family,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, size: 21) : null,
        suffixIcon: suffix,
      ),
    );
  }
}

class AppDropdown<T> extends StatelessWidget {
  final String? label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? prefixIcon;

  const AppDropdown({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(
          fontFamily: AppTextStyles.family,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, size: 21) : null,
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const AppSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
          fontFamily: AppTextStyles.family,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 22),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── States ────────────────────────────────────────────

class AppLoading extends StatelessWidget {
  final String? message;
  const AppLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message!, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const AppEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text('لا توجد بيانات',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expanded: false,
                  icon: Icons.add_rounded),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AppErrorState(
      {super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 36, color: AppColors.danger),
            ),
            const SizedBox(height: 14),
            const Text('حدث خطأ أثناء تحميل البيانات',
                style: AppTextStyles.cardTitle),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              AppButton.secondary(
                  label: 'إعادة المحاولة',
                  onPressed: onRetry,
                  expanded: false,
                  icon: Icons.refresh_rounded),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Dialogs ───────────────────────────────────────────

class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: AppTextStyles.cardTitle),
      content: content,
      actions: actions,
    );
  }

  static Future<bool> confirm(
    BuildContext context,
    String message, {
    String title = 'تأكيد الحذف',
    String confirmLabel = 'حذف',
    String cancelLabel = 'إلغاء',
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: title,
        content: Text(message, style: AppTextStyles.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelLabel)),
          AppButton.danger(
              label: confirmLabel,
              onPressed: () => Navigator.pop(context, true),
              expanded: false),
        ],
      ),
    );
    return r ?? false;
  }
}

// ── Cards: Stat / Action / Transaction ─────────────────

class AppStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color? bg;
  final VoidCallback? onTap;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: (bg ?? color).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const AppActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 25, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.arrow_back_ios_rounded,
              size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class AppTransactionCard extends StatelessWidget {
  final String partnerName;
  final String voucherId;
  final String date;
  final int totalItems;
  final double totalQty;
  final bool isReceipt;
  final String? status;
  final VoidCallback onTap;

  const AppTransactionCard({
    super.key,
    required this.partnerName,
    required this.voucherId,
    required this.date,
    required this.totalItems,
    required this.totalQty,
    required this.isReceipt,
    this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        isReceipt ? AppColors.successStrong : AppColors.warning;
    final accentBg =
        isReceipt ? AppColors.successBg : AppColors.warningBg;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isReceipt
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 24,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(partnerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$voucherId  •  $date',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _chip('الأصناف: $totalItems'),
                    if (status != null) ...[
                      const SizedBox(width: 6),
                      _chip(status!, highlight: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: accent.withValues(alpha: .35),
                  width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fmtQty(totalQty),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontFamily: AppTextStyles.family,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      height: 1.1),
                ),
                Text('كمية',
                    style: TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {bool highlight = false}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: .12)
            : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontFamily: AppTextStyles.family,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: highlight
                  ? AppColors.primaryDark
                  : AppColors.primaryDark)),
    );
  }

  String _fmtQty(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}

/// عنوان قسم داخل الصفحة.
class AppSectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontFamily: AppTextStyles.family,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary))),
        if (actionLabel != null && onAction != null)
          TextButton(
              onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
