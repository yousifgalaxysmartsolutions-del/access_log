import 'dart:async';
import '../../../requests/domain/usecases/incident_request_use_case.dart';
import '../../../requests/data/models/request_creation_models.dart';
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
const _unchanged = Object();

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
    this.locationBusy = false,
    this.photoBusy = false,
    this.locationFailure,
    this.photoFailure,
    this.remark = '',
    this.requirementsValid = false,
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
  final bool locationBusy, photoBusy, requirementsValid;
  final Failure? locationFailure, photoFailure;
  final String remark;
  bool get requiresLocation => configuration?.gpsRequired ?? false;
  bool get requiresPhoto => configuration?.photoRequiredLevel == 1;
  bool get requiresForm =>
      configuration?.questionFormId?.trim().isNotEmpty ?? false;
  // Unknown levels keep their previous fail-closed behavior.
  bool get unknownPhotoPolicy =>
      configuration != null &&
      configuration!.photoRequiredLevel != 0 &&
      configuration!.photoRequiredLevel != 1;
  bool get hasRequirements =>
      requiresLocation || requiresPhoto || requiresForm || unknownPhotoPolicy;

  ActionConfigurationState requirementsState({
    ActionConfigurationStage? stage,
    Object? location = _unchanged,
    Object? photo = _unchanged,
    Object? execution = _unchanged,
    bool? locationBusy,
    bool? photoBusy,
    Object? locationFailure = _unchanged,
    Object? photoFailure = _unchanged,
    String? remark,
    bool? requirementsValid,
    List<CapFormAnswer>? answers,
  }) => ActionConfigurationState(
    stage ?? this.stage,
    configuration: configuration,
    location: identical(location, _unchanged)
        ? this.location
        : location as String?,
    photo: identical(photo, _unchanged)
        ? this.photo
        : photo as CapFormEvidence?,
    execution: identical(execution, _unchanged)
        ? this.execution
        : execution as IncidentExecutionContext?,
    answers: answers ?? this.answers,
    failure: failure,
    team: team,
    executionFailure: executionFailure,
    locationBusy: locationBusy ?? this.locationBusy,
    photoBusy: photoBusy ?? this.photoBusy,
    locationFailure: identical(locationFailure, _unchanged)
        ? this.locationFailure
        : locationFailure as Failure?,
    photoFailure: identical(photoFailure, _unchanged)
        ? this.photoFailure
        : photoFailure as Failure?,
    remark: remark ?? this.remark,
    requirementsValid: requirementsValid ?? this.requirementsValid,
  );
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
    locationBusy: locationBusy,
    photoBusy: photoBusy,
    locationFailure: locationFailure,
    photoFailure: photoFailure,
    remark: remark,
    requirementsValid: requirementsValid,
  );
}

/// Shared requirements engine; final execution is routed by the selected flow.
class IncidentActionConfigurationCubit extends Cubit<ActionConfigurationState> {
  IncidentActionConfigurationCubit({
    required this.action,
    required this.getConfiguration,
    required this.form,
    required this.getLocation,
    this.handlePhoto = unresolvedActionPhotoPolicy,
    this.incidentId,
    this.executor,
    this.requestExecutor,
    this.requestNewStatusId,
    Duration Function()? formElapsed,
  }) : super(const ActionConfigurationState(ActionConfigurationStage.initial)) {
    _formElapsed = formElapsed ?? (() => _formTimer.elapsed);
    _formSubscription = form.stream.listen((_) => _syncRequirements());
  }
  final IncidentAvailableAction action;
  final GetIncidentActionConfigurationUseCase getConfiguration;
  final CapFormCubit form;
  final Future<String?> Function() getLocation;
  final ActionPhotoHandler handlePhoto;
  final int? incidentId;
  final IncidentExecutionUseCase? executor;
  final IncidentRequestUseCase? requestExecutor;

  /// Explicit execution input only; never inferred from actions/status/labels.
  final int? requestNewStatusId;
  final Stopwatch _formTimer = Stopwatch();
  late final Duration Function() _formElapsed;
  int? _submittedMinutes;
  bool get isRequest => action.flow == IncidentActionFlow.request;
  bool get submissionBlocked =>
      isRequest && (requestNewStatusId == null || requestNewStatusId! <= 0);
  bool get hasExecutor =>
      isRequest ? requestExecutor != null : executor != null;
  RequestExecutionContext? get requestExecution {
    final input = state.execution;
    if (!isRequest || input == null) return null;
    return RequestExecutionContext(
      incidentId: input.incidentId,
      requestTypeId: action.actionTypeId,
      newStatusId: requestNewStatusId,
      remark: input.remark,
      lat: input.lat,
      long: input.long,
      photo: input.photo,
      questionFormId: input.questionFormId,
      answers: input.answers,
      noOfMinute: state.requiresForm
          ? (_submittedMinutes ?? _formElapsed().inMinutes)
          : 0,
    );
  }

  int _revision = 0;
  bool _running = false;
  Future<void>? _closing;
  late final StreamSubscription<CapFormState> _formSubscription;
  bool get _editingRequirements =>
      !isClosed &&
      {
        ActionConfigurationStage.loadingForm,
        ActionConfigurationStage.formReady,
        ActionConfigurationStage.readyToContinue,
      }.contains(state.stage);
  static bool supports(IncidentAvailableAction action) => const {
    IncidentAction.assign,
    IncidentAction.cancel,
    IncidentAction.approve,
    IncidentAction.reject,
    IncidentAction.hold,
    IncidentAction.complete,
    IncidentAction.interventionRequest,
    IncidentAction.renewalRequest,
    IncidentAction.departureRequest,
  }.contains(action.type);

  Future<void> start() async {
    if (isClosed || _running || state.execution != null) return;
    if (!supports(action) ||
        action.actionTypeId <= 0 ||
        (isRequest &&
            (requestExecutor == null ||
                incidentId == null ||
                incidentId! <= 0))) {
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
    void stage(ActionConfigurationStage value, {Failure? failure}) {
      if (current()) {
        emit(
          ActionConfigurationState(
            value,
            configuration: configuration,
            location: state.location,
            photo: state.photo,
            remark: state.remark,
            locationBusy: state.locationBusy,
            photoBusy: state.photoBusy,
            locationFailure: state.locationFailure,
            photoFailure: state.photoFailure,
            failure: failure,
            execution:
                value == ActionConfigurationStage.readyToContinue &&
                    incidentId != null
                ? IncidentExecutionContext.collected(
                    incidentId: incidentId!,
                    action: action,
                    location: state.location,
                    photo: state.photo,
                    answers: const [],
                    remark: state.remark,
                  )
                : null,
          ),
        );
      }
    }

    try {
      stage(ActionConfigurationStage.loadingConfiguration);
      final result = isRequest
          ? await requestExecutor!.getConfiguration(
              action.actionTypeId,
              incidentId!,
            )
          : await getConfiguration(action.actionTypeId);
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
      final rawId = configuration.questionFormId?.trim();
      if (rawId == null || rawId.isEmpty) {
        stage(ActionConfigurationStage.formReady);
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
        stage(ActionConfigurationStage.formReady);
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
      if (isRequest && !_formTimer.isRunning) _formTimer.start();
    } on Exception catch (error) {
      stage(
        ActionConfigurationStage.failure,
        failure: ExceptionMapper.map(error),
      );
    } finally {
      _running = false;
      _syncRequirements();
    }
  }

  // Uses the existing form validation; this getter never emits field errors.
  void _syncRequirements() {
    if (!_editingRequirements || _running) return;
    final answers = state.requiresForm
        ? form.confirmedAnswers(forSubmission: false, showErrors: false)
        : const <CapFormAnswer>[];
    final valid =
        !state.locationBusy &&
        !state.photoBusy &&
        !state.unknownPhotoPolicy &&
        (!state.requiresLocation || _validLocation(state.location)) &&
        (!state.requiresPhoto || (state.photo?.bytes.isNotEmpty ?? false)) &&
        answers != null;
    final execution = !valid || incidentId == null
        ? null
        : IncidentExecutionContext.collected(
            incidentId: incidentId!,
            action: action,
            location: state.location,
            photo: state.photo,
            formId: state.requiresForm ? form.state.form?.id : null,
            answers: answers,
            remark: state.remark,
          );
    emit(
      state.requirementsState(
        stage: valid
            ? ActionConfigurationStage.readyToContinue
            : ActionConfigurationStage.formReady,
        execution: execution,
        requirementsValid: valid,
        answers: List.unmodifiable(answers ?? const <CapFormAnswer>[]),
      ),
    );
  }

  bool _validLocation(String? value) {
    final parts = value
        ?.split(',')
        .map((s) => double.tryParse(s.trim()))
        .toList();
    return parts?.length == 2 &&
        parts![0]?.isFinite == true &&
        parts[1]?.isFinite == true &&
        parts[0]!.abs() <= 90 &&
        parts[1]!.abs() <= 180;
  }

  Future<void> refreshLocation() async {
    if (!_editingRequirements ||
        !state.requiresLocation ||
        state.locationBusy) {
      return;
    }
    final revision = _revision;
    emit(state.requirementsState(locationBusy: true, locationFailure: null));
    _syncRequirements();
    try {
      final location = await getLocation();
      if (isClosed || revision != _revision) return;
      emit(
        state.requirementsState(
          location: _validLocation(location) ? location : state.location,
          locationBusy: false,
          locationFailure: _validLocation(location)
              ? null
              : const ValidationFailure(),
        ),
      );
    } on Exception catch (error) {
      if (isClosed || revision != _revision) return;
      emit(
        state.requirementsState(
          locationBusy: false,
          locationFailure: ExceptionMapper.map(error),
        ),
      );
    }
    _syncRequirements();
  }

  Future<void> capturePhoto() async {
    if (!_editingRequirements || !state.requiresPhoto || state.photoBusy) {
      return;
    }
    await _updatePhoto(() async {
      final result = await handlePhoto(state.configuration!.photoRequiredLevel);
      if (result.outcome == ActionPhotoOutcome.awaitingPolicy) {
        throw const FormatException('Unknown photo policy');
      }
      return result.outcome == ActionPhotoOutcome.completed
          ? result.evidence
          : null;
    });
  }

  Future<void> editPhoto(
    Future<CapFormEvidence?> Function(CapFormEvidence) edit,
  ) async {
    if (!_editingRequirements || state.photo == null || state.photoBusy) return;
    final original = state.photo!;
    await _updatePhoto(() => edit(original));
  }

  Future<void> _updatePhoto(Future<CapFormEvidence?> Function() collect) async {
    final revision = _revision;
    emit(state.requirementsState(photoBusy: true, photoFailure: null));
    _syncRequirements();
    try {
      final photo = await collect();
      if (isClosed || revision != _revision) return;
      emit(
        state.requirementsState(
          photo: photo?.bytes.isNotEmpty == true ? photo : state.photo,
          photoBusy: false,
        ),
      );
    } on Exception catch (error) {
      if (isClosed || revision != _revision) return;
      emit(
        state.requirementsState(
          photoBusy: false,
          photoFailure: ExceptionMapper.map(error),
        ),
      );
    }
    _syncRequirements();
  }

  void removePhoto() {
    if (!_editingRequirements || state.photoBusy) return;
    emit(state.requirementsState(photo: null, photoFailure: null));
    _syncRequirements();
  }

  Future<void> retryForm() async {
    if (!_editingRequirements || form.state.loading) return;
    final formId = int.tryParse(
      state.configuration?.questionFormId?.trim() ?? '',
    );
    if (formId == null || formId <= 0) return;
    emit(
      state.requirementsState(
        stage: ActionConfigurationStage.loadingForm,
        execution: null,
        requirementsValid: false,
      ),
    );
    await form.load(formId);
    if (isClosed) return;
    if (isRequest && form.state.form != null && !_formTimer.isRunning) {
      _formTimer.start();
    }
    emit(state.requirementsState(stage: ActionConfigurationStage.formReady));
    _syncRequirements();
  }

  void completeForm() {
    if (!_editingRequirements) return;
    if (state.requiresForm) form.confirmedAnswers(forSubmission: false);
    _syncRequirements();
  }

  void setRemark(String value) {
    if (isClosed ||
        state.stage == ActionConfigurationStage.submitting ||
        state.stage == ActionConfigurationStage.succeeded) {
      return;
    }
    if (_editingRequirements) {
      emit(state.requirementsState(remark: value));
      _syncRequirements();
      return;
    }
    if (state.execution == null) return;
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
    if (isRequest) {
      await _createRequest();
      return;
    }
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

  Future<void> _createRequest() async {
    if (isClosed ||
        _running ||
        requestExecutor == null ||
        submissionBlocked ||
        state.stage != ActionConfigurationStage.readyToContinue ||
        !state.requirementsValid) {
      return;
    }
    final input = requestExecution;
    if (input == null) return;
    _submittedMinutes ??= input.noOfMinute;
    _formTimer.stop();
    _running = true;
    final revision = _revision;
    emit(state.executionState(ActionConfigurationStage.submitting));
    try {
      final result = await requestExecutor!.create(input);
      if (isClosed || revision != _revision) return;
      switch (result) {
        case Success():
          emit(state.executionState(ActionConfigurationStage.succeeded));
        case FailureResult(:final failure):
          emit(
            state.executionState(
              ActionConfigurationStage.readyToContinue,
              failure: failure,
            ),
          );
      }
    } on Exception catch (error) {
      if (!isClosed && revision == _revision) {
        emit(
          state.executionState(
            ActionConfigurationStage.readyToContinue,
            failure: ExceptionMapper.map(error),
          ),
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
  Future<void> close() {
    if (_closing != null) return _closing!;
    _revision++;
    _formTimer.stop();
    // Mark both cubits closed immediately, including when a route disposes them.
    return _closing = Future.wait<void>([
      _formSubscription.cancel(),
      form.close(),
      super.close(),
    ]).then((_) {});
  }
}
