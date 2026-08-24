import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/mock_content_localization.dart';
import '../../core/theme/app_tokens.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/app_button.dart';
import '../../widgets/background_simulation_components.dart';
import '../../widgets/cap_incident_card.dart';
import '../../widgets/info_row.dart';
import '../../widgets/section_card.dart';
import 'incident_action_flows.dart';
import 'active_intervention_screen.dart';
import 'new_request_flows.dart';
import '../requests/my_requests_screen.dart';

class IncidentDetailsScreen extends StatefulWidget {
  const IncidentDetailsScreen({super.key, required this.incident});
  final CapIncident incident;
  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen>
    with SingleTickerProviderStateMixin {
  late CapIncidentStatus status = widget.incident.status;
  CapIncidentStatus heldFromStatus = CapIncidentStatus.inProcess;
  late final TabController tabController;
  late final List<RelatedRequest> relatedRequests;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    relatedRequests = List<RelatedRequest>.of(MockData.relatedRequests);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  void _updateStatus(CapIncidentStatus next, String message) {
    final previous = status;
    setState(() => status = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: context.tr('UNDO', 'تراجع'),
          onPressed: () => setState(() => status = previous),
        ),
      ),
    );
  }

  Future<void> _newRequest(RelatedRequestType type) async {
    final request = await Navigator.push<RelatedRequest>(
      context,
      MaterialPageRoute(
        builder: (_) => NewRequestWizard(incident: widget.incident, type: type),
      ),
    );
    if (request != null && mounted) {
      setState(() => relatedRequests.insert(0, request));
      tabController.animateTo(2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Request added to Related Requests',
              'تمت إضافة الطلب إلى الطلبات المرتبطة',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _decideRelatedRequest(RelatedRequest request, bool approved) {
    final index = relatedRequests.indexWhere(
      (item) => item.number == request.number,
    );
    if (index < 0) return;
    setState(() {
      relatedRequests[index] = request.copyWith(
        status: approved ? 'Approved' : 'Rejected',
      );
      status = statusAfterRequestDecision(
        current: status,
        requestType: request.type,
        approved: approved,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved
              ? context.tr(
                  'Request approved • Workflow status updated',
                  'تمت الموافقة على الطلب • تم تحديث حالة الفلو',
                )
              : context.tr(
                  'Request rejected • Incident status unchanged',
                  'تم رفض الطلب • حالة البلاغ لم تتغير',
                ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cancelIncident() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
        title: Text(context.tr('Cancel Incident?', 'إلغاء البلاغ؟')),
        content: Text(
          context.tr(
            'This will move the incident to Cancelled. This is a local prototype action.',
            'سيتم نقل البلاغ إلى حالة ملغى. هذا إجراء تجريبي محلي.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Back', 'رجوع')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Cancel Incident', 'إلغاء البلاغ')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _updateStatus(
        CapIncidentStatus.cancelled,
        context.tr('Incident cancelled', 'تم إلغاء البلاغ'),
      );
    }
  }

  Future<void> _openAction(Widget flow) async {
    final next = await Navigator.push<CapIncidentStatus>(
      context,
      MaterialPageRoute(builder: (_) => flow),
    );
    if (next != null && mounted) setState(() => status = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Incident Details', 'تفاصيل البلاغ')),
      actions: [
        IconButton(
          tooltip: context.tr('Share incident', 'مشاركة البلاغ'),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'Mock incident link copied',
                  'تم نسخ رابط البلاغ المحاكى',
                ),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          ),
          icon: const Icon(Icons.ios_share_outlined),
        ),
        PopupMenuButton<String>(
          onSelected: (value) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.strings.isArabic
                    ? 'تم اختيار $value (محاكاة)'
                    : '$value selected (mock)',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          ),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: context.tr('Add note', 'إضافة ملاحظة'),
              child: Text(context.tr('Add note', 'إضافة ملاحظة')),
            ),
            PopupMenuItem(
              value: context.tr('Print summary', 'طباعة الملخص'),
              child: Text(context.tr('Print summary', 'طباعة الملخص')),
            ),
          ],
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
        return Column(
          children: [
            _IncidentHeader(
              incident: widget.incident,
              status: status,
              compact: constraints.maxHeight < 700 || largeText,
            ),
            if (status == CapIncidentStatus.inProcess)
              ActiveInterventionIndicator(
                incident: widget.incident,
                margin: EdgeInsets.fromLTRB(
                  14,
                  constraints.maxHeight < 500 ? 4 : 10,
                  14,
                  0,
                ),
              ),
            if (status == CapIncidentStatus.inProcess &&
                constraints.maxHeight >= 720 &&
                !largeText)
              ActiveInterventionBanner(
                site:
                    '${context.mockText(widget.incident.siteName)} • ${widget.incident.siteCode}',
                onLocationTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationSimulationScreen(
                      site: context.mockText(widget.incident.siteName),
                    ),
                  ),
                ),
                onWarningTap: () => showGeofenceWarning(
                  context,
                  siteName: context.mockText(widget.incident.siteName),
                  onViewIncident: () {},
                ),
                onPhotoTap: () => showPhotoReminder(
                  context,
                  incidentNumber: widget.incident.number,
                  site: context.mockText(widget.incident.siteName),
                  onCapture: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MockEvidenceCaptureScreen(
                        site: widget.incident.siteName,
                      ),
                    ),
                  ),
                ),
              ),
            Container(
              color: Theme.of(context).cardColor,
              child: TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.orangeDark,
                indicatorColor: AppColors.orange,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: context.tr('General', 'عام')),
                  Tab(text: context.tr('Timeline', 'الخط الزمني')),
                  Tab(text: context.tr('Related Requests', 'الطلبات المرتبطة')),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  _GeneralTab(incident: widget.incident, status: status),
                  const _TimelineTab(),
                  _RequestsTab(
                    requests: relatedRequests,
                    incident: widget.incident,
                    onApprove: (request) =>
                        _decideRelatedRequest(request, true),
                    onReject: (request) =>
                        _decideRelatedRequest(request, false),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
    bottomNavigationBar: _ActionArea(
      status: status,
      onAssign: () => _openAction(AssignTaskFlow(incident: widget.incident)),
      onCancel: _cancelIncident,
      onAccept: () => _updateStatus(
        CapIncidentStatus.pending,
        context.tr(
          'Assignment approved • Status changed to Pending',
          'تمت الموافقة على الإسناد • تم تغيير الحالة إلى قيد الانتظار',
        ),
      ),
      onReject: () =>
          _openAction(RejectIncidentFlow(incident: widget.incident)),
      onHold: () {
        heldFromStatus = status;
        _openAction(
          FieldTaskWizard(incident: widget.incident, type: TaskFlowType.hold),
        );
      },
      onComplete: () => _openAction(
        FieldTaskWizard(incident: widget.incident, type: TaskFlowType.complete),
      ),
      onResume: () => _updateStatus(
        heldFromStatus,
        context.tr('Incident resumed successfully', 'تم استئناف البلاغ بنجاح'),
      ),
      onEntryRequest: () => _newRequest(RelatedRequestType.intervention),
      onRenewalRequest: () => _newRequest(RelatedRequestType.renewal),
      onDepartureRequest: () => _newRequest(RelatedRequestType.departure),
    ),
  );
}

class _IncidentHeader extends StatelessWidget {
  const _IncidentHeader({
    required this.incident,
    required this.status,
    this.compact = false,
  });
  final CapIncident incident;
  final CapIncidentStatus status;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppColors.ink,
    padding: EdgeInsets.fromLTRB(18, compact ? 10 : 17, 18, compact ? 10 : 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                incident.number,
                style: AppTypography.section.copyWith(color: Colors.white),
              ),
            ),
            _HeaderChip(
              label: _statusLabel(context, status),
              color: capStatusColor(status),
            ),
            const SizedBox(width: 7),
            _HeaderChip(
              label: incident.priority.name.toUpperCase(),
              color: priorityColor(incident.priority),
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 15),
        Text(
          context.mockText(incident.title),
          style: AppTypography.title.copyWith(color: Colors.white),
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: compact ? 6 : 11),
        Row(
          children: [
            const Icon(Icons.cell_tower, color: AppColors.orange, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '${context.mockText(incident.siteName)} • ${incident.siteCode}',
                style: AppTypography.meta.copyWith(color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .2),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: .45)),
    ),
    child: Text(
      label,
      style: AppTypography.meta.copyWith(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab({required this.incident, required this.status});
  final CapIncident incident;
  final CapIncidentStatus status;

  Future<void> _openDirections(BuildContext context) async {
    final tower = MockData.towerSites
        .where((site) => site.code == incident.siteCode)
        .firstOrNull;
    if (tower == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Tower coordinates are not available.',
              'إحداثيات البرج غير متاحة.',
            ),
          ),
        ),
      );
      return;
    }

    final destination = '${tower.latitude},${tower.longitude}';
    final directionsUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    });
    final opened = await launchUrl(
      directionsUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Unable to open Google Maps on this device.',
              'تعذر فتح خرائط Google على هذا الجهاز.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: [
      SectionCard(
        title: context.tr('Core information', 'المعلومات الأساسية'),
        icon: Icons.assignment_outlined,
        child: Column(
          children: [
            InfoRow(
              icon: Icons.tag,
              label: context.tr('Incident Number', 'رقم البلاغ'),
              value: incident.number,
            ),
            InfoRow(
              icon: Icons.category_outlined,
              label: context.tr('Incident Type', 'نوع البلاغ'),
              value: context.mockText(incident.type),
            ),
            InfoRow(
              icon: Icons.title,
              label: context.tr('Title', 'العنوان'),
              value: context.mockText(incident.title),
            ),
            InfoRow(
              icon: Icons.sync_alt,
              label: context.tr('Current Status', 'الحالة الحالية'),
              value: _statusLabel(context, status),
            ),
            InfoRow(
              icon: Icons.person_outline,
              label: context.tr('Current User', 'المستخدم الحالي'),
              value: context.mockText(incident.currentUser),
            ),
          ],
        ),
      ),
      const SizedBox(height: 13),
      SectionCard(
        title: context.tr('Site & location', 'بيانات الموقع'),
        icon: Icons.cell_tower,
        child: Column(
          children: [
            InfoRow(
              icon: Icons.business_outlined,
              label: context.tr('Site Name', 'اسم الموقع'),
              value: context.mockText(incident.siteName),
            ),
            InfoRow(
              icon: Icons.qr_code,
              label: context.tr('Site Code', 'كود الموقع'),
              value: incident.siteCode,
            ),
            InfoRow(
              icon: Icons.public,
              label: context.tr('Region', 'الإقليم'),
              value: context.mockText(incident.region),
            ),
            InfoRow(
              icon: Icons.map_outlined,
              label: context.tr('Area', 'المنطقة'),
              value: context.mockText(incident.area),
            ),
            const SizedBox(height: 10),
            //   MiniLocationCard(site: context.mockText(incident.siteName)),
            const SizedBox(height: 12),
            AppButton(
              label: context.tr('Directions to Tower', 'الاتجاه إلى البرج'),
              icon: Icons.directions_outlined,
              expanded: true,
              onPressed: () => _openDirections(context),
            ),
          ],
        ),
      ),
      const SizedBox(height: 13),
      SectionCard(
        title: context.tr('Technical details', 'التفاصيل الفنية'),
        icon: Icons.memory_outlined,
        child: Column(
          children: [
            InfoRow(
              icon: Icons.inventory_2_outlined,
              label: context.tr('Product Name', 'اسم المنتج'),
              value: context.mockText(incident.productName),
            ),
            InfoRow(
              icon: Icons.account_tree_outlined,
              label: context.tr('Native MO Name', 'اسم MO الأصلي'),
              value: incident.nativeMoName,
            ),
            InfoRow(
              icon: Icons.notifications_active_outlined,
              label: context.tr('Notification Type', 'نوع الإشعار'),
              value: context.mockText(incident.notificationType),
            ),
            InfoRow(
              icon: Icons.event_outlined,
              label: context.tr('Created Date', 'تاريخ الإنشاء'),
              value: _dateTime(incident.dateTime),
            ),
          ],
        ),
      ),
      const SizedBox(height: 13),
      SectionCard(
        title: context.tr('Description', 'الوصف'),
        icon: Icons.notes,
        child: Text(
          context.mockText(incident.description),
          style: AppTypography.body.copyWith(color: AppColors.muted),
        ),
      ),
    ],
  );
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              context.tr('Incident lifecycle', 'دورة حياة البلاغ'),
              style: AppTypography.title,
            ),
          ),
          Text(
            '${MockData.incidentTimeline.where((event) => event.completed).length} of ${MockData.incidentTimeline.length}',
            style: AppTypography.meta.copyWith(color: AppColors.muted),
          ),
        ],
      ),
      const SizedBox(height: 20),
      ...List.generate(
        MockData.incidentTimeline.length,
        (index) => _HistoryItem(
          event: MockData.incidentTimeline[index],
          last: index == MockData.incidentTimeline.length - 1,
        ),
      ),
    ],
  );
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.event, required this.last});
  final IncidentHistoryEvent event;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final color = event.completed ? AppColors.orange : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: event.completed
                        ? AppColors.orange
                        : Theme.of(context).cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    event.completed ? Icons.check : Icons.more_horiz,
                    size: 17,
                    color: event.completed ? Colors.white : AppColors.muted,
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _eventAction(context, event.action),
                              style: AppTypography.section,
                            ),
                          ),
                          Text(
                            _dateTime(event.dateTime),
                            style: AppTypography.meta.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.user,
                              style: AppTypography.meta.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _eventRemarks(context, event.action, event.remarks),
                        style: AppTypography.body.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
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

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.requests,
    required this.incident,
    required this.onApprove,
    required this.onReject,
  });
  final List<RelatedRequest> requests;
  final CapIncident incident;
  final ValueChanged<RelatedRequest> onApprove;
  final ValueChanged<RelatedRequest> onReject;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
    children: [
      Text(
        context.tr('Related Requests', 'الطلبات المرتبطة'),
        style: AppTypography.title,
      ),
      const SizedBox(height: 6),
      Text(
        context.tr(
          'Requests created during this incident lifecycle.',
          'الطلبات التي تم إنشاؤها خلال دورة حياة البلاغ.',
        ),
        style: AppTypography.body.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      ...RelatedRequestType.values.map((type) {
        final typeRequests = requests.where((item) => item.type == type);
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_requestIcon(type), size: 19, color: AppColors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _requestTypePlural(context, type),
                      style: AppTypography.section,
                    ),
                  ),
                  Text(
                    '${typeRequests.length}',
                    style: AppTypography.meta.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ...typeRequests.map(
                (request) => _RequestCard(
                  request: request,
                  incident: incident,
                  onApprove: () => onApprove(request),
                  onReject: () => onReject(request),
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.incident,
    required this.onApprove,
    required this.onReject,
  });
  final RelatedRequest request;
  final CapIncident incident;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  MyRequest get details {
    final matches = MockData.myRequests.where(
      (item) => item.number == request.number,
    );
    final saved = matches.isEmpty ? null : matches.first;
    final status = switch (request.status) {
      'Approved' => MyRequestStatus.approved,
      'Rejected' => MyRequestStatus.rejected,
      'Completed' => MyRequestStatus.completed,
      _ => MyRequestStatus.pending,
    };
    return MyRequest(
      number: request.number,
      type: request.type,
      status: status,
      incidentNumber: incident.number,
      siteName: incident.siteName,
      siteCode: incident.siteCode,
      createdDate: request.dateTime,
      createdBy: request.createdBy,
      questionnaireSummary:
          saved?.questionnaireSummary ??
          switch (request.type) {
            RelatedRequestType.intervention =>
              'Site access and intervention requirements were confirmed.',
            RelatedRequestType.renewal =>
              'Additional intervention time was requested for field work.',
            RelatedRequestType.departure =>
              'Site departure checks and handover details were recorded.',
          },
      renewalMinutes: request.type == RelatedRequestType.renewal
          ? saved?.renewalMinutes ?? 60
          : null,
      confirmationSerial: request.type == RelatedRequestType.departure
          ? saved?.confirmationSerial ?? MockData.confirmationSerialNumber
          : null,
      attachments: request.type == RelatedRequestType.intervention
          ? saved?.attachments ?? const ['site_evidence.jpg']
          : const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (request.status) {
      'Approved' => AppColors.success,
      'Rejected' => AppColors.error,
      'Draft' => AppColors.muted,
      _ => AppColors.warning,
    };
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RequestDetailsScreen(request: details),
          ),
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.number,
                      style: AppTypography.label.copyWith(
                        color: AppColors.orangeDark,
                      ),
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
                      _requestStatus(context, request.status),
                      style: AppTypography.meta.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _RequestRow(
                icon: Icons.category_outlined,
                label: context.tr('Type', 'النوع'),
                value: _requestTypeLabel(context, request.type),
              ),
              const SizedBox(height: 7),
              _RequestRow(
                icon: Icons.schedule,
                label: context.tr('Date', 'التاريخ'),
                value: _dateTime(request.dateTime),
              ),
              const SizedBox(height: 7),
              _RequestRow(
                icon: Icons.person_outline,
                label: context.tr('Created By', 'أنشأه'),
                value: request.createdBy,
              ),
              if (request.status == 'Pending Approval') ...[
                const Divider(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close),
                        label: Text(context.tr('Reject', 'رفض')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 7),
      Text(
        '$label: ',
        style: AppTypography.meta.copyWith(color: AppColors.muted),
      ),
      Expanded(
        child: Text(
          value,
          style: AppTypography.meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.status,
    required this.onAssign,
    required this.onCancel,
    required this.onAccept,
    required this.onReject,
    required this.onHold,
    required this.onComplete,
    required this.onResume,
    required this.onEntryRequest,
    required this.onRenewalRequest,
    required this.onDepartureRequest,
  });
  final CapIncidentStatus status;
  final VoidCallback onAssign,
      onCancel,
      onAccept,
      onReject,
      onHold,
      onComplete,
      onResume,
      onEntryRequest,
      onRenewalRequest,
      onDepartureRequest;
  @override
  Widget build(BuildContext context) {
    final actions = switch (status) {
      CapIncidentStatus.needAssign => [
        AppButton(
          label: context.tr('Assign', 'إسناد'),
          icon: Icons.person_add_alt,
          onPressed: onAssign,
          expanded: true,
        ),
        AppButton(
          label: context.tr('Cancel', 'إلغاء'),
          icon: Icons.close,
          style: AppButtonStyle.outline,
          onPressed: onCancel,
          expanded: true,
        ),
      ],
      CapIncidentStatus.needApproval => [
        AppButton(
          label: context.tr('Approve', 'موافقة'),
          icon: Icons.approval_outlined,
          onPressed: onAccept,
          expanded: true,
        ),
        AppButton(
          label: context.tr('Reject', 'رفض'),
          icon: Icons.close,
          style: AppButtonStyle.outline,
          onPressed: onReject,
          expanded: true,
        ),
      ],
      CapIncidentStatus.pending => [
        AppButton(
          label: context.tr('Hold', 'تعليق'),
          icon: Icons.pause,
          style: AppButtonStyle.outline,
          onPressed: onHold,
          expanded: true,
        ),
        AppButton(
          label: context.tr('New Entry Request', 'طلب دخول جديد'),
          icon: Icons.login,
          onPressed: onEntryRequest,
          expanded: true,
        ),
      ],
      CapIncidentStatus.inProcess => [
        AppButton(
          label: context.tr('Hold', 'تعليق'),
          icon: Icons.pause,
          style: AppButtonStyle.outline,
          onPressed: onHold,
          expanded: true,
        ),
        AppButton(
          label: context.tr('New Renewal', 'طلب تجديد'),
          icon: Icons.autorenew,
          style: AppButtonStyle.secondary,
          onPressed: onRenewalRequest,
          expanded: true,
        ),
        AppButton(
          label: context.tr('Complete', 'إكمال'),
          icon: Icons.task_alt,
          onPressed: onComplete,
          expanded: true,
        ),
      ],
      CapIncidentStatus.hold => [
        AppButton(
          label: context.tr('Resume Activity', 'استئناف النشاط'),
          icon: Icons.play_arrow,
          onPressed: onResume,
          expanded: true,
        ),
      ],
      CapIncidentStatus.completed => [
        AppButton(
          label: context.tr('New Departure Request', 'طلب مغادرة جديد'),
          icon: Icons.logout,
          onPressed: onDepartureRequest,
          expanded: true,
        ),
      ],
      CapIncidentStatus.cancelled => <Widget>[],
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: actions.isEmpty
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, color: AppColors.error),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.tr(
                        'No operational actions • Incident cancelled',
                        'لا توجد إجراءات تشغيلية • البلاغ ملغى',
                      ),
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              )
            : actions.length >= 3
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: actions[0]),
                      const SizedBox(width: 9),
                      Expanded(child: actions[1]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      actions.length - 2,
                      (index) => Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: index == actions.length - 3 ? 0 : 9,
                          ),
                          child: actions[index + 2],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: List.generate(
                  actions.length,
                  (index) => Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: index == actions.length - 1 ? 0 : 9,
                      ),
                      child: actions[index],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

IconData _requestIcon(RelatedRequestType type) => switch (type) {
  RelatedRequestType.intervention => Icons.build_circle_outlined,
  RelatedRequestType.renewal => Icons.autorenew,
  RelatedRequestType.departure => Icons.logout,
};

String _dateTime(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} Aug 2026 • ${(date.hour > 12 ? date.hour - 12 : date.hour).toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';

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

String _requestTypeLabel(BuildContext context, RelatedRequestType type) =>
    switch (type) {
      RelatedRequestType.intervention => context.tr(
        'Intervention Request',
        'طلب تدخل',
      ),
      RelatedRequestType.renewal => context.tr('Renewal Request', 'طلب تجديد'),
      RelatedRequestType.departure => context.tr(
        'Departure Request',
        'طلب مغادرة',
      ),
    };

String _requestTypePlural(BuildContext context, RelatedRequestType type) =>
    switch (type) {
      RelatedRequestType.intervention => context.tr(
        'Intervention Requests',
        'طلبات التدخل',
      ),
      RelatedRequestType.renewal => context.tr(
        'Renewal Requests',
        'طلبات التجديد',
      ),
      RelatedRequestType.departure => context.tr(
        'Departure Requests',
        'طلبات المغادرة',
      ),
    };

String _requestStatus(BuildContext context, String status) => switch (status) {
  'Approved' => context.tr('Approved', 'موافق عليه'),
  'Rejected' => context.tr('Rejected', 'مرفوض'),
  'Draft' => context.tr('Draft', 'مسودة'),
  'Pending Approval' => context.tr('Pending Approval', 'بانتظار الموافقة'),
  _ => status,
};

String _eventAction(BuildContext context, String action) => switch (action) {
  'Created' => context.tr('Created', 'تم الإنشاء'),
  'Assigned' => context.tr('Assigned', 'تم الإسناد'),
  'Started' => context.tr('Started', 'تم البدء'),
  'On Hold' => context.tr('On Hold', 'تم التعليق'),
  'Renewed' => context.tr('Renewed', 'تم التجديد'),
  'Completed' => context.tr('Completed', 'تم الإكمال'),
  'Closed' => context.tr('Closed', 'تم الإغلاق'),
  _ => action,
};

String _eventRemarks(BuildContext context, String action, String english) {
  final arabic = switch (action) {
    'Created' => 'تم إنشاء البلاغ من إنذار حرج بوحدة المقوم.',
    'Assigned' => 'تم إسناده إلى فريق العمليات الميدانية بالقاهرة الكبرى.',
    'Started' => 'أكد المهندس دخول الموقع وبدأ العمل الميداني.',
    'On Hold' => 'بانتظار الموافقة على وحدة المقوم البديلة.',
    'Renewed' => 'تم تمديد نافذة العمل لساعتين إضافيتين.',
    'Completed' => 'تم استبدال الوحدة وعادت القراءات إلى المستوى الطبيعي.',
    'Closed' => 'تمت مراجعة الأدلة وإغلاق البلاغ رسميًا.',
    _ => english,
  };
  return context.strings.isArabic ? arabic : english;
}
