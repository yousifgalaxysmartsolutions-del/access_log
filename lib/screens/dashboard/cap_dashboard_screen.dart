import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/mock_content_localization.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/identity_verification_mock.dart';
import '../map/tower_map_screen.dart';
import '../reporting/reporting_screen.dart';

class CapDashboardScreen extends StatelessWidget {
  const CapDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final today = MockData.capIncidents
        .where((item) => item.dateTime.day == 10 && item.dateTime.month == 8)
        .toList();
    final month = MockData.capIncidents
        .where((item) => item.dateTime.year == 2026 && item.dateTime.month == 8)
        .toList();
    int count(CapIncidentStatus status) =>
        month.where((item) => item.status == status).length;
    final open = month
        .where(
          (item) =>
              item.status != CapIncidentStatus.completed &&
              item.status != CapIncidentStatus.cancelled,
        )
        .length;
    final completed = count(CapIncidentStatus.completed);
    final completionRate = month.isEmpty
        ? 0
        : (completed / month.length * 100).round();
    // final cards = [
    //   _Metric(
    //     context.tr('Total Incidents', 'إجمالي البلاغات'),
    //     month.length,
    //     Icons.assignment_outlined,
    //     null,
    //   ),
    //   _Metric(
    //     context.tr('Open Incidents', 'البلاغات المفتوحة'),
    //     open,
    //     Icons.inbox_outlined,
    //     null,
    //   ),
    //   _Metric(
    //     context.tr('Completed', 'مكتمل'),
    //     completed,
    //     Icons.task_alt_outlined,
    //     CapIncidentStatus.completed,
    //   ),
    //   _Metric(
    //     context.tr('Completion Rate', 'نسبة الإنجاز'),
    //     completionRate,
    //     Icons.trending_up_rounded,
    //     null,
    //     suffix: '%',
    //   ),
    // ];

    final cards = [
      _Metric(
        context.tr('Total Incidents', 'إجمالي البلاغات'),
        today.length,
        Icons.assignment_outlined,
        null,
      ),
      _Metric(
        context.tr('Open Incidents', 'البلاغات المفتوحة'),
        open,
        Icons.inbox_outlined,
        null,
      ),
      _Metric(
        context.tr('In Progress', 'قيد التنفيذ'),
        count(CapIncidentStatus.inProcess),
        Icons.construction_outlined,
        CapIncidentStatus.inProcess,
      ),
      _Metric(
        context.tr('Completed', 'مكتمل'),
        count(CapIncidentStatus.completed),
        Icons.task_alt_outlined,
        CapIncidentStatus.completed,
      ),
      _Metric(
        context.tr('On Hold', 'معلق'),
        count(CapIncidentStatus.hold),
        Icons.pause_circle_outline,
        CapIncidentStatus.hold,
      ),
      _Metric(
        context.tr("Today's Activities", 'أنشطة اليوم'),
        today.length,
        Icons.today_outlined,
        null,
      ),
      _Metric(
        context.tr('Need Approval', 'تحتاج موافقة'),
        today.where((item) => item.needsApproval).length,
        Icons.approval_outlined,
        null,
      ),
    ];
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: () async =>
          Future<void>.delayed(const Duration(milliseconds: 700)),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            sliver: SliverList.list(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('CAP Dashboard', 'لوحة تحكم CAP'),
                            style: AppTypography.display,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            context.tr(
                              'August 2026 performance overview',
                              'ملخص أداء أغسطس 2026',
                            ),
                            style: AppTypography.body.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.tr(
                            'Try Identity Check',
                            'تجربة التحقق من الهوية',
                          ),
                          onPressed: () =>
                              showMockIdentityVerification(context),
                          icon: const Icon(Icons.face_retouching_natural),
                          color: AppColors.orange,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          tooltip: context.tr('Tower Map', 'خريطة الأبراج'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TowerMapScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.map_outlined),
                          color: AppColors.orange,
                        ),
                        // Container(
                        //   padding: const EdgeInsets.symmetric(
                        //     horizontal: 10,
                        //     vertical: 7,
                        //   ),
                        //   decoration: BoxDecoration(
                        //     color: AppColors.success.withValues(alpha: .1),
                        //     borderRadius: BorderRadius.circular(9),
                        //   ),
                        //   child: Text(
                        //     context.tr('ON DUTY', 'في الخدمة'),
                        //     style: AppTypography.meta.copyWith(
                        //       color: AppColors.success,
                        //       fontWeight: FontWeight.w800,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _MonthlyPerformanceCard(
                  completed: completed,
                  total: month.length,
                  completionRate: completionRate,
                  onOpenReport: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: Text(context.tr('Reporting', 'التقارير')),
                        ),
                        body: const SafeArea(child: ReportingScreen()),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 11) / 2;
                    return Wrap(
                      spacing: 11,
                      runSpacing: 11,
                      children: cards
                          .map(
                            (metric) => SizedBox(
                              width: width,
                              child: _MetricCard(
                                metric: metric,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.incidentList,
                                  arguments: IncidentListFilter(
                                    status: metric.status,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _StatusOverview(
                  total: month.length,
                  rows: [
                    _StatusRow(
                      context.tr('In Process', 'قيد التنفيذ'),
                      count(CapIncidentStatus.inProcess),
                      AppColors.info,
                      CapIncidentStatus.inProcess,
                    ),
                    _StatusRow(
                      context.tr('Pending', 'قيد الانتظار'),
                      count(CapIncidentStatus.pending) +
                          count(CapIncidentStatus.needApproval),
                      AppColors.warning,
                      CapIncidentStatus.pending,
                    ),
                    _StatusRow(
                      context.tr('On Hold', 'معلق'),
                      count(CapIncidentStatus.hold),
                      AppColors.purple,
                      CapIncidentStatus.hold,
                    ),
                    _StatusRow(
                      context.tr('Completed', 'مكتمل'),
                      completed,
                      AppColors.success,
                      CapIncidentStatus.completed,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                // Row(
                //   children: [
                //     Expanded(
                //       child: Text(
                //         context.tr('Current Activity', 'النشاط الحالي'),
                //         style: AppTypography.title,
                //       ),
                //     ),
                //     TextButton(
                //       onPressed: () =>
                //           Navigator.pushNamed(context, AppRoutes.incidentList),
                //       child: Text(context.tr('View today', 'عرض اليوم')),
                //     ),
                //   ],
                // ),
                // const SizedBox(height: 9),
                // ActiveInterventionIndicator(incident: active),
                // const SizedBox(height: 22),
                // Row(
                //   children: [
                //     Expanded(
                //       child: Text(
                //         context.tr('Next assignment', 'المهمة التالية'),
                //         style: AppTypography.title,
                //       ),
                //     ),
                //   ],
                // ),
                // const SizedBox(height: 10),
                // CapIncidentCard(
                //   incident: today[1],
                //   onTap: () => _openNextAssignment(context, today[1]),
                // ),
                // const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('Currently Active', 'النشط حاليًا'),
                        style: AppTypography.title,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${today.length}',
                        style: AppTypography.label.copyWith(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...today.map(
                  (incident) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CompactIncidentTile(
                      incident: incident,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.incidentDetails,
                        arguments: incident,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyPerformanceCard extends StatelessWidget {
  const _MonthlyPerformanceCard({
    required this.completed,
    required this.total,
    required this.completionRate,
    required this.onOpenReport,
  });

  final int completed;
  final int total;
  final int completionRate;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.ink,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Monthly Performance', 'أداء الشهر'),
                      style: AppTypography.section.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      context.tr(
                        '$completed of $total incidents completed',
                        'تم إنجاز $completed من أصل $total بلاغًا',
                      ),
                      style: AppTypography.meta.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Text(
                '$completionRate%',
                style: AppTypography.title.copyWith(
                  color: AppColors.orange,
                  fontSize: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: completionRate / 100,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: .14),
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenReport,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: .28)),
              ),
              icon: const Icon(Icons.bar_chart_rounded, size: 19),
              label: Text(
                context.tr('View Monthly Reports', 'عرض تقارير الشهر'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusRow {
  const _StatusRow(this.label, this.value, this.color, this.status);
  final String label;
  final int value;
  final Color color;
  final CapIncidentStatus status;
}

class _StatusOverview extends StatelessWidget {
  const _StatusOverview({required this.total, required this.rows});

  final int total;
  final List<_StatusRow> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Monthly Status Overview', 'ملخص حالات الشهر'),
                  style: AppTypography.section,
                ),
              ),
              const Icon(Icons.donut_small_rounded, color: AppColors.orange),
            ],
          ),
          const SizedBox(height: 18),
          ...rows.map(
            (row) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.incidentList,
                arguments: IncidentListFilter(status: row.status),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: row.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(row.label, style: AppTypography.label),
                        ),
                        Text(
                          '${row.value}',
                          style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : row.value / total,
                        minHeight: 6,
                        backgroundColor: row.color.withValues(alpha: .1),
                        color: row.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.status);
  final String label;
  final int value;
  final IconData icon;
  final CapIncidentStatus? status;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.onTap});
  final _Metric metric;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(metric.icon, color: AppColors.orange, size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${metric.value}',
                    style: AppTypography.title.copyWith(fontSize: 23),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric.label,
                    style: AppTypography.meta.copyWith(color: AppColors.muted),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left
                  : Icons.chevron_right,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

class CompactIncidentTile extends StatelessWidget {
  const CompactIncidentTile({super.key, required this.incident, this.onTap});

  final CapIncident incident;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(incident.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: Row(
            children: [
              /// Status side indicator
              Container(
                width: 5,
                height: 125,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(18),
                    bottomStart: Radius.circular(18),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Number + Status
                      Row(
                        children: [
                          Text(
                            incident.number,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF777777),
                            ),
                          ),

                          const Spacer(),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _localizedStatus(context, incident.status),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 9),

                      /// Title
                      Text(
                        context.mockText(incident.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF161616),
                        ),
                      ),

                      const SizedBox(height: 10),

                      /// Site
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Color(0xFF777777),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${context.mockText(incident.siteName)}'
                              '  •  ${incident.siteCode}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF777777),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      /// Footer
                      Row(
                        children: [
                          _InfoItem(
                            icon: Icons.flag_rounded,
                            label: _localizedPriority(
                              context,
                              incident.priority,
                            ),
                            color: _priorityColor(incident.priority),
                          ),

                          const SizedBox(width: 14),

                          _InfoItem(
                            icon: Icons.calendar_today_rounded,
                            label: _formatDate(incident.dateTime),
                          ),

                          const Spacer(),

                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5F5F5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Directionality.of(context) == TextDirection.rtl
                                  ? Icons.arrow_back_ios_new_rounded
                                  : Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: const Color(0xFF222222),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? const Color(0xFF777777);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: itemColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: color != null ? FontWeight.w700 : FontWeight.w500,
            color: itemColor,
          ),
        ),
      ],
    );
  }
}

Color _statusColor(CapIncidentStatus status) => switch (status) {
  CapIncidentStatus.needAssign => const Color(0xFFF97316),

  CapIncidentStatus.needApproval => const Color(0xFF7C3AED),

  CapIncidentStatus.pending => const Color(0xFFF59E0B),

  CapIncidentStatus.inProcess => const Color(0xFF2563EB),

  CapIncidentStatus.hold => const Color(0xFF8B5CF6),

  CapIncidentStatus.completed => const Color(0xFF16A34A),

  CapIncidentStatus.cancelled => const Color(0xFFDC2626),
};

Color _priorityColor(Priority priority) => switch (priority) {
  Priority.critical => const Color(0xFFDC2626),

  Priority.high => const Color(0xFFEA580C),

  Priority.medium => const Color(0xFF2563EB),

  Priority.low => const Color(0xFF16A34A),
};

String _localizedStatus(BuildContext context, CapIncidentStatus status) =>
    switch (status) {
      CapIncidentStatus.needAssign => context.tr('Need Assign', 'تحتاج إسناد'),

      CapIncidentStatus.needApproval => context.tr(
        'Need Approval',
        'بانتظار الموافقة',
      ),

      CapIncidentStatus.pending => context.tr('Pending', 'بانتظار القبول'),

      CapIncidentStatus.inProcess => context.tr('In Process', 'قيد التنفيذ'),

      CapIncidentStatus.hold => context.tr('On Hold', 'متوقف مؤقتًا'),

      CapIncidentStatus.completed => context.tr('Completed', 'مكتمل'),

      CapIncidentStatus.cancelled => context.tr('Cancelled', 'ملغى'),
    };

String _localizedPriority(BuildContext context, Priority priority) =>
    switch (priority) {
      Priority.critical => context.tr('Critical', 'حرجة'),

      Priority.high => context.tr('High', 'عالية'),

      Priority.medium => context.tr('Medium', 'متوسطة'),

      Priority.low => context.tr('Low', 'منخفضة'),
    };

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';
}
