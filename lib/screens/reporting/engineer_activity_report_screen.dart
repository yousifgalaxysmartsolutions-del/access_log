import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/reports/data/models/engineers_activity_report_models.dart';
import '../../features/reports/data/models/incident_report_models.dart';
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
                Text(
                  '${IncidentReportFilter.date(state.active.fromDate)} — ${IncidentReportFilter.date(state.active.toDate)}',
                  style: AppTypography.meta,
                ),
                if (state.active.hasFilters)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: cubit.resetFilters,
                      icon: const Icon(Icons.filter_alt_off),
                      label: Text(
                        context.tr('Reset Filters', 'إعادة ضبط الفلاتر'),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
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
                          ? _EngineerActivityCard(
                              item: data.items[i],
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

class _EngineerActivityCard extends StatelessWidget {
  const _EngineerActivityCard({required this.item, this.onTap});
  final EngineersActivityReportItem item;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final name = item.engineerName ?? '—';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e.substring(0, 1))
        .join()
        .toUpperCase();
    final metadata = [
      item.team,
      item.jobTitle,
    ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' • ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.orange.withValues(
                          alpha: .15,
                        ),
                        child: Text(
                          initials,
                          style: AppTypography.label.copyWith(
                            color: AppColors.orangeDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: AppTypography.section),
                            if (metadata.isNotEmpty)
                              Text(
                                metadata,
                                style: AppTypography.meta.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
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
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                  const Divider(height: 24),
                  _ActivityCounters(item: item),
                ],
              ),
            ),
            if (item.locations.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final site in item.locations)
                    Chip(
                      avatar: const Icon(Icons.cell_tower, size: 16),
                      label: Text(site.name ?? site.code ?? site.id ?? '—'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RegionActivityCard extends StatelessWidget {
  const _RegionActivityCard({
    super.key,
    required this.item,
    required this.onEngineer,
  });
  final EngineersActivityReportItem item;
  final ValueChanged<int> onEngineer;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: item.city?.name ?? '—',
    icon: Icons.public,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item.city?.id != null)
          Text(
            context.tr(
              'Region ID: ${item.city!.id}',
              'معرّف الإقليم: ${item.city!.id}',
            ),
            style: AppTypography.meta.copyWith(color: AppColors.muted),
          ),
        const SizedBox(height: 12),
        _ActivityCounters(item: item),
        const Divider(height: 24),
        for (final engineer in item.engineers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.person_outline,
              color: AppColors.orangeDark,
            ),
            title: Text(engineer.name ?? '—'),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: engineer.id == null || engineer.id! <= 0
                ? null
                : () => onEngineer(engineer.id!),
          ),
      ],
    ),
  );
}

class _ActivityCounters extends StatelessWidget {
  const _ActivityCounters({required this.item});
  final EngineersActivityReportItem item;
  @override
  Widget build(BuildContext context) {
    final counters = [
      (context.tr('Assigned', 'مسند'), item.assignedCount),
      (context.tr('In Progress', 'قيد التنفيذ'), item.inProgressCount),
      (context.tr('Completed', 'مكتمل'), item.completedCount),
      (context.tr('On Hold', 'متوقف'), item.onHoldCount),
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
