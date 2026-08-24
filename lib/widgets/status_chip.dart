import 'package:flutter/material.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_tokens.dart';
import '../models/models.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final IncidentStatus status;
  String get label => switch (status) {
    IncidentStatus.enRoute => 'En Route',
    IncidentStatus.onSite => 'On Site',
    IncidentStatus.inProgress => 'In Progress',
    _ => '${status.name[0].toUpperCase()}${status.name.substring(1)}',
  };
  Color get color => switch (status) {
    IncidentStatus.completed => AppColors.success,
    IncidentStatus.rejected || IncidentStatus.overdue => AppColors.error,
    IncidentStatus.escalated => AppColors.purple,
    IncidentStatus.enRoute || IncidentStatus.onSite => AppColors.info,
    IncidentStatus.inProgress || IncidentStatus.pending => AppColors.warning,
    _ => AppColors.orange,
  };
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(AppRadius.small),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          _localizedLabel(context),
          style: AppTypography.meta.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  String _localizedLabel(BuildContext context) => switch (status) {
    IncidentStatus.assigned => context.tr('Assigned', 'تم الإسناد'),
    IncidentStatus.accepted => context.tr('Accepted', 'تم القبول'),
    IncidentStatus.enRoute => context.tr('En Route', 'في الطريق'),
    IncidentStatus.onSite => context.tr('On Site', 'في الموقع'),
    IncidentStatus.inProgress => context.tr('In Progress', 'قيد التنفيذ'),
    IncidentStatus.pending => context.tr('Pending', 'معلق'),
    IncidentStatus.completed => context.tr('Completed', 'مكتمل'),
    IncidentStatus.rejected => context.tr('Rejected', 'مرفوض'),
    IncidentStatus.escalated => context.tr('Escalated', 'تم التصعيد'),
    IncidentStatus.overdue => context.tr('Overdue', 'متأخر'),
  };
}
