import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/exception_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../../forms/data/models/cap_form_models.dart';
import '../../../forms/presentation/bloc/cap_form_cubit.dart';
import '../../data/models/incident_action_configuration_models.dart';
import '../../domain/actions/incident_available_action.dart';
import '../../domain/actions/incident_execution_context.dart';
import '../../domain/usecases/incident_execution_use_case.dart';
import '../../domain/usecases/get_incident_action_configuration_use_case.dart';

enum ActionConfigurationStage {
  initial,
  loadingConfiguration,
  requestingLocation,
  waitingForPhoto,
  loadingForm,
  formReady,
  readyToContinue,
  loadingTeam,
  selectingTeam,
  submitting,
  succeeded,
  failure,
}

enum ActionPhotoOutcome { completed, awaitingPolicy, cancelled }

class ActionPhotoResult {
  const ActionPhotoResult(this.outcome, {this.evidence});
  final ActionPhotoOutcome outcome;
  final CapFormEvidence? evidence;
}

typedef ActionPhotoHandler = Future<ActionPhotoResult> Function(int? level);

/// Fallback when no capture policy has been supplied by the host.
Future<ActionPhotoResult> unresolvedActionPhotoPolicy(int? level) async =>
    const ActionPhotoResult(ActionPhotoOutcome.awaitingPolicy);

/// Confirmed business rules: zero skips photos; one requires camera evidence.
/// Other values remain undefined rather than silently bypassing requirements.
Future<ActionPhotoResult> resolveActionPhoto(
  int? level, {
  required Future<CapFormEvidence?> Function() capturePhoto,
}) async {
  if (level == 0) {
    return const ActionPhotoResult(ActionPhotoOutcome.completed);
  }
  if (level != 1) return unresolvedActionPhotoPolicy(level);
  final evidence = await capturePhoto();
  if (evidence == null || evidence.bytes.isEmpty) {
    return const ActionPhotoResult(ActionPhotoOutcome.cancelled);
  }
  return ActionPhotoResult(ActionPhotoOutcome.completed, evidence: evidence);
}

class ActionConfigurationState {
  const ActionConfigurationState(
    this.stage, {
    this.configuration,
    this.location,
    this.photo,
    this.answers = const [],
    this.failure,
    this.execution,
    this.team = const [],
    this.executionFailure,
  });
  final ActionConfigurationStage stage;
  final IncidentActionConfiguration? configuration;
  final String? location;
  final CapFormEvidence? photo;
  final List<CapFormAnswer> answers;
  final Failure? failure;
  final IncidentExecutionContext? execution;
  final List<IncidentTeamMember> team;
  final Failure? executionFailure;
  ActionConfigurationState executionState(
    ActionConfigurationStage stage, {
    IncidentExecutionContext? execution,
    List<IncidentTeamMember>? team,
    Failure? failure,
  }) => ActionConfigurationState(
    stage,
    configuration: configuration,
    location: location,
    photo: photo,
    answers: answers,
    execution: execution ?? this.execution,
    team: team ?? this.team,
    executionFailure: failure,
  );
}

/// Shared requirements and final execution; requests remain outside this flow.
class IncidentActionConfigurationCubit extends Cubit<ActionConfigurationState> {
  IncidentActionConfigurationCubit({
    required this.action,
    required this.getConfiguration,
    required this.form,
    required this.getLocation,
    this.handlePhoto = unresolvedActionPhotoPolicy,
    this.incidentId,
    this.executor,
  }) : super(const ActionConfigurationState(ActionConfigurationStage.initial));
  final IncidentAvailableAction action;
  final GetIncidentActionConfigurationUseCase getConfiguration;
  final CapFormCubit form;
  final Future<String?> Function() getLocation;
  final ActionPhotoHandler handlePhoto;
  final int? incidentId;
  final IncidentExecutionUseCase? executor;
  int _revision = 0;
  bool _running = false;
  static bool supports(IncidentAvailableAction action) =>
      action.flow != IncidentActionFlow.request &&
      const {
        IncidentAction.assign,
        IncidentAction.cancel,
        IncidentAction.approve,
        IncidentAction.reject,
        IncidentAction.hold,
        IncidentAction.complete,
      }.contains(action.type);

  Future<void> start() async {
    if (isClosed || _running || state.execution != null) return;
    if (!supports(action) || action.actionTypeId <= 0) {
      emit(
        const ActionConfigurationState(
          ActionConfigurationStage.failure,
          failure: ValidationFailure(),
        ),
      );
      return;
    }
    _running = true;
    final revision = ++_revision;
    bool current() => !isClosed && revision == _revision;
    IncidentActionConfiguration? configuration;
    String? location;
    CapFormEvidence? photo;
    void stage(ActionConfigurationStage value, {Failure? failure}) {
      if (current()) {
        emit(
          ActionConfigurationState(
            value,
            configuration: configuration,
            location: location,
            photo: photo,
            failure: failure,
            execution:
                value == ActionConfigurationStage.readyToContinue &&
                    incidentId != null
                ? IncidentExecutionContext.collected(
                    incidentId: incidentId!,
                    action: action,
                    location: location,
                    photo: photo,
                    answers: const [],
                  )
                : null,
          ),
        );
      }
    }

    try {
      stage(ActionConfigurationStage.loadingConfiguration);
      final result = await getConfiguration(action.actionTypeId);
      if (!current()) return;
      switch (result) {
        case FailureResult(:final failure):
          stage(ActionConfigurationStage.failure, failure: failure);
          return;
        case Success(:final data):
          configuration = data;
      }
      // Critical short circuit: absolutely no property/requirement access here.
      if (configuration == null) {
        stage(ActionConfigurationStage.readyToContinue);
        return;
      }
      if (configuration.gpsRequired) {
        stage(ActionConfigurationStage.requestingLocation);
        location = await getLocation();
        if (!current()) return;
        if (location == null || location.trim().isEmpty) {
          stage(
            ActionConfigurationStage.failure,
            failure: const CancelledFailure(),
          );
          return;
        }
      }
      stage(ActionConfigurationStage.waitingForPhoto);
      final photoResult = await handlePhoto(configuration.photoRequiredLevel);
      if (!current()) return;
      switch (photoResult.outcome) {
        case ActionPhotoOutcome.awaitingPolicy:
          return;
        case ActionPhotoOutcome.cancelled:
          stage(
            ActionConfigurationStage.failure,
            failure: const CancelledFailure(),
          );
          return;
        case ActionPhotoOutcome.completed:
          photo = photoResult.evidence;
      }
      final rawId = configuration.questionFormId?.trim();
      if (rawId == null || rawId.isEmpty) {
        stage(ActionConfigurationStage.readyToContinue);
        return;
      }
      final formId = int.tryParse(rawId);
      if (formId == null || formId <= 0) {
        stage(
          ActionConfigurationStage.failure,
          failure: const ValidationFailure(),
        );
        return;
      }
      stage(ActionConfigurationStage.loadingForm);
      await form.load(formId);
      if (!current()) return;
      if (form.state.failure != null) {
        stage(ActionConfigurationStage.failure, failure: form.state.failure);
        return;
      }
      if (form.state.form == null) {
        stage(
          ActionConfigurationStage.failure,
          failure: const UnknownFailure(),
        );
        return;
      }
      stage(ActionConfigurationStage.formReady);
    } on Exception catch (error) {
      stage(
        ActionConfigurationStage.failure,
        failure: ExceptionMapper.map(error),
      );
    } finally {
      _running = false;
    }
  }

  void completeForm() {
    if (isClosed || state.stage != ActionConfigurationStage.formReady) return;
    final answers = form.confirmedAnswers(forSubmission: false);
    if (answers == null) return;
    emit(
      ActionConfigurationState(
        ActionConfigurationStage.readyToContinue,
        configuration: state.configuration,
        location: state.location,
        photo: state.photo,
        answers: List.unmodifiable(answers),
        execution: incidentId == null
            ? null
            : IncidentExecutionContext.collected(
                incidentId: incidentId!,
                action: action,
                location: state.location,
                photo: state.photo,
                formId: form.state.form!.id,
                answers: answers,
              ),
      ),
    );
  }

  void setRemark(String value) {
    if (isClosed ||
        state.execution == null ||
        state.stage == ActionConfigurationStage.submitting ||
        state.stage == ActionConfigurationStage.succeeded) {
      return;
    }
    emit(
      state.executionState(
        state.stage,
        execution: state.execution!.withInput(remark: value),
      ),
    );
  }

  void selectMember(int id) {
    if (isClosed ||
        state.stage != ActionConfigurationStage.selectingTeam ||
        !state.team.any((m) => m.id == id)) {
      return;
    }
    emit(
      state.executionState(
        state.stage,
        execution: state.execution!.withInput(assignedUserId: id),
      ),
    );
  }

  Future<void> continueExecution() async {
    if (isClosed ||
        _running ||
        executor == null ||
        state.execution == null ||
        !{
          ActionConfigurationStage.readyToContinue,
          ActionConfigurationStage.selectingTeam,
        }.contains(state.stage)) {
      return;
    }
    _running = true;
    final revision = _revision;
    final original = state.stage;
    try {
      if (action.type == IncidentAction.assign &&
          original == ActionConfigurationStage.readyToContinue) {
        emit(state.executionState(ActionConfigurationStage.loadingTeam));
        final result = await executor!.getTeam();
        if (isClosed || revision != _revision) return;
        switch (result) {
          case Success(:final data):
            emit(
              state.executionState(
                ActionConfigurationStage.selectingTeam,
                team: List.unmodifiable(data),
              ),
            );
          case FailureResult(:final failure):
            emit(state.executionState(original, failure: failure));
        }
      } else {
        if (action.type == IncidentAction.assign &&
            !state.team.any((m) => m.id == state.execution!.assignedUserId)) {
          return;
        }
        emit(state.executionState(ActionConfigurationStage.submitting));
        final result = await executor!.execute(state.execution!);
        if (isClosed || revision != _revision) return;
        switch (result) {
          case Success():
            emit(state.executionState(ActionConfigurationStage.succeeded));
          case FailureResult(:final failure):
            emit(state.executionState(original, failure: failure));
        }
      }
    } on Exception catch (error) {
      if (!isClosed && revision == _revision) {
        emit(
          state.executionState(original, failure: ExceptionMapper.map(error)),
        );
      }
    } finally {
      _running = false;
    }
  }

  void retryTeam() {
    if (isClosed ||
        _running ||
        state.stage != ActionConfigurationStage.selectingTeam) {
      return;
    }
    emit(state.executionState(ActionConfigurationStage.readyToContinue));
    continueExecution();
  }

  @override
  Future<void> close() async {
    _revision++;
    await form.close();
    return super.close();
  }
}
