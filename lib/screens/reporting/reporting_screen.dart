import 'dart:math' as math;
import 'engineer_activity_report_screen.dart';
export 'engineer_activity_report_screen.dart' show EngineerActivityReportScreen;
import '../../features/reports/data/models/requests_path_report_models.dart';
import 'request_flow_report_screen.dart';
export 'request_flow_report_screen.dart' show RequestFlowReportScreen;
import '../requests/api_request_details_screen.dart';
import '../../features/reports/data/models/engineer_locations_report_models.dart';
import 'engineer_sites_report_screen.dart';
export 'engineer_sites_report_screen.dart' show EngineerSitesReportScreen;
import '../../features/reports/data/models/incident_report_models.dart';
import '../../features/incidents/data/mappers/incident_mapper.dart';
import 'incident_report_screen.dart';
export 'incident_report_screen.dart' show IncidentReportScreen;

import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/mock_content_localization.dart';
import '../../core/theme/app_tokens.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/app_button.dart';
import '../../widgets/cap_incident_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../incidents/incident_details_screen.dart';

enum ReportRange { today, week, month, custom }

enum ReportSort { newest, oldest, priority }

class ReportingFilter {
  const ReportingFilter({
    this.range = ReportRange.month,
    this.from,
    this.to,
    this.region,
    this.area,
    this.site,
    this.type,
    this.employee,
    this.status,
    this.priority,
  });

  final ReportRange range;
  final DateTime? from, to;
  final String? region, area, site, type, employee;
  final CapIncidentStatus? status;
  final Priority? priority;

  bool get hasOptionalFilters =>
      region != null ||
      area != null ||
      site != null ||
      type != null ||
      employee != null ||
      status != null ||
      priority != null ||
      from != null ||
      to != null;

  ReportingFilter copyWith({
    ReportRange? range,
    DateTime? from,
    DateTime? to,
    String? region,
    String? area,
    String? site,
    String? type,
    String? employee,
    CapIncidentStatus? status,
    Priority? priority,
    bool clearRegion = false,
    bool clearArea = false,
    bool clearSite = false,
    bool clearType = false,
    bool clearEmployee = false,
    bool clearStatus = false,
    bool clearPriority = false,
  }) => ReportingFilter(
    range: range ?? this.range,
    from: from ?? this.from,
    to: to ?? this.to,
    region: clearRegion ? null : region ?? this.region,
    area: clearArea ? null : area ?? this.area,
    site: clearSite ? null : site ?? this.site,
    type: clearType ? null : type ?? this.type,
    employee: clearEmployee ? null : employee ?? this.employee,
    status: clearStatus ? null : status ?? this.status,
    priority: clearPriority ? null : priority ?? this.priority,
  );
}

List<CapIncident> applyReportingFilter(
  Iterable<CapIncident> source,
  ReportingFilter filter,
) {
  final anchor = DateTime(2026, 8, 10, 23, 59, 59);
  DateTime? start;
  DateTime? end = anchor;
  switch (filter.range) {
    case ReportRange.today:
      start = DateTime(2026, 8, 10);
    case ReportRange.week:
      start = DateTime(2026, 8, 4);
    case ReportRange.month:
      start = DateTime(2026, 8, 1);
    case ReportRange.custom:
      start = filter.from;
      end = filter.to?.add(const Duration(days: 1));
  }
  return source.where((incident) {
    bool matches(String value, String? expected) =>
        expected == null || value == expected;
    return (start == null || !incident.dateTime.isBefore(start)) &&
        (end == null || incident.dateTime.isBefore(end)) &&
        matches(incident.region, filter.region) &&
        matches(incident.area, filter.area) &&
        matches(incident.siteName, filter.site) &&
        matches(incident.type, filter.type) &&
        matches(incident.currentUser, filter.employee) &&
        (filter.status == null || incident.status == filter.status) &&
        (filter.priority == null || incident.priority == filter.priority);
  }).toList();
}

class ReportingScreen extends StatefulWidget {
  const ReportingScreen({super.key});

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  ReportingFilter filter = const ReportingFilter();

  List<CapIncident> get incidents =>
      applyReportingFilter(MockData.capIncidents, filter);

  void _openIncidentReport({CapIncidentStatus? status}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IncidentReportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = incidents;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Reporting', 'التقارير'),
                    style: AppTypography.display,
                  ),
                  const SizedBox(height: 5),
                  // Text(
                  //   context.tr(
                  //     'Operational reports and activity insights',
                  //     'تقارير التشغيل ومؤشرات الأنشطة الميدانية',
                  //   ),
                  //   style: AppTypography.body.copyWith(color: AppColors.muted),
                  // ),
                ],
              ),
            ),
            // IconButton(
            //   tooltip: context.tr('Report filters', 'فلاتر التقارير'),
            //   onPressed: _openFilters,
            //   icon: Badge(
            //     isLabelVisible: filter.hasOptionalFilters,
            //     backgroundColor: AppColors.orange,
            //     smallSize: 8,
            //     child: const Icon(Icons.tune),
            //   ),
            // ),
          ],
        ),
        // const SizedBox(height: 18),
        // _RangeSelector(
        //   value: filter.range,
        //   onChanged: (value) {
        //     if (value == ReportRange.custom) {
        //       _openFilters();
        //     } else {
        //       setState(() => filter = filter.copyWith(range: value));
        //     }
        //   },
        // ),
        // const SizedBox(height: 18),
        // _SectionHeading(
        //   title: context.tr('Report Summary', 'ملخص التقارير'),
        //   subtitle: _rangeLabel(context, filter),
        // ),
        // const SizedBox(height: 11),
        // _SummaryGrid(
        //   incidents: items,
        //   onTap: (status) => _openIncidentReport(status: status),
        // ),
        // const SizedBox(height: 25),
        _SectionHeading(
          title: context.tr('Report Types', 'أنواع التقارير'),
          subtitle: context.tr(
            'Prototype views based on current mock data',
            'شاشات افتراضية مبنية على البيانات التجريبية الحالية',
          ),
        ),
        const SizedBox(height: 11),
        _ReportTypeCard(
          icon: Icons.assignment_outlined,
          title: context.tr('Incident Report', 'تقرير البلاغات'),
          description: context.tr(
            'Status distribution and detailed incident records',
            'توزيع الحالات والسجلات التفصيلية للبلاغات',
          ),
          count: items.length,
          onTap: _openIncidentReport,
        ),
        const SizedBox(height: 11),
        _ReportTypeCard(
          icon: Icons.engineering_outlined,
          title: context.tr(
            'Engineer Activity Report',
            'تقرير أنشطة المهندسين',
          ),
          description: context.tr(
            'Assignments and recent field activity by engineer',
            'المهام والأنشطة الميدانية الحديثة لكل مهندس',
          ),
          count: MockData.teamMembers.length,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EngineerActivityReportScreen(),
            ),
          ),
        ),
        const SizedBox(height: 11),
        _ReportTypeCard(
          icon: Icons.cell_tower_outlined,
          title: context.tr('Site Activity Report', 'تقرير أنشطة المواقع'),
          description: context.tr(
            'Incident volume and operational history by site',
            'حجم البلاغات والسجل التشغيلي لكل موقع',
          ),
          count: items.map((item) => item.siteCode).toSet().length,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SiteActivityReportScreen(filter: filter),
            ),
          ),
        ),
        const SizedBox(height: 11),
        _ReportTypeCard(
          icon: Icons.account_tree_outlined,
          title: context.tr('Request Flow Report', 'تقرير مسار الطلبات'),
          description: context.tr(
            'Visual request lifecycle from creation to final decision',
            'مسار مرئي للطلب من الإنشاء حتى القرار النهائي',
          ),
          count: MockData.myRequests.length,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RequestFlowReportScreen()),
          ),
        ),
        const SizedBox(height: 11),
        _ReportTypeCard(
          icon: Icons.pin_drop_outlined,
          title: context.tr('Engineer Sites Report', 'تقرير مواقع المهندس'),
          description: context.tr(
            'Sites visited and field work completed by the engineer',
            'المواقع التي عمل بها المهندس والأنشطة الميدانية',
          ),
          count: _engineerSiteWork().length,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EngineerSitesReportScreen(),
            ),
          ),
        ),
        if (items.isEmpty) ...[
          const SizedBox(height: 20),
          EmptyState(
            icon: Icons.analytics_outlined,
            title: context.tr('No Reports Available', 'لا توجد تقارير متاحة'),
            description: context.tr(
              'No data found for the selected filters.',
              'لم يتم العثور على بيانات للفلاتر المحددة.',
            ),
          ),
        ],
      ],
    );
  }
}

/// Bindings for the original request report cards and active-filter banner.
abstract final class RequestsPathReportVisuals {
  static Widget summary(RequestsPathReportSummary? summary) =>
      _RequestStatusSummary(summary: summary);
  static Widget card(RequestsPathReportItem item, {String? statusCode}) =>
      _RequestFlowCard(request: item, statusCode: statusCode);
  static Widget activeFilters({
    required int count,
    required VoidCallback onReset,
  }) => _ActiveReportFilterBanner(count: count, onReset: onReset);
}

class _ActiveReportFilterBanner extends StatelessWidget {
  const _ActiveReportFilterBanner({required this.count, required this.onReset});
  final int count;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.info.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(AppRadius.control),
      border: Border.all(color: AppColors.info.withValues(alpha: .3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.filter_alt, color: AppColors.info),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            context.strings.isArabic
                ? '$count نتيجة مطابقة للفلاتر'
                : '$count results match active filters',
            style: AppTypography.label,
          ),
        ),
        TextButton(
          onPressed: onReset,
          child: Text(context.tr('Reset', 'إعادة ضبط')),
        ),
      ],
    ),
  );
}

class _RequestStatusSummary extends StatelessWidget {
  const _RequestStatusSummary({required this.summary});
  final RequestsPathReportSummary? summary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: MyRequestStatus.values.map((status) {
          final count = switch (status) {
            MyRequestStatus.pending => summary?.pendingDecisionCount,
            MyRequestStatus.approved => summary?.approvedCount,
            MyRequestStatus.rejected => summary?.rejectedCount,
            MyRequestStatus.completed => summary?.completedCount,
          };
          final color = _requestReportStatusColor(status);
          return SizedBox(
            width: width,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: color.withValues(alpha: .24)),
              ),
              child: Row(
                children: [
                  Icon(_requestReportStatusIcon(status), color: color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _requestReportStatusLabel(context, status),
                      maxLines: 2,
                      style: AppTypography.meta.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    count?.toString() ?? '—',
                    style: AppTypography.title.copyWith(color: color),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

class _RequestFlowCard extends StatelessWidget {
  const _RequestFlowCard({required this.request, this.statusCode});
  final RequestsPathReportItem request;
  final String? statusCode;
  @override
  Widget build(BuildContext context) {
    final code = (statusCode ?? request.requestStatus?.name ?? '')
        .trim()
        .toUpperCase();
    final finalColor = switch (code) {
      'APPROVED' => AppColors.info,
      'REJECTED' => AppColors.error,
      'COMPLETED' => AppColors.success,
      'PENDING' || 'PENDING_DECISION' => AppColors.warning,
      _ => AppColors.muted,
    };
    final steps = request.steps;
    return Card(
      child: InkWell(
        onTap: request.id == null || request.id! <= 0
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ApiRequestDetailsScreen(requestId: request.id!),
                ),
              ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_tree_outlined,
                    color: AppColors.orange,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.requestCode ?? '—',
                          style: AppTypography.section,
                        ),
                        Text(
                          '${request.incidentNo ?? '—'} • ${request.locationName ?? '—'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${request.requestType?.name ?? '—'} • ${request.requestStatus?.name ?? '—'}',
                style: AppTypography.meta.copyWith(color: finalColor),
              ),
              const Divider(height: 26),
              if (steps.isEmpty)
                Text(
                  context.tr(
                    'No path steps returned.',
                    'لا توجد خطوات مسار في البيانات المستلمة.',
                  ),
                  style: AppTypography.meta,
                ),
              ...List.generate(steps.length, (index) {
                final step = steps[index];
                final state = step.state?.trim().toLowerCase();
                final primary = context.strings.isArabic
                    ? step.titleAr
                    : step.titleEn;
                final secondary = context.strings.isArabic
                    ? step.titleEn
                    : step.titleAr;
                final title = primary?.trim().isNotEmpty == true
                    ? primary!
                    : secondary?.trim().isNotEmpty == true
                    ? secondary!
                    : step.key ?? '—';
                final color = state == 'done'
                    ? step.key?.trim().toLowerCase() == 'final'
                          ? finalColor
                          : AppColors.success
                    : state == 'current'
                    ? AppColors.warning
                    : AppColors.muted;
                final icon = state == 'done'
                    ? Icons.check_circle_outline
                    : state == 'current'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 30,
                        child: Column(
                          children: [
                            Icon(icon, color: color, size: 22),
                            if (index < steps.length - 1)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: AppColors.border,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTypography.label.copyWith(
                                  color: color,
                                ),
                              ),
                              if (state == 'current')
                                Text(
                                  context.tr('Current step', 'الخطوة الحالية'),
                                  style: AppTypography.meta.copyWith(
                                    color: color,
                                  ),
                                ),
                              if (state != null &&
                                  state != 'done' &&
                                  state != 'current')
                                Text(step.state!, style: AppTypography.meta),
                              if (step.dateTime?.trim().isNotEmpty == true)
                                Text(
                                  formatCapApiDate(step.dateTime),
                                  style: AppTypography.meta.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// The existing engineer report visuals, bound to CAP values only.
abstract final class EngineerSitesReportVisuals {
  static Widget site(EngineerLocationReportItem item) =>
      _EngineerSiteCard(site: item);
  static Widget summary(
    BuildContext context,
    EngineerLocationsReportData data,
  ) {
    final name = data.engineer?.name ?? '—';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1))
        .join()
        .toUpperCase();
    final metadata = [
      data.team,
      data.jobTitle,
    ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' • ');
    return Card(
      color: AppColors.ink,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.orange,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.section.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      if (metadata.isNotEmpty)
                        Text(
                          metadata,
                          style: AppTypography.meta.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 26, color: Colors.white24),
            Row(
              children: [
                _DarkCounter(
                  label: context.tr('Sites', 'المواقع'),
                  value: data.locationsCount,
                ),
                _DarkCounter(
                  label: context.tr('Incidents', 'البلاغات'),
                  value: data.incidentsCount,
                ),
                _DarkCounter(
                  label: context.tr('Requests', 'الطلبات'),
                  value: data.requestsCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkCounter extends StatelessWidget {
  const _DarkCounter({required this.label, required this.value});
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value?.toString() ?? '—',
          style: AppTypography.title.copyWith(color: AppColors.orange),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.meta.copyWith(color: Colors.white70),
        ),
      ],
    ),
  );
}

class _EngineerSiteCard extends StatelessWidget {
  const _EngineerSiteCard({required this.site});
  final EngineerLocationReportItem site;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFF1E5),
                child: Icon(Icons.cell_tower, color: AppColors.orange),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.location?.name ?? '—',
                      style: AppTypography.section,
                    ),
                    Text(
                      '${site.location?.code ?? site.location?.id ?? '—'} • ${site.region?.name ?? '—'} / ${site.area?.name ?? '—'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 25),
          Row(
            children: [
              Expanded(
                child: _SiteWorkMetric(
                  icon: Icons.assignment_outlined,
                  label: context.tr('Incidents', 'البلاغات'),
                  value: site.incidentsCount,
                ),
              ),
              Expanded(
                child: _SiteWorkMetric(
                  icon: Icons.inbox_outlined,
                  label: context.tr('Requests', 'الطلبات'),
                  value: site.requestsCount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.history, size: 17, color: AppColors.muted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${context.tr('Last activity', 'آخر نشاط')}: ${formatCapApiDate(site.lastActivityDate)}',
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SiteWorkMetric extends StatelessWidget {
  const _SiteWorkMetric({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: AppColors.orange),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          '$label: ${value?.toString() ?? '—'}',
          maxLines: 2,
          style: AppTypography.label,
        ),
      ),
    ],
  );
}

class _EngineerSiteWork {
  _EngineerSiteWork(this.tower);
  final TowerSite tower;
  final List<CapIncident> incidents = [];
  final List<MyRequest> requests = [];

  DateTime get lastActivity {
    final dates = <DateTime>[
      ...incidents.map((item) => item.dateTime),
      ...requests.map((item) => item.createdDate),
    ]..sort();
    return dates.last;
  }
}

List<_EngineerSiteWork> _engineerSiteWork() {
  final groups = <String, _EngineerSiteWork>{};
  _EngineerSiteWork? groupFor(String code) {
    final towers = MockData.towerSites.where((item) => item.code == code);
    if (towers.isEmpty) return null;
    return groups.putIfAbsent(code, () => _EngineerSiteWork(towers.first));
  }

  for (final incident in MockData.capIncidents.where(
    (item) => item.currentUser == MockData.engineer.name,
  )) {
    groupFor(incident.siteCode)?.incidents.add(incident);
  }
  for (final request in MockData.myRequests.where(
    (item) => item.createdBy == MockData.engineer.name,
  )) {
    groupFor(request.siteCode)?.requests.add(request);
  }
  final result = groups.values.toList()
    ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  return result;
}

Color _requestReportStatusColor(MyRequestStatus status) => switch (status) {
  MyRequestStatus.pending => AppColors.warning,
  MyRequestStatus.approved => AppColors.info,
  MyRequestStatus.rejected => AppColors.error,
  MyRequestStatus.completed => AppColors.success,
};

IconData _requestReportStatusIcon(MyRequestStatus status) => switch (status) {
  MyRequestStatus.pending => Icons.hourglass_top_rounded,
  MyRequestStatus.approved => Icons.check_circle_outline,
  MyRequestStatus.rejected => Icons.cancel_outlined,
  MyRequestStatus.completed => Icons.task_alt,
};

String _requestReportStatusLabel(
  BuildContext context,
  MyRequestStatus status,
) => switch (status) {
  MyRequestStatus.pending => context.tr(
    'Decision Pending',
    'القرار قيد الانتظار',
  ),
  MyRequestStatus.approved => context.tr('Approved', 'تمت الموافقة'),
  MyRequestStatus.rejected => context.tr('Rejected', 'تم الرفض'),
  MyRequestStatus.completed => context.tr('Completed', 'مكتمل'),
};

class EngineerReportDetailsScreen extends StatefulWidget {
  const EngineerReportDetailsScreen({
    super.key,
    required this.member,
    required this.incidents,
    required this.filter,
  });

  final TeamMember member;
  final List<CapIncident> incidents;
  final ReportingFilter filter;

  @override
  State<EngineerReportDetailsScreen> createState() =>
      _EngineerReportDetailsScreenState();
}

class _EngineerReportDetailsScreenState
    extends State<EngineerReportDetailsScreen> {
  static const allSites = '__all_sites__';
  String selectedSiteCode = allSites;

  @override
  Widget build(BuildContext context) {
    final sites = <String, CapIncident>{};
    for (final incident in widget.incidents) {
      sites.putIfAbsent(incident.siteCode, () => incident);
    }
    final filtered = selectedSiteCode == allSites
        ? widget.incidents
        : widget.incidents
              .where((item) => item.siteCode == selectedSiteCode)
              .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Engineer Details', 'تفاصيل المهندس')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          _PersonHero(member: widget.member),
          const SizedBox(height: 14),
          SectionCard(
            title: context.tr('Filter by Site', 'تصفية حسب الموقع'),
            icon: Icons.filter_alt_outlined,
            child: DropdownButtonFormField<String>(
              key: ValueKey(selectedSiteCode),
              initialValue: selectedSiteCode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('Worked Site', 'موقع العمل'),
                prefixIcon: const Icon(Icons.cell_tower_outlined),
                helperText: sites.isEmpty
                    ? context.tr(
                        'No assigned sites for this period',
                        'لا توجد مواقع مسندة في هذه الفترة',
                      )
                    : context.tr(
                        '${sites.length} sites available',
                        'يتوفر ${sites.length} موقع',
                      ),
              ),
              items: [
                DropdownMenuItem(
                  value: allSites,
                  child: Text(context.tr('All Sites', 'كل المواقع')),
                ),
                ...sites.entries.map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      '${context.mockText(entry.value.siteName)} • ${entry.key}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: sites.isEmpty
                  ? null
                  : (value) =>
                        setState(() => selectedSiteCode = value ?? allSites),
            ),
          ),
          const SizedBox(height: 14),
          _ReportHeader(
            title: context.tr('Incident Counters', 'مؤشرات البلاغات'),
            range: selectedSiteCode == allSites
                ? _rangeLabel(context, widget.filter)
                : context.mockText(sites[selectedSiteCode]!.siteName),
            filter: widget.filter,
          ),
          const SizedBox(height: 12),
          _SummaryGrid(incidents: filtered, compact: true),
          const SizedBox(height: 14),
          SectionCard(
            title: context.tr('Recent Activities', 'الأنشطة الحديثة'),
            icon: Icons.timeline,
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      context.tr(
                        'No activities for the selected site.',
                        'لا توجد أنشطة للموقع المحدد.',
                      ),
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  )
                : Column(
                    children: filtered
                        .take(4)
                        .map(
                          (incident) => _ActivityRow(
                            title: context.mockText(incident.title),
                            subtitle:
                                '${incident.number} • ${context.mockText(incident.siteName)}',
                            time: _shortDate(incident.dateTime),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 14),
          _RecordsSection(incidents: filtered),
        ],
      ),
    );
  }
}

class SiteActivityReportScreen extends StatelessWidget {
  const SiteActivityReportScreen({super.key, required this.filter});

  final ReportingFilter filter;

  @override
  Widget build(BuildContext context) {
    final incidents = applyReportingFilter(MockData.capIncidents, filter);
    final groups = <String, List<CapIncident>>{};
    for (final incident in incidents) {
      groups.putIfAbsent(incident.siteCode, () => []).add(incident);
    }
    final sites = groups.values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Site Activity Report', 'تقرير أنشطة المواقع')),
      ),
      body: sites.isEmpty
          ? EmptyState(
              icon: Icons.cell_tower_outlined,
              title: context.tr('No Reports Available', 'لا توجد تقارير متاحة'),
              description: context.tr(
                'No data found for the selected filters.',
                'لم يتم العثور على بيانات للفلاتر المحددة.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              itemCount: sites.length,
              separatorBuilder: (_, _) => const SizedBox(height: 11),
              itemBuilder: (_, index) => _SiteReportCard(
                incidents: sites[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SiteReportDetailsScreen(
                      incidents: sites[index],
                      filter: filter,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class SiteReportDetailsScreen extends StatelessWidget {
  const SiteReportDetailsScreen({
    super.key,
    required this.incidents,
    required this.filter,
  });

  final List<CapIncident> incidents;
  final ReportingFilter filter;

  @override
  Widget build(BuildContext context) {
    final site = incidents.first;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Site Details', 'تفاصيل الموقع'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Card(
            color: AppColors.ink,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 27,
                    backgroundColor: AppColors.orange,
                    child: Icon(Icons.cell_tower, color: AppColors.ink),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.mockText(site.siteName),
                          style: AppTypography.title.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${site.siteCode} • ${context.mockText(site.region)} / ${context.mockText(site.area)}',
                          style: AppTypography.meta.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ReportHeader(
            title: context.tr('Incident Counters', 'مؤشرات البلاغات'),
            range: _rangeLabel(context, filter),
            filter: filter,
          ),
          const SizedBox(height: 12),
          _SummaryGrid(incidents: incidents, compact: true),
          const SizedBox(height: 14),
          SectionCard(
            title: context.tr('Activity Timeline', 'الخط الزمني للأنشطة'),
            icon: Icons.history,
            child: Column(
              children: incidents
                  .take(4)
                  .map(
                    (item) => _ActivityRow(
                      title: item.title,
                      subtitle: '${item.number} • ${item.status.label}',
                      time: _shortDate(item.dateTime),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _RecordsSection(incidents: incidents),
        ],
      ),
    );
  }
}

class ReportingFilterSheet extends StatefulWidget {
  const ReportingFilterSheet({super.key, required this.initial});

  final ReportingFilter initial;

  @override
  State<ReportingFilterSheet> createState() => _ReportingFilterSheetState();
}

class _ReportingFilterSheetState extends State<ReportingFilterSheet> {
  late ReportingFilter value = widget.initial;

  List<String> _values(String Function(CapIncident item) read) =>
      MockData.capIncidents.map(read).toSet().toList()..sort();

  List<String> get _areas =>
      MockData.capIncidents
          .where((item) => value.region == null || item.region == value.region)
          .map((item) => item.area)
          .toSet()
          .toList()
        ..sort();

  List<String> get _sites =>
      MockData.capIncidents
          .where(
            (item) =>
                (value.region == null || item.region == value.region) &&
                (value.area == null || item.area == value.area),
          )
          .map((item) => item.siteName)
          .toSet()
          .toList()
        ..sort();

  Future<void> _date(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from
          ? value.from ?? DateTime(2026, 8, 1)
          : value.to ?? DateTime(2026, 8, 10),
      firstDate: DateTime(2026),
      lastDate: DateTime(2027),
    );
    if (picked != null) {
      setState(() {
        value = value.copyWith(
          range: ReportRange.custom,
          from: from ? picked : null,
          to: from ? null : picked,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 13, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Reporting Filters', 'فلاتر التقارير'),
                    style: AppTypography.title,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Close', 'إغلاق'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
              children: [
                Text(
                  context.tr('Date range', 'النطاق الزمني'),
                  style: AppTypography.label,
                ),
                const SizedBox(height: 8),
                _RangeSelector(
                  value: value.range,
                  onChanged: (range) =>
                      setState(() => value = value.copyWith(range: range)),
                ),
                if (value.range == ReportRange.custom) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          label: context.tr('Date From', 'من تاريخ'),
                          value: value.from,
                          onTap: () => _date(true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateButton(
                          label: context.tr('Date To', 'إلى تاريخ'),
                          value: value.to,
                          onTap: () => _date(false),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                _FilterDropdown<String>(
                  label: context.tr('Region', 'الإقليم'),
                  value: value.region,
                  values: _values((item) => item.region),
                  labelOf: (item) => context.mockText(item),
                  onChanged: (item) => setState(
                    () => value = value.copyWith(
                      region: item,
                      clearRegion: item == null,
                      clearArea: true,
                      clearSite: true,
                    ),
                  ),
                ),
                _FilterDropdown<String>(
                  label: context.tr('Area', 'المنطقة'),
                  value: value.area,
                  values: _areas,
                  labelOf: (item) => context.mockText(item),
                  onChanged: (item) => setState(
                    () => value = value.copyWith(
                      area: item,
                      clearArea: item == null,
                      clearSite: true,
                    ),
                  ),
                ),
                _FilterDropdown<String>(
                  label: context.tr('Site', 'الموقع'),
                  value: value.site,
                  values: _sites,
                  labelOf: (item) => context.mockText(item),
                  onChanged: (item) => setState(
                    () => value = value.copyWith(
                      site: item,
                      clearSite: item == null,
                    ),
                  ),
                ),
                _FilterDropdown<String>(
                  label: context.tr('Employee', 'الموظف'),
                  value: value.employee,
                  values: MockData.teamMembers.map((item) => item.name).toList()
                    ..sort(),
                  labelOf: (item) => item,
                  onChanged: (item) => setState(
                    () => value = value.copyWith(
                      employee: item,
                      clearEmployee: item == null,
                    ),
                  ),
                ),
                _FilterDropdown<String>(
                  label: context.tr('Incident Type', 'نوع البلاغ'),
                  value: value.type,
                  values: _values((item) => item.type),
                  labelOf: (item) => context.mockText(item),
                  onChanged: (item) => setState(
                    () => value = value.copyWith(
                      type: item,
                      clearType: item == null,
                    ),
                  ),
                ),
                _FilterDropdown<CapIncidentStatus>(
                  label: context.tr('Status', 'الحالة'),
                  value: value.status,
                  values: CapIncidentStatus.values,
                  labelOf: (item) => _statusLabel(context, item),
                  onChanged: (item) => setState(
                    () => value = value.copyWith(
                      status: item,
                      clearStatus: item == null,
                    ),
                  ),
                ),
                _FilterDropdown<Priority>(
                  label: context.tr('Priority', 'الأولوية'),
                  value: value.priority,
                  values: Priority.values,
                  labelOf: (item) => _priorityLabel(context, item),
                  onChanged: (item) => setState(
                    () => value = value.copyWith(
                      priority: item,
                      clearPriority: item == null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.tr('Reset', 'إعادة ضبط'),
                      style: AppButtonStyle.outline,
                      onPressed: () =>
                          setState(() => value = const ReportingFilter()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: context.tr('Apply', 'تطبيق'),
                      onPressed: () => Navigator.pop(context, value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class StatusDonutCard extends StatelessWidget {
  const StatusDonutCard({
    super.key,
    this.incidents = const [],
    this.breakdown,
    this.totalCount,
  });
  final List<CapIncident> incidents;
  final List<IncidentReportBreakdown>? breakdown;
  final int? totalCount;
  @override
  Widget build(BuildContext context) {
    final entries = breakdown == null
        ? [
            for (final status in CapIncidentStatus.values)
              (
                _statusLabel(context, status),
                incidents.where((item) => item.status == status).length,
                capStatusColor(status),
              ),
          ]
        : [
            for (final item in breakdown!)
              (
                item.info?.name ?? '—',
                item.count,
                capBackendStatusColor(
                  item.info?.id,
                  IncidentMapper.mapStatus(
                    id: item.info?.id ?? -1,
                    name: item.info?.name ?? '',
                  ),
                ),
              ),
          ];
    return SectionCard(
      title: context.tr('Incidents by Status', 'البلاغات حسب الحالة'),
      icon: Icons.donut_large,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final chart = SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(132),
                  painter: _DonutPainter([
                    for (final entry in entries) (entry.$2 ?? 0, entry.$3),
                  ]),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      breakdown == null
                          ? '${incidents.length}'
                          : totalCount?.toString() ?? '—',
                      style: AppTypography.title,
                    ),
                    Text(
                      context.tr('Total', 'الإجمالي'),
                      style: AppTypography.meta,
                    ),
                  ],
                ),
              ],
            ),
          );
          final legend = Column(
            children: [
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: entry.$3),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(entry.$1, style: AppTypography.meta),
                      ),
                      Text(
                        entry.$2?.toString() ?? '—',
                        style: AppTypography.label,
                      ),
                    ],
                  ),
                ),
            ],
          );
          return constraints.maxWidth < 330
              ? Column(children: [chart, const SizedBox(height: 12), legend])
              : Row(
                  children: [
                    chart,
                    const SizedBox(width: 18),
                    Expanded(child: legend),
                  ],
                );
        },
      ),
    );
  }
}

class PriorityBarsCard extends StatelessWidget {
  const PriorityBarsCard({
    super.key,
    this.incidents = const [],
    this.breakdown,
    this.totalCount,
  });
  final List<CapIncident> incidents;
  final List<IncidentReportBreakdown>? breakdown;
  final int? totalCount;
  @override
  Widget build(BuildContext context) {
    final maximum = math.max(
      1,
      breakdown == null ? incidents.length : totalCount ?? 0,
    );
    final entries = breakdown == null
        ? [
            for (final priority in Priority.values)
              (
                _priorityLabel(context, priority),
                incidents.where((item) => item.priority == priority).length,
                priorityColor(priority),
              ),
          ]
        : [
            for (final item in breakdown!)
              (
                item.info?.name ?? '—',
                item.count,
                priorityColor(
                  IncidentMapper.mapPriority(
                    id: item.info?.id ?? -1,
                    name: item.info?.name ?? '',
                  ),
                ),
              ),
          ];
    return SectionCard(
      title: context.tr('Incidents by Priority', 'البلاغات حسب الأولوية'),
      icon: Icons.bar_chart,
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 62,
                    child: Text(entry.$1, style: AppTypography.meta),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: ((entry.$2 ?? 0) / maximum).clamp(0, 1),
                        minHeight: 9,
                        color: entry.$3,
                        backgroundColor: entry.$3.withValues(alpha: .1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 20,
                    child: Text(
                      entry.$2?.toString() ?? '—',
                      style: AppTypography.label,
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

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.entries);
  final List<(int, Color)> entries;
  @override
  void paint(Canvas canvas, Size size) {
    final total = entries.fold<int>(
      0,
      (sum, entry) => sum + math.max(0, entry.$1),
    );
    final rect = (Offset.zero & size).deflate(12);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        paint..color = AppColors.border,
      );
      return;
    }
    var start = -math.pi / 2;
    for (final entry in entries) {
      final sweep = math.pi * 2 * (math.max(0, entry.$1) / total);
      if (sweep > 0) {
        canvas.drawArc(rect, start, sweep, false, paint..color = entry.$2);
        start += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.entries != entries;
}

/// Adapters for the original report visuals, shared by the CAP report.
abstract final class IncidentReportVisuals {
  static Widget header({
    required String title,
    required String range,
    List<(IconData, String)> labels = const [],
  }) => _ReportHeader(title: title, range: range, labels: labels);
  static Widget metric({
    required String label,
    required int? value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) => _KpiCard(
    label: label,
    value: value,
    icon: icon,
    color: color,
    compact: true,
    onTap: onTap,
  );
  static Widget dateButton({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) => _DateButton(label: label, value: value, onTap: onTap);
  static Widget range({
    required ReportRange value,
    required ValueChanged<ReportRange> onChanged,
  }) => _RangeSelector(value: value, onChanged: onChanged);
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.incidents, this.compact = false});
  final List<CapIncident> incidents;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    int count(CapIncidentStatus status) =>
        incidents.where((item) => item.status == status).length;
    final values = [
      (
        context.tr('Total Incidents', 'إجمالي البلاغات'),
        incidents.length,
        Icons.assignment_outlined,
        AppColors.orange,
        null,
      ),
      (
        context.tr('Open Incidents', 'البلاغات المفتوحة'),
        incidents
            .where(
              (item) =>
                  item.status != CapIncidentStatus.completed &&
                  item.status != CapIncidentStatus.cancelled,
            )
            .length,
        Icons.inbox_outlined,
        AppColors.warning,
        null,
      ),
      (
        context.tr('In Progress', 'قيد التنفيذ'),
        count(CapIncidentStatus.inProcess),
        Icons.engineering_outlined,
        AppColors.info,
        CapIncidentStatus.inProcess,
      ),
      (
        context.tr('On Hold', 'متوقف مؤقتًا'),
        count(CapIncidentStatus.hold),
        Icons.pause_circle_outline,
        AppColors.purple,
        CapIncidentStatus.hold,
      ),
      (
        context.tr('Completed', 'مكتمل'),
        count(CapIncidentStatus.completed),
        Icons.task_alt,
        AppColors.success,
        CapIncidentStatus.completed,
      ),
      (
        context.tr('Cancelled', 'ملغى'),
        count(CapIncidentStatus.cancelled),
        Icons.cancel_outlined,
        AppColors.error,
        CapIncidentStatus.cancelled,
      ),
    ];
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: values
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _KpiCard(
                    label: item.$1,
                    value: item.$2,
                    icon: item.$3,
                    color: item.$4,
                    compact: compact,
                    onTap: null,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.compact = false,
  });
  final String label;
  final int? value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value?.toString() ?? '—', style: AppTypography.title),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.meta.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 17, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});
  final ReportRange value;
  final ValueChanged<ReportRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (ReportRange.today, context.tr('Today', 'اليوم')),
      (ReportRange.week, context.tr('This Week', 'هذا الأسبوع')),
      (ReportRange.month, context.tr('This Month', 'هذا الشهر')),
      (ReportRange.custom, context.tr('Custom', 'مخصص')),
    ];
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => SizedBox(
                  width: width,
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        option.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    selected: value == option.$1,
                    onSelected: (_) => onChanged(option.$1),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ReportTypeCard extends StatelessWidget {
  const _ReportTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.count,
    required this.onTap,
  });
  final IconData icon;
  final String title, description;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.orange, size: 25),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.section),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.meta.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  '$count',
                  style: AppTypography.title.copyWith(
                    color: AppColors.orangeDark,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _SiteReportCard extends StatelessWidget {
  const _SiteReportCard({required this.incidents, required this.onTap});
  final List<CapIncident> incidents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final site = incidents.first;
    final completed = incidents
        .where((item) => item.status == CapIncidentStatus.completed)
        .length;
    final open =
        incidents.length -
        completed -
        incidents
            .where((item) => item.status == CapIncidentStatus.cancelled)
            .length;
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
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFFF1E5),
                    child: Icon(Icons.cell_tower, color: AppColors.orange),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.mockText(site.siteName),
                          style: AppTypography.section,
                        ),
                        Text(
                          '${site.siteCode} • ${context.mockText(site.region)} / ${context.mockText(site.area)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  _CountLabel(
                    label: context.tr('Total', 'الإجمالي'),
                    value: incidents.length,
                  ),
                  _CountLabel(label: context.tr('Open', 'مفتوح'), value: open),
                  _CountLabel(
                    label: context.tr('Completed', 'مكتمل'),
                    value: completed,
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


class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text('$value', style: AppTypography.section),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.meta.copyWith(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _PersonHero extends StatelessWidget {
  const _PersonHero({required this.member});
  final TeamMember member;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.ink,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: AppColors.orange,
            child: Text(
              member.initials,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: AppTypography.title.copyWith(color: Colors.white),
                ),
                Text(
                  '${member.role} • ${MockData.teamName}',
                  style: AppTypography.meta.copyWith(color: Colors.white70),
                ),
                Text(
                  '${context.tr('Area', 'المنطقة')}: ${context.mockText(member.area)}',
                  style: AppTypography.meta.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.incidents});
  final List<CapIncident> incidents;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: context.tr('Assigned Incidents', 'البلاغات المسندة'),
    icon: Icons.assignment_outlined,
    child: incidents.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                context.tr(
                  'No data found for selected filters.',
                  'لا توجد بيانات للفلاتر المحددة.',
                ),
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.muted),
              ),
            ),
          )
        : Column(
            children: incidents
                .map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.number,
                      style: AppTypography.label.copyWith(
                        color: AppColors.orangeDark,
                      ),
                    ),
                    subtitle: Text(
                      context.mockText(item.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: context.tr('View incident', 'عرض البلاغ'),
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IncidentDetailsScreen(incident: item),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.title,
    required this.subtitle,
    required this.time,
  });
  final String title, subtitle, time;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, size: 18, color: AppColors.success),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.mockText(title), style: AppTypography.label),
              Text(
                context.mockText(subtitle),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.meta.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(time, style: AppTypography.meta.copyWith(color: AppColors.muted)),
      ],
    ),
  );
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({
    required this.title,
    required this.range,
    this.filter,
    this.labels = const [],
  });
  final String title, range;
  final ReportingFilter? filter;
  final List<(IconData, String)> labels;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.orange.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.orange.withValues(alpha: .16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.section),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _FilterChip(icon: Icons.date_range, label: range),
            for (final label in labels)
              _FilterChip(icon: label.$1, label: label.$2),
            if (filter?.region != null)
              _FilterChip(
                icon: Icons.public,
                label: context.mockText(filter!.region!),
              ),
            if (filter?.status != null)
              _FilterChip(
                icon: Icons.tune,
                label: _statusLabel(context, filter!.status!),
              ),
            if (filter?.priority != null)
              _FilterChip(
                icon: Icons.flag_outlined,
                label: _priorityLabel(context, filter!.priority!),
              ),
          ],
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.orange),
        const SizedBox(width: 5),
        Flexible(child: Text(label, style: AppTypography.meta)),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTypography.title),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: AppTypography.meta.copyWith(color: AppColors.muted),
      ),
    ],
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.calendar_today_outlined, size: 17),
    label: Text(
      value == null ? label : '${value!.day}/${value!.month}/${value!.year}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final List<T> values;
  final String Function(T item) labelOf;
  final ValueChanged<T?> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.tune, size: 20),
      ),
      items: [
        DropdownMenuItem<T>(
          value: null,
          child: Text(context.tr('All', 'الكل')),
        ),
        ...values.map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(
              labelOf(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    ),
  );
}

String _rangeLabel(BuildContext context, ReportingFilter filter) {
  if (filter.range == ReportRange.custom) {
    final from = filter.from == null ? '—' : _shortDate(filter.from!);
    final to = filter.to == null ? '—' : _shortDate(filter.to!);
    return '$from — $to';
  }
  return switch (filter.range) {
    ReportRange.today => context.tr('Today', 'اليوم'),
    ReportRange.week => context.tr('This Week', 'هذا الأسبوع'),
    ReportRange.month => context.tr('This Month', 'هذا الشهر'),
    ReportRange.custom => '',
  };
}

String _statusLabel(BuildContext context, CapIncidentStatus status) =>
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

String _priorityLabel(BuildContext context, Priority priority) =>
    switch (priority) {
      Priority.critical => context.tr('Critical', 'حرجة'),
      Priority.high => context.tr('High', 'عالية'),
      Priority.medium => context.tr('Medium', 'متوسطة'),
      Priority.low => context.tr('Low', 'منخفضة'),
    };

String _shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
