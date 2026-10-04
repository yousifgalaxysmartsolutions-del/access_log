import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/requests/data/models/request_models.dart';
import '../../features/requests/presentation/bloc/request_list_bloc.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_row.dart';
import '../../widgets/section_card.dart';
import '../incidents/incident_details_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});
  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  RequestListBloc? bloc;
  @override
  void initState() {
    super.initState();
    if (services.isRegistered<RequestListBloc>()) {
      bloc = services<RequestListBloc>()
        ..add(const LoadRequestLookup())
        ..add(const LoadRequests());
    }
  }

  @override
  void dispose() {
    bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => bloc == null
      ? Center(
          child: Text(
            context.tr(
              'Requests unavailable. Please restart the app.',
              'الطلبات غير متاحة. يرجى إعادة تشغيل التطبيق.',
            ),
          ),
        )
      : BlocProvider.value(value: bloc!, child: const _RequestReadView());
}

bool _activeFilters(RequestListState state) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return state.fromDate != today ||
      state.toDate != today ||
      state.requestTypeId != -1 ||
      state.requestStatusId != -1 ||
      state.locationCode.isNotEmpty ||
      state.incidentNo.isNotEmpty;
}

String _value(String? value) =>
    value == null || value.trim().isEmpty ? '-' : value;

class _RequestReadView extends StatefulWidget {
  const _RequestReadView();
  @override
  State<_RequestReadView> createState() => _RequestReadViewState();
}

class _RequestReadViewState extends State<_RequestReadView> {
  final search = TextEditingController();
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    scroll.addListener(_nearBottom);
  }

  void _nearBottom() {
    if (!scroll.hasClients || scroll.position.extentAfter > 240) return;
    final bloc = context.read<RequestListBloc>();
    final state = bloc.state;
    if (state.hasMore &&
        !state.loading &&
        !state.refreshing &&
        !state.loadingMore &&
        state.loadMoreFailure == null) {
      bloc.add(const LoadMoreRequests());
    }
  }

  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _apply(RequestListState state, {int? type, int? status}) =>
      context.read<RequestListBloc>().add(
        ApplyRequestFilters(
          fromDate: state.fromDate,
          toDate: state.toDate,
          requestTypeId: type ?? state.requestTypeId,
          requestStatusId: status ?? state.requestStatusId,
          locationCode: state.locationCode,
          incidentNo: state.incidentNo,
        ),
      );
  Future<void> _filters() async {
    final bloc = context.read<RequestListBloc>();
    final event = await showModalBottomSheet<ApplyRequestFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RequestFilterSheet(initial: bloc.state),
      ),
    );
    if (event != null && mounted) bloc.add(event);
  }

  Future<void> _refresh() async {
    final bloc = context.read<RequestListBloc>();
    final done = bloc.stream
        .skipWhile((state) => !state.refreshing)
        .firstWhere((state) => !state.refreshing && !state.loading);
    bloc.add(const RefreshRequests());
    await done;
  }

  Future<void> _decision(
    RequestListItemDto item,
    RequestActionKind kind,
  ) async {
    final bloc = context.read<RequestListBloc>();
    if (bloc.state.actingRequestId != null ||
        !canDecideRequest(item, bloc.state.lookupData)) {
      return;
    }
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _RequestDecisionDialog(kind: kind),
    );
    if (text == null || !mounted) return;
    if (kind == RequestActionKind.approve) {
      bloc.add(ApproveRequest(requestId: item.id!, remark: text));
    } else {
      bloc.add(RejectRequest(requestId: item.id!, reason: text));
    }
  }

  Widget _retry(
    String message,
    String label,
    VoidCallback action, {
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      children: [
        Text(message),
        TextButton.icon(
          key: key,
          onPressed: action,
          icon: const Icon(Icons.refresh),
          label: Text(label),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: BlocConsumer<RequestListBloc, RequestListState>(
      listenWhen: (previous, current) =>
          previous.actionRevision != current.actionRevision,
      listener: (context, state) {
        final message = state.actionFailure != null
            ? context.tr(
                'Unable to complete the request decision. Please try again.',
                'تعذر تنفيذ القرار على الطلب. يرجى المحاولة مجددًا.',
              )
            : state.lastDecision?.requestStatus?.name?.toLowerCase() ==
                  'approved'
            ? context.tr(
                'Request approved successfully',
                'تمت الموافقة على الطلب بنجاح',
              )
            : state.lastDecision?.requestStatus?.name?.toLowerCase() ==
                  'rejected'
            ? context.tr('Request rejected successfully', 'تم رفض الطلب بنجاح')
            : context.tr(
                'Decision submitted. Updating requests.',
                'تم إرسال القرار. جارٍ تحديث الطلبات.',
              );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        // CAP search is not supported: search only the pages already loaded.
        final query = search.text.trim().toLowerCase();
        final items = state.items
            .where(
              (item) =>
                  query.isEmpty ||
                  [
                    item.id?.toString(),
                    item.incidentNo,
                    item.locationCode,
                    item.locationName,
                    item.requestType?.name,
                    item.requestStatus?.name,
                    item.createdBy?.name,
                    item.remark,
                  ].any(
                    (value) => value?.toLowerCase().contains(query) ?? false,
                  ),
            )
            .toList();
        final bloc = context.read<RequestListBloc>();
        final lookupReady = state.lookupData != null && !state.lookupLoading;
        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.orange,
          child: CustomScrollView(
            controller: scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                sliver: SliverList.list(
                  children: [
                    Text(
                      context.tr('My Requests', 'طلباتي'),
                      style: AppTypography.display,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Track requests created from your field incidents.',
                        'تابع الطلبات التي أنشأتها من البلاغات الميدانية.',
                      ),
                      style: AppTypography.body.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: context.tr(
                                'Search request, incident, or site',
                                'ابحث بالطلب أو البلاغ أو الموقع',
                              ),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: context.tr(
                                        'Clear search',
                                        'مسح البحث',
                                      ),
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        search.clear();
                                        setState(() {});
                                      },
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: IconButton.filledTonal(
                            tooltip: context.tr('Filter', 'تصفية'),
                            onPressed: _filters,
                            icon: Badge(
                              isLabelVisible: _activeFilters(state),
                              child: const Icon(Icons.tune),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(
                        'Search covers loaded requests only.',
                        'البحث يشمل الطلبات المحمّلة فقط.',
                      ),
                      style: AppTypography.meta,
                    ),
                    if (state.lookupLoading)
                      const LinearProgressIndicator(
                        key: ValueKey('lookup-loading'),
                      ),
                    if (state.lookupFailure != null)
                      _retry(
                        context.tr(
                          'Unable to load filter options.',
                          'تعذر تحميل خيارات التصفية.',
                        ),
                        context.tr('Retry filters', 'إعادة تحميل الفلاتر'),
                        () => bloc.add(const LoadRequestLookup()),
                      ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(context.tr('All', 'الكل')),
                            selected: state.requestTypeId == -1,
                            onSelected: lookupReady
                                ? (_) => _apply(state, type: -1)
                                : null,
                          ),
                          for (final item
                              in state.lookupData?.requestType ??
                                  <RequestLookupItemDto>[])
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 8,
                              ),
                              child: ChoiceChip(
                                label: Text(_value(item.name)),
                                selected:
                                    item.id != null &&
                                    item.id == state.requestTypeId,
                                onSelected: lookupReady && item.id != null
                                    ? (_) => _apply(state, type: item.id)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        'status-${state.requestStatusId}-${state.lookupData.hashCode}',
                      ),
                      isExpanded: true,
                      initialValue: state.requestStatusId,
                      decoration: InputDecoration(
                        labelText: context.tr('Status', 'الحالة'),
                      ),
                      items: _lookupOptions(
                        context,
                        state.lookupData?.requestStatus ?? [],
                        state.requestStatusId,
                      ),
                      onChanged: lookupReady
                          ? (id) => _apply(state, status: id)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.tr(
                        '${items.length} requests',
                        '${items.length} طلبات',
                      ),
                      style: AppTypography.section,
                    ),
                    if (state.failure != null && !state.loading)
                      _retry(
                        context.tr(
                          'Unable to load requests.',
                          'تعذر تحميل الطلبات.',
                        ),
                        context.tr('Retry', 'إعادة المحاولة'),
                        () => bloc.add(const LoadRequests()),
                      ),
                  ],
                ),
              ),
              if (state.loading && state.items.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(child: RequestLoadingSkeleton()),
                )
              else if (items.isEmpty && state.failure == null)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      EmptyState(
                        icon: Icons.inbox_outlined,
                        title: state.items.isNotEmpty
                            ? context.tr(
                                'No search results',
                                'لا توجد نتائج بحث',
                              )
                            : _activeFilters(state)
                            ? context.tr(
                                'No matching requests',
                                'لا توجد طلبات مطابقة',
                              )
                            : context.tr(
                                'No requests yet',
                                'لا توجد طلبات بعد',
                              ),
                        description: context.tr(
                          'Try a different search or filter.',
                          'جرّب بحثًا أو تصفية مختلفة.',
                        ),
                      ),
                      if (state.items.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            search.clear();
                            setState(() {});
                          },
                          child: Text(context.tr('Clear search', 'مسح البحث')),
                        ),
                    ],
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => RequestCard(
                      request: items[index],
                      lookup: state.lookupData,
                      actionBusy: state.actingRequestId != null,
                      actingAction: state.actingRequestId == items[index].id
                          ? state.actingAction
                          : null,
                      onApprove: () =>
                          _decision(items[index], RequestActionKind.approve),
                      onReject: () =>
                          _decision(items[index], RequestActionKind.reject),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: state.loadingMore
                      ? const Center(
                          child: CircularProgressIndicator(
                            key: ValueKey('load-more-loading'),
                          ),
                        )
                      : state.loadMoreFailure != null
                      ? _retry(
                          context.tr(
                            'Unable to load more requests.',
                            'تعذر تحميل المزيد من الطلبات.',
                          ),
                          context.tr('Retry more', 'إعادة تحميل المزيد'),
                          () => bloc.add(const LoadMoreRequests()),
                        )
                      : state.hasMore
                      ? TextButton(
                          onPressed: state.loading || state.refreshing
                              ? null
                              : () => bloc.add(const LoadMoreRequests()),
                          child: Text(context.tr('Load more', 'تحميل المزيد')),
                        )
                      : const SizedBox(height: 16),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

List<DropdownMenuItem<int>> _lookupOptions(
  BuildContext context,
  List<RequestLookupItemDto> items,
  int selected,
) {
  final seen = <int>{-1};
  return [
    DropdownMenuItem(value: -1, child: Text(context.tr('All', 'الكل'))),
    for (final item in items)
      if (item.id != null && seen.add(item.id!))
        DropdownMenuItem(value: item.id, child: Text(_value(item.name))),
    if (!seen.contains(selected))
      DropdownMenuItem(value: selected, child: Text('$selected')),
  ];
}

class RequestFilterSheet extends StatefulWidget {
  const RequestFilterSheet({super.key, required this.initial});
  final RequestListState initial;
  @override
  State<RequestFilterSheet> createState() => _RequestFilterSheetState();
}

class _RequestFilterSheetState extends State<RequestFilterSheet> {
  late DateTime from = widget.initial.fromDate, to = widget.initial.toDate;
  late int type = widget.initial.requestTypeId,
      status = widget.initial.requestStatusId;
  late final location = TextEditingController(
    text: widget.initial.locationCode,
  );
  late final incident = TextEditingController(text: widget.initial.incidentNo);
  bool invalid = false;
  @override
  void dispose() {
    location.dispose();
    incident.dispose();
    super.dispose();
  }

  Future<void> _date(bool start) async {
    final now = DateTime.now();
    final selected = start ? from : to;
    final value = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(
        selected.year < now.year - 20 ? selected.year : now.year - 20,
      ),
      lastDate: DateTime(
        selected.year > now.year + 20 ? selected.year : now.year + 20,
        12,
        31,
      ),
    );
    if (value != null && mounted) {
      setState(() {
        if (start) {
          from = value;
        } else {
          to = value;
        }
      });
    }
  }

  void _submit({bool reset = false}) {
    if (reset) {
      final now = DateTime.now();
      from = to = DateTime(now.year, now.month, now.day);
      type = status = -1;
      location.clear();
      incident.clear();
    }
    if (from.isAfter(to)) {
      setState(() => invalid = true);
      return;
    }
    Navigator.pop(
      context,
      ApplyRequestFilters(
        fromDate: from,
        toDate: to,
        requestTypeId: type,
        requestStatusId: status,
        locationCode: location.text,
        incidentNo: incident.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Material(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: BlocBuilder<RequestListBloc, RequestListState>(
            builder: (context, state) {
              final ready = state.lookupData != null && !state.lookupLoading;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('Filter requests', 'تصفية الطلبات'),
                    style: AppTypography.title,
                  ),
                  const SizedBox(height: 12),
                  if (state.lookupLoading) const LinearProgressIndicator(),
                  if (state.lookupFailure != null)
                    TextButton(
                      onPressed: () => context.read<RequestListBloc>().add(
                        const LoadRequestLookup(),
                      ),
                      child: Text(
                        context.tr('Retry filters', 'إعادة تحميل الفلاتر'),
                      ),
                    ),
                  OutlinedButton(
                    key: const ValueKey('from-date'),
                    onPressed: () => _date(true),
                    child: Text(
                      '${context.tr('From Date', 'من تاريخ')}: ${MaterialLocalizations.of(context).formatCompactDate(from)}',
                    ),
                  ),
                  OutlinedButton(
                    key: const ValueKey('to-date'),
                    onPressed: () => _date(false),
                    child: Text(
                      '${context.tr('To Date', 'إلى تاريخ')}: ${MaterialLocalizations.of(context).formatCompactDate(to)}',
                    ),
                  ),
                  if (invalid)
                    Text(
                      context.tr(
                        'Start date must be on or before end date.',
                        'تاريخ البداية يجب ألا يتجاوز تاريخ النهاية.',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  DropdownButtonFormField<int>(
                    key: ValueKey('filter-type-${state.lookupData.hashCode}'),
                    initialValue: type,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Request Type', 'نوع الطلب'),
                    ),
                    items: _lookupOptions(
                      context,
                      state.lookupData?.requestType ?? [],
                      type,
                    ),
                    onChanged: ready
                        ? (value) => setState(() => type = value!)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey('filter-status-${state.lookupData.hashCode}'),
                    initialValue: status,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Request Status', 'حالة الطلب'),
                    ),
                    items: _lookupOptions(
                      context,
                      state.lookupData?.requestStatus ?? [],
                      status,
                    ),
                    onChanged: ready
                        ? (value) => setState(() => status = value!)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: location,
                    decoration: InputDecoration(
                      labelText: context.tr('Location Code', 'كود الموقع'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: incident,
                    decoration: InputDecoration(
                      labelText: context.tr('Incident Number', 'رقم البلاغ'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _submit(reset: true),
                        child: Text(context.tr('Reset', 'إعادة ضبط')),
                      ),
                      FilledButton(
                        onPressed: _submit,
                        child: Text(
                          context.tr('Apply Filters', 'تطبيق الفلاتر'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    this.lookup,
    this.onApprove,
    this.onReject,
    this.actionBusy = false,
    this.actingAction,
  });
  final RequestListItemDto request;
  final RequestLookupData? lookup;
  final VoidCallback? onApprove, onReject;
  final bool actionBusy;
  final RequestActionKind? actingAction;
  @override
  Widget build(BuildContext context) {
    final type = lookup?.requestType
        .where((item) => item.id != null && item.id == request.requestType?.id)
        .firstOrNull;
    final code = (type?.code ?? request.requestType?.name ?? '').toLowerCase();
    final icon = code.contains('intervention')
        ? Icons.build_circle_outlined
        : code.contains('renewal')
        ? Icons.autorenew
        : code.contains('departure')
        ? Icons.logout
        : Icons.description_outlined;
    final statusLookup = lookup?.requestStatus
        .where(
          (item) => item.id != null && item.id == request.requestStatus?.id,
        )
        .firstOrNull;
    final status = (statusLookup?.code ?? request.requestStatus?.name)
        ?.toLowerCase();
    final typeColor = code.contains('renewal')
        ? AppColors.info
        : code.contains('departure')
        ? AppColors.success
        : code.contains('intervention')
        ? AppColors.orange
        : AppColors.muted;
    final color = switch (status) {
      'pending' => AppColors.warning,
      'approved' => AppColors.info,
      'rejected' => AppColors.error,
      _ => AppColors.muted,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: typeColor),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          'Request #${request.id ?? '-'}',
                          'طلب #${request.id ?? '-'}',
                        ),
                        style: AppTypography.section,
                      ),
                      Text(
                        _value(request.requestType?.name),
                        style: AppTypography.meta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                _value(request.requestStatus?.name),
                style: AppTypography.meta.copyWith(color: color),
              ),
            ),
            const Divider(height: 27),
            _CardMeta(
              icon: Icons.assignment_outlined,
              value: _value(request.incidentNo),
            ),
            const SizedBox(height: 7),
            _CardMeta(
              icon: Icons.cell_tower,
              value:
                  '${_value(request.locationName)} • ${_value(request.locationCode)}',
            ),
            const SizedBox(height: 7),
            _CardMeta(
              icon: Icons.event_outlined,
              value: formatCapApiDate(request.createdDate),
            ),
            const SizedBox(height: 7),
            _CardMeta(
              icon: Icons.person_outline,
              value: _value(request.createdBy?.name),
            ),
            const SizedBox(height: 7),
            _CardMeta(icon: Icons.notes, value: _value(request.remark)),
            if (canDecideRequest(request, lookup)) ...[
              const Divider(height: 27),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: actionBusy ? null : onReject,
                      icon: actingAction == RequestActionKind.reject
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                key: ValueKey('decision-${request.id}'),
                              ),
                            )
                          : const Icon(Icons.close_rounded),
                      label: Text(context.tr('Reject', 'رفض')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: actionBusy ? null : onApprove,
                      icon: actingAction == RequestActionKind.approve
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                key: ValueKey('decision-${request.id}'),
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(context.tr('Approve', 'موافقة')),
                    ),
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

class _RequestDecisionDialog extends StatefulWidget {
  const _RequestDecisionDialog({required this.kind});
  final RequestActionKind kind;
  @override
  State<_RequestDecisionDialog> createState() => _RequestDecisionDialogState();
}

class _RequestDecisionDialogState extends State<_RequestDecisionDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approve = widget.kind == RequestActionKind.approve;
    return AlertDialog(
      title: Text(
        approve
            ? context.tr('Approve Request', 'الموافقة على الطلب')
            : context.tr('Reject Request', 'رفض الطلب'),
      ),
      content: SingleChildScrollView(
        child: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: approve
                ? context.tr('Remark', 'ملاحظة')
                : context.tr('Reason', 'سبب الرفض'),
            helperText: context.tr('Optional', 'اختياري'),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel', 'إلغاء')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(
            approve
                ? context.tr('Approve', 'موافقة')
                : context.tr('Reject', 'رفض'),
          ),
        ),
      ],
    );
  }
}

class RequestDetailsScreen extends StatelessWidget {
  const RequestDetailsScreen({super.key, required this.request});
  final MyRequest request;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Request Details', 'تفاصيل الطلب'))),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        _RequestHeader(request: request),
        const SizedBox(height: 13),
        SectionCard(
          title: context.tr('Request information', 'بيانات الطلب'),
          icon: Icons.info_outline,
          child: Column(
            children: [
              InfoRow(
                icon: Icons.tag,
                label: context.tr('Request Number', 'رقم الطلب'),
                value: request.number,
              ),
              InfoRow(
                icon: _typeIcon(request.type),
                label: context.tr('Request Type', 'نوع الطلب'),
                value: _typeLabel(context, request.type),
              ),
              InfoRow(
                icon: Icons.sync_alt,
                label: context.tr('Status', 'الحالة'),
                value: _statusLabel(context, request.status),
              ),
              InfoRow(
                icon: Icons.assignment_outlined,
                label: context.tr('Incident Number', 'رقم البلاغ'),
                value: request.incidentNumber,
              ),
              InfoRow(
                icon: Icons.cell_tower,
                label: context.tr('Site', 'الموقع'),
                value: '${request.siteName} • ${request.siteCode}',
              ),
              InfoRow(
                icon: Icons.event_outlined,
                label: context.tr('Created Date', 'تاريخ الإنشاء'),
                value: _formatDate(request.createdDate),
              ),
              InfoRow(
                icon: Icons.person_outline,
                label: context.tr('Created By', 'أنشأه'),
                value: request.createdBy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        _SpecificDetails(request: request),
        const SizedBox(height: 13),
        SectionCard(
          title: context.tr('Request Timeline', 'الخط الزمني للطلب'),
          icon: Icons.timeline,
          child: _RequestTimeline(status: request.status),
        ),
      ],
    ),
    bottomNavigationBar: Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: AppButton(
          label: context.tr('View Related Incident', 'عرض البلاغ المرتبط'),
          icon: Icons.open_in_new,
          expanded: true,
          onPressed: () {
            final incident = MockData.capIncidents
                .cast<CapIncident?>()
                .firstWhere(
                  (item) => item?.number == request.incidentNumber,
                  orElse: () => MockData.capIncidents.first,
                )!;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IncidentDetailsScreen(incident: incident),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _SpecificDetails extends StatelessWidget {
  const _SpecificDetails({required this.request});
  final MyRequest request;
  @override
  Widget build(BuildContext context) => switch (request.type) {
    RelatedRequestType.intervention => Column(
      children: [
        SectionCard(
          title: context.tr('Site information', 'بيانات الموقع'),
          icon: Icons.cell_tower,
          child: Column(
            children: [
              InfoRow(
                icon: Icons.business_outlined,
                label: context.tr('Site', 'الموقع'),
                value: request.siteName,
              ),
              InfoRow(
                icon: Icons.qr_code,
                label: context.tr('Site Code', 'كود الموقع'),
                value: request.siteCode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        _QuestionnaireSummary(text: request.questionnaireSummary),
        const SizedBox(height: 13),
        _Attachments(names: request.attachments),
      ],
    ),
    RelatedRequestType.renewal => Column(
      children: [
        SectionCard(
          title: context.tr('Renewal information', 'بيانات التجديد'),
          icon: Icons.more_time,
          child: InfoRow(
            icon: Icons.schedule,
            label: context.tr('Renewal Time', 'مدة التجديد'),
            value: context.strings.isArabic
                ? '${request.renewalMinutes} دقيقة'
                : '${request.renewalMinutes} minutes',
          ),
        ),
        const SizedBox(height: 13),
        _QuestionnaireSummary(text: request.questionnaireSummary),
      ],
    ),
    RelatedRequestType.departure => Column(
      children: [
        SectionCard(
          title: context.tr('Departure information', 'بيانات المغادرة'),
          icon: Icons.logout,
          child: InfoRow(
            icon: Icons.confirmation_number_outlined,
            label: context.tr(
              'Confirmation Serial Number',
              'رقم التأكيد المسلسل',
            ),
            value: request.confirmationSerial ?? '—',
          ),
        ),
        const SizedBox(height: 13),
        _QuestionnaireSummary(text: request.questionnaireSummary),
        const SizedBox(height: 13),
        SectionCard(
          title: context.tr('Departure Photo', 'صورة المغادرة'),
          icon: Icons.photo_outlined,
          child: Container(
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.image_outlined,
                  size: 38,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('Mock departure evidence', 'دليل مغادرة محاكى'),
                  style: AppTypography.label,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  };
}

class _QuestionnaireSummary extends StatelessWidget {
  const _QuestionnaireSummary({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: context.tr('Questionnaire summary', 'ملخص الاستبيان'),
    icon: Icons.fact_check_outlined,
    child: Text(
      text,
      style: AppTypography.body.copyWith(color: AppColors.muted),
    ),
  );
}

class _Attachments extends StatelessWidget {
  const _Attachments({required this.names});
  final List<String> names;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: context.tr('Attachments', 'المرفقات'),
    icon: Icons.attach_file,
    child: names.isEmpty
        ? Text(
            context.tr('No attachments', 'لا توجد مرفقات'),
            style: AppTypography.body.copyWith(color: AppColors.muted),
          )
        : Column(
            children: names
                .map(
                  (name) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.description_outlined,
                      color: AppColors.orange,
                    ),
                    title: Text(name, style: AppTypography.label),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

class _RequestTimeline extends StatelessWidget {
  const _RequestTimeline({required this.status});
  final MyRequestStatus status;
  @override
  Widget build(BuildContext context) {
    final finalLabel = status == MyRequestStatus.rejected
        ? context.tr('Rejected', 'مرفوض')
        : status == MyRequestStatus.pending
        ? context.tr('Decision pending', 'بانتظار القرار')
        : context.tr('Approved', 'موافق عليه');
    final steps = [
      (context.tr('Created', 'تم الإنشاء'), true),
      (context.tr('Submitted', 'تم الإرسال'), true),
      (context.tr('Under Review', 'قيد المراجعة'), true),
      (finalLabel, status != MyRequestStatus.pending),
    ];
    return Column(
      children: List.generate(steps.length, (index) {
        final complete = steps[index].$2;
        final color = complete ? AppColors.orange : AppColors.border;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: complete ? AppColors.orange : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Icon(
                        complete ? Icons.check : Icons.more_horiz,
                        color: complete ? Colors.white : AppColors.muted,
                        size: 15,
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(child: Container(width: 2, color: color)),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[index].$1, style: AppTypography.label),
                      const SizedBox(height: 3),
                      Text(
                        index == 3
                            ? context.tr(
                                'Prototype review state',
                                'حالة مراجعة محاكاة',
                              )
                            : '10 Aug 2026 • ${9 + index}:15 AM',
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
    );
  }
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({required this.request});
  final MyRequest request;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: _typeColor(request.type),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_typeIcon(request.type), color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.number,
                    style: AppTypography.section.copyWith(color: Colors.white),
                  ),
                  Text(
                    _typeLabel(context, request.type),
                    style: AppTypography.meta.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor(request.status).withValues(alpha: .22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusLabel(context, request.status),
                style: AppTypography.meta.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          '${request.siteName} • ${request.siteCode}',
          style: AppTypography.label.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 5),
        Text(
          request.incidentNumber,
          style: AppTypography.meta.copyWith(color: AppColors.orange),
        ),
      ],
    ),
  );
}

class RequestLoadingSkeleton extends StatelessWidget {
  const RequestLoadingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      4,
      (_) => Container(
        height: 188,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _Bone(width: 42, height: 42),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Bone(width: 145, height: 13),
                      SizedBox(height: 8),
                      _Bone(width: 90, height: 10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _Bone(width: double.infinity, height: 11),
            const SizedBox(height: 11),
            const _Bone(width: 230, height: 11),
            const SizedBox(height: 11),
            const _Bone(width: 170, height: 11),
          ],
        ),
      ),
    ),
  );
}

class _Bone extends StatelessWidget {
  const _Bone({required this.width, required this.height});
  final double width, height;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white10
          : const Color(0xFFECECE8),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.icon, required this.value});
  final IconData icon;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          value,
          style: AppTypography.meta.copyWith(color: AppColors.muted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

IconData _typeIcon(RelatedRequestType type) => switch (type) {
  RelatedRequestType.intervention => Icons.build_circle_outlined,
  RelatedRequestType.renewal => Icons.autorenew,
  RelatedRequestType.departure => Icons.logout,
};

Color _typeColor(RelatedRequestType type) => switch (type) {
  RelatedRequestType.intervention => AppColors.orange,
  RelatedRequestType.renewal => AppColors.info,
  RelatedRequestType.departure => AppColors.success,
};

Color _statusColor(MyRequestStatus status) => switch (status) {
  MyRequestStatus.pending => AppColors.warning,
  MyRequestStatus.approved => AppColors.info,
  MyRequestStatus.rejected => AppColors.error,
  MyRequestStatus.completed => AppColors.success,
};

String _typeLabel(BuildContext context, RelatedRequestType type) =>
    switch (type) {
      RelatedRequestType.intervention => context.tr('Intervention', 'تدخل'),
      RelatedRequestType.renewal => context.tr('Renewal', 'تجديد'),
      RelatedRequestType.departure => context.tr('Departure', 'مغادرة'),
    };

String _statusLabel(BuildContext context, MyRequestStatus status) =>
    switch (status) {
      MyRequestStatus.pending => context.tr('Pending', 'قيد المراجعة'),
      MyRequestStatus.approved => context.tr('Approved', 'موافق عليه'),
      MyRequestStatus.rejected => context.tr('Rejected', 'مرفوض'),
      MyRequestStatus.completed => context.tr('Completed', 'مكتمل'),
    };

String _formatDate(DateTime date) => formatCapApiDate(date.toIso8601String());
