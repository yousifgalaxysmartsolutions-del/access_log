import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/localization/app_strings.dart';
import '../../../widgets/app_button.dart';
import '../../forms/domain/usecases/cap_form_use_cases.dart';
import '../../forms/presentation/bloc/cap_form_cubit.dart';
import '../../forms/presentation/widgets/cap_dynamic_form.dart';
import '../../forms/presentation/widgets/cap_form_capture.dart';
import '../domain/actions/incident_available_action.dart';
import '../domain/usecases/incident_execution_use_case.dart';
import '../domain/usecases/get_incident_action_configuration_use_case.dart';
import 'bloc/incident_action_configuration_cubit.dart';

class IncidentActionConfigurationScreen extends StatefulWidget {
  const IncidentActionConfigurationScreen({
    super.key,
    required this.action,
    this.incidentId,
    this.coordinator,
  });
  final IncidentAvailableAction action;
  final int? incidentId;

  /// Optional test/host injection. This route owns and closes the coordinator.
  final IncidentActionConfigurationCubit? coordinator;
  @override
  State<IncidentActionConfigurationScreen> createState() =>
      _IncidentActionConfigurationScreenState();
}

class _IncidentActionConfigurationScreenState
    extends State<IncidentActionConfigurationScreen> {
  final capture = CapNativeFormCapture();
  late final IncidentActionConfigurationCubit coordinator;
  @override
  void initState() {
    super.initState();
    coordinator =
        widget.coordinator ??
        IncidentActionConfigurationCubit(
          action: widget.action,
          incidentId: widget.incidentId,
          executor: services<IncidentExecutionUseCase>(),
          getConfiguration: services<GetIncidentActionConfigurationUseCase>(),
          // Answers are submitted once with the final action, never separately.
          form: CapFormCubit(services<GetCapFormUseCase>()),
          getLocation: capture.getCurrentLocation,
          handlePhoto: (level) =>
              resolveActionPhoto(level, capturePhoto: capture.capturePhoto),
        );
    coordinator.start();
  }

  @override
  void dispose() {
    coordinator.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Action requirements', 'متطلبات الإجراء')),
    ),
    body: BlocConsumer<IncidentActionConfigurationCubit, ActionConfigurationState>(
      bloc: coordinator,
      listener: (context, state) {
        if (state.stage == ActionConfigurationStage.succeeded) {
          Navigator.pop(context, true);
        }
      },
      builder: (context, state) {
        if (state.stage == ActionConfigurationStage.formReady) {
          return CapDynamicForm(
            cubit: coordinator.form,
            forSubmission: false,
            capture: (q) => capture.capture(context, q),
            onRetry: coordinator.start,
            onConfirmed: (_) => coordinator.completeForm(),
          );
        }
        final (title, icon, loading) = switch (state.stage) {
          ActionConfigurationStage.initial ||
          ActionConfigurationStage.loadingConfiguration => (
            context.tr(
              'Loading action configuration',
              'جارٍ تحميل إعدادات الإجراء',
            ),
            Icons.settings_outlined,
            true,
          ),
          ActionConfigurationStage.requestingLocation => (
            context.tr('Retrieving your location', 'جارٍ تحديد موقعك'),
            Icons.my_location,
            true,
          ),
          ActionConfigurationStage.waitingForPhoto => (
            context.tr(
              state.configuration?.photoRequiredLevel == 1
                  ? 'Capture the required photo'
                  : 'Photo requirements await configuration',
              state.configuration?.photoRequiredLevel == 1
                  ? 'التقط الصورة المطلوبة'
                  : 'متطلبات الصور تنتظر تحديد القواعد',
            ),
            Icons.photo_camera_outlined,
            false,
          ),
          ActionConfigurationStage.loadingForm => (
            context.tr('Loading form', 'جارٍ تحميل النموذج'),
            Icons.description_outlined,
            true,
          ),
          ActionConfigurationStage.loadingTeam => (
            context.tr('Loading team members', 'جارٍ تحميل أعضاء الفريق'),
            Icons.groups_outlined,
            true,
          ),
          ActionConfigurationStage.selectingTeam => (
            context.tr('Select a team member', 'اختر عضو الفريق'),
            Icons.person_outline,
            false,
          ),
          ActionConfigurationStage.submitting => (
            context.tr('Submitting action', 'جارٍ تنفيذ الإجراء'),
            Icons.hourglass_top,
            true,
          ),
          ActionConfigurationStage.succeeded => (
            context.tr(
              'Action completed successfully',
              'تم تنفيذ الإجراء بنجاح',
            ),
            Icons.check_circle_outline,
            false,
          ),
          ActionConfigurationStage.readyToContinue => (
            context.tr('Ready to continue', 'جاهز للمتابعة'),
            Icons.check_circle_outline,
            false,
          ),
          _ => (
            context.tr(
              'Unable to complete requirements',
              'تعذّر استكمال المتطلبات',
            ),
            Icons.error_outline,
            false,
          ),
        };
        return PopScope(
          canPop: state.stage != ActionConfigurationStage.submitting,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (loading) const CircularProgressIndicator(),
                    if (state.stage ==
                            ActionConfigurationStage.waitingForPhoto &&
                        state.configuration?.photoRequiredLevel != 1)
                      Text(
                        context.tr(
                          'Photo level: ${state.configuration?.photoRequiredLevel}. No photo policy has been defined; no camera was opened.',
                          'مستوى الصور: ${state.configuration?.photoRequiredLevel}. لم تُحدد سياسة هذا المستوى؛ لم يتم فتح الكاميرا.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    if (state.stage == ActionConfigurationStage.readyToContinue)
                      Text(
                        context.tr(
                          'Requirements completed. No action has been executed.',
                          'تم استكمال المتطلبات فقط. لم يتم تنفيذ الإجراء.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    if (state.failure != null) ...[
                      Text(state.failure!.message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      AppButton(
                        label: context.tr('Retry', 'إعادة المحاولة'),
                        onPressed: coordinator.start,
                      ),
                    ],
                    if (state.executionFailure != null)
                      Text(
                        state.executionFailure!.message,
                        textAlign: TextAlign.center,
                      ),
                    if (state.stage ==
                        ActionConfigurationStage.selectingTeam) ...[
                      if (state.team.isEmpty) ...[
                        Text(
                          context.tr(
                            'No team members available',
                            'لا يوجد أعضاء فريق متاحون',
                          ),
                        ),
                        TextButton(
                          onPressed: coordinator.retryTeam,
                          child: Text(
                            context.tr('Reload team', 'إعادة تحميل الفريق'),
                          ),
                        ),
                      ],
                      ...state.team.map(
                        (member) => ListTile(
                          selected:
                              state.execution?.assignedUserId == member.id,
                          leading: Icon(
                            state.execution?.assignedUserId == member.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text(member.name),
                          subtitle: Text(
                            '${member.userName} · ${member.mobile}',
                          ),
                          onTap: () => coordinator.selectMember(member.id),
                        ),
                      ),
                    ],
                    if (state.execution != null &&
                        (state.stage ==
                                ActionConfigurationStage.readyToContinue ||
                            state.stage ==
                                ActionConfigurationStage.selectingTeam)) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('execution-remark'),
                        initialValue: state.execution!.remark,
                        minLines: 1,
                        maxLines: 3,
                        onChanged: coordinator.setRemark,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'Remark (optional)',
                            'الملاحظة (اختياري)',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label:
                            state.stage ==
                                    ActionConfigurationStage.readyToContinue &&
                                widget.action.type == IncidentAction.assign
                            ? context.tr(
                                'Continue to team selection',
                                'متابعة لاختيار عضو الفريق',
                              )
                            : context.tr('Confirm action', 'تأكيد الإجراء'),
                        onPressed:
                            state.stage ==
                                    ActionConfigurationStage.selectingTeam &&
                                state.execution!.assignedUserId == null
                            ? null
                            : coordinator.continueExecution,
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                      label: context.tr(
                        'Back to incident',
                        'العودة إلى البلاغ',
                      ),
                      onPressed:
                          state.stage == ActionConfigurationStage.submitting
                          ? null
                          : () => Navigator.pop(
                              context,
                              state.stage == ActionConfigurationStage.succeeded,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
