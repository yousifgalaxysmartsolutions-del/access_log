import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title, description;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppColors.orange),
          ),
          const SizedBox(height: 18),
          Text(title, style: AppTypography.title, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTypography.body.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            AppButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    ),
  );
}
