import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/mock_content_localization.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/dashboard/presentation/dashboard_bloc_scope.dart';
import '../../features/dashboard/presentation/dashboard_view_data.dart';
import '../../models/models.dart';
import '../../widgets/identity_verification_mock.dart';
import '../map/tower_map_screen.dart';
import '../reporting/reporting_screen.dart';

class CapDashboardScreen extends StatelessWidget {
  const CapDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      DashboardBlocScope(child: const _CapDashboardView());
}

class _CapDashboardView extends StatelessWidget {
  const _CapDashboardView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        final data = DashboardViewData.fromState(
          state,
          monthDate: DateTime.now(),
        );
        return _DashboardContent(data: data, state: state);
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data, required this.state});

  final DashboardViewData data;
  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final now = data.monthDate;
    final today = data.todayIncidents;
    // A first load has nothing to show yet, so the dashboard renders the real
    // layout with placeholders instead of flashing zeroes and an empty list.
    final isFirstLoad =
        state.status == DashboardStatus.loading && !data.hasContent;
    final cards = [
      _Metric(
        context.tr('Total Incidents', 'إجمالي البلاغات'),
        data.totalIncidents,
        Icons.assignment_outlined,
        null,
      ),
      _Metric(
        context.tr('Open Incidents', 'البلاغات المفتوحة'),
        data.openIncidents,
        Icons.inbox_outlined,
        null,
      ),
      _Metric(
        context.tr('In Progress', 'قيد التنفيذ'),
        data.inProgress,
        Icons.construction_outlined,
        CapIncidentStatus.inProcess,
      ),
      _Metric(
        context.tr('Completed', 'مكتمل'),
        data.completed,
        Icons.task_alt_outlined,
        CapIncidentStatus.completed,
      ),
      _Metric(
        context.tr('On Hold', 'معلق'),
        data.onHold,
        Icons.pause_circle_outline,
        CapIncidentStatus.hold,
      ),
      _Metric(
        context.tr("Today's Activities", 'أنشطة اليوم'),
        data.todaysActivities,
        Icons.today_outlined,
        null,
      ),
      _Metric(
        context.tr('Need Approval', 'تحتاج موافقة'),
        data.needApproval,
        Icons.approval_outlined,
        null,
      ),
    ];
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: () async {
        final bloc = context.read<DashboardBloc>();
        bloc.add(const DashboardRefreshed());
        // Resolves once the bloc leaves the loading state, so the spinner is
        // tied to real data instead of a fixed delay.
        await bloc.stream.firstWhere(
          (s) => s.status != DashboardStatus.loading,
        );
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            sliver: SliverList.list(
              children: [
                _header(context, now),
                const SizedBox(height: 20),
                if (isFirstLoad)
                  ..._DashboardSkeleton.placeholders(context)
                else
                  ..._sections(context: context, today: today, cards: cards),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Every section below the header. Each depends on loaded data, so they
  /// are swapped out wholesale while the first load is in flight.
  List<Widget> _sections({
    required BuildContext context,
    required List<CapIncident> today,
    required List<_Metric> cards,
  }) => [
    _MonthlyPerformanceCard(
      completed: data.monthCompleted,
      total: data.monthTotal,
      completionRate: data.monthPercentage,
      completionLabel: data.monthCompletionLabel,
      onOpenReport: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(context.tr('Reporting', 'التقارير'))),
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
                      arguments: IncidentListFilter(status: metric.status),
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
      total: data.totalIncidents,
      rows: [
        _StatusRow(
          context.tr('In Process', 'قيد التنفيذ'),
          data.inProgress,
          AppColors.info,
          CapIncidentStatus.inProcess,
        ),
        _StatusRow(
          context.tr('Pending', 'قيد الانتظار'),
          data.openIncidents,
          AppColors.warning,
          CapIncidentStatus.pending,
        ),
        _StatusRow(
          context.tr('On Hold', 'معلق'),
          data.onHold,
          AppColors.purple,
          CapIncidentStatus.hold,
        ),
        _StatusRow(
          context.tr('Completed', 'مكتمل'),
          data.completed,
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
    _DashboardFeedback(state: state, hasContent: data.hasContent),
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
  ];

  /// Title, subtitle and quick actions. Shown above the skeleton because none of
  /// it depends on a loaded response.
  Widget _header(BuildContext context, DateTime now) => Row(
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
                '${dashboardMonthTitle(now, context.strings)} performance overview',
                'ملخص أداء ${dashboardMonthTitle(now, context.strings)}',
              ),
              style: AppTypography.body.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.tr('Try Identity Check', 'تجربة التحقق من الهوية'),
            onPressed: () => showMockIdentityVerification(context),
            icon: const Icon(Icons.face_retouching_natural),
            color: AppColors.orange,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: context.tr('Tower Map', 'خريطة الأبراج'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TowerMapScreen()),
            ),
            icon: const Icon(Icons.map_outlined),
            color: AppColors.orange,
          ),
        ],
      ),
    ],
  );
}

/// Placeholder layout shown during the first dashboard load.
///
/// Mirrors the real section order and card geometry so the transition to loaded
/// content does not shift the page, instead of flashing zeroes and an empty list.
/// Joins the non-empty site parts, or returns null when CAP sent no location.
String? _siteLabel(BuildContext context, CapIncident incident) {
  final parts = <String>{
    if (incident.siteName.trim().isNotEmpty)
      context.mockText(incident.siteName),
    if (incident.siteCode.trim().isNotEmpty &&
        incident.siteCode.trim() != incident.siteName.trim())
      incident.siteCode,
  };
  return parts.isEmpty ? null : parts.join('  •  ');
}

class _DashboardSkeleton {
  const _DashboardSkeleton._();

  static List<Widget> placeholders(BuildContext context) => [
    _MonthlyCardSkeleton(),
    const SizedBox(height: 14),
    const _MetricGridSkeleton(),
    const SizedBox(height: 24),
    const _StatusOverviewSkeleton(),
    const SizedBox(height: 26),
    Row(
      children: [
        Expanded(
          child: Text(
            context.tr('Currently Active', 'النشط حاليًا'),
            style: AppTypography.title,
          ),
        ),
        const _SkeletonBox(width: 34, height: 26, radius: 20),
      ],
    ),
    const SizedBox(height: 10),
    const _IncidentTileSkeleton(),
    const SizedBox(height: 10),
    const _IncidentTileSkeleton(),
    const SizedBox(height: 10),
    const _IncidentTileSkeleton(),
  ];
}

/// Sweeping highlight shared by every placeholder block.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        final sweep = _controller.value * 2 - 1;
        return LinearGradient(
          begin: Alignment(-1 + sweep, -1 + sweep),
          end: Alignment(1 + sweep, 1 + sweep),
          colors: const [
            Color(0xFFECECEC),
            Color(0xFFF8F8F8),
            Color(0xFFECECEC),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(bounds);
      },
      child: child,
    ),
    child: widget.child,
  );
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, this.height = 12, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => _Shimmer(
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}

class _MonthlyCardSkeleton extends StatelessWidget {
  const _MonthlyCardSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _SkeletonBox(width: 120, height: 10, radius: 5),
        SizedBox(height: 16),
        _SkeletonBox(width: 90, height: 30, radius: 8),
        SizedBox(height: 14),
        _SkeletonBox(height: 8, radius: 4),
        SizedBox(height: 8),
        _SkeletonBox(width: 160, height: 8, radius: 4),
      ],
    ),
  );
}

class _MetricGridSkeleton extends StatelessWidget {
  const _MetricGridSkeleton();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 11) / 2;
      return Wrap(
        spacing: 11,
        runSpacing: 11,
        children: List.generate(
          6,
          (_) => SizedBox(
            width: width,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEAEAEA)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 26, height: 26, radius: 13),
                  SizedBox(height: 14),
                  _SkeletonBox(width: 64, height: 22, radius: 6),
                  SizedBox(height: 10),
                  _SkeletonBox(height: 9, radius: 4),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _StatusOverviewSkeleton extends StatelessWidget {
  const _StatusOverviewSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEAEAEA)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _SkeletonBox(width: 140, height: 16, radius: 6),
        SizedBox(height: 18),
        _SkeletonRowSkeleton(),
        SizedBox(height: 14),
        _SkeletonRowSkeleton(),
        SizedBox(height: 14),
        _SkeletonRowSkeleton(),
        SizedBox(height: 14),
        _SkeletonRowSkeleton(),
      ],
    ),
  );
}

class _SkeletonRowSkeleton extends StatelessWidget {
  const _SkeletonRowSkeleton();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      _SkeletonBox(width: 10, height: 10, radius: 5),
      SizedBox(width: 12),
      Expanded(child: _SkeletonBox(height: 11)),
      SizedBox(width: 12),
      _SkeletonBox(width: 26, height: 11),
    ],
  );
}

class _IncidentTileSkeleton extends StatelessWidget {
  const _IncidentTileSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEAEAEA)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SkeletonBox(width: 54, height: 10, radius: 5),
            Spacer(),
            _SkeletonBox(width: 58, height: 22, radius: 20),
          ],
        ),
        SizedBox(height: 9),
        _SkeletonBox(width: 200, height: 15),
        SizedBox(height: 10),
        _SkeletonBox(width: 140, height: 11),
        SizedBox(height: 12),
        _SkeletonBox(width: 110, height: 11),
      ],
    ),
  );
}

class _MonthlyPerformanceCard extends StatelessWidget {
  const _MonthlyPerformanceCard({
    required this.completed,
    required this.total,
    required this.completionRate,

    required this.completionLabel,
    required this.onOpenReport,
  });

  final int completed;
  final int total;

  /// Kept as the raw CAP value; only the label is pre-formatted.
  final double completionRate;
  final String completionLabel;
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
                completionLabel,
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
              // Clamped because CAP sends a raw ratio that can exceed 100.
              value: (completionRate / 100).clamp(0.0, 1.0),
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

/// Loading, failure and empty feedback for the dashboard sections.
///
/// Each section reports independently so one failing endpoint still leaves the
/// other one usable.
class _DashboardFeedback extends StatelessWidget {
  const _DashboardFeedback({required this.state, required this.hasContent});

  final DashboardState state;
  final bool hasContent;

  @override
  Widget build(BuildContext context) {
    final statsFailure = state.statsFailure;
    final incidentsFailure = state.incidentsFailure;
    final loading = state.status == DashboardStatus.loading && !hasContent;

    if (statsFailure == null &&
        incidentsFailure == null &&
        !loading &&
        state.todayIncidents.isNotEmpty) {
      return const SizedBox.shrink();
    }

    final message =
        statsFailure?.message ??
        incidentsFailure?.message ??
        context.tr('Loading dashboard…', 'جارٍ تحميل اللوحة…');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.info_outline_rounded, size: 17, color: AppColors.muted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
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

                      /// Site. `GetIncidentList` rows carry no location, so the
                      /// whole row is dropped rather than rendering a bare
                      /// separator between empty values.
                      if (_siteLabel(context, incident) case final site?)
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
                                site,
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
