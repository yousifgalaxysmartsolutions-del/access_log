import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.action,
  });
  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // A pair of widgets is inserted together when an icon is supplied.
              // ignore: use_null_aware_elements
              if (icon != null) ...[
                Icon(icon, color: AppColors.orange, size: 21),
                const SizedBox(width: 9),
              ],
              Expanded(child: Text(title, style: AppTypography.section)),
              ?action,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}
