import 'package:flutter/material.dart';
import 'dart:async';
import '../../features/incidents/data/incident_lookup_store.dart';
import '../../features/incidents/data/models/incident_lookup_models.dart';
import '../../core/network/result.dart';
import '../../core/di/injection.dart';
import '../../core/error/failure.dart';
import '../../features/incidents/domain/usecases/get_incident_list_use_case.dart';
import '../../features/incidents/presentation/bloc/incident_list_bloc.dart';
import '../../widgets/skeleton_shimmer.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/models.dart';
import '../../widgets/cap_incident_card.dart';
import '../../widgets/empty_state.dart';

enum IncidentSort { newest, oldest, priority }

class IncidentListScreen extends StatefulWidget {
  const IncidentListScreen({
    super.key,
    this.initialFilter,
    this.isActive = true,
  });
  final bool isActive;
  final IncidentListFilter? initialFilter;
  @override
  State<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends State<IncidentListScreen> {
  final searchController = TextEditingController();
  late IncidentListFilter filter;
  IncidentSort sort = IncidentSort.newest;
  late final IncidentListBloc bloc;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _refreshLookup();
    filter = widget.initialFilter ?? const IncidentListFilter();
    bloc = IncidentListBloc(
      services.isRegistered<GetIncidentListUseCase>()
          ? services<GetIncidentListUseCase>()
          : null,
    );
    final (from, to) = IncidentListBloc.range(filter);
    _load(from, to);
  }

  Future<void> _load(DateTime from, DateTime to) =>
      bloc.load(from, to, statusId: filter.statusId ?? -1, filter: filter);

  @override
  void didUpdateWidget(IncidentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _refreshLookup();
      filter = const IncidentListFilter();
      searchController.clear();
      sort = IncidentSort.newest;
      final (from, to) = IncidentListBloc.range(filter);
      unawaited(_load(from, to));
    }
  }

  void _refreshLookup() {
    if (services.isRegistered<IncidentLookupStore>()) {
      unawaited(services<IncidentLookupStore>().refresh());
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    bloc.close();
    super.dispose();
  }

  List<CapIncident> get results {
    final query = searchController.text.trim().toLowerCase();
    bool contains(String value, String? expected) =>
        expected == null ||
        expected.isEmpty ||
        value.toLowerCase().contains(expected.toLowerCase());
    final items = bloc.state.incidents.where((incident) {
      final matchesSearch =
          query.isEmpty ||
          [
            incident.number,
            incident.type,
            incident.siteName,
            incident.siteCode,
            incident.title,
            incident.area,
            incident.region,
            incident.location,
          ].any((value) => value.toLowerCase().contains(query));
      return matchesSearch &&
          (filter.statusId != null ||
              filter.status == null ||
              incident.status == filter.status) &&
          (filter.priority == null || incident.priority == filter.priority) &&
          contains(incident.region, filter.region) &&
          contains(incident.area, filter.area) &&
          contains('${incident.siteName} ${incident.siteCode}', filter.site) &&
          contains(incident.type, filter.type) &&
          contains(incident.location, filter.location);
    }).toList();
    switch (sort) {
      case IncidentSort.newest:
        if (items.every((item) => item.hasRealDate)) {
          items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        }
      case IncidentSort.oldest:
        if (items.every((item) => item.hasRealDate)) {
          items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        }
      case IncidentSort.priority:
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

  Future<void> _openFilters() async {
    final updated = await showModalBottomSheet<IncidentListFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Material(child: IncidentFilterSheet(initial: filter)),
      ),
    );
    if (updated != null && mounted) {
      final (from, to) = IncidentListBloc.range(updated);
      if (from.isAfter(to)) return;
      setState(() => filter = updated);
      if (from != bloc.state.from ||
          to != bloc.state.to ||
          (updated.statusId ?? -1) != bloc.state.statusId ||
          updated.priorityId != bloc.state.filter.priorityId ||
          updated.incidentTypeId != bloc.state.filter.incidentTypeId ||
          updated.locationCode != bloc.state.filter.locationCode ||
          updated.incidentNumber != bloc.state.filter.incidentNumber) {
        await _load(from, to);
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<IncidentListState>(
    stream: bloc.stream,
    initialData: bloc.state,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final items = results;
    final state = bloc.state;
    String formatDate(DateTime date) =>
        '${MaterialLocalizations.of(context).formatMediumDate(date)} ${date.year}';
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Incidents', 'البلاغات')),
        actions: [
          PopupMenuButton<IncidentSort>(
            tooltip: context.tr('Sort incidents', 'ترتيب البلاغات'),
            initialValue: sort,
            onSelected: (value) => setState(() => sort = value),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: IncidentSort.newest,
                child: Text(context.tr('Newest first', 'الأحدث أولاً')),
              ),
              PopupMenuItem(
                value: IncidentSort.oldest,
                child: Text(context.tr('Oldest first', 'الأقدم أولاً')),
              ),
              PopupMenuItem(
                value: IncidentSort.priority,
                child: Text(context.tr('Priority first', 'الأولوية أولاً')),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: () => _load(state.from, state.to),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              sliver: SliverList.list(
                children: [
                  TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.tr(
                        'Search number, site, type, or title',
                        'ابحث بالرقم أو الموقع أو النوع أو العنوان',
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openFilters,
                          icon: Badge(
                            isLabelVisible: filter.isActive,
                            backgroundColor: AppColors.orange,
                            smallSize: 7,
                            child: const Icon(Icons.tune),
                          ),
                          label: Text(context.tr('Filters', 'الفلاتر')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            sort = sort == IncidentSort.newest
                                ? IncidentSort.oldest
                                : IncidentSort.newest;
                          }),
                          icon: Icon(
                            sort == IncidentSort.oldest
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                          ),
                          label: Text(switch (sort) {
                            IncidentSort.newest => context.tr(
                              'Newest',
                              'الأحدث',
                            ),
                            IncidentSort.oldest => context.tr(
                              'Oldest',
                              'الأقدم',
                            ),
                            IncidentSort.priority => context.tr(
                              'Priority',
                              'الأولوية',
                            ),
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.strings.isArabic
                              ? '${items.length} بلاغات'
                              : '${items.length} incidents',
                          style: AppTypography.section,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          state.from == state.to
                              ? formatDate(state.from)
                              : '${formatDate(state.from)} – ${formatDate(state.to)}',
                          style: AppTypography.meta.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (filter.status != null || filter.statusId != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: InputChip(
                        label: Text(
                          filter.statusName ??
                              (filter.status == null
                                  ? '${filter.statusId}'
                                  : _statusLabel(context, filter.status!)),
                        ),
                        onDeleted: () {
                          setState(() => filter = filter.withoutStatus());
                          unawaited(_load(state.from, state.to));
                        },
                      ),
                    ),
                  ],
                  if (state.incidents.any((item) => !item.hasRealDate))
                    Text(
                      context.tr(
                        'Incident dates unavailable; date sorting keeps server order.',
                        'تواريخ البلاغات غير متاحة؛ الترتيب الزمني يحتفظ بترتيب الخادم.',
                      ),
                      style: AppTypography.meta,
                    ),
                  if (state.failure != null) ...[
                    Text(
                      state.failure is ValidationFailure
                          ? context.tr(
                              'Start date must be on or before end date.',
                              'تاريخ البداية يجب ألا يتجاوز تاريخ النهاية.',
                            )
                          : context.tr(
                              'Unable to load incidents. Check your connection and try again.',
                              'تعذر تحميل البلاغات. تحقق من الاتصال وأعد المحاولة.',
                            ),
                    ),
                    TextButton.icon(
                      onPressed: () => _load(state.from, state.to),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.tr('Retry', 'إعادة المحاولة')),
                    ),
                  ],
                ],
              ),
            ),
            if (state.loading && state.incidents.isEmpty)
              SliverList.list(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: SkeletonBox(height: 200),
                  ),
                ),
              )
            else if (items.isEmpty && state.failure == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_off,
                  title: context.tr('No incidents found', 'لا توجد بلاغات'),
                  description: context.tr(
                    state.incidents.isEmpty
                        ? 'No incidents in the selected date range.'
                        : 'Try adjusting your search or filter criteria.',
                    state.incidents.isEmpty
                        ? 'لا توجد بلاغات في نطاق التاريخ المحدد.'
                        : 'جرّب تعديل البحث أو معايير التصفية.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 11),
                  itemBuilder: (context, index) => CapIncidentCard(
                    incident: items[index],
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.incidentDetails,
                      arguments: items[index],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class IncidentFilterSheet extends StatefulWidget {
  const IncidentFilterSheet({super.key, required this.initial});
  final IncidentListFilter initial;
  @override
  State<IncidentFilterSheet> createState() => _IncidentFilterSheetState();
}

class _IncidentFilterSheetState extends State<IncidentFilterSheet> {
  late int statusId = widget.initial.statusId ?? -1;
  late int priorityId = widget.initial.priorityId ?? -1;
  late int incidentTypeId = widget.initial.incidentTypeId ?? -1;
  IncidentLookupData? lookup;
  bool lookupLoading = false;
  bool lookupFailed = false;
  late final region = TextEditingController(text: widget.initial.region);
  late final area = TextEditingController(text: widget.initial.area);
  late final site = TextEditingController(text: widget.initial.locationCode);
  late final number = TextEditingController(
    text: widget.initial.incidentNumber,
  );
  late final location = TextEditingController(text: widget.initial.location);
  DateTime? from;
  DateTime? to;
  bool invalidRange = false;

  @override
  void initState() {
    super.initState();
    from = widget.initial.from;
    to = widget.initial.to;
    if (services.isRegistered<IncidentLookupStore>()) {
      lookup = services<IncidentLookupStore>().current;
    }
    if (lookup == null) unawaited(_loadLookup());
  }

  Future<void> _loadLookup() async {
    setState(() {
      lookupLoading = true;
      lookupFailed = false;
    });
    if (!services.isRegistered<IncidentLookupStore>()) {
      setState(() {
        lookupLoading = false;
        lookupFailed = true;
      });
      return;
    }
    final result = await services<IncidentLookupStore>().refresh();
    if (!mounted) return;
    setState(() {
      lookupLoading = false;
      if (result is Success<IncidentLookupData>) {
        lookup = result.data;
      } else {
        lookupFailed = true;
      }
    });
  }

  Widget _lookupField(
    String label,
    IconData icon,
    List<IncidentLookupItem> items,
    int selected,
    ValueChanged<int> onChanged,
  ) {
    final choices = <int, String>{
      -1: context.tr('All', 'الكل'),
      for (final item in items)
        if (item.id != null && item.id! > 0) item.id!: item.name ?? '-',
    };
    if (!choices.containsKey(selected)) choices[selected] = '$selected';
    return DropdownButtonFormField<int>(
      key: ValueKey('$label:$selected:${choices.entries}'),
      isExpanded: true,
      initialValue: selected,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: choices.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: lookupLoading || lookupFailed
          ? null
          : (value) => onChanged(value ?? -1),
    );
  }

  @override
  void dispose() {
    for (final controller in [region, area, site, number, location]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _date(bool start) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 20),
      lastDate: DateTime(DateTime.now().year + 20),
      initialDate: start
          ? (from ?? DateTime.now())
          : (to ?? from ?? DateTime.now()),
    );
    if (selected != null) {
      setState(() => start ? from = selected : to = selected);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              context.tr('Filter incidents', 'تصفية البلاغات'),
              style: AppTypography.title,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              Text(
                context.tr('Date range', 'نطاق التاريخ'),
                style: AppTypography.label,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: context.tr('From', 'من'),
                      date: from,
                      onTap: () => _date(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      label: context.tr('To', 'إلى'),
                      date: to,
                      onTap: () => _date(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (invalidRange)
                Text(
                  context.tr(
                    'Start date must be on or before end date.',
                    'تاريخ البداية يجب ألا يتجاوز تاريخ النهاية.',
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: region,
                      label: context.tr('Region', 'الإقليم'),
                      icon: Icons.public,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      controller: area,
                      label: context.tr('Area', 'المنطقة'),
                      icon: Icons.map_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: site,
                label: context.tr('Location code', 'كود الموقع'),
                icon: Icons.cell_tower,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: number,
                label: context.tr('Incident number', 'رقم البلاغ'),
                icon: Icons.tag,
              ),
              const SizedBox(height: 12),
              if (lookupLoading) const LinearProgressIndicator(),
              if (lookupFailed) ...[
                Text(
                  context.tr(
                    'Unable to load filter options.',
                    'تعذّر تحميل خيارات الفلترة.',
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadLookup,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.tr('Retry', 'إعادة المحاولة')),
                ),
              ],
              _lookupField(
                context.tr('Incident type', 'نوع البلاغ'),
                Icons.category_outlined,
                lookup?.incidentType ?? const [],
                incidentTypeId,
                (value) => setState(() => incidentTypeId = value),
              ),
              const SizedBox(height: 12),
              _lookupField(
                context.tr('Status', 'الحالة'),
                Icons.sync_alt,
                lookup?.status ?? const [],
                statusId,
                (value) => setState(() => statusId = value),
              ),
              const SizedBox(height: 12),
              _lookupField(
                context.tr('Priority', 'الأولوية'),
                Icons.flag_outlined,
                lookup?.priority ?? const [],
                priorityId,
                (value) => setState(() => priorityId = value),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: location,
                label: context.tr('Location', 'الموقع'),
                icon: Icons.location_on_outlined,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(context, const IncidentListFilter()),
                  child: Text(context.tr('Reset', 'إعادة ضبط')),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (from != null && to != null && from!.isAfter(to!)) {
                      setState(() => invalidRange = true);
                      return;
                    }
                    Navigator.pop(
                      context,
                      IncidentListFilter(
                        statusId: statusId == -1 ? null : statusId,
                        statusName:
                            lookup?.status
                                .where((item) => item.id == statusId)
                                .firstOrNull
                                ?.name ??
                            (statusId == widget.initial.statusId
                                ? widget.initial.statusName
                                : null),
                        priorityId: priorityId == -1 ? null : priorityId,
                        incidentTypeId: incidentTypeId == -1
                            ? null
                            : incidentTypeId,
                        region: region.text,
                        area: area.text,
                        locationCode: site.text,
                        incidentNumber: number.text,
                        location: location.text,
                        from: from,
                        to: to,
                      ),
                    );
                  },
                  child: Text(context.tr('Apply Filters', 'تطبيق الفلاتر')),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      child: Text(
        date == null
            ? context.tr('Select', 'اختر')
            : '${date!.day}/${date!.month}/${date!.year}',
        style: AppTypography.label,
      ),
    ),
  );
}

String _statusLabel(BuildContext context, CapIncidentStatus status) {
  final name = status == CapIncidentStatus.hold ? 'Hold' : status.label;
  if (services.isRegistered<IncidentLookupStore>()) {
    for (final item in services<IncidentLookupStore>().current?.status ?? []) {
      if (item.name?.toLowerCase() == name.toLowerCase()) {
        return item.name!;
      }
    }
  }
  return name;
}
