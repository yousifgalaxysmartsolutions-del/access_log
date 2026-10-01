import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/failure.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/mock_content_localization.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/incidents/data/models/incident_details_models.dart';
import '../../features/incidents/presentation/bloc/incident_details_bloc.dart';
import '../../features/incidents/presentation/incident_details_bloc_scope.dart';
import '../../models/models.dart';
import '../../widgets/app_button.dart';
import '../../widgets/background_simulation_components.dart';
import '../../widgets/cap_incident_card.dart';
import '../../widgets/info_row.dart';
import '../../widgets/section_card.dart';
import '../../widgets/skeleton_shimmer.dart';
import 'incident_action_flows.dart';
import 'active_intervention_screen.dart';
import 'new_request_flows.dart';

/// Tab indexes. General and Related Requests read real API data; Timeline is
/// still mock-backed because its payload is unknown.
const int _generalTabIndex = 0;
const int _timelineTabIndex = 1;
const int _relatedRequestsTabIndex = 2;

class IncidentDetailsScreen extends StatefulWidget {
  const IncidentDetailsScreen({super.key, required this.incident});
  final CapIncident incident;
  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen>
    with SingleTickerProviderStateMixin {
  /// One bloc for this screen's lifetime.
  ///
  /// Created here rather than in `build` because most call sites push this screen
  /// directly instead of through `AppRoutes`, and `initState` needs it for the
  /// first load.
  late final IncidentDetailsBloc detailsBloc;
  late CapIncidentStatus status = widget.incident.status;
  CapIncidentStatus heldFromStatus = CapIncidentStatus.inProcess;
  late final TabController tabController;

  /// The tab index the selection last came to rest at.
  ///
  /// `TabController` publishes `index` before `TabBar.onTap` runs, so the
  /// controller value cannot distinguish a re-tap from a real move. This field
  /// is only updated once a movement has settled, which makes it the single
  /// source of truth for "the tab the user is currently looking at".
  int _settledIndex = _generalTabIndex;

  @override
  void initState() {
    super.initState();
    detailsBloc = IncidentDetailsBlocScope.resolve();
    tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    // Dispatched from a post-frame callback rather than `build` so the first
    // load happens exactly once and never during layout. The screen owns no
    // other async state for General; everything else comes from the bloc.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGeneral());
  }

  @override
  void dispose() {
    tabController.removeListener(_onTabChanged);
    tabController.dispose();
    detailsBloc.close();
    super.dispose();
  }

  /// Requests General data for the selected tab.
  ///
  /// The real CAP `incidentId` travels on `CapIncident`; [CapIncident.number] is
  /// only the display number.
  void _loadGeneral() {
    if (!mounted) return;
    detailsBloc.add(
      LoadIncidentGeneral(
        incidentId: widget.incident.incidentId,
        incidentNo: widget.incident.number,
      ),
    );
  }

  /// Requests Related Requests data for the selected tab.
  ///
  /// Uses the same real [CapIncident.incidentId] source as General: never a
  /// literal, a list index, or something derived from the incident number.
  void _loadRelatedRequests() {
    if (!mounted) return;
    detailsBloc.add(
      LoadIncidentRelatedRequests(incidentId: widget.incident.incidentId),
    );
  }

  /// Requests Timeline data for the selected tab.
  ///
  /// Uses the same real [CapIncident.incidentId] source as General and Related
  /// Requests: never a literal, a list index, or something derived from the
  /// incident number.
  void _loadTimeline() {
    if (!mounted) return;
    detailsBloc.add(
      LoadIncidentTimeline(incidentId: widget.incident.incidentId),
    );
  }

  /// Loads the panel a settled tab selection belongs to.
  void _loadPanelFor(int tabIndex) => switch (tabIndex) {
    _generalTabIndex => _loadGeneral(),
    _timelineTabIndex => _loadTimeline(),
    _relatedRequestsTabIndex => _loadRelatedRequests(),
    _ => null,
  };

  /// Fires on real index changes: tab taps that move the selection and swipes.
  void _onTabChanged() {
    if (tabController.indexIsChanging) return;
    // Animation between tabs reports the destination index before the old tab
    // has settled, so only react once the movement finished.
    if (tabController.animation?.isAnimating ?? false) return;
    _settledIndex = tabController.index;
    _loadPanelFor(tabController.index);
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

  /// Prototype entry point for the bottom action area.
  ///
  /// The create-request API is not connected yet, so the wizard still runs but
  /// its result is deliberately discarded: injecting a locally built request into
  /// the tab would present prototype data as if `GetIncidentRequests` had
  /// returned it. The write sprint will create the request on the backend and
  /// then refresh the tab.
  Future<void> _newRequest(RelatedRequestType type) async {
    final request = await Navigator.push<RelatedRequest>(
      context,
      MaterialPageRoute(
        builder: (_) => NewRequestWizard(incident: widget.incident, type: type),
      ),
    );
    if (request != null && mounted) {
      tabController.animateTo(_relatedRequestsTabIndex);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Creating requests is not connected yet',
              'إنشاء الطلبات غير متصل بالخدمة بعد',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
  Widget build(BuildContext context) => BlocProvider<IncidentDetailsBloc>.value(
    value: detailsBloc,
    child: _buildScreen(context),
  );

  Widget _buildScreen(BuildContext context) => Scaffold(
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
                onTap: (index) {
                  // Tapping the tab that is already selected produces no index
                  // change, so the listener above never runs for it. Handling it
                  // here keeps one user action to exactly one API call.
                  //
                  // `TabController.index` cannot be used to tell a re-tap from a
                  // real move: the controller flips `index` before `onTap` runs, so
                  // by the time this callback fires a genuine move already reports
                  // the destination index. [_settledIndex] holds the index the
                  // selection last came to rest at, so `index == _settledIndex`
                  // means the tap did not move anything and is a true re-tap.
                  if (index == _settledIndex) _loadPanelFor(index);
                },
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
                  // Each panel rebuilds only on its own slice of the state, so
                  // loading or failing one never disturbs the others.
                  BlocBuilder<IncidentDetailsBloc, IncidentDetailsState>(
                    buildWhen: (previous, current) =>
                        previous.generalLoading != current.generalLoading ||
                        previous.generalData != current.generalData ||
                        previous.generalFailure != current.generalFailure,
                    builder: (context, state) => _GeneralTab(
                      data: state.generalData,
                      loading: state.generalLoading,
                      failure: state.generalFailure,
                      onRetry: _loadGeneral,
                      status: status,
                    ),
                  ),
                  BlocBuilder<IncidentDetailsBloc, IncidentDetailsState>(
                    buildWhen: (previous, current) =>
                        previous.timelineLoading != current.timelineLoading ||
                        previous.timelineData != current.timelineData ||
                        previous.timelineFailure != current.timelineFailure,
                    builder: (context, state) => _TimelineTab(
                      data: state.timelineData,
                      loading: state.timelineLoading,
                      failure: state.timelineFailure,
                      onRetry: _loadTimeline,
                    ),
                  ),
                  BlocBuilder<IncidentDetailsBloc, IncidentDetailsState>(
                    buildWhen: (previous, current) =>
                        previous.relatedRequestsLoading !=
                            current.relatedRequestsLoading ||
                        previous.relatedRequestsData !=
                            current.relatedRequestsData ||
                        previous.relatedRequestsFailure !=
                            current.relatedRequestsFailure,
                    builder: (context, state) => _RequestsTab(
                      data: state.relatedRequestsData,
                      loading: state.relatedRequestsLoading,
                      failure: state.relatedRequestsFailure,
                      onRetry: _loadRelatedRequests,
                    ),
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

/// The General panel, driven entirely by `IncidentDetailsBloc.general*`.
///
/// [data] is the real `GetIncidentDetails` payload and stays the source of
/// truth for every field here; nothing is mapped back into `CapIncident`.
class _GeneralTab extends StatelessWidget {
  const _GeneralTab({
    required this.data,
    required this.loading,
    required this.failure,
    required this.onRetry,
    required this.status,
  });

  final IncidentDetailsData? data;
  final bool loading;
  final Failure? failure;
  final VoidCallback onRetry;

  /// Still the prototype action workflow's status; header and actions keep
  /// using it until the action APIs land.
  final CapIncidentStatus status;

  /// Directions come from the API location, never from `MockData.towerSites`.
  Future<void> _openDirections(BuildContext context) async {
    final latitude = data?.location?.latitude;
    final longitude = data?.location?.longitude;
    if (latitude == null || longitude == null) {
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

    final destination = '$latitude,$longitude';
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
  Widget build(BuildContext context) {
    // First load: placeholder only inside this tab, so the AppBar, header, tab
    // bar and action area stay visible. It also covers the single idle frame
    // before the initial dispatch reaches the bloc.
    final details = data;
    if (details == null) {
      if (failure != null) {
        return _GeneralTabError(message: failure!.message, onRetry: onRetry);
      }
      return const _GeneralTabSkeleton();
    }

    final location = details.location;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // Refresh and post-refresh failure indicators are non-blocking: the last
        // successful payload stays on screen.
        if (loading || failure != null)
          _TabNotice(
            loading: loading,
            message: failure?.message,
            onRetry: onRetry,
          ),
        if (loading || failure != null) const SizedBox(height: 13),
        SectionCard(
          title: context.tr('Core information', 'المعلومات الأساسية'),
          icon: Icons.assignment_outlined,
          child: Column(
            children: [
              InfoRow(
                icon: Icons.tag,
                label: context.tr('Incident Number', 'رقم البلاغ'),
                value: _orDash(details.incidentNo),
              ),
              InfoRow(
                icon: Icons.category_outlined,
                label: context.tr('Incident Type', 'نوع البلاغ'),
                value: _orDash(details.incidentType?.name),
              ),
              InfoRow(
                icon: Icons.title,
                label: context.tr('Title', 'العنوان'),
                value: _orDash(details.title),
              ),
              InfoRow(
                icon: Icons.sync_alt,
                label: context.tr('Current Status', 'الحالة الحالية'),
                value: _orDash(details.status?.name),
              ),
              InfoRow(
                icon: Icons.person_outline,
                label: context.tr('Current User', 'المستخدم الحالي'),
                value: _orDash(details.assignedEngineer?.name),
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
                value: _orDash(location?.name),
              ),
              InfoRow(
                icon: Icons.qr_code,
                label: context.tr('Site Code', 'كود الموقع'),
                value: _orDash(location?.id),
              ),
              InfoRow(
                icon: Icons.public,
                label: context.tr('Region', 'الإقليم'),
                value: _orDash(location?.region?.name),
              ),
              InfoRow(
                icon: Icons.map_outlined,
                label: context.tr('Area', 'المنطقة'),
                value: _orDash(location?.area?.name),
              ),
              const SizedBox(height: 10),
              //   MiniLocationCard(site: ...),
              const SizedBox(height: 12),
              _ModernDirectionsButton(
                siteName: _orDash(location?.name),
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
                value: _orDash(details.productName),
              ),
              InfoRow(
                icon: Icons.account_tree_outlined,
                label: context.tr('Native MO Name', 'اسم MO الأصلي'),
                value: _orDash(details.nativeMoName),
              ),
              InfoRow(
                icon: Icons.notifications_active_outlined,
                label: context.tr('Notification Type', 'نوع الإشعار'),
                value: _orDash(details.notificationType?.name),
              ),
              InfoRow(
                icon: Icons.event_outlined,
                label: context.tr('Created Date', 'تاريخ الإنشاء'),
                value: _apiDate(details.createdDate),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        SectionCard(
          title: context.tr('Description', 'الوصف'),
          icon: Icons.notes,
          child: Text(
            _orDash(details.description),
            style: AppTypography.body.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

/// Placeholder shown inside the General tab on its first load.
class _GeneralTabSkeleton extends StatelessWidget {
  const _GeneralTabSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: const [
      _GeneralSkeletonCard(rows: 5),
      SizedBox(height: 13),
      _GeneralSkeletonCard(rows: 4, trailing: true),
      SizedBox(height: 13),
      _GeneralSkeletonCard(rows: 4),
      SizedBox(height: 13),
      _GeneralSkeletonCard(rows: 3),
    ],
  );
}

class _GeneralSkeletonCard extends StatelessWidget {
  const _GeneralSkeletonCard({required this.rows, this.trailing = false});

  final int rows;

  /// Reserves the space the directions button occupies in the loaded layout so
  /// the transition does not shift the card.
  final bool trailing;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: '',
    icon: Icons.circle_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBox(width: 120, height: 12, radius: 6),
        const SizedBox(height: 18),
        for (var i = 0; i < rows; i++) ...[
          const SkeletonBox(height: 10, radius: 5),
          const SizedBox(height: 14),
        ],
        if (trailing) const SkeletonBox(width: 150, height: 40, radius: 20),
      ],
    ),
  );
}

/// Full-tab error state, used when a load failed with no data to fall back on.
class _GeneralTabError extends StatelessWidget {
  const _GeneralTabError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    // Scrollable so a long backend message cannot overflow a short tab.
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(context.tr('Retry', 'إعادة المحاولة')),
          ),
        ],
      ),
    ),
  );
}

/// Slim, non-blocking strip for refreshing and for failures that still have
/// data on screen.
class _TabNotice extends StatelessWidget {
  const _TabNotice({
    required this.loading,
    required this.message,
    required this.onRetry,
  });

  final bool loading;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = message != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: (failed ? AppColors.error : AppColors.orange).withValues(
          alpha: .09,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (loading && !failed)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              failed ? Icons.error_outline : Icons.refresh,
              size: 16,
              color: failed ? AppColors.error : AppColors.orange,
            ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              failed ? message! : context.tr('Refreshing…', 'جارٍ التحديث…'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                fontSize: 12,
                color: failed ? AppColors.error : AppColors.muted,
              ),
            ),
          ),
          if (failed)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.error,
              ),
              child: Text(context.tr('Retry', 'إعادة المحاولة')),
            ),
        ],
      ),
    );
  }
}

class _ModernDirectionsButton extends StatelessWidget {
  const _ModernDirectionsButton({
    required this.siteName,
    required this.onPressed,
  });

  final String siteName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      label: context.tr('Open tower directions', 'فتح اتجاهات البرج'),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? const [Color(0xFF292929), Color(0xFF202020)]
                  : const [Colors.white, Color(0xFFFFF6ED)],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.orange.withValues(alpha: dark ? .5 : .32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: dark ? .12 : .16),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.orange, Color(0xFFFF9D35)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange.withValues(alpha: .28),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.assistant_direction_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                context.tr(
                                  'Directions to Tower',
                                  'الاتجاه إلى البرج',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.section.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withValues(alpha: .13),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                context.tr('MAP', 'الخريطة'),
                                style: AppTypography.meta.copyWith(
                                  color: AppColors.orangeDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          siteName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta.copyWith(
                            color: dark ? Colors.white70 : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.arrow_back_rounded
                          : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Timeline panel, driven by `GetIncidentTimeline` through the bloc.
///
/// Renders the API payload directly: every returned event is a historical entry
/// that already happened, so all of them draw as completed. There is no
/// `completed` flag on the contract and none is invented - `actionType` and
/// `eventType` describe what the event was, not how far a workflow has
/// progressed, so deriving completion from them would be a guess.
class _TimelineTab extends StatelessWidget {
  const _TimelineTab({
    required this.data,
    required this.loading,
    required this.failure,
    required this.onRetry,
  });

  final IncidentTimelineData? data;
  final bool loading;
  final Failure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // No payload yet: an initial failure outranks the skeleton so Retry is
    // reachable, otherwise the panel waits in its first-load state.
    if (data == null) {
      if (failure != null) {
        return _TimelineTabError(message: failure!.message, onRetry: onRetry);
      }
      return const _TimelineTabSkeleton();
    }

    // A payload exists, so refresh and refresh-failure both keep the events
    // already on screen and only add a non-blocking strip above them.
    final events = data!.events ?? const <IncidentTimelineEventDto>[];
    return ListView(
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
              '${events.length} of ${events.length}',
              style: AppTypography.meta.copyWith(color: AppColors.muted),
            ),
          ],
        ),
        _TabNotice(
          loading: loading,
          message: failure?.message,
          onRetry: onRetry,
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: _TimelineEmptyState(),
          )
        else ...[
          const SizedBox(height: 20),
          // Backend order is preserved as received; the panel does not re-sort.
          ...List.generate(
            events.length,
            (index) => _HistoryItem(
              event: events[index],
              last: index == events.length - 1,
            ),
          ),
        ],
      ],
    );
  }
}

/// One timeline entry.
///
/// The visual design is unchanged from the prototype: rail, marker, card, title
/// with date, user row, remarks. Only the data source changed - it now reads
/// [IncidentTimelineEventDto] instead of the prototype `IncidentHistoryEvent`.
///
/// Every entry draws as completed because the API only returns events that have
/// already happened.
class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.event, required this.last});

  final IncidentTimelineEventDto event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.orange;
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
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 17, color: Colors.white),
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
                              _eventTitle(event),
                              style: AppTypography.section,
                            ),
                          ),
                          Text(
                            _apiDate(event.dateTime),
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
                              _orDash(event.performedBy?.name),
                              style: AppTypography.meta.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _orDash(event.eventDescription),
                        style: AppTypography.body.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      if (_eventTransition(event) != null) ...[
                        const SizedBox(height: 9),
                        Text(
                          _eventTransition(event)!,
                          style: AppTypography.meta.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
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

/// Title shown on the card.
///
/// Prefers the API's own `eventTitle` and falls back through `actionType.name`
/// and `eventType` before giving up. API text is rendered as sent - it is never
/// run through the prototype localization helpers, which only know the old
/// hardcoded action vocabulary.
String _eventTitle(IncidentTimelineEventDto event) {
  final candidates = [
    event.eventTitle?.trim(),
    event.actionType?.name?.trim(),
    event.eventType?.trim(),
  ];
  for (final candidate in candidates) {
    if (candidate != null && candidate.isNotEmpty) return candidate;
  }
  return '-';
}

/// `oldValue` to `newValue` when the backend sent both, as supplementary text.
///
/// Optional: an event without a transition simply omits the line rather than
/// rendering an empty or placeholder row.
String? _eventTransition(IncidentTimelineEventDto event) {
  final from = event.oldValue?.name?.trim();
  final to = event.newValue?.name?.trim();
  final hasFrom = from != null && from.isNotEmpty;
  final hasTo = to != null && to.isNotEmpty;
  if (!hasFrom && !hasTo) return null;
  return '${hasFrom ? from : '-'} \u2192 ${hasTo ? to : '-'}';
}

/// Shown when the API succeeds but the incident has no history yet.
///
/// This is a success, not an error, so it carries no retry affordance.
class _TimelineEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          const Icon(Icons.timeline_outlined, size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            context.tr('No timeline events', 'لا توجد أحداث في الخط الزمني'),
            style: AppTypography.body.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

/// Skeleton shaped like the timeline it stands in for: a title row, then a
/// vertical rail with a marker dot and a card per entry.
class _TimelineTabSkeleton extends StatelessWidget {
  const _TimelineTabSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
    children: [
      Row(
        children: const [
          Expanded(child: SkeletonBox(height: 14, radius: 7)),
          SizedBox(width: 44),
          SkeletonBox(width: 34, height: 11, radius: 5),
        ],
      ),
      const SizedBox(height: 24),
      _TimelineSkeletonItem(),
      _TimelineSkeletonItem(),
      _TimelineSkeletonItem(last: true),
    ],
  );
}

class _TimelineSkeletonItem extends StatelessWidget {
  const _TimelineSkeletonItem({this.last = false});

  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 38,
          child: Column(
            children: [
              const SkeletonBox(width: 32, height: 32, radius: 16),
              if (!last)
                Expanded(child: Container(width: 2, color: AppColors.border)),
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
                  children: const [
                    SkeletonBox(width: 132, height: 12, radius: 6),
                    SizedBox(height: 14),
                    SkeletonBox(width: 92, height: 10, radius: 5),
                    SizedBox(height: 14),
                    SkeletonBox(height: 10, radius: 5),
                    SizedBox(height: 8),
                    SkeletonBox(width: 150, height: 10, radius: 5),
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

class _TimelineTabError extends StatelessWidget {
  const _TimelineTabError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    // Scrollable so a long backend message cannot overflow a short tab.
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(context.tr('Retry', 'إعادة المحاولة')),
          ),
        ],
      ),
    ),
  );
}

/// Related Requests panel, driven entirely by `GetIncidentRequests`.
///
/// Consumes the API DTOs directly ([IncidentRequestsData] /
/// [IncidentRequestItemDto]) instead of the prototype `RelatedRequest` model, so
/// nothing on screen has to be invented to satisfy the old shape.
class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.data,
    required this.loading,
    required this.failure,
    required this.onRetry,
  });

  final IncidentRequestsData? data;
  final bool loading;
  final Failure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // First load: placeholder only inside this tab, so the AppBar, header, tab
    // bar and action area stay visible. It also covers the idle frame before the
    // first dispatch reaches the bloc.
    final requests = data;
    if (requests == null) {
      if (failure != null) {
        return _RequestsTabError(message: failure!.message, onRetry: onRetry);
      }
      return const _RequestsTabSkeleton();
    }

    final items = requests.items ?? const <IncidentRequestItemDto>[];
    if (items.isEmpty) {
      // An empty list is a successful response, not a failure.
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          const _RequestsTabHeader(),
          const SizedBox(height: 18),
          _RequestsEmptyState(
            // Surfaces a backend that answers with no rows for an incident that
            // does have requests, without turning it into an error.
            message: failure?.message,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      children: [
        // Refresh and post-refresh failure indicators are non-blocking: the last
        // successful list stays on screen.
        if (loading || failure != null) ...[
          _TabNotice(
            loading: loading,
            message: failure?.message,
            onRetry: onRetry,
          ),
          const SizedBox(height: 13),
        ],
        const _RequestsTabHeader(),
        const SizedBox(height: 18),
        for (final group in _groupRequestsByType(items)) ...[
          _RequestGroupHeader(
            typeName: group.typeName,
            count: group.items.length,
          ),
          const SizedBox(height: 9),
          for (final item in group.items) _RequestCard(item: item),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// Title block shared by the loaded and empty states.
class _RequestsTabHeader extends StatelessWidget {
  const _RequestsTabHeader();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
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
    ],
  );
}

/// One request as returned by the API.
///
/// No tap target: `RequestDetailsScreen` needs a full `MyRequest` (questionnaire,
/// renewal minutes, serial, attachments) that `GetIncidentRequests` does not
/// return, and fabricating those from `MockData` would show invented data as
/// real. Navigation returns with the `GetRequestDetails` API.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item});

  final IncidentRequestItemDto item;

  @override
  Widget build(BuildContext context) {
    final statusName = item.requestStatus?.name?.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    // The API exposes a numeric request id, not a request
                    // number, so it is labelled as an id and never dressed up as
                    // something like "REQ-1".
                    context.tr(
                      'Request ID: ${item.id ?? '-'}',
                      'رقم الطلب: ${item.id ?? '-'}',
                    ),
                    style: AppTypography.label.copyWith(
                      color: AppColors.orangeDark,
                    ),
                  ),
                ),
                _RequestStatusChip(statusName: statusName),
              ],
            ),
            const SizedBox(height: 11),
            _RequestRow(
              icon: Icons.category_outlined,
              label: context.tr('Type', 'النوع'),
              value: _orDash(item.requestType?.name),
            ),
            const SizedBox(height: 7),
            _RequestRow(
              icon: Icons.schedule,
              label: context.tr('Date', 'التاريخ'),
              value: _apiDate(item.createdDate),
            ),
            const SizedBox(height: 7),
            _RequestRow(
              icon: Icons.person_outline,
              label: context.tr('Created By', 'أنشأه'),
              value: _orDash(item.createdBy?.name),
            ),
            const SizedBox(height: 7),
            _RequestRow(
              icon: Icons.notes_outlined,
              label: context.tr('Remark', 'ملاحظات'),
              value: _orDash(item.remark),
            ),
            const SizedBox(height: 7),
            _RequestRow(
              icon: Icons.person_pin_circle_outlined,
              label: context.tr('Last Modified By', 'آخر تعديل بواسطة'),
              value: _orDash(item.lastModifiedBy?.name),
            ),
            const SizedBox(height: 7),
            _RequestRow(
              icon: Icons.update,
              label: context.tr('Last Modified Date', 'تاريخ آخر تعديل'),
              value: _apiDate(item.lastModifiedDate),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status pill that keeps the existing colour language and degrades to a neutral
/// tone for statuses the API adds later.
class _RequestStatusChip extends StatelessWidget {
  const _RequestStatusChip({required this.statusName});

  final String? statusName;

  @override
  Widget build(BuildContext context) {
    final name = statusName ?? '';
    final color = switch (name.toLowerCase()) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        _requestStatus(context, name),
        style: AppTypography.meta.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Group header for one request type, keeping the previous grouped layout.
///
/// The title is the API's own `requestType.name`; unknown types are grouped and
/// shown rather than dropped, and only the icon falls back to a generic one.
class _RequestGroupHeader extends StatelessWidget {
  const _RequestGroupHeader({required this.typeName, required this.count});

  final String? typeName;
  final int count;

  @override
  Widget build(BuildContext context) {
    final title = typeName?.trim();
    return Row(
      children: [
        Icon(_requestIconForType(title), size: 19, color: AppColors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title == null || title.isEmpty
                ? context.tr('Requests', 'الطلبات')
                : title,
            style: AppTypography.section,
          ),
        ),
        Text(
          '$count',
          style: AppTypography.meta.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Placeholder shown inside the Related Requests tab on its first load.
class _RequestsTabSkeleton extends StatelessWidget {
  const _RequestsTabSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
    children: const [
      _RequestsTabHeader(),
      SizedBox(height: 18),
      _RequestSkeletonCard(),
      SizedBox(height: 20),
      _RequestSkeletonCard(),
    ],
  );
}

class _RequestSkeletonCard extends StatelessWidget {
  const _RequestSkeletonCard();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(width: 130, height: 12, radius: 6),
          SizedBox(height: 18),
          SkeletonBox(height: 10, radius: 5),
          SizedBox(height: 14),
          SkeletonBox(height: 10, radius: 5),
          SizedBox(height: 14),
          SkeletonBox(width: 200, height: 10, radius: 5),
        ],
      ),
    ),
  );
}

/// Full-tab error state, used when a load failed with no data to fall back on.
class _RequestsTabError extends StatelessWidget {
  const _RequestsTabError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    // Scrollable so a long backend message cannot overflow a short tab.
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(context.tr('Retry', 'إعادة المحاولة')),
          ),
        ],
      ),
    ),
  );
}

/// Success-with-no-rows state. Deliberately not an error: the backend answered
/// correctly and simply has nothing linked to this incident.
class _RequestsEmptyState extends StatelessWidget {
  const _RequestsEmptyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 12),
    child: Column(
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 40,
          color: AppColors.muted.withValues(alpha: .7),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('No related requests', 'لا توجد طلبات مرتبطة'),
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.muted),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppTypography.meta.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}

/// Requests bucketed by the type name the API returned, preserving the order the
/// types first appear in so the grouping stays stable across refreshes.
class _RequestGroup {
  const _RequestGroup({required this.typeName, required this.items});

  final String? typeName;
  final List<IncidentRequestItemDto> items;
}

List<_RequestGroup> _groupRequestsByType(List<IncidentRequestItemDto> items) {
  final order = <String?>{};
  final grouped = <String?, List<IncidentRequestItemDto>>{};
  for (final item in items) {
    final name = item.requestType?.name?.trim();
    final key = name == null || name.isEmpty ? null : name;
    if (!grouped.containsKey(key)) {
      grouped[key] = <IncidentRequestItemDto>[];
      order.add(key);
    }
    grouped[key]!.add(item);
  }
  return [
    for (final key in order) _RequestGroup(typeName: key, items: grouped[key]!),
  ];
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

/// Icon for a request type, keyed on the API's `requestType.name`.
///
/// Matching on the display name rather than a numeric id keeps unknown types
/// working: they simply fall through to the generic icon instead of being
/// dropped or forced into a guessed mapping.
IconData _requestIconForType(String? typeName) =>
    switch (typeName?.trim().toLowerCase()) {
      'intervention request' => Icons.build_circle_outlined,
      'renewal request' => Icons.autorenew,
      'departure request' => Icons.logout,
      _ => Icons.description_outlined,
    };

/// Placeholder for API fields that arrived empty or null, so the UI never
/// renders the literal text "null".
String _orDash(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? '-' : trimmed;
}

/// Formats a CAP date string for display.
///
/// The API sends dates as strings whose exact shape has not been confirmed, so
/// anything unparseable is returned trimmed and unchanged rather than guessed
/// at. Needs Verification: the accepted date format should be pinned once a live
/// `GetIncidentDetails` payload is available.
String _apiDate(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return '-';
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return trimmed;
  final hour = parsed.hour > 12 ? parsed.hour - 12 : parsed.hour;
  final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
  return '${parsed.day.toString().padLeft(2, '0')}/'
      '${parsed.month.toString().padLeft(2, '0')}/${parsed.year} • '
      '${hour.toString().padLeft(2, '0')}:'
      '${parsed.minute.toString().padLeft(2, '0')} $suffix';
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

String _requestStatus(BuildContext context, String status) => switch (status) {
  'Approved' => context.tr('Approved', 'موافق عليه'),
  'Rejected' => context.tr('Rejected', 'مرفوض'),
  'Draft' => context.tr('Draft', 'مسودة'),
  'Pending Approval' => context.tr('Pending Approval', 'بانتظار الموافقة'),
  _ => status,
};
