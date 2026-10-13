import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/reports/data/models/incident_report_models.dart';
import '../../features/reports/presentation/bloc/engineer_locations_report_cubit.dart';
import '../../widgets/empty_state.dart';
import 'engineer_sites_report_filter_sheet.dart';
import 'reporting_screen.dart' show EngineerSitesReportVisuals;

class EngineerSitesReportScreen extends StatelessWidget {
  const EngineerSitesReportScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => services<EngineerLocationsReportCubit>()..loadInitial(),
    child: const _EngineerSitesReportView(),
  );
}

class _EngineerSitesReportView extends StatelessWidget {
  const _EngineerSitesReportView();
  Future<void> _filters(BuildContext context) async {
    final cubit = context.read<EngineerLocationsReportCubit>();
    cubit.beginFilters();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const EngineerSitesReportFilterSheet(),
      ),
    );
    if (!cubit.isClosed) cubit.cancelFilters();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<EngineerLocationsReportCubit, EngineerLocationsReportState>(
    builder: (context, state) {
      final cubit = context.read<EngineerLocationsReportCubit>();
      final data = state.data;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            context.tr('Engineer Sites Report', 'تقرير مواقع المهندس'),
          ),
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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                Text(
                  '${IncidentReportFilter.date(state.active.fromDate)} — ${IncidentReportFilter.date(state.active.toDate)}',
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                if (state.teamLoading) const LinearProgressIndicator(),
                if (state.teamFailure != null) ...[
                  Text(
                    context.tr(
                      'Unable to load team members. Your own report remains available.',
                      'تعذر تحميل أعضاء الفريق. يمكنك عرض تقريرك الشخصي.',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: cubit.refreshTeam,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      context.tr('Retry team list', 'إعادة تحميل الفريق'),
                    ),
                  ),
                ],
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
                  EngineerSitesReportVisuals.summary(context, data),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('Worked Sites', 'المواقع التي تم العمل بها'),
                    style: AppTypography.title,
                  ),
                  const SizedBox(height: 10),
                  if (data.locations.isEmpty)
                    EmptyState(
                      icon: Icons.pin_drop_outlined,
                      title: context.tr(
                        'No Site Activity',
                        'لا توجد أنشطة مواقع',
                      ),
                      description: context.tr(
                        'No site activity found for the selected engineer and dates.',
                        'لا توجد أنشطة مواقع للمهندس والفترة المحددين.',
                      ),
                    ),
                  for (final item in data.locations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: EngineerSitesReportVisuals.site(item),
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
