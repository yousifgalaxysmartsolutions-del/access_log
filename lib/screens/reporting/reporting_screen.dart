import 'dart:math' as math;

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
import '../requests/my_requests_screen.dart';

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
    this.status,
    this.priority,
  });

  final ReportRange range;
  final DateTime? from, to;
  final String? region, area, site, type;
  final CapIncidentStatus? status;
  final Priority? priority;

  bool get hasOptionalFilters =>
      region != null ||
      area != null ||
      site != null ||
      type != null ||
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
    CapIncidentStatus? status,
    Priority? priority,
    bool clearRegion = false,
    bool clearArea = false,
    bool clearSite = false,
    bool clearType = false,
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
      MaterialPageRoute(
        builder: (_) => IncidentReportScreen(
          initialFilter: status == null
              ? filter
              : filter.copyWith(status: status),
        ),
      ),
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
              builder: (_) => EngineerActivityReportScreen(filter: filter),
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

class RequestFlowReportScreen extends StatelessWidget {
  const RequestFlowReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = List<MyRequest>.of(MockData.myRequests)
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Request Flow Report', 'تقرير مسار الطلبات')),
      ),
      body: requests.isEmpty
          ? EmptyState(
              icon: Icons.account_tree_outlined,
              title: context.tr('No Requests Available', 'لا توجد طلبات'),
              description: context.tr(
                'Created requests will appear in this flow report.',
                'ستظهر الطلبات المنشأة في تقرير المسار.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                _RequestStatusSummary(requests: requests),
                const SizedBox(height: 18),
                Text(
                  context.tr('Request Lifecycles', 'مسارات الطلبات'),
                  style: AppTypography.title,
                ),
                const SizedBox(height: 10),
                ...requests.map(
                  (request) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _RequestFlowCard(request: request),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RequestStatusSummary extends StatelessWidget {
  const _RequestStatusSummary({required this.requests});
  final List<MyRequest> requests;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: MyRequestStatus.values.map((status) {
          final count = requests.where((item) => item.status == status).length;
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
                    '$count',
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
  const _RequestFlowCard({required this.request});
  final MyRequest request;

  @override
  Widget build(BuildContext context) {
    final finalColor = _requestReportStatusColor(request.status);
    final steps = [
      (
        context.tr('Created', 'تم الإنشاء'),
        Icons.add_circle_outline,
        AppColors.success,
        true,
      ),
      (
        context.tr('Submitted', 'تم الإرسال'),
        Icons.send_outlined,
        AppColors.success,
        true,
      ),
      (
        context.tr('Under Review', 'قيد المراجعة'),
        Icons.manage_search_outlined,
        request.status == MyRequestStatus.pending
            ? AppColors.warning
            : AppColors.success,
        true,
      ),
      (
        _requestReportStatusLabel(context, request.status),
        _requestReportStatusIcon(request.status),
        finalColor,
        request.status != MyRequestStatus.pending,
      ),
    ];
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RequestDetailsScreen(request: request),
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
                  Icon(Icons.account_tree_outlined, color: AppColors.orange),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.number, style: AppTypography.section),
                        Text(
                          '${request.incidentNumber} • ${request.siteName}',
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
              const Divider(height: 26),
              ...List.generate(steps.length, (index) {
                final item = steps[index];
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 30,
                        child: Column(
                          children: [
                            Icon(
                              item.$4 ? item.$2 : Icons.radio_button_unchecked,
                              color: item.$3,
                              size: 22,
                            ),
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
                          child: Text(
                            item.$1,
                            style: AppTypography.label.copyWith(color: item.$3),
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

class EngineerSitesReportScreen extends StatelessWidget {
  const EngineerSitesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sites = _engineerSiteWork();
    final incidentCount = sites.fold<int>(
      0,
      (total, item) => total + item.incidents.length,
    );
    final requestCount = sites.fold<int>(
      0,
      (total, item) => total + item.requests.length,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Engineer Sites Report', 'تقرير مواقع المهندس')),
      ),
      body: sites.isEmpty
          ? EmptyState(
              icon: Icons.pin_drop_outlined,
              title: context.tr('No Site Activity', 'لا توجد أنشطة مواقع'),
              description: context.tr(
                'Engineer site activity will appear here.',
                'ستظهر هنا أنشطة المهندس في المواقع.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                Card(
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
                                MockData.engineer.initials,
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
                                    MockData.engineer.name,
                                    style: AppTypography.section.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${MockData.teamName} • ${MockData.regionName}',
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
                              value: sites.length,
                            ),
                            _DarkCounter(
                              label: context.tr('Incidents', 'البلاغات'),
                              value: incidentCount,
                            ),
                            _DarkCounter(
                              label: context.tr('Requests', 'الطلبات'),
                              value: requestCount,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr('Worked Sites', 'المواقع التي تم العمل بها'),
                  style: AppTypography.title,
                ),
                const SizedBox(height: 10),
                ...sites.map(
                  (site) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _EngineerSiteCard(site: site),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DarkCounter extends StatelessWidget {
  const _DarkCounter({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
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
  final _EngineerSiteWork site;

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
                    Text(site.tower.name, style: AppTypography.section),
                    Text(
                      '${site.tower.code} • ${site.tower.region} / ${site.tower.area}',
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
                  value: site.incidents.length,
                ),
              ),
              Expanded(
                child: _SiteWorkMetric(
                  icon: Icons.inbox_outlined,
                  label: context.tr('Requests', 'الطلبات'),
                  value: site.requests.length,
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
                  '${context.tr('Last activity', 'آخر نشاط')}: ${_shortDate(site.lastActivity)}',
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
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: AppColors.orange),
      const SizedBox(width: 7),
      Flexible(
        child: Text('$label: $value', maxLines: 2, style: AppTypography.label),
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

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key, required this.initialFilter});

  final ReportingFilter initialFilter;

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  late ReportingFilter filter = widget.initialFilter;
  final search = TextEditingController();
  ReportSort sort = ReportSort.newest;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<CapIncident> get incidents {
    final query = search.text.trim().toLowerCase();
    final items = applyReportingFilter(MockData.capIncidents, filter)
        .where(
          (item) =>
              query.isEmpty ||
              [
                item.number,
                item.type,
                item.siteName,
                item.title,
                item.currentUser,
              ].any((value) => value.toLowerCase().contains(query)),
        )
        .toList();
    switch (sort) {
      case ReportSort.newest:
        items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      case ReportSort.oldest:
        items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      case ReportSort.priority:
        const rank = {
          Priority.critical: 0,
          Priority.high: 1,
          Priority.medium: 2,
          Priority.low: 3,
        };
        items.sort((a, b) => rank[a.priority]!.compareTo(rank[b.priority]!));
    }
    return items;
  }

  Future<void> _filters() async {
    final result = await showModalBottomSheet<ReportingFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportingFilterSheet(initial: filter),
    );
    if (result != null) setState(() => filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final items = incidents;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Incident Report', 'تقرير البلاغات')),
        actions: [
          IconButton(
            tooltip: context.tr('Filters', 'الفلاتر'),
            onPressed: _filters,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            sliver: SliverList.list(
              children: [
                _ReportHeader(
                  title: context.tr(
                    'Incident Status Overview',
                    'نظرة عامة على حالات البلاغات',
                  ),
                  range: _rangeLabel(context, filter),
                  filter: filter,
                ),
                const SizedBox(height: 16),
                _SummaryGrid(
                  incidents: items,
                  compact: true,
                  onTap: (status) => setState(
                    () => filter = status == null
                        ? filter.copyWith(clearStatus: true)
                        : filter.copyWith(status: status),
                  ),
                ),
                const SizedBox(height: 14),
                StatusDonutCard(incidents: items),
                const SizedBox(height: 14),
                PriorityBarsCard(incidents: items),
                const SizedBox(height: 18),
                TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: context.tr(
                      'Search report records',
                      'ابحث في سجلات التقرير',
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.strings.isArabic
                            ? '${items.length} سجلًا تفصيليًا'
                            : '${items.length} detailed records',
                        style: AppTypography.section,
                      ),
                    ),
                    PopupMenuButton<ReportSort>(
                      initialValue: sort,
                      tooltip: context.tr('Sort', 'ترتيب'),
                      onSelected: (value) => setState(() => sort = value),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: ReportSort.newest,
                          child: Text(context.tr('Newest', 'الأحدث')),
                        ),
                        PopupMenuItem(
                          value: ReportSort.oldest,
                          child: Text(context.tr('Oldest', 'الأقدم')),
                        ),
                        PopupMenuItem(
                          value: ReportSort.priority,
                          child: Text(context.tr('Priority', 'الأولوية')),
                        ),
                      ],
                      icon: const Icon(Icons.sort),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off,
                title: context.tr(
                  'No Reports Available',
                  'لا توجد تقارير متاحة',
                ),
                description: context.tr(
                  'No data found for the selected filters.',
                  'لم يتم العثور على بيانات للفلاتر المحددة.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => CapIncidentCard(
                  incident: items[index],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          IncidentDetailsScreen(incident: items[index]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EngineerActivityReportScreen extends StatefulWidget {
  const EngineerActivityReportScreen({super.key, required this.filter});

  final ReportingFilter filter;

  @override
  State<EngineerActivityReportScreen> createState() =>
      _EngineerActivityReportScreenState();
}

class _EngineerActivityReportScreenState
    extends State<EngineerActivityReportScreen> {
  static const allSites = '__all_sites__';
  final Map<String, String> selectedSites = {};

  @override
  Widget build(BuildContext context) {
    final incidents = applyReportingFilter(
      MockData.capIncidents,
      widget.filter,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('Engineer Activity Report', 'تقرير أنشطة المهندسين'),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        itemCount: MockData.teamMembers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 11),
        itemBuilder: (_, index) {
          final member = MockData.teamMembers[index];
          final assigned = incidents
              .where((item) => item.currentUser == member.name)
              .toList();
          final sites = <String, CapIncident>{};
          for (final incident in assigned) {
            sites.putIfAbsent(incident.siteCode, () => incident);
          }
          final selected = selectedSites[member.name] ?? allSites;
          final visible = selected == allSites
              ? assigned
              : assigned.where((item) => item.siteCode == selected).toList();
          return _EngineerReportCard(
            member: member,
            incidents: visible,
            sites: sites,
            selectedSite: selected,
            onSiteChanged: (value) =>
                setState(() => selectedSites[member.name] = value),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EngineerReportDetailsScreen(
                  member: member,
                  incidents: assigned,
                  filter: widget.filter,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
                    ),
                  ),
                ),
                _FilterDropdown<String>(
                  label: context.tr('Area', 'المنطقة'),
                  value: value.area,
                  values: _values((item) => item.area),
                  labelOf: (item) => context.mockText(item),
                  onChanged: (item) => setState(
                    () => value = value.copyWith(
                      area: item,
                      clearArea: item == null,
                    ),
                  ),
                ),
                _FilterDropdown<String>(
                  label: context.tr('Site', 'الموقع'),
                  value: value.site,
                  values: _values((item) => item.siteName),
                  labelOf: (item) => context.mockText(item),
                  onChanged: (item) => setState(
                    () => value = value.copyWith(
                      site: item,
                      clearSite: item == null,
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
  const StatusDonutCard({super.key, required this.incidents});

  final List<CapIncident> incidents;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final status in CapIncidentStatus.values)
        status: incidents.where((item) => item.status == status).length,
    };
    return SectionCard(
      title: context.tr('Incidents by Status', 'البلاغات حسب الحالة'),
      icon: Icons.donut_large,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final compact = constraints.maxWidth < 330;
          final chart = SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(132),
                  painter: _DonutPainter(counts),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${incidents.length}', style: AppTypography.title),
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
            children: CapIncidentStatus.values
                .map(
                  (status) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: capStatusColor(status),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _statusLabel(context, status),
                            style: AppTypography.meta,
                          ),
                        ),
                        Text('${counts[status]}', style: AppTypography.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
          return compact
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
  const PriorityBarsCard({super.key, required this.incidents});

  final List<CapIncident> incidents;

  @override
  Widget build(BuildContext context) {
    final maximum = math.max(1, incidents.length);
    return SectionCard(
      title: context.tr('Incidents by Priority', 'البلاغات حسب الأولوية'),
      icon: Icons.bar_chart,
      child: Column(
        children: Priority.values.map((priority) {
          final count = incidents
              .where((item) => item.priority == priority)
              .length;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    _priorityLabel(context, priority),
                    style: AppTypography.meta,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: count / maximum,
                      minHeight: 9,
                      color: priorityColor(priority),
                      backgroundColor: priorityColor(
                        priority,
                      ).withValues(alpha: .1),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 20,
                  child: Text('$count', style: AppTypography.label),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.counts);
  final Map<CapIncidentStatus, int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    if (total == 0) {
      canvas.drawArc(
        rect.deflate(12),
        0,
        math.pi * 2,
        false,
        paint..color = AppColors.border,
      );
      return;
    }
    var start = -math.pi / 2;
    for (final status in CapIncidentStatus.values) {
      final sweep = math.pi * 2 * (counts[status]! / total);
      if (sweep > 0) {
        canvas.drawArc(
          rect.deflate(12),
          start,
          sweep,
          false,
          paint..color = capStatusColor(status),
        );
        start += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.counts != counts;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.incidents,
    this.onTap,
    this.compact = false,
  });
  final List<CapIncident> incidents;
  final ValueChanged<CapIncidentStatus?>? onTap;
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
                    onTap: onTap == null ? null : () => onTap!(item.$5),
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
  final int value;
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
                  Text('$value', style: AppTypography.title),
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

class _EngineerReportCard extends StatelessWidget {
  const _EngineerReportCard({
    required this.member,
    required this.incidents,
    required this.sites,
    required this.selectedSite,
    required this.onSiteChanged,
    required this.onTap,
  });
  final TeamMember member;
  final List<CapIncident> incidents;
  final Map<String, CapIncident> sites;
  final String selectedSite;
  final ValueChanged<String> onSiteChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.orange,
                        child: Text(
                          member.initials,
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
                            Text(member.name, style: AppTypography.section),
                            Text(
                              '${MockData.teamName} • ${member.role}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.meta.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.strings.isArabic
                                  ? '${sites.length} موقع'
                                  : '${sites.length} sites',
                              style: AppTypography.meta.copyWith(
                                color: AppColors.orangeDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                  const Divider(height: 24),
                  _MiniCounters(incidents: incidents),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 18,
                color: AppColors.orange,
              ),
              const SizedBox(width: 7),
              Text(
                context.tr('Filter sites', 'تصفية المواقع'),
                style: AppTypography.label,
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: Text(context.tr('All Sites', 'كل المواقع')),
                  selected:
                      selectedSite ==
                      _EngineerActivityReportScreenState.allSites,
                  onSelected: (_) => onSiteChanged(
                    _EngineerActivityReportScreenState.allSites,
                  ),
                ),
                ...sites.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsetsDirectional.only(start: 7),
                    child: ChoiceChip(
                      label: Text(
                        context.mockText(entry.value.siteName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: selectedSite == entry.key,
                      onSelected: (_) => onSiteChanged(entry.key),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (sites.isEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.tr(
                  'No worked sites in this period',
                  'لا توجد مواقع عمل في هذه الفترة',
                ),
                style: AppTypography.meta.copyWith(color: AppColors.muted),
              ),
            ),
          ],
        ],
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

class _MiniCounters extends StatelessWidget {
  const _MiniCounters({required this.incidents});
  final List<CapIncident> incidents;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _CountLabel(
        label: context.tr('Assigned', 'مسند'),
        value: incidents.length,
      ),
      _CountLabel(
        label: context.tr('In Progress', 'قيد التنفيذ'),
        value: incidents
            .where((item) => item.status == CapIncidentStatus.inProcess)
            .length,
      ),
      _CountLabel(
        label: context.tr('Completed', 'مكتمل'),
        value: incidents
            .where((item) => item.status == CapIncidentStatus.completed)
            .length,
      ),
      _CountLabel(
        label: context.tr('On Hold', 'متوقف'),
        value: incidents
            .where((item) => item.status == CapIncidentStatus.hold)
            .length,
      ),
    ],
  );
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
    required this.filter,
  });
  final String title, range;
  final ReportingFilter filter;
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
            if (filter.region != null)
              _FilterChip(
                icon: Icons.public,
                label: context.mockText(filter.region!),
              ),
            if (filter.status != null)
              _FilterChip(
                icon: Icons.tune,
                label: _statusLabel(context, filter.status!),
              ),
            if (filter.priority != null)
              _FilterChip(
                icon: Icons.flag_outlined,
                label: _priorityLabel(context, filter.priority!),
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
        Text(label, style: AppTypography.meta),
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
