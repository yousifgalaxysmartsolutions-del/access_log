import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/cap_incident_card.dart';
import '../../widgets/empty_state.dart';

enum IncidentSort { newest, oldest, priority }

class IncidentListScreen extends StatefulWidget {
  const IncidentListScreen({super.key, this.initialFilter});
  final IncidentListFilter? initialFilter;
  @override
  State<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends State<IncidentListScreen> {
  final searchController = TextEditingController();
  late IncidentListFilter filter;
  IncidentSort sort = IncidentSort.newest;

  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter ?? const IncidentListFilter();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<CapIncident> get results {
    final query = searchController.text.trim().toLowerCase();
    bool contains(String value, String? expected) =>
        expected == null ||
        expected.isEmpty ||
        value.toLowerCase().contains(expected.toLowerCase());
    final items = MockData.capIncidents.where((incident) {
      final isToday =
          incident.dateTime.year == 2026 &&
          incident.dateTime.month == 8 &&
          incident.dateTime.day == 10;
      final matchesSearch =
          query.isEmpty ||
          [
            incident.number,
            incident.type,
            incident.siteName,
            incident.siteCode,
            incident.title,
            incident.area,
          ].any((value) => value.toLowerCase().contains(query));
      return isToday &&
          matchesSearch &&
          (filter.status == null || incident.status == filter.status) &&
          (filter.priority == null || incident.priority == filter.priority) &&
          contains(incident.region, filter.region) &&
          contains(incident.area, filter.area) &&
          contains('${incident.siteName} ${incident.siteCode}', filter.site) &&
          contains(incident.number, filter.incidentNumber) &&
          contains(incident.type, filter.type) &&
          contains(incident.location, filter.location) &&
          (filter.from == null || !incident.dateTime.isBefore(filter.from!)) &&
          (filter.to == null ||
              incident.dateTime.isBefore(
                filter.to!.add(const Duration(days: 1)),
              ));
    }).toList();
    switch (sort) {
      case IncidentSort.newest:
        items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      case IncidentSort.oldest:
        items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
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
      builder: (_) => IncidentFilterSheet(initial: filter),
    );
    if (updated != null) setState(() => filter = updated);
  }

  @override
  Widget build(BuildContext context) {
    final items = results;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Today’s Incidents', 'بلاغات اليوم')),
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
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 750));
          if (mounted) setState(() {});
        },
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
                      Text(
                        '10 Aug 2026',
                        style: AppTypography.meta.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  if (filter.status != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: InputChip(
                        label: Text(_statusLabel(context, filter.status!)),
                        onDeleted: () =>
                            setState(() => filter = const IncidentListFilter()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_off,
                  title: context.tr('No incidents found', 'لا توجد بلاغات'),
                  description: context.tr(
                    'Try adjusting your search or filter criteria.',
                    'جرّب تعديل البحث أو معايير التصفية.',
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
  late CapIncidentStatus? status = widget.initial.status;
  late Priority? priority = widget.initial.priority;
  late final region = TextEditingController(text: widget.initial.region);
  late final area = TextEditingController(text: widget.initial.area);
  late final site = TextEditingController(text: widget.initial.site);
  late final number = TextEditingController(
    text: widget.initial.incidentNumber,
  );
  late final type = TextEditingController(text: widget.initial.type);
  late final location = TextEditingController(text: widget.initial.location);
  DateTime? from;
  DateTime? to;

  @override
  void initState() {
    super.initState();
    from = widget.initial.from;
    to = widget.initial.to;
  }

  @override
  void dispose() {
    for (final controller in [region, area, site, number, type, location]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _date(bool start) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
      initialDate: start
          ? (from ?? DateTime(2026, 8, 10))
          : (to ?? DateTime(2026, 8, 10)),
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
                label: context.tr('Site name or code', 'اسم أو كود الموقع'),
                icon: Icons.cell_tower,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: number,
                label: context.tr('Incident number', 'رقم البلاغ'),
                icon: Icons.tag,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: type,
                label: context.tr('Incident type', 'نوع البلاغ'),
                icon: Icons.category_outlined,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CapIncidentStatus>(
                isExpanded: true,
                initialValue: status,
                decoration: InputDecoration(
                  labelText: context.tr('Status', 'الحالة'),
                  prefixIcon: const Icon(Icons.sync_alt),
                ),
                items: CapIncidentStatus.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_statusLabel(context, value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => status = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Priority>(
                isExpanded: true,
                initialValue: priority,
                decoration: InputDecoration(
                  labelText: context.tr('Priority', 'الأولوية'),
                  prefixIcon: const Icon(Icons.flag_outlined),
                ),
                items: Priority.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_priorityLabel(context, value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => priority = value),
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
                  onPressed: () => Navigator.pop(
                    context,
                    IncidentListFilter(
                      status: status,
                      priority: priority,
                      region: region.text,
                      area: area.text,
                      site: site.text,
                      incidentNumber: number.text,
                      type: type.text,
                      location: location.text,
                      from: from,
                      to: to,
                    ),
                  ),
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
