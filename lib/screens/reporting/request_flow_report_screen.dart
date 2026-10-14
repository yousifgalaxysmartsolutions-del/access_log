import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/reports/data/models/incident_report_models.dart';
import '../../features/reports/presentation/bloc/requests_path_report_cubit.dart';
import '../../widgets/empty_state.dart';
import 'request_flow_report_filter_sheet.dart';
import 'reporting_screen.dart' show RequestsPathReportVisuals;

class RequestFlowReportScreen extends StatelessWidget {
  const RequestFlowReportScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => services<RequestsPathReportCubit>()..loadInitial(),
    child: const _RequestFlowReportView(),
  );
}

class _RequestFlowReportView extends StatelessWidget {
  const _RequestFlowReportView();
  Future<void> _openFilters(BuildContext context) async {
    final cubit = context.read<RequestsPathReportCubit>();
    cubit.beginFilters();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const RequestFlowReportFilterSheet(),
      ),
    );
    if (!cubit.isClosed) cubit.cancelFilters();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<RequestsPathReportCubit, RequestsPathReportState>(
    builder: (context, state) {
      final cubit = context.read<RequestsPathReportCubit>();
      final data = state.data;
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Request Flow Report', 'تقرير مسار الطلبات')),
          actions: [
            IconButton(
              tooltip: context.tr('Request Filters', 'فلاتر الطلبات'),
              onPressed: () => _openFilters(context),
              icon: Badge(
                isLabelVisible: state.active.active,
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
                Text(
                  '${IncidentReportFilter.date(state.active.fromDate)} — ${IncidentReportFilter.date(state.active.toDate)}',
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
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
                  if (state.active.active) ...[
                    RequestsPathReportVisuals.activeFilters(
                      count: data.totalCount,
                      onReset: cubit.resetFilters,
                    ),
                    const SizedBox(height: 14),
                  ],
                  RequestsPathReportVisuals.summary(data.summary),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('Request Lifecycles', 'مسارات الطلبات'),
                    style: AppTypography.title,
                  ),
                  const SizedBox(height: 10),
                  if (data.items.isEmpty)
                    EmptyState(
                      icon: Icons.account_tree_outlined,
                      title: context.tr(
                        'No Requests Available',
                        'لا توجد طلبات',
                      ),
                      description: context.tr(
                        'No requests match the selected filters.',
                        'لا توجد طلبات تطابق الفلاتر المحددة.',
                      ),
                    ),
                  for (final item in data.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: RequestsPathReportVisuals.card(
                        item,
                        statusCode: cubit.statusCode(item.requestStatus?.id),
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
