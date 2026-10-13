import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/reports/presentation/bloc/engineer_locations_report_cubit.dart';
import '../../widgets/app_button.dart';
import 'reporting_screen.dart' show IncidentReportVisuals;

class EngineerSitesReportFilterSheet extends StatelessWidget {
  const EngineerSitesReportFilterSheet({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<EngineerLocationsReportCubit, EngineerLocationsReportState>(
    builder: (context, state) {
      final cubit = context.read<EngineerLocationsReportCubit>();
      final draft = state.draft;
      if (draft == null) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(heightFactor: 1, child: CircularProgressIndicator()),
          ),
        );
      }
      Future<void> pick(bool from) async {
        final value = await showDatePicker(
          context: context,
          initialDate: from ? draft.fromDate : draft.toDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (value != null && !cubit.isClosed) {
          cubit.updateDraft(
            fromDate: from ? value : null,
            toDate: from ? null : value,
          );
        }
      }

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                const SizedBox(height: 12),
                Text(
                  context.tr('Date From', 'من تاريخ'),
                  style: AppTypography.label,
                ),
                IncidentReportVisuals.dateButton(
                  label: context.tr('Date From', 'من تاريخ'),
                  value: draft.fromDate,
                  onTap: () => pick(true),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('Date To', 'إلى تاريخ'),
                  style: AppTypography.label,
                ),
                IncidentReportVisuals.dateButton(
                  label: context.tr('Date To', 'إلى تاريخ'),
                  value: draft.toDate,
                  onTap: () => pick(false),
                ),
                const SizedBox(height: 16),
                if (state.teamLoading) const LinearProgressIndicator(),
                if (state.teamFailure != null)
                  TextButton.icon(
                    onPressed: cubit.refreshTeam,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      context.tr('Retry team list', 'إعادة تحميل الفريق'),
                    ),
                  ),
                if (cubit.hasOtherEngineers)
                  DropdownButtonFormField<int>(
                    key: ValueKey('engineer-${draft.engineerUserId}'),
                    initialValue: draft.engineerUserId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Engineer', 'المهندس'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    items: cubit.engineers.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id != null) cubit.updateDraft(engineerUserId: id);
                    },
                  ),
                if (state.filterError)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      context.tr(
                        'Check the selected engineer and date range. Start date must not be after end date.',
                        'تحقق من المهندس والفترة المحددين. تاريخ البداية يجب ألا يتجاوز تاريخ النهاية.',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
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
                        icon: Icons.check,
                        onPressed: () async {
                          if (await cubit.applyFilters() && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
