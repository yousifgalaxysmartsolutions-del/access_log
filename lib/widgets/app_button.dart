import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

enum AppButtonStyle { primary, secondary, outline, text, destructive }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.loading = false,
    this.expanded = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool loading, expanded;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = switch (style) {
      AppButtonStyle.primary => AppColors.orange,
      AppButtonStyle.secondary =>
        dark ? Colors.white12 : const Color(0xFFF0F0ED),
      AppButtonStyle.destructive => AppColors.error,
      _ => Colors.transparent,
    };
    final fg = switch (style) {
      AppButtonStyle.primary => AppColors.ink,
      AppButtonStyle.destructive => Colors.white,
      AppButtonStyle.text => AppColors.orange,
      _ => dark ? Colors.white : AppColors.ink,
    };
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: loading
          ? SizedBox(
              key: const ValueKey('loader'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: .45),
        disabledForegroundColor: fg.withValues(alpha: .65),
        elevation: 0,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: style == AppButtonStyle.outline
              ? BorderSide(color: dark ? Colors.white24 : AppColors.border)
              : BorderSide.none,
        ),
      ),
      child: child,
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
