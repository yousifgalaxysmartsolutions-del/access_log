import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../incidents/domain/actions/incident_execution_context.dart';
import '../../data/models/engineer_locations_report_models.dart';
import '../../domain/usecases/get_engineer_locations_report_use_case.dart';

const _keep = Object();

class EngineerLocationsReportState {
  const EngineerLocationsReportState({
    required this.active,
    this.draft,
    this.data,
    this.loading = false,
    this.teamLoading = false,
    this.failure,
    this.teamFailure,
    this.filterError = false,
    this.team = const [],
  });
  final EngineerLocationsReportFilter active;
  final EngineerLocationsReportFilter? draft;
  final EngineerLocationsReportData? data;
  final bool loading, teamLoading, filterError;
  final Failure? failure, teamFailure;
  final List<IncidentTeamMember> team;
  EngineerLocationsReportState copyWith({
    EngineerLocationsReportFilter? active,
    Object? draft = _keep,
    Object? data = _keep,
    bool? loading,
    bool? teamLoading,
    bool? filterError,
    Object? failure = _keep,
    Object? teamFailure = _keep,
    List<IncidentTeamMember>? team,
  }) => EngineerLocationsReportState(
    active: active ?? this.active,
    draft: identical(draft, _keep)
        ? this.draft
        : draft as EngineerLocationsReportFilter?,
    data: identical(data, _keep)
        ? this.data
        : data as EngineerLocationsReportData?,
    loading: loading ?? this.loading,
    teamLoading: teamLoading ?? this.teamLoading,
    filterError: filterError ?? this.filterError,
    failure: identical(failure, _keep) ? this.failure : failure as Failure?,
    teamFailure: identical(teamFailure, _keep)
        ? this.teamFailure
        : teamFailure as Failure?,
    team: team ?? this.team,
  );
}

class EngineerLocationsReportCubit extends Cubit<EngineerLocationsReportState> {
  EngineerLocationsReportCubit({
    required this.getReport,
    required this.loadTeam,
    required this.currentUser,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(
         EngineerLocationsReportState(
           active: EngineerLocationsReportFilter.currentMonth(
             (now ?? DateTime.now)(),
             currentUser()?.numericId ?? 0,
           ),
         ),
       );
  final GetEngineerLocationsReportUseCase getReport;
  final Future<Result<List<IncidentTeamMember>>> Function() loadTeam;
  final SessionUser? Function() currentUser;
  final DateTime Function() now;
  bool _started = false;
  int _revision = 0;
  bool get hasOtherEngineers =>
      state.team.any((e) => e.id != currentUser()?.numericId);
  Map<int, String> get engineers => {
    if ((currentUser()?.numericId ?? 0) > 0)
      currentUser()!.numericId: currentUser()!.name ?? '—',
    for (final member in state.team) member.id: member.name,
  };
  Future<void> loadInitial() async {
    if (_started) return;
    _started = true;
    if (state.active.engineerUserId <= 0) {
      await refresh();
      return;
    }
    await Future.wait([refresh(), refreshTeam()]);
  }

  Future<void> refreshTeam() async {
    if (state.teamLoading) return;
    emit(state.copyWith(teamLoading: true, teamFailure: null));
    final result = await loadTeam();
    if (isClosed) return;
    switch (result) {
      case Success(:final data):
        final unique = <int, IncidentTeamMember>{};
        for (final member in data) {
          if (member.id > 0) unique.putIfAbsent(member.id, () => member);
        }
        emit(
          state.copyWith(
            teamLoading: false,
            team: List.unmodifiable(unique.values),
          ),
        );
      case FailureResult(:final failure):
        emit(state.copyWith(teamLoading: false, teamFailure: failure));
    }
  }

  void beginFilters() =>
      emit(state.copyWith(draft: state.active, filterError: false));
  void cancelFilters() => emit(state.copyWith(draft: null, filterError: false));
  void updateDraft({
    DateTime? fromDate,
    DateTime? toDate,
    int? engineerUserId,
  }) {
    final draft = state.draft;
    if (draft == null ||
        (engineerUserId != null && !engineers.containsKey(engineerUserId))) {
      return;
    }
    emit(
      state.copyWith(
        draft: draft.copyWith(
          fromDate: fromDate,
          toDate: toDate,
          engineerUserId: engineerUserId,
        ),
        filterError: false,
      ),
    );
  }

  void resetDraft() => emit(
    state.copyWith(
      draft: EngineerLocationsReportFilter.currentMonth(
        now(),
        currentUser()?.numericId ?? 0,
      ),
      filterError: false,
    ),
  );
  Future<bool> applyFilters() async {
    final draft = state.draft;
    if (draft == null) return false;
    if (draft.fromDate.isAfter(draft.toDate) ||
        !engineers.containsKey(draft.engineerUserId)) {
      emit(state.copyWith(filterError: true));
      return false;
    }
    emit(
      state.copyWith(
        active: draft,
        draft: null,
        data: null,
        filterError: false,
      ),
    );
    await refresh();
    return true;
  }

  Future<void> refresh() async {
    final revision = ++_revision;
    emit(state.copyWith(loading: true, failure: null));
    final result = await getReport(state.active);
    if (isClosed || revision != _revision) return;
    switch (result) {
      case Success(:final data):
        emit(state.copyWith(loading: false, data: data));
      case FailureResult(:final failure):
        emit(state.copyWith(loading: false, failure: failure));
    }
  }
}
