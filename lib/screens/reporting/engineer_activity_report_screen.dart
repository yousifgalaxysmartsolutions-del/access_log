import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/reports/data/models/engineers_activity_report_models.dart';
import '../../features/reports/presentation/bloc/engineers_activity_report_cubit.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import 'engineer_activity_report_filter_sheet.dart';
import 'engineer_sites_report_screen.dart';


class EngineerActivityReportScreen extends StatelessWidget {
  const EngineerActivityReportScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => services<EngineersActivityReportCubit>()..loadInitial(),
    child: const _ActivityReportView(),
  );
}

class _ActivityReportView extends StatelessWidget {
  const _ActivityReportView();
  Future<void> _filters(BuildContext context) async {
    final cubit = context.read<EngineersActivityReportCubit>();
    cubit.beginFilters();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const EngineerActivityReportFilterSheet(),
      ),
    );
    if (!cubit.isClosed) cubit.cancelFilters();
  }

  void _engineer(BuildContext context, int id) {
    if (id <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EngineerSitesReportScreen(
          initialFilter: context
              .read<EngineersActivityReportCubit>()
              .detailsFilter(id),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<EngineersActivityReportCubit, EngineersActivityReportState>(
    builder: (context, state) {
      final cubit = context.read<EngineersActivityReportCubit>();
      final data = state.data;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            context.tr('Engineer Activity Report', 'تقرير أنشطة المهندسين'),
          ),
          actions: [
            IconButton(
              tooltip: context.tr('Report Filters', 'فلاتر التقرير'),
              onPressed: () => _filters(context),
              icon: Badge(
                isLabelVisible: state.active.hasFilters,
                backgroundColor: AppColors.orange,
                smallSize: 9,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                SectionCard(
                  title: context.tr(
                    'Group Engineer Reports',
                    'تجميع تقارير المهندسين',
                  ),
                  icon: Icons.account_tree_outlined,
                  child: DropdownButtonFormField<EngineersActivityGroup>(
                    key: ValueKey(state.active.groupBy),
                    initialValue: state.active.groupBy,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Group by', 'تجميع حسب'),
                      prefixIcon: const Icon(Icons.layers_outlined),
                      helperText: context.tr(
                        'Groups update automatically when employees or locations are added.',
                        'تتحدث المجموعات تلقائيًا عند إضافة موظفين أو مواقع.',
                      ),
                    ),
                    items: EngineersActivityGroup.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e == EngineersActivityGroup.engineer
                                  ? context.tr('Engineer', 'المهندس')
                                  : context.tr('Region', 'الإقليم'),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (e) {
                      if (e != null) cubit.changeGroup(e);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (state.active.hasFilters)
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: .3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, color: AppColors.info),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            context.tr(
                              '${data?.totalCount ?? '—'} groups match active filters',
                              '${data?.totalCount ?? '—'} مجموعات مطابقة للفلاتر النشطة',
                            ),
                            style: AppTypography.label,
                          ),
                        ),
                        TextButton(
                          onPressed: cubit.resetFilters,
                          child: Text(context.tr('Reset', 'إعادة ضبط')),
                        ),
                      ],
                    ),
                  ),
                if (state.active.hasFilters) const SizedBox(height: 14),
                if (state.loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (state.failure != null)
                  Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      Text(state.failure!.message, textAlign: TextAlign.center),
                      TextButton.icon(
                        onPressed: cubit.refresh,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.tr('Retry', 'إعادة المحاولة')),
                      ),
                    ],
                  ),
                if (data != null &&
                    !state.loading &&
                    state.failure == null) ...[
                  if (data.items.isEmpty)
                    EmptyState(
                      icon: Icons.location_off_outlined,
                      title: context.tr('No groups found', 'لا توجد مجموعات'),
                      description: context.tr(
                        'No engineer activity matches the selected period.',
                        'لا توجد أنشطة مهندسين تطابق الفترة المحددة.',
                      ),
                    ),
                  for (var i = 0; i < data.items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: data.groupBy == EngineersActivityGroup.engineer
                          ? _EngineerReportCard(
                              item: data.items[i],
                              selection: cubit.siteSelection(
                                data.items[i].engineerId,
                              ),
                              showSiteFilter: state.active.locationCode.isEmpty,
                              onSiteChanged:
                                  data.items[i].engineerId == null ||
                                      data.items[i].engineerId! <= 0
                                  ? null
                                  : (code) => cubit.selectEngineerSite(
                                      data.items[i].engineerId!,
                                      code,
                                    ),
                              onTap:
                                  data.items[i].engineerId == null ||
                                      data.items[i].engineerId! <= 0
                                  ? null
                                  : () => _engineer(
                                      context,
                                      data.items[i].engineerId!,
                                    ),
                            )
                          : _RegionActivityCard(
                              key: ValueKey(
                                'region-${data.items[i].city?.id}-$i',
                              ),
                              item: data.items[i],
                              onEngineer: (id) => _engineer(context, id),
                            ),
                    ),
                  Wrap(
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
                        context.tr('Page ${data.page}', 'صفحة ${data.page}'),
                      ),
                      OutlinedButton(
                        onPressed: state.canNext
                            ? () => cubit.loadPage(data.page + 1)
                            : null,
                        child: Text(context.tr('Next', 'التالي')),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _EngineerReportCard extends StatelessWidget {
  const _EngineerReportCard({
    required this.item,
    required this.selection,
    required this.showSiteFilter,
    required this.onSiteChanged,
    this.onTap,
  });
  final EngineersActivityReportItem item;
  final ActivitySiteSelection selection;
  final bool showSiteFilter;
  final ValueChanged<String>? onSiteChanged;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final name = item.engineerName ?? '—';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1))
        .join()
        .toUpperCase();
    final metadata = [
      item.team,
      item.jobTitle,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • ');
    return Card(
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
                              Text(name, style: AppTypography.section),
                              Text(
                                metadata.isEmpty ? '—' : metadata,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.meta.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                context.tr(
                                  '${item.locations.length} sites',
                                  '${item.locations.length} موقع',
                                ),
                                style: AppTypography.meta.copyWith(
                                  color: AppColors.orangeDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onTap != null)
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.muted,
                          ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (selection.loading)
                      const LinearProgressIndicator()
                    else
                      _ActivityCounters(
                        item: selection.code.isEmpty ? item : selection.data,
                      ),
                  ],
                ),
              ),
            ),
            if (selection.failure != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    Text(
                      selection.failure!.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: onSiteChanged == null
                          ? null
                          : () => onSiteChanged!(selection.code),
                      child: Text(context.tr('Retry', 'إعادة المحاولة')),
                    ),
                  ],
                ),
              ),
            if (showSiteFilter) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.filter_alt_outlined,
                    size: 18,
                    color: AppColors.orange,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      context.tr('Filter sites', 'تصفية المواقع'),
                      style: AppTypography.label,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(14) + 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: Text(context.tr('All Sites', 'كل المواقع')),
                      selected: selection.code.isEmpty,
                      onSelected: onSiteChanged == null
                          ? null
                          : (_) => onSiteChanged!(''),
                    ),
                    for (final site in item.locations)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 7),
                        child: ChoiceChip(
                          label: Text(
                            site.name ?? site.code ?? site.id ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected:
                              selection.code == (site.code ?? site.id) &&
                              selection.code.isNotEmpty,
                          onSelected:
                              onSiteChanged == null ||
                                  (site.code ?? site.id)?.isNotEmpty != true
                              ? null
                              : (_) => onSiteChanged!(site.code ?? site.id!),
                        ),
                      ),
                  ],
                ),
              ),
              if (item.locations.isEmpty) ...[
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
          ],
        ),
      ),
    );
  }
}

class _RegionActivityCard extends StatefulWidget {
  const _RegionActivityCard({
    super.key,
    required this.item,
    required this.onEngineer,
  });
  final EngineersActivityReportItem item;
  final ValueChanged<int> onEngineer;
  @override
  State<_RegionActivityCard> createState() => _RegionActivityCardState();
}

class _RegionActivityCardState extends State<_RegionActivityCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.item.city?.id != null) {
        context.read<EngineersActivityReportCubit>().loadRegion(
          widget.item.city!.id!,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EngineersActivityReportCubit>();
    final state = context.watch<EngineersActivityReportCubit>().state;
    final details = state.regionDetails[widget.item.city?.id];
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        onExpansionChanged: (expanded) {
          if (expanded && widget.item.city?.id != null) {
            cubit.loadRegion(widget.item.city!.id!);
          }
        },
        leading: const CircleAvatar(
          backgroundColor: AppColors.orange,
          child: Icon(Icons.location_on, color: AppColors.ink),
        ),
        title: Text(
          widget.item.city?.name ?? '—',
          style: AppTypography.section,
        ),
        subtitle: Text(
          context.tr(
            '${widget.item.engineers.length} engineers • ${widget.item.assignedCount ?? '—'} incidents',
            '${widget.item.engineers.length} مهندس • ${widget.item.assignedCount ?? '—'} بلاغ',
          ),
        ),
        children: [
          if (details == null || details.loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (details?.failure != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(details!.failure!.message),
                  TextButton(
                    onPressed: () =>
                        cubit.loadRegion(widget.item.city!.id!, retry: true),
                    child: Text(context.tr('Retry', 'إعادة المحاولة')),
                  ),
                ],
              ),
            ),
          if (details != null &&
              !details.loading &&
              details.failure == null) ...[
            if (details.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  context.tr(
                    'No engineer activity in this region.',
                    'لا توجد أنشطة مهندسين لهذا الإقليم.',
                  ),
                ),
              ),
            for (final engineer in details.items)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: _EngineerReportCard(
                  item: engineer,
                  selection: cubit.siteSelection(
                    engineer.engineerId,
                    regionId: widget.item.city?.id,
                  ),
                  showSiteFilter: state.active.locationCode.isEmpty,
                  onSiteChanged:
                      engineer.engineerId == null || engineer.engineerId! <= 0
                      ? null
                      : (code) => cubit.selectEngineerSite(
                          engineer.engineerId!,
                          code,
                          regionId: widget.item.city?.id,
                        ),
                  onTap:
                      engineer.engineerId == null || engineer.engineerId! <= 0
                      ? null
                      : () => widget.onEngineer(engineer.engineerId!),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivityCounters extends StatelessWidget {
  const _ActivityCounters({required this.item});
  final EngineersActivityReportItem? item;
  @override
  Widget build(BuildContext context) {
    final counters = [
      (context.tr('Assigned', 'مسند'), item?.assignedCount),
      (context.tr('In Progress', 'قيد التنفيذ'), item?.inProgressCount),
      (context.tr('Completed', 'مكتمل'), item?.completedCount),
      (context.tr('On Hold', 'متوقف'), item?.onHoldCount),
    ];
    Widget value((String, int?) counter) => Column(
      children: [
        Text(counter.$2?.toString() ?? '—', style: AppTypography.section),
        const SizedBox(height: 2),
        Text(
          counter.$1,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.meta.copyWith(color: AppColors.muted),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (_, constraints) =>
          constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 18
          ? Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final counter in counters)
                  SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: value(counter),
                  ),
              ],
            )
          : Row(
              children: [
                for (final counter in counters) Expanded(child: value(counter)),
              ],
            ),
    );
  }
}
