import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/reports/data/models/incident_report_models.dart';
import '../../features/reports/presentation/bloc/engineers_activity_report_cubit.dart';
import '../../widgets/app_button.dart';
import 'reporting_screen.dart' show IncidentReportVisuals, ReportRange;

class EngineerActivityReportFilterSheet extends StatelessWidget {
  const EngineerActivityReportFilterSheet({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<EngineersActivityReportCubit, EngineersActivityReportState>(
    builder: (context, state) {
      final cubit = context.read<EngineersActivityReportCubit>();
      final filter = state.draft;
      if (filter == null) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(heightFactor: 1, child: CircularProgressIndicator()),
          ),
        );
      }
      Future<void> pickDate(bool from) async {
        final value = await showDatePicker(
          context: context,
          initialDate: from ? filter.fromDate : filter.toDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (value != null && !cubit.isClosed && cubit.state.draft != null) {
          cubit.updateDraft(
            cubit.state.draft!.copyWith(
              range: IncidentReportDateRange.custom,
              fromDate: from ? value : null,
              toDate: from ? null : value,
            ),
          );
        }
      }

      return Container(
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
                        context.tr('Report Filters', 'فلاتر التقرير'),
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
                    IncidentReportVisuals.range(
                      value: ReportRange.values[filter.range.index],
                      onChanged: (range) => cubit.setDraftRange(
                        IncidentReportDateRange.values[range.index],
                      ),
                    ),
                    if (filter.range == IncidentReportDateRange.custom) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: IncidentReportVisuals.dateButton(
                              label: context.tr('Date From', 'من تاريخ'),
                              value: filter.fromDate,
                              onTap: () => pickDate(true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: IncidentReportVisuals.dateButton(
                              label: context.tr('Date To', 'إلى تاريخ'),
                              value: filter.toDate,
                              onTap: () => pickDate(false),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (state.filterError)
                      Text(
                        context.tr(
                          'Start date must not be after end date.',
                          'تاريخ البداية يجب ألا يتجاوز تاريخ النهاية.',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 18),
                    if (state.optionsLoading) const LinearProgressIndicator(),
                    if (state.optionsFailure != null) ...[
                      Text(
                        context.tr(
                          'Unable to load filter options.',
                          'تعذر تحميل خيارات الفلترة.',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: cubit.loadOptions,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.tr('Retry', 'إعادة المحاولة')),
                      ),
                    ],
                    _select<int>(
                      context,
                      'Engineer',
                      'المهندس',
                      filter.engineerUserId,
                      cubit.engineers,
                      -1,
                      (id) => cubit.updateDraft(
                        filter.copyWith(engineerUserId: id),
                      ),
                    ),
                    _select<int>(
                      context,
                      'Region',
                      'الإقليم',
                      filter.regionId,
                      {for (final e in cubit.regions) e.id!: e.name ?? '—'},
                      -1,
                      (id) => cubit.updateDraft(filter.copyWith(regionId: id)),
                    ),
                    _select<int>(
                      context,
                      'Area',
                      'المنطقة',
                      filter.areaId,
                      {for (final e in cubit.areas) e.id!: e.name ?? '—'},
                      -1,
                      (id) => cubit.updateDraft(filter.copyWith(areaId: id)),
                    ),
                    _select<String>(
                      context,
                      'Site',
                      'الموقع',
                      filter.locationCode,
                      {
                        for (final e in cubit.sites)
                          e.id!: '${e.name ?? '—'} (${e.id})',
                      },
                      '',
                      (id) =>
                          cubit.updateDraft(filter.copyWith(locationCode: id)),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    10,
                    18,
                    12 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: context.tr('Reset', 'إعادة ضبط'),
                          style: AppButtonStyle.outline,
                          onPressed: cubit.resetDraft,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: context.tr('Apply Filters', 'تطبيق الفلاتر'),
                          onPressed: () async {
                            if (await cubit.applyFilters() && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
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
    },
  );
  Widget _select<T>(
    BuildContext context,
    String en,
    String ar,
    T value,
    Map<T, String> options,
    T all,
    ValueChanged<T> onChanged,
  ) {
    final choices = <T, String>{all: context.tr('All', 'الكل'), ...options};
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        key: ValueKey('$en-$value-${choices.keys.join(',')}'),
        initialValue: choices.containsKey(value) ? value : all,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.tr(en, ar),
          prefixIcon: const Icon(Icons.tune, size: 20),
        ),
        items: choices.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(
                  e.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: options.isEmpty
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      ),
    );
  }
}
