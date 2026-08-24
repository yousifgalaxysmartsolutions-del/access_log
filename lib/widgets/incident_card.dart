import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';
import '../models/models.dart';
import 'app_button.dart';
import 'status_chip.dart';

class IncidentCard extends StatelessWidget {
  const IncidentCard({super.key, required this.incident, this.onAction});
  final Incident incident;
  final VoidCallback? onAction;
  Color get priorityColor => switch (incident.priority) {
    Priority.critical => AppColors.error,
    Priority.high => AppColors.warning,
    Priority.medium => AppColors.info,
    Priority.low => AppColors.success,
  };
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                incident.number,
                style: AppTypography.meta.copyWith(color: AppColors.muted),
              ),
              const Spacer(),
              StatusChip(status: incident.status),
            ],
          ),
          const SizedBox(height: 14),
          Text(incident.site.name, style: AppTypography.section),
          const SizedBox(height: 6),
          Text(
            incident.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _Meta(
                icon: Icons.schedule_outlined,
                text: incident.scheduledTime,
              ),
              _Meta(
                icon: Icons.location_on_outlined,
                text: incident.site.location,
              ),
              _Meta(
                icon: Icons.flag_outlined,
                text: incident.priority.name,
                color: priorityColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: incident.status == IncidentStatus.enRoute
                ? 'Open assignment'
                : 'View details',
            icon: Icons.arrow_forward,
            onPressed: onAction,
            expanded: true,
          ),
        ],
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color ?? AppColors.muted),
      const SizedBox(width: 5),
      Text(
        text,
        style: AppTypography.meta.copyWith(color: color ?? AppColors.muted),
      ),
    ],
  );
}
