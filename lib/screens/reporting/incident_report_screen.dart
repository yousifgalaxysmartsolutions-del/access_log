import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/reports/data/models/incident_report_models.dart';
import '../../features/reports/presentation/bloc/incident_report_cubit.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/cap_incident_card.dart';
import '../../widgets/section_card.dart';
import '../incidents/incident_details_screen.dart';
import 'incident_report_filter_sheet.dart';
import 'reporting_screen.dart'
    show IncidentReportVisuals, StatusDonutCard, PriorityBarsCard;

class IncidentReportScreen extends StatelessWidget {
  const IncidentReportScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => services<IncidentReportCubit>()..loadInitial(),
    child: const _IncidentReportView(),
  );
}

class _IncidentReportView extends StatefulWidget {
  const _IncidentReportView();
  @override
  State<_IncidentReportView> createState() => _IncidentReportViewState();
}

class _IncidentReportViewState extends State<_IncidentReportView> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _filters(BuildContext context) async {
    final cubit = context.read<IncidentReportCubit>();
    cubit.beginFilters();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const IncidentReportFilterSheet(),
      ),
    );
    if (!cubit.isClosed) cubit.cancelFilters();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<IncidentReportCubit, IncidentReportState>(
    listener: (context, state) {
      if (search.text != state.active.searchKeyword) {
        search.value = TextEditingValue(
          text: state.active.searchKeyword,
          selection: TextSelection.collapsed(
            offset: state.active.searchKeyword.length,
          ),
        );
      }
    },
    builder: (context, state) {
      final cubit = context.read<IncidentReportCubit>();
      final data = state.data;
      final items = cubit.incidents;
      final lookup = state.lookup;
      final labels = <(IconData, String)>[];
      for (final region in cubit.regions) {
        if (region.id == state.active.regionId) {
          labels.add((Icons.public, region.name ?? '—'));
        }
      }
      for (final status in lookup?.status ?? []) {
        if (status.id == state.active.statusId) {
          labels.add((Icons.tune, status.name ?? '—'));
        }
      }
      for (final priority in lookup?.priority ?? []) {
        if (priority.id == state.active.priorityId) {
          labels.add((Icons.flag_outlined, priority.name ?? '—'));
        }
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Incident Report', 'تقرير البلاغات')),
          actions: [
            IconButton(
              tooltip: context.tr('Filters', 'الفلاتر'),
              onPressed: () => _filters(context),
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  sliver: SliverList.list(
                    children: [
                      IncidentReportVisuals.header(
                        title: context.tr(
                          'Incident Status Overview',
                          'نظرة عامة على حالات البلاغات',
                        ),
                        range:
                            '${IncidentReportFilter.date(state.active.fromDate)} — ${IncidentReportFilter.date(state.active.toDate)}',
                        labels: labels,
                      ),
                      const SizedBox(height: 16),
                      if (state.loading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (state.failure != null)
                        SectionCard(
                          title: context.tr(
                            'Unable to load report',
                            'تعذر تحميل التقرير',
                          ),
                          icon: Icons.error_outline,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(state.failure!.message),
                              TextButton.icon(
                                onPressed: cubit.refresh,
                                icon: const Icon(Icons.refresh),
                                label: Text(
                                  context.tr('Retry', 'إعادة المحاولة'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (data != null &&
                          !state.loading &&
                          state.failure == null) ...[
                        _Summary(
                          summary: data.summary,
                          onStatus: cubit.filterStatus,
                          statusIdForCode: cubit.statusIdForCode,
                        ),
                        const SizedBox(height: 14),
                        StatusDonutCard(
                          breakdown: data.statusBreakdown,
                          totalCount:
                              data.summary?.totalCount ?? data.totalCount,
                        ),
                        const SizedBox(height: 14),
                        PriorityBarsCard(
                          breakdown: data.priorityBreakdown,
                          totalCount: data.totalCount,
                        ),
                        const SizedBox(height: 18),
                      ],
                      TextFormField(
                        controller: search,
                        textInputAction: TextInputAction.search,
                        onChanged: cubit.updateSearch,
                        onFieldSubmitted: cubit.search,
                        decoration: InputDecoration(
                          hintText: context.tr(
                            'Search report records',
                            'ابحث في سجلات التقرير',
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: state.active.searchKeyword.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: context.tr(
                                    'Clear search',
                                    'مسح البحث',
                                  ),
                                  onPressed: () => cubit.search(''),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (data != null &&
                          !state.loading &&
                          state.failure == null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.tr(
                                  '${data.totalCount} detailed records',
                                  '${data.totalCount} سجلًا تفصيليًا',
                                ),
                                style: AppTypography.section,
                              ),
                            ),
                            PopupMenuButton<IncidentReportSort>(
                              initialValue: state.sort,
                              tooltip: context.tr(
                                'Sort current page',
                                'ترتيب الصفحة الحالية',
                              ),
                              onSelected: cubit.changeSort,
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: IncidentReportSort.newest,
                                  child: Text(context.tr('Newest', 'الأحدث')),
                                ),
                                PopupMenuItem(
                                  value: IncidentReportSort.oldest,
                                  child: Text(context.tr('Oldest', 'الأقدم')),
                                ),
                                PopupMenuItem(
                                  value: IncidentReportSort.priority,
                                  child: Text(
                                    context.tr('Priority', 'الأولوية'),
                                  ),
                                ),
                              ],
                              icon: const Icon(Icons.sort),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (data != null && !state.loading && state.failure == null)
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
                          onTap: items[index].incidentId <= 0
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => IncidentDetailsScreen(
                                      incident: items[index],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                if (data != null && !state.loading && state.failure == null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: state.canPrevious
                                ? () => cubit.loadPage(data.page - 1)
                                : null,
                            child: Text(context.tr('Previous', 'السابق')),
                          ),
                          Text(
                            context.tr(
                              'Page ${data.page}',
                              'صفحة ${data.page}',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: state.canNext
                                ? () => cubit.loadPage(data.page + 1)
                                : null,
                            child: Text(context.tr('Next', 'التالي')),
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
    },
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.summary,
    required this.onStatus,
    required this.statusIdForCode,
  });
  final IncidentReportSummary? summary;
  final ValueChanged<int> onStatus;
  final int? Function(String code) statusIdForCode;
  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        context.tr('Total Incidents', 'إجمالي البلاغات'),
        summary?.totalCount,
        Icons.assignment_outlined,
        AppColors.orange,
        -1,
      ),
      (
        context.tr('Open Incidents', 'البلاغات المفتوحة'),
        summary?.openCount,
        Icons.inbox_outlined,
        AppColors.warning,
        null,
      ),
      (
        context.tr('In Progress', 'قيد التنفيذ'),
        summary?.inProgressCount,
        Icons.engineering_outlined,
        AppColors.info,
        statusIdForCode('IN_PROCESS'),
      ),
      (
        context.tr('On Hold', 'متوقف مؤقتًا'),
        summary?.onHoldCount,
        Icons.pause_circle_outline,
        AppColors.purple,
        statusIdForCode('HOLD'),
      ),
      (
        context.tr('Completed', 'مكتمل'),
        summary?.completedCount,
        Icons.task_alt,
        AppColors.success,
        statusIdForCode('COMPLETED'),
      ),
      (
        context.tr('Cancelled', 'ملغى'),
        summary?.cancelledCount,
        Icons.cancel_outlined,
        AppColors.error,
        statusIdForCode('CANCELLED'),
      ),
    ];
    return LayoutBuilder(
      builder: (_, constraints) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: (constraints.maxWidth - 10) / 2,
              child: IncidentReportVisuals.metric(
                label: metric.$1,
                value: metric.$2,
                icon: metric.$3,
                color: metric.$4,
                onTap: metric.$5 == null ? null : () => onStatus(metric.$5!),
              ),
            ),
        ],
      ),
    );
  }
}
