import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../requests/domain/usecases/incident_request_use_case.dart';
import '../../../core/localization/app_strings.dart';
import '../../../widgets/app_button.dart';
import '../../forms/data/models/cap_form_models.dart';
import '../../forms/presentation/widgets/cap_dynamic_form.dart';
import '../../forms/presentation/widgets/cap_form_capture.dart';
import '../../forms/presentation/widgets/cap_photo_editor.dart';
import '../domain/actions/incident_available_action.dart';
import 'incident_action_flow_factory.dart';
import 'bloc/incident_action_configuration_cubit.dart';

class IncidentActionConfigurationScreen extends StatefulWidget {
  const IncidentActionConfigurationScreen({
    super.key,
    required this.action,
    this.incidentId,
    this.coordinator,
    this.requestNewStatusId = IncidentRequestUseCase.confirmedNewStatusId,
    this.siteLatitude,
    this.siteLongitude,
  });
  final IncidentAvailableAction action;
  final int? incidentId;

  /// Provided explicitly by a confirmed backend execution policy, never UI inference.
  final int? requestNewStatusId;
  final double? siteLatitude, siteLongitude;

  /// This route owns and closes the coordinator, including injected instances.
  final IncidentActionConfigurationCubit? coordinator;
  @override
  State<IncidentActionConfigurationScreen> createState() =>
      _IncidentActionConfigurationScreenState();
}

class _IncidentActionConfigurationScreenState
    extends State<IncidentActionConfigurationScreen> {
  final capture = CapNativeFormCapture();
  late final IncidentActionConfigurationCubit coordinator;
  bool showRemark = false, directStarted = false;
  final _dynamicFormKey = GlobalKey<CapDynamicFormState>();
  final _locationKey = GlobalKey();
  final _photoKey = GlobalKey();
  bool _validating = false;

  Future<void> submitRequest() async {
    if (_validating) return;
    _validating = true;
    try {
      final state = coordinator.state;
      final missingLocation = state.requiresLocation && state.location == null;
      final missingPhoto =
          state.requiresPhoto && (state.photo?.bytes.isEmpty ?? true);
      if (missingLocation || missingPhoto) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              missingLocation
                  ? context.tr(
                      'Capture your location first',
                      'حدّد موقعك أولًا',
                    )
                  : context.tr('Add the required photo', 'أضف الصورة المطلوبة'),
            ),
          ),
        );
        final target =
            (missingLocation ? _locationKey : _photoKey).currentContext;
        if (target != null) {
          await Scrollable.ensureVisible(
            target,
            alignment: 0.1,
            duration: const Duration(milliseconds: 250),
          );
        }
        return;
      }
      if (state.requiresForm &&
          !(await _dynamicFormKey.currentState!.validateAndFocus())) {
        return;
      }
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      await coordinator.continueExecution();
    } finally {
      _validating = false;
    }
  }

  @override
  void initState() {
    super.initState();
    coordinator =
        widget.coordinator ??
        IncidentActionFlowFactory.create(
          action: widget.action,
          incidentId: widget.incidentId,
          requestNewStatusId: widget.requestNewStatusId,
          siteLatitude: widget.siteLatitude,
          siteLongitude: widget.siteLongitude,
          capture: capture,
        );
    if (coordinator.state.stage == ActionConfigurationStage.initial) {
      coordinator.start().then((_) => continueWithoutRequirements());
    } else {
      continueWithoutRequirements();
    }
  }

  void continueWithoutRequirements() {
    if (!mounted ||
        directStarted ||
        !coordinator.hasExecutor ||
        coordinator.submissionBlocked ||
        coordinator.state.hasRequirements ||
        coordinator.state.stage != ActionConfigurationStage.readyToContinue) {
      return;
    }
    directStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) coordinator.continueExecution();
    });
  }

  @override
  void dispose() {
    coordinator.close();
    super.dispose();
  }

  String actionLabel(BuildContext context) => switch (widget.action.type) {
    IncidentAction.assign => context.tr('Continue', 'متابعة'),
    IncidentAction.cancel => context.tr('Cancel incident', 'إلغاء البلاغ'),
    IncidentAction.approve => context.tr('Approve', 'موافقة'),
    IncidentAction.reject => context.tr('Reject', 'رفض'),
    IncidentAction.hold => context.tr('Put on hold', 'تعليق البلاغ'),
    IncidentAction.complete => context.tr('Complete task', 'إكمال المهمة'),
    IncidentAction.interventionRequest ||
    IncidentAction.renewalRequest ||
    IncidentAction.departureRequest => context.tr(
      'Submit request',
      'إرسال الطلب',
    ),
  };
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<IncidentActionConfigurationCubit, ActionConfigurationState>(
    bloc: coordinator,
    listener: (context, state) {
      if (state.stage == ActionConfigurationStage.succeeded) {
        Navigator.pop(context, true);
      }
      continueWithoutRequirements();
    },
    builder: (context, state) {
      final submitting = state.stage == ActionConfigurationStage.submitting;
      final requirements =
          state.hasRequirements &&
          !{
            ActionConfigurationStage.loadingTeam,
            ActionConfigurationStage.selectingTeam,
            ActionConfigurationStage.submitting,
            ActionConfigurationStage.succeeded,
          }.contains(state.stage);
      final selecting = state.stage == ActionConfigurationStage.selectingTeam;
      final working =
          submitting ||
          state.stage == ActionConfigurationStage.loadingTeam ||
          state.stage == ActionConfigurationStage.loadingConfiguration ||
          state.stage == ActionConfigurationStage.initial;
      final enabled =
          !working &&
          !coordinator.submissionBlocked &&
          (coordinator.isRequest
              ? (requirements || state.requirementsValid) &&
                    !state.locationBusy &&
                    !state.photoBusy &&
                    !coordinator.form.state.loading &&
                    state.failure == null &&
                    !state.unknownPhotoPolicy
              : state.execution != null &&
                    (selecting
                        ? state.execution!.assignedUserId != null
                        : state.requirementsValid));
      return PopScope(
        canPop: !submitting,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              selecting
                  ? context.tr('Assign incident', 'إسناد البلاغ')
                  : coordinator.isRequest
                  ? context.tr('Request requirements', 'متطلبات الطلب')
                  : context.tr('Action requirements', 'متطلبات الإجراء'),
            ),
            actions: [
              if (requirements)
                IconButton(
                  tooltip: context.tr('Add remark', 'إضافة ملاحظة'),
                  onPressed: () => setState(() => showRemark = !showRemark),
                  icon: const Icon(Icons.edit_note_outlined),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (coordinator.submissionBlocked)
                            _ErrorNotice(
                              message: context.tr(
                                'You can prepare this request. Submission is unavailable until the backend NewStatusId is confirmed.',
                                'يمكنك تجهيز الطلب، لكن الإرسال غير متاح لحين تأكيد قيمة NewStatusId من فريق الخادم.',
                              ),
                            ),
                          if (working) ...[
                            const SizedBox(height: 40),
                            const Center(child: CircularProgressIndicator()),
                            const SizedBox(height: 16),
                            Text(
                              context.tr(
                                submitting
                                    ? 'Submitting action…'
                                    : 'Preparing action…',
                                submitting
                                    ? 'جارٍ تنفيذ الإجراء…'
                                    : 'جارٍ تجهيز الإجراء…',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (state.failure != null)
                            _ErrorNotice(
                              message: state.failure!.message,
                              onRetry: coordinator.start,
                            ),
                          if (state.executionFailure != null)
                            _ErrorNotice(
                              message: state.executionFailure!.message,
                            ),
                          if (requirements) ...[
                            if (state.requiresLocation)
                              _RequirementCard(
                                key: _locationKey,
                                sectionKey: const ValueKey('location-section'),
                                title: context.tr('Location', 'الموقع'),
                                icon: Icons.my_location,
                                required: true,
                                completed: state.location != null,
                                busy: state.locationBusy,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      state.location == null
                                          ? context.tr(
                                              'Capture your current location',
                                              'حدّد موقعك الحالي',
                                            )
                                          : context.tr(
                                              'Location captured',
                                              'تم تحديد الموقع',
                                            ),
                                    ),
                                    if (state.location != null)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: SelectableText(
                                            state.location!.replaceFirst(
                                              ',',
                                              '  /  ',
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    if (state.locationFailure != null)
                                      _ErrorNotice(
                                        message: state.locationFailure!.message,
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: state.locationBusy
                                          ? null
                                          : coordinator.refreshLocation,
                                      icon: Icon(
                                        state.location == null
                                            ? Icons.my_location
                                            : Icons.refresh,
                                      ),
                                      label: Text(
                                        state.location == null
                                            ? context.tr(
                                                'Capture location',
                                                'تحديد الموقع',
                                              )
                                            : context.tr(
                                                'Refresh location',
                                                'تحديث الموقع',
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (state.requiresPhoto)
                              _RequirementCard(
                                key: _photoKey,
                                sectionKey: const ValueKey('photo-section'),
                                title: context.tr('Photo', 'الصورة'),
                                icon: Icons.photo_camera_outlined,
                                required: true,
                                completed: state.photo != null,
                                busy: state.photoBusy,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: AspectRatio(
                                        aspectRatio: 4 / 3,
                                        child: state.photo == null
                                            ? ColoredBox(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surfaceContainer,
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .add_a_photo_outlined,
                                                      size: 48,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      context.tr(
                                                        'Add a photo',
                                                        'أضف صورة',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : Image.memory(
                                                state.photo!.bytes,
                                                fit: BoxFit.contain,
                                                semanticLabel: context.tr(
                                                  'Captured incident photo',
                                                  'صورة البلاغ الملتقطة',
                                                ),
                                                errorBuilder: (_, _, _) =>
                                                    const Center(
                                                      child: Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        size: 48,
                                                      ),
                                                    ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (state.photoFailure != null)
                                      _ErrorNotice(
                                        message: state.photoFailure!.message,
                                      ),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: state.photoBusy
                                              ? null
                                              : coordinator.capturePhoto,
                                          icon: const Icon(
                                            Icons.photo_camera_outlined,
                                          ),
                                          label: Text(
                                            state.photo == null
                                                ? context.tr(
                                                    'Capture photo',
                                                    'التقاط صورة',
                                                  )
                                                : context.tr(
                                                    'Retake',
                                                    'إعادة التصوير',
                                                  ),
                                          ),
                                        ),
                                        if (state.photo != null) ...[
                                          OutlinedButton.icon(
                                            onPressed: state.photoBusy
                                                ? null
                                                : () => coordinator.editPhoto(
                                                    (photo) =>
                                                        Navigator.push<
                                                          CapFormEvidence
                                                        >(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                CapPhotoEditor(
                                                                  photo: photo,
                                                                ),
                                                          ),
                                                        ),
                                                  ),
                                            icon: const Icon(Icons.crop_rotate),
                                            label: Text(
                                              context.tr('Edit', 'تعديل'),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: state.photoBusy
                                                ? null
                                                : coordinator.removePhoto,
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            label: Text(
                                              context.tr('Remove', 'حذف'),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            if (showRemark || state.remark.isNotEmpty)
                              _RequirementCard(
                                title: context.tr('Remark', 'الملاحظة'),
                                icon: Icons.notes_outlined,
                                required: false,
                                completed: state.remark.trim().isNotEmpty,
                                child: TextFormField(
                                  key: const ValueKey('execution-remark'),
                                  initialValue: state.remark,
                                  minLines: 3,
                                  maxLines: 6,
                                  onChanged: coordinator.setRemark,
                                  decoration: InputDecoration(
                                    hintText: context.tr(
                                      'Add any useful details',
                                      'أضف أي تفاصيل مفيدة',
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            if (state.requiresForm)
                              _RequirementCard(
                                sectionKey: const ValueKey('form-section'),
                                title: context.tr(
                                  'Additional Information',
                                  'معلومات إضافية',
                                ),
                                icon: Icons.description_outlined,
                                required: coordinator
                                    .form
                                    .state
                                    .visibleQuestions
                                    .any((q) => q.required),
                                completed:
                                    coordinator.form.confirmedAnswers(
                                      forSubmission: false,
                                      showErrors: false,
                                    ) !=
                                    null,
                                child: CapDynamicForm(
                                  key: _dynamicFormKey,
                                  cubit: coordinator.form,
                                  embedded: true,
                                  forSubmission: false,
                                  capture: (q) => capture.capture(context, q),
                                  onRetry: coordinator.retryForm,
                                  onConfirmed: (_) =>
                                      coordinator.completeForm(),
                                ),
                              ),
                            if (state.unknownPhotoPolicy)
                              _ErrorNotice(
                                message: context.tr(
                                  'Photo requirements are unavailable. Please try again later.',
                                  'متطلبات الصورة غير متاحة. يرجى المحاولة لاحقًا.',
                                ),
                              ),
                          ],
                          if (selecting) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.group_outlined,
                                    size: 32,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr(
                                      'Choose an engineer',
                                      'اختر المهندس',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.tr(
                                      'Select a team member to assign this incident.',
                                      'اختر أحد أعضاء الفريق لإسناد البلاغ إليه.',
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              context.tr(
                                'Team members (${state.team.length})',
                                'أعضاء الفريق (${state.team.length})',
                              ),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 12),
                            if (state.team.isEmpty)
                              _ErrorNotice(
                                message: context.tr(
                                  'No team members available',
                                  'لا يوجد أعضاء فريق متاحون',
                                ),
                                onRetry: coordinator.retryTeam,
                              ),
                            for (final member in state.team)
                              _TeamMemberCard(
                                name: member.name,
                                userName: member.userName,
                                mobile: member.mobile,
                                selected:
                                    state.execution?.assignedUserId ==
                                    member.id,
                                onTap: () =>
                                    coordinator.selectMember(member.id),
                              ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('assignment-remark'),
                              initialValue: state.execution?.remark ?? '',
                              minLines: 2,
                              maxLines: 4,
                              onChanged: coordinator.setRemark,
                              decoration: InputDecoration(
                                labelText: context.tr(
                                  'Remark (optional)',
                                  'الملاحظة (اختياري)',
                                ),
                                alignLabelWithHint: true,
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (requirements ||
                    selecting ||
                    state.executionFailure != null ||
                    coordinator.submissionBlocked)
                  Material(
                    elevation: 4,
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: AppButton(
                        key: const ValueKey('requirements-continue'),
                        expanded: true,
                        label: selecting
                            ? context.tr('Confirm assignment', 'تأكيد الإسناد')
                            : actionLabel(context),
                        loading: working,
                        onPressed: enabled
                            ? () {
                                if (coordinator.isRequest) {
                                  submitRequest();
                                  return;
                                }
                                FocusScope.of(context).unfocus();
                                coordinator.continueExecution();
                              }
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.name,
    required this.userName,
    required this.mobile,
    required this.selected,
    required this.onTap,
  });

  final String name, userName, mobile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: selected
                        ? colors.primary
                        : colors.secondaryContainer,
                    foregroundColor: selected
                        ? colors.onPrimary
                        : colors.onSecondaryContainer,
                    child: const Icon(Icons.person_outline_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? colors.onPrimaryContainer
                                    : colors.onSurface,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Text(
                              userName,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: selected
                                    ? colors.onPrimaryContainer
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              mobile,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: selected
                                    ? colors.onPrimaryContainer
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? colors.primary : colors.outline,
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

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({
    super.key,
    this.sectionKey,
    required this.title,
    required this.icon,
    required this.required,
    required this.completed,
    this.busy = false,
    required this.child,
  });
  final Key? sectionKey;
  final String title;
  final IconData icon;
  final bool required, completed, busy;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: sectionKey,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (required)
                  Text(
                    context.tr('Required', 'مطلوب'),
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                if (completed && !busy)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 18, color: colors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.tr('Completed', 'مكتمل'),
                          style: TextStyle(color: colors.primary),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('Retry', 'إعادة المحاولة')),
          ),
      ],
    ),
  );
}
