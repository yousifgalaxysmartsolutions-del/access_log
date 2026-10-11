import 'package:flutter/material.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_tokens.dart';
import '../models/models.dart';

Color capStatusColor(CapIncidentStatus status) => switch (status) {
  CapIncidentStatus.needAssign => AppColors.orange,
  CapIncidentStatus.needApproval => AppColors.purple,
  CapIncidentStatus.pending => AppColors.warning,
  CapIncidentStatus.inProcess => AppColors.info,
  CapIncidentStatus.hold => AppColors.purple,
  CapIncidentStatus.completed => AppColors.success,
  CapIncidentStatus.cancelled => AppColors.error,
};

Color incidentStatusColor(CapIncident incident) =>
    capBackendStatusColor(incident.backendStatusId, incident.status);

Color capBackendStatusColor(int? id, CapIncidentStatus fallback) =>
    switch (id) {
      1 => AppColors.orange,
      2 => AppColors.purple,
      3 => AppColors.warning,
      4 => AppColors.info,
      5 => AppColors.success,
      6 || 8 => AppColors.error,
      7 => AppColors.purple,
      null => capStatusColor(fallback),
      _ => AppColors.muted,
    };

Color priorityColor(Priority priority) => switch (priority) {
  Priority.critical => AppColors.error,
  Priority.high => AppColors.orangeDark,
  Priority.medium => AppColors.info,
  Priority.low => AppColors.success,
};

class CapIncidentCard extends StatelessWidget {
  const CapIncidentCard({super.key, required this.incident, this.onTap});
  final CapIncident incident;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = incidentStatusColor(incident);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      incident.number,
                      style: AppTypography.label.copyWith(
                        color: AppColors.orangeDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          incident.backendStatusId == 8
                              ? Icons.cancel_outlined
                              : _statusIcon(incident.status),
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          incident.displayStatus,
                          style: AppTypography.meta.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(incident.title, style: AppTypography.section),
              const SizedBox(height: 9),
              _CardLine(
                icon: Icons.cell_tower,
                text: [
                  incident.siteName,
                  incident.siteCode,
                ].where((value) => value.isNotEmpty).join(' • '),
              ),
              const SizedBox(height: 7),
              _CardLine(
                icon: Icons.map_outlined,
                text: '${incident.region} • ${incident.area}',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Divider(height: 1),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _Pill(icon: Icons.category_outlined, label: incident.type),
                  _Pill(
                    icon: Icons.flag_outlined,
                    label: incident.displayPriority,
                    color: priorityColor(incident.priority),
                  ),
                  _Pill(
                    icon: Icons.schedule,
                    label: incident.hasRealDate
                        ? formatIncidentCreatedDate(incident.dateTime)
                        : context.tr('Date unavailable', 'التاريخ غير متاح'),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 13,
                    backgroundColor: Color(0xFFF0F0ED),
                    child: Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      incident.currentUser,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    size: 21,
                    color: AppColors.muted,
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

IconData _statusIcon(CapIncidentStatus status) => switch (status) {
  CapIncidentStatus.needAssign => Icons.person_add_alt,
  CapIncidentStatus.needApproval => Icons.approval_outlined,
  CapIncidentStatus.pending => Icons.pending_actions,
  CapIncidentStatus.inProcess => Icons.engineering,
  CapIncidentStatus.hold => Icons.pause_circle_outline,
  CapIncidentStatus.completed => Icons.task_alt,
  CapIncidentStatus.cancelled => Icons.cancel_outlined,
};

String formatIncidentCreatedDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: AppColors.muted),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: AppTypography.meta.copyWith(color: AppColors.muted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: color ?? AppColors.muted),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          style: AppTypography.meta.copyWith(color: color ?? AppColors.muted),
        ),
      ),
    ],
  );
}
