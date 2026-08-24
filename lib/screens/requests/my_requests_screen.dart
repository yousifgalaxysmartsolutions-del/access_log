import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_row.dart';
import '../../widgets/section_card.dart';
import '../incidents/incident_details_screen.dart';

enum RequestListState { content, loading, empty }

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});
  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final search = TextEditingController();
  late final List<MyRequest> requests = List<MyRequest>.of(MockData.myRequests);
  RelatedRequestType? type;
  MyRequestStatus? status;
  RequestListState viewState = RequestListState.content;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<MyRequest> get results {
    final query = search.text.trim().toLowerCase();
    return requests.where((request) {
      final matchesSearch =
          query.isEmpty ||
          [
            request.number,
            request.incidentNumber,
            request.siteName,
            request.siteCode,
            request.createdBy,
          ].any((value) => value.toLowerCase().contains(query));
      return matchesSearch &&
          (type == null || request.type == type) &&
          (status == null || request.status == status);
    }).toList();
  }

  void _setDecision(MyRequest request, MyRequestStatus next) {
    final localIndex = requests.indexWhere(
      (item) => item.number == request.number,
    );
    final centralIndex = MockData.myRequests.indexWhere(
      (item) => item.number == request.number,
    );
    final updated = request.copyWith(status: next);
    setState(() {
      if (localIndex >= 0) requests[localIndex] = updated;
      if (centralIndex >= 0) MockData.myRequests[centralIndex] = updated;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next == MyRequestStatus.approved
              ? context.tr(
                  '${request.number} approved',
                  'تمت الموافقة على ${request.number}',
                )
              : context.tr(
                  '${request.number} rejected',
                  'تم رفض ${request.number}',
                ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _filter() async {
    final selected = await showModalBottomSheet<MyRequestStatus?>(
      context: context,
      showDragHandle: true,
      builder: (context) => _StatusFilterSheet(selected: status),
    );
    if (!mounted) return;
    setState(() => status = selected);
  }

  @override
  Widget build(BuildContext context) {
    final items = results;
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: () async {
        setState(() => viewState = RequestListState.loading);
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() => viewState = RequestListState.content);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('My Requests', 'طلباتي'),
                        style: AppTypography.display,
                      ),
                    ),
                    PopupMenuButton<RequestListState>(
                      tooltip: context.tr('Preview state', 'معاينة الحالة'),
                      onSelected: (value) => setState(() => viewState = value),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: RequestListState.content,
                          child: Text(context.tr('Content', '[المحتوى')),
                        ),
                        PopupMenuItem(
                          value: RequestListState.loading,
                          child: Text(
                            context.tr('Loading skeleton', 'هيكل التحميل'),
                          ),
                        ),
                        PopupMenuItem(
                          value: RequestListState.empty,
                          child: Text(context.tr('Empty state', 'حالة فارغة')),
                        ),
                      ],
                      icon: const Icon(Icons.science_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Track requests created from your field incidents.',
                    'تابع الطلبات التي أنشأتها من البلاغات الميدانية.',
                  ),
                  style: AppTypography.body.copyWith(color: AppColors.muted),
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
                                  onPressed: () {
                                    search.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
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
                        onPressed: _filter,
                        icon: Badge(
                          isLabelVisible: status != null,
                          smallSize: 7,
                          backgroundColor: AppColors.orange,
                          child: const Icon(Icons.tune),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TypeChip(
                        label: context.tr('All', 'الكل'),
                        selected: type == null,
                        onTap: () => setState(() => type = null),
                      ),
                      ...RelatedRequestType.values.map(
                        (value) => _TypeChip(
                          label: _typeLabel(context, value),
                          selected: type == value,
                          onTap: () => setState(() => type = value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.strings.isArabic
                            ? '${items.length} طلبات'
                            : '${items.length} requests',
                        style: AppTypography.section,
                      ),
                    ),
                    if (status != null)
                      InputChip(
                        label: Text(_statusLabel(context, status!)),
                        onDeleted: () => setState(() => status = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (viewState == RequestListState.loading)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 30),
              sliver: SliverToBoxAdapter(child: RequestLoadingSkeleton()),
            )
          else if (viewState == RequestListState.empty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.inbox_outlined,
                title: context.tr('No requests yet', 'لا توجد طلبات بعد'),
                description: context.tr(
                  'Requests created from active incidents will appear here.',
                  'ستظهر هنا الطلبات المنشأة من البلاغات النشطة.',
                ),
              ),
            )
          else if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off,
                title: context.tr('No search results', 'لا توجد نتائج بحث'),
                description: context.tr(
                  'Try another term or clear the active filters.',
                  'جرّب عبارة أخرى أو امسح عوامل التصفية.',
                ),
                actionLabel: context.tr('Clear filters', 'مسح الفلاتر'),
                onAction: () => setState(() {
                  search.clear();
                  type = null;
                  status = null;
                }),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => RequestCard(
                  request: items[index],
                  onApprove: () =>
                      _setDecision(items[index], MyRequestStatus.approved),
                  onReject: () =>
                      _setDecision(items[index], MyRequestStatus.rejected),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RequestDetailsScreen(request: items[index]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });
  final MyRequest request;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(request.status);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
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
                      color: _typeColor(request.type).withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _typeIcon(request.type),
                      color: _typeColor(request.type),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.number, style: AppTypography.section),
                        const SizedBox(height: 2),
                        Text(
                          _typeLabel(context, request.type),
                          style: AppTypography.meta.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      _statusLabel(context, request.status),
                      style: AppTypography.meta.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 27),
              _CardMeta(
                icon: Icons.assignment_outlined,
                value: request.incidentNumber,
              ),
              const SizedBox(height: 7),
              _CardMeta(
                icon: Icons.cell_tower,
                value: '${request.siteName} • ${request.siteCode}',
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _CardMeta(
                      icon: Icons.event_outlined,
                      value: _formatDate(request.createdDate),
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              _CardMeta(icon: Icons.person_outline, value: request.createdBy),
              const Divider(height: 27),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: request.status == MyRequestStatus.rejected
                          ? null
                          : onReject,
                      icon: const Icon(Icons.close_rounded),
                      label: Text(context.tr('Reject', 'رفض')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: request.status == MyRequestStatus.approved
                          ? null
                          : onApprove,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(context.tr('Approve', 'موافقة')),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _StatusFilterSheet extends StatelessWidget {
  const _StatusFilterSheet({required this.selected});
  final MyRequestStatus? selected;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Filter by status', 'تصفية حسب الحالة'),
            style: AppTypography.title,
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MyRequestStatus.values
                .map(
                  (value) => ChoiceChip(
                    label: Text(_statusLabel(context, value)),
                    selected: selected == value,
                    onSelected: (_) => Navigator.pop(context, value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(context.tr('Clear status filter', 'مسح تصفية الحالة')),
          ),
        ],
      ),
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

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} Aug 2026 • ${(date.hour > 12 ? date.hour - 12 : date.hour).toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
