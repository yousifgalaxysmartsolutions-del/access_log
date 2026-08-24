import 'package:flutter/material.dart';

import '../../ai_copilot/ai_copilot_models.dart';
import '../../ai_copilot/ai_copilot_screen.dart';
import '../../ai_copilot/ai_copilot_service.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/app_button.dart';
import '../../widgets/background_simulation_components.dart';
import '../../widgets/dynamic_questionnaire.dart';
import '../../widgets/evidence_collection.dart';
import '../../widgets/location_validation.dart';
import '../../widgets/section_card.dart';
import '../../widgets/session_timeout_ui.dart';
import '../auth/auth_screens.dart';
import '../incidents/incident_details_screen.dart';
import '../more/more_screens.dart';
import '../requests/my_requests_screen.dart';

class PrototypeDemoScreen extends StatelessWidget {
  const PrototypeDemoScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  CapIncident _incident(CapIncidentStatus status) =>
      MockData.capIncidents.firstWhere((item) => item.status == status);

  MyRequest _request(MyRequestStatus status) => MockData.myRequests.firstWhere(
    (item) => item.status == status,
    orElse: () => MyRequest(
      number: 'REQ-DEMO-${status.name.toUpperCase()}',
      type: RelatedRequestType.intervention,
      status: status,
      incidentNumber: MockData.capIncidents.first.number,
      siteName: 'Cairo Central Site',
      siteCode: 'CAI-CORE-014',
      createdDate: DateTime(2026, 8, 11, 9, 45),
      createdBy: MockData.engineer.name,
      questionnaireSummary: 'Prototype state preview.',
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Prototype Demo', 'عرض النموذج')),
      actions: [
        Container(
          margin: const EdgeInsetsDirectional.only(end: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            'DEV ONLY',
            style: AppTypography.meta.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
      children: [
        _DemoHero(),
        const SizedBox(height: 22),
        _DemoSection(
          title: 'CLIENT DEMO SCENARIOS',
          icon: Icons.play_circle_outline,
          items: MockData.prototypeScenarios
              .map(
                (scenario) => _item(
                  scenario.title,
                  _scenarioIcon(scenario.type),
                  () => _open(
                    context,
                    IncidentDetailsScreen(
                      incident: MockData.incidentForScenario(scenario.type),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        _DemoSection(
          title: 'AI COPILOT STATES',
          icon: Icons.auto_awesome,
          items: [
            _item(
              'Groq Copilot',
              Icons.cloud_outlined,
              () => _open(
                context,
                AiCopilotScreen(incident: MockData.capIncidents.first),
              ),
            ),
            _item(
              'Local Mock Fallback',
              Icons.offline_bolt_outlined,
              () => _open(
                context,
                AiCopilotScreen(
                  incident: MockData.capIncidents.first,
                  client: AiCopilotService(mode: AiCopilotMode.mock),
                ),
              ),
              color: AppColors.info,
            ),
          ],
        ),
        _DemoSection(
          title: 'AUTHENTICATION STATES',
          icon: Icons.lock_person_outlined,
          items: [
            _item(
              'Normal Login',
              Icons.login,
              () => _open(context, const LoginScreen()),
            ),
            _item(
              'Loading',
              Icons.hourglass_top,
              () => _open(
                context,
                const LoginScreen(initialPreview: LoginPreviewState.loading),
              ),
            ),
            _item(
              'Invalid Credentials',
              Icons.error_outline,
              () => _open(
                context,
                const LoginScreen(initialPreview: LoginPreviewState.invalid),
              ),
            ),
            _item(
              'Inactive User',
              Icons.person_off_outlined,
              () => _open(
                context,
                const LoginScreen(initialPreview: LoginPreviewState.inactive),
              ),
            ),
            _item(
              'Unauthorized Device',
              Icons.phonelink_lock_outlined,
              () => _open(
                context,
                const LoginScreen(
                  initialPreview: LoginPreviewState.unauthorized,
                ),
              ),
            ),
          ],
        ),
        _DemoSection(
          title: 'SESSION STATES',
          icon: Icons.timer_outlined,
          items: [
            _item(
              'Session Warning',
              Icons.timer_outlined,
              () => showSessionExpirationWarning(context),
              color: AppColors.warning,
            ),
            _item(
              'Session Expired',
              Icons.lock_clock_outlined,
              () => _open(context, const SessionReturnSimulationScreen()),
              color: AppColors.error,
            ),
            _item(
              'Active Intervention Logout Warning',
              Icons.engineering_outlined,
              () async {
                final logout = await showActiveInterventionLogoutWarning(
                  context,
                );
                if (logout && context.mounted) {
                  navigateToSecureLogin(context);
                }
              },
              color: AppColors.orange,
            ),
          ],
        ),
        _DemoSection(
          title: 'INCIDENT STATES',
          icon: Icons.assignment_outlined,
          items: CapIncidentStatus.values
              .map(
                (status) => _item(
                  _incidentLabel(status),
                  _incidentIcon(status),
                  () => _open(
                    context,
                    IncidentDetailsScreen(incident: _incident(status)),
                  ),
                  color: _incidentColor(status),
                ),
              )
              .toList(),
        ),
        _DemoSection(
          title: 'LOCATION STATES',
          icon: Icons.my_location,
          items: [
            _locationItem(context, 'Checking', LocationCheckState.checking),
            _locationItem(
              context,
              'Inside Geofence',
              LocationCheckState.verified,
            ),
            _locationItem(
              context,
              'Outside Geofence',
              LocationCheckState.outside,
            ),
            _locationItem(
              context,
              'GPS unavailable',
              LocationCheckState.unavailable,
            ),
          ],
        ),
        _DemoSection(
          title: 'REQUEST STATES',
          icon: Icons.inbox_outlined,
          items: MyRequestStatus.values
              .map(
                (status) => _item(
                  _requestLabel(status),
                  Icons.description_outlined,
                  () => _open(
                    context,
                    RequestDetailsScreen(request: _request(status)),
                  ),
                  color: _requestColor(status),
                ),
              )
              .toList(),
        ),
        _DemoSection(
          title: 'PHOTO STATES',
          icon: Icons.photo_library_outlined,
          items: [
            _item(
              'No photos',
              Icons.photo_outlined,
              () => _open(
                context,
                const _PhotoStateScreen(title: 'No photos', optional: true),
              ),
            ),
            _item(
              'Photo required',
              Icons.add_a_photo_outlined,
              () => _open(
                context,
                const _PhotoStateScreen(title: 'Photo required'),
              ),
            ),
            _item(
              'Photos captured',
              Icons.collections_outlined,
              () => _open(
                context,
                const _PhotoStateScreen(
                  title: 'Photos captured',
                  initialCount: 2,
                ),
              ),
            ),
            _item(
              'Photo reminder',
              Icons.notification_important_outlined,
              () => _open(context, const _PhotoReminderDemo()),
              color: AppColors.warning,
            ),
          ],
        ),
        _DemoSection(
          title: 'SYNC VISUAL STATES',
          icon: Icons.sync,
          items: [
            _item(
              'Online',
              Icons.cloud_done_outlined,
              () => _open(
                context,
                const _SyncStateScreen(state: _SyncState.online),
              ),
              color: AppColors.success,
            ),
            _item(
              'Offline',
              Icons.cloud_off_outlined,
              () => _open(
                context,
                const _SyncStateScreen(state: _SyncState.offline),
              ),
              color: AppColors.error,
            ),
            _item(
              'Pending Sync',
              Icons.cloud_upload_outlined,
              () => _open(
                context,
                const _SyncStateScreen(state: _SyncState.pending),
              ),
              color: AppColors.warning,
            ),
          ],
        ),
        _DemoSection(
          title: 'FORM STATES',
          icon: Icons.dynamic_form_outlined,
          items: [
            _item(
              'Empty',
              Icons.article_outlined,
              () => _open(
                context,
                const _FormStateScreen(state: _FormState.empty),
              ),
            ),
            _item(
              'Partially completed',
              Icons.pending_actions_outlined,
              () => _open(
                context,
                const _FormStateScreen(state: _FormState.partial),
              ),
              color: AppColors.warning,
            ),
            _item(
              'Validation errors',
              Icons.report_gmailerrorred,
              () => _open(
                context,
                const _FormStateScreen(state: _FormState.errors),
              ),
              color: AppColors.error,
            ),
            _item(
              'Completed',
              Icons.task_alt,
              () => _open(
                context,
                const _FormStateScreen(state: _FormState.completed),
              ),
              color: AppColors.success,
            ),
          ],
        ),
        _DemoSection(
          title: 'NOTIFICATION STATES',
          icon: Icons.notifications_outlined,
          items: [
            _item(
              'Read',
              Icons.mark_email_read_outlined,
              () => _open(context, const _NotificationStateScreen(read: true)),
            ),
            _item(
              'Unread',
              Icons.mark_email_unread_outlined,
              () => _open(context, const _NotificationStateScreen()),
              color: AppColors.orange,
            ),
            _item(
              'GPS Warning',
              Icons.gps_off,
              () => _open(
                context,
                const LocationValidationScreen(
                  initialState: LocationCheckState.outside,
                ),
              ),
              color: AppColors.error,
            ),
            _item(
              'SOC Message',
              Icons.security_outlined,
              () => _open(
                context,
                MessageDetailsScreen(
                  notification: _notification(AppNotificationType.socMessage),
                  announcement: false,
                ),
              ),
              color: AppColors.purple,
            ),
            _item(
              'Photo Reminder',
              Icons.add_a_photo_outlined,
              () => _open(context, const _PhotoReminderDemo()),
              color: AppColors.warning,
            ),
          ],
        ),
      ],
    ),
  );

  _DemoItem _locationItem(
    BuildContext context,
    String label,
    LocationCheckState state,
  ) => _item(
    label,
    Icons.location_on_outlined,
    () => _open(context, LocationValidationScreen(initialState: state)),
  );

  _DemoItem _item(
    String label,
    IconData icon,
    VoidCallback onTap, {
    Color color = AppColors.orange,
  }) => _DemoItem(label: label, icon: icon, color: color, onTap: onTap);
}

class _DemoHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF111111), Color(0xFF2C2C2C)],
      ),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.science_outlined, color: AppColors.orange, size: 34),
        const SizedBox(height: 14),
        Text(
          context.tr('UI State Gallery', 'معرض حالات الواجهة'),
          style: AppTypography.display.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 7),
        Text(
          context.tr(
            'Quickly preview prototype states. No system behavior is connected.',
            'معاينة سريعة لحالات النموذج. لا يوجد سلوك نظام متصل.',
          ),
          style: AppTypography.body.copyWith(color: Colors.white60),
        ),
      ],
    ),
  );
}

IconData _scenarioIcon(PrototypeScenarioType type) => switch (type) {
  PrototypeScenarioType.newAssignment => Icons.person_add_alt_outlined,
  PrototypeScenarioType.pendingApproval => Icons.fact_check_outlined,
  PrototypeScenarioType.activeIntervention => Icons.engineering_outlined,
  PrototypeScenarioType.taskOnHold => Icons.pause_circle_outline,
  PrototypeScenarioType.readyToComplete => Icons.task_alt,
};

class _DemoSection extends StatelessWidget {
  const _DemoSection({
    required this.title,
    required this.icon,
    required this.items,
  });
  final String title;
  final IconData icon;
  final List<_DemoItem> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.orange, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTypography.meta.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: List.generate(
              items.length,
              (index) => Column(
                children: [
                  ListTile(
                    onTap: items[index].onTap,
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: items[index].color.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        items[index].icon,
                        color: items[index].color,
                        size: 20,
                      ),
                    ),
                    title: Text(items[index].label, style: AppTypography.label),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.muted,
                    ),
                  ),
                  if (index < items.length - 1)
                    const Divider(height: 1, indent: 64),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DemoItem {
  const _DemoItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _PhotoStateScreen extends StatelessWidget {
  const _PhotoStateScreen({
    required this.title,
    this.optional = false,
    this.initialCount = 0,
  });
  final String title;
  final bool optional;
  final int initialCount;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MockPhotoPicker(
          title: title,
          optional: optional,
          initialPhotoCount: initialCount,
        ),
      ],
    ),
  );
}

class _PhotoReminderDemo extends StatefulWidget {
  const _PhotoReminderDemo();
  @override
  State<_PhotoReminderDemo> createState() => _PhotoReminderDemoState();
}

class _PhotoReminderDemoState extends State<_PhotoReminderDemo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showPhotoReminder(
        context,
        incidentNumber: 'INC-2026-1001',
        site: 'Cairo Central Site',
        onCapture: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PhotoCaptureScreen()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Photo Reminder')),
    body: const Center(
      child: Icon(
        Icons.notifications_active_outlined,
        size: 64,
        color: AppColors.warning,
      ),
    ),
  );
}

enum _SyncState { online, offline, pending }

class _SyncStateScreen extends StatelessWidget {
  const _SyncStateScreen({required this.state});
  final _SyncState state;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon, color) = switch (state) {
      _SyncState.online => (
        'Online',
        'All prototype data is up to date.',
        Icons.cloud_done_outlined,
        AppColors.success,
      ),
      _SyncState.offline => (
        'Offline',
        'Changes remain safely in this mock session.',
        Icons.cloud_off_outlined,
        AppColors.error,
      ),
      _SyncState.pending => (
        'Pending Sync',
        '3 prototype changes are waiting to sync.',
        Icons.cloud_upload_outlined,
        AppColors.warning,
      ),
    };
    return _CenteredStateScreen(
      title: title,
      message: message,
      icon: icon,
      color: color,
    );
  }
}

enum _FormState { empty, partial, errors, completed }

class _FormStateScreen extends StatelessWidget {
  const _FormStateScreen({required this.state});
  final _FormState state;

  @override
  Widget build(BuildContext context) {
    if (state == _FormState.empty) {
      return const Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: DynamicQuestionnaireView(),
          ),
        ),
      );
    }
    final (title, value, error, complete) = switch (state) {
      _FormState.partial => (
        'Partially completed',
        'Voltage checked; notes pending',
        null,
        false,
      ),
      _FormState.errors => (
        'Validation errors',
        '',
        'This required field must be completed',
        false,
      ),
      _FormState.completed => (
        'Completed',
        'All operational checks completed',
        null,
        true,
      ),
      _ => ('Empty', '', null, false),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Form preview',
            icon: Icons.dynamic_form_outlined,
            child: Column(
              children: [
                TextFormField(
                  initialValue: value,
                  decoration: InputDecoration(
                    labelText: 'Technician observation *',
                    errorText: error,
                    helperText: complete
                        ? 'Validated and ready'
                        : 'Required field',
                  ),
                  readOnly: complete,
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: complete ? 1 : .5,
                  color: complete ? AppColors.success : AppColors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: complete ? 'Completed' : 'Continue',
            icon: complete ? Icons.check : Icons.arrow_forward,
            expanded: true,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _NotificationStateScreen extends StatelessWidget {
  const _NotificationStateScreen({this.read = false});
  final bool read;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(read ? 'Read Notification' : 'Unread Notification'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: read ? null : AppColors.orange.withValues(alpha: .05),
        child: ListTile(
          leading: const Icon(Icons.assignment_add, color: AppColors.orange),
          title: Text(
            'New Assignment',
            style: AppTypography.label.copyWith(
              fontWeight: read ? FontWeight.w600 : FontWeight.w800,
            ),
          ),
          subtitle: const Text(
            'INC-2026-1001 was assigned to you.\n2 minutes ago',
          ),
          trailing: read
              ? const Icon(Icons.done_all, color: AppColors.success)
              : const Icon(Icons.circle, color: AppColors.orange, size: 9),
        ),
      ),
    ),
  );
}

class _CenteredStateScreen extends StatelessWidget {
  const _CenteredStateScreen({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
  final String title, message;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTypography.display,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

String _incidentLabel(CapIncidentStatus status) => switch (status) {
  CapIncidentStatus.needAssign => 'Need Assign',
  CapIncidentStatus.needApproval => 'Need Approval',
  CapIncidentStatus.pending => 'Pending',
  CapIncidentStatus.inProcess => 'In Process',
  CapIncidentStatus.hold => 'Hold',
  CapIncidentStatus.completed => 'Completed',
  CapIncidentStatus.cancelled => 'Cancelled',
};
IconData _incidentIcon(CapIncidentStatus status) => switch (status) {
  CapIncidentStatus.needAssign => Icons.person_add_alt,
  CapIncidentStatus.needApproval => Icons.approval_outlined,
  CapIncidentStatus.pending => Icons.pending_actions,
  CapIncidentStatus.inProcess => Icons.engineering,
  CapIncidentStatus.hold => Icons.pause_circle_outline,
  CapIncidentStatus.completed => Icons.task_alt,
  CapIncidentStatus.cancelled => Icons.cancel_outlined,
};
Color _incidentColor(CapIncidentStatus status) => switch (status) {
  CapIncidentStatus.needAssign => AppColors.info,
  CapIncidentStatus.needApproval => AppColors.purple,
  CapIncidentStatus.pending => AppColors.warning,
  CapIncidentStatus.inProcess => AppColors.orange,
  CapIncidentStatus.hold => AppColors.purple,
  CapIncidentStatus.completed => AppColors.success,
  CapIncidentStatus.cancelled => AppColors.error,
};
String _requestLabel(MyRequestStatus status) =>
    '${status.name[0].toUpperCase()}${status.name.substring(1)}';
Color _requestColor(MyRequestStatus status) => switch (status) {
  MyRequestStatus.pending => AppColors.warning,
  MyRequestStatus.approved => AppColors.info,
  MyRequestStatus.rejected => AppColors.error,
  MyRequestStatus.completed => AppColors.success,
};
AppNotification _notification(AppNotificationType type) =>
    MockData.notifications.firstWhere((item) => item.type == type);
