import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../data/models/incident_details_models.dart';
import '../../domain/usecases/get_incident_details_use_case.dart';
import '../../domain/usecases/get_incident_requests_use_case.dart';
import '../../domain/usecases/get_incident_timeline_use_case.dart';

sealed class IncidentDetailsEvent {
  const IncidentDetailsEvent();
}

/// Loads the "General" panel.
class LoadIncidentGeneral extends IncidentDetailsEvent {
  const LoadIncidentGeneral({
    required this.incidentId,
    required this.incidentNo,
  });

  final int incidentId;
  final String incidentNo;
}

/// Loads the "Timeline" panel.
class LoadIncidentTimeline extends IncidentDetailsEvent {
  const LoadIncidentTimeline({required this.incidentId});

  final int incidentId;
}

/// Loads the "Related Requests" panel.
class LoadIncidentRelatedRequests extends IncidentDetailsEvent {
  const LoadIncidentRelatedRequests({required this.incidentId});

  final int incidentId;
}

/// One state holding all three panels independently.
///
/// Each panel owns its own loading flag, payload and failure, so loading or
/// failing one tab never disturbs the other two. There is deliberately no
/// single `status` field and no shared `copyWith`: every emit rebuilds the whole
/// state and explicitly passes `null` where a value must be cleared, which is
/// how this project avoids the "stale error survives a retry" bug that a naive
/// `copyWith(x: x ?? this.x)` would introduce.
class IncidentDetailsState {
  const IncidentDetailsState({
    this.generalLoading = false,
    this.generalData,
    this.generalFailure,
    this.timelineLoading = false,
    this.timelineData,
    this.timelineFailure,
    this.relatedRequestsLoading = false,
    this.relatedRequestsData,
    this.relatedRequestsFailure,
  });

  final bool generalLoading;
  final IncidentDetailsData? generalData;
  final Failure? generalFailure;

  /// Timeline history as returned by `GetIncidentTimeline`.
  final IncidentTimelineData? timelineData;
  final bool timelineLoading;
  final Failure? timelineFailure;

  final bool relatedRequestsLoading;
  final IncidentRequestsData? relatedRequestsData;
  final Failure? relatedRequestsFailure;

  /// True once at least one panel has delivered content.
  bool get hasContent =>
      generalData != null ||
      timelineData != null ||
      relatedRequestsData != null;
}

/// Coordinates the three incident detail reads behind one bloc.
///
/// Panels load independently and re-issue their request every time the matching
/// event arrives: selecting a tab again must fetch fresh data, so there is no
/// "already loaded" short-circuit. Nothing is loaded from the constructor
/// because the incident id arrives with the screen's arguments.
///
/// ## Concurrency
///
/// Bloc's default transformer processes events concurrently (it flat-maps each
/// handler), so two `LoadIncidentGeneral` events really can overlap. Each panel
/// therefore owns a request counter: a handler claims a number before awaiting
/// and discards its own result if a newer request for the same panel has since
/// claimed one. That yields `restartable()`-style semantics per panel - the
/// newest request always wins - without adding `bloc_concurrency`, which this
/// project does not depend on.
///
/// The counters are per panel rather than global, so the three panels never
/// queue behind one another and a panel's in-flight request is never dropped
/// because a different panel started loading.
class IncidentDetailsBloc
    extends Bloc<IncidentDetailsEvent, IncidentDetailsState> {
  IncidentDetailsBloc({
    required GetIncidentDetailsUseCase getIncidentDetails,
    required GetIncidentTimelineUseCase getIncidentTimeline,
    required GetIncidentRequestsUseCase getIncidentRequests,
  }) : _getIncidentDetails = getIncidentDetails,
       _getIncidentTimeline = getIncidentTimeline,
       _getIncidentRequests = getIncidentRequests,
       super(const IncidentDetailsState()) {
    on<LoadIncidentGeneral>(_onGeneral);
    on<LoadIncidentTimeline>(_onTimeline);
    on<LoadIncidentRelatedRequests>(_onRelatedRequests);
  }

  final GetIncidentDetailsUseCase _getIncidentDetails;
  final GetIncidentTimelineUseCase _getIncidentTimeline;
  final GetIncidentRequestsUseCase _getIncidentRequests;

  /// Monotonic request id per panel; see the concurrency notes above.
  int _generalRequest = 0;
  int _timelineRequest = 0;
  int _relatedRequestsRequest = 0;

  Future<void> _onGeneral(
    LoadIncidentGeneral event,
    Emitter<IncidentDetailsState> emit,
  ) async {
    final request = ++_generalRequest;

    // Clearing the failure here is what makes a retry look clean: the panel
    // shows loading without the previous error, while the last known incident
    // stays on screen.
    emit(
      IncidentDetailsState(
        generalLoading: true,
        generalData: state.generalData,
        generalFailure: null,
        timelineLoading: state.timelineLoading,
        timelineData: state.timelineData,
        timelineFailure: state.timelineFailure,
        relatedRequestsLoading: state.relatedRequestsLoading,
        relatedRequestsData: state.relatedRequestsData,
        relatedRequestsFailure: state.relatedRequestsFailure,
      ),
    );

    final result = await _getIncidentDetails(
      incidentId: event.incidentId,
      incidentNo: event.incidentNo,
    );

    // A newer request for this panel owns the state now, so this stale
    // response is discarded rather than allowed to overwrite fresher data.
    if (request != _generalRequest) return;

    emit(
      IncidentDetailsState(
        generalLoading: false,
        // Kept when the refresh fails so the panel still shows the last known
        // incident alongside its error.
        generalData: _valueOf(result) ?? state.generalData,
        generalFailure: _failureOf(result),
        timelineLoading: state.timelineLoading,
        timelineData: state.timelineData,
        timelineFailure: state.timelineFailure,
        relatedRequestsLoading: state.relatedRequestsLoading,
        relatedRequestsData: state.relatedRequestsData,
        relatedRequestsFailure: state.relatedRequestsFailure,
      ),
    );
  }

  Future<void> _onTimeline(
    LoadIncidentTimeline event,
    Emitter<IncidentDetailsState> emit,
  ) async {
    final request = ++_timelineRequest;

    emit(
      IncidentDetailsState(
        generalLoading: state.generalLoading,
        generalData: state.generalData,
        generalFailure: state.generalFailure,
        timelineLoading: true,
        timelineData: state.timelineData,
        timelineFailure: null,
        relatedRequestsLoading: state.relatedRequestsLoading,
        relatedRequestsData: state.relatedRequestsData,
        relatedRequestsFailure: state.relatedRequestsFailure,
      ),
    );

    final result = await _getIncidentTimeline(incidentId: event.incidentId);

    // A newer request for this panel owns the state now, so this stale
    // response is discarded rather than allowed to overwrite fresher data.
    if (request != _timelineRequest) return;

    emit(
      IncidentDetailsState(
        generalLoading: state.generalLoading,
        generalData: state.generalData,
        generalFailure: state.generalFailure,
        timelineLoading: false,
        timelineData: _valueOf(result) ?? state.timelineData,
        timelineFailure: _failureOf(result),
        relatedRequestsLoading: state.relatedRequestsLoading,
        relatedRequestsData: state.relatedRequestsData,
        relatedRequestsFailure: state.relatedRequestsFailure,
      ),
    );
  }

  Future<void> _onRelatedRequests(
    LoadIncidentRelatedRequests event,
    Emitter<IncidentDetailsState> emit,
  ) async {
    final request = ++_relatedRequestsRequest;

    emit(
      IncidentDetailsState(
        generalLoading: state.generalLoading,
        generalData: state.generalData,
        generalFailure: state.generalFailure,
        timelineLoading: state.timelineLoading,
        timelineData: state.timelineData,
        timelineFailure: state.timelineFailure,
        relatedRequestsLoading: true,
        relatedRequestsData: state.relatedRequestsData,
        relatedRequestsFailure: null,
      ),
    );

    final result = await _getIncidentRequests(incidentId: event.incidentId);

    // A newer request for this panel owns the state now, so this stale
    // response is discarded rather than allowed to overwrite fresher data.
    if (request != _relatedRequestsRequest) return;

    // An incident with `items: []` is a success, so `_valueOf` returns the empty
    // payload and no failure is produced.
    emit(
      IncidentDetailsState(
        generalLoading: state.generalLoading,
        generalData: state.generalData,
        generalFailure: state.generalFailure,
        timelineLoading: state.timelineLoading,
        timelineData: state.timelineData,
        timelineFailure: state.timelineFailure,
        relatedRequestsLoading: false,
        relatedRequestsData: _valueOf(result) ?? state.relatedRequestsData,
        relatedRequestsFailure: _failureOf(result),
      ),
    );
  }
}

T? _valueOf<T>(Result<T> result) => switch (result) {
  Success(:final data) => data,
  FailureResult<T>() => null,
};

Failure? _failureOf<T>(Result<T> result) => switch (result) {
  Success<T>() => null,
  FailureResult(:final failure) => failure,
};
