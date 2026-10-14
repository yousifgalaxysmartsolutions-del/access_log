import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../incidents/data/models/incident_details_models.dart';
import '../../../incidents/domain/actions/incident_execution_context.dart';
import '../../data/models/engineers_activity_report_models.dart';
import '../../data/models/engineer_locations_report_models.dart';
import '../../data/models/incident_report_models.dart';
import '../../domain/usecases/get_engineers_activity_report_use_case.dart';
import '../../domain/usecases/incident_report_use_cases.dart';

const _keep = Object();

class EngineersActivityReportState {
  const EngineersActivityReportState({
    required this.active,
    this.draft,
    this.data,
    this.locations = const [],
    this.team = const [],
    this.loading = false,
    this.optionsLoading = false,
    this.filterError = false,
    this.failure,
    this.optionsFailure,
  });
  final EngineersActivityReportFilter active;
  final EngineersActivityReportFilter? draft;
  final EngineersActivityReportData? data;
  final List<IncidentLocationDto> locations;
  final List<IncidentTeamMember> team;
  final bool loading, optionsLoading, filterError;
  final Failure? failure, optionsFailure;
  bool get canPrevious => !loading && (data?.page ?? 1) > 1;
  bool get canNext =>
      !loading &&
      data != null &&
      data!.pageSize > 0 &&
      data!.page * data!.pageSize < data!.totalCount;
  EngineersActivityReportState copyWith({
    EngineersActivityReportFilter? active,
    Object? draft = _keep,
    Object? data = _keep,
    List<IncidentLocationDto>? locations,
    List<IncidentTeamMember>? team,
    bool? loading,
    bool? optionsLoading,
    bool? filterError,
    Object? failure = _keep,
    Object? optionsFailure = _keep,
  }) => EngineersActivityReportState(
    active: active ?? this.active,
    draft: identical(draft, _keep)
        ? this.draft
        : draft as EngineersActivityReportFilter?,
    data: identical(data, _keep)
        ? this.data
        : data as EngineersActivityReportData?,
    locations: locations ?? this.locations,
    team: team ?? this.team,
    loading: loading ?? this.loading,
    optionsLoading: optionsLoading ?? this.optionsLoading,
    filterError: filterError ?? this.filterError,
    failure: identical(failure, _keep) ? this.failure : failure as Failure?,
    optionsFailure: identical(optionsFailure, _keep)
        ? this.optionsFailure
        : optionsFailure as Failure?,
  );
}

class EngineersActivityReportCubit extends Cubit<EngineersActivityReportState> {
  EngineersActivityReportCubit({
    required this.getReport,
    required this.getLocations,
    required this.loadTeam,
    required this.currentUser,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(
         EngineersActivityReportState(
           active: EngineersActivityReportFilter.currentMonth(
             (now ?? DateTime.now)(),
           ),
         ),
       );
  final GetEngineersActivityReportUseCase getReport;
  final GetReportLocationsUseCase getLocations;
  final Future<Result<List<IncidentTeamMember>>> Function() loadTeam;
  final SessionUser? Function() currentUser;
  final DateTime Function() now;
  bool _started = false, _locationsLoaded = false, _teamLoaded = false;
  int _revision = 0;
  Future<void> loadInitial() async {
    if (_started) return;
    _started = true;
    await Future.wait([refresh(), loadOptions()]);
  }

  Future<void> loadOptions() async {
    if (state.optionsLoading) return;
    emit(state.copyWith(optionsLoading: true, optionsFailure: null));
    final results = await Future.wait<Object>([
      _locationsLoaded
          ? Future.value(Success(state.locations))
          : getLocations(),
      _teamLoaded ? Future.value(Success(state.team)) : loadTeam(),
    ]);
    if (isClosed) return;
    final locations = results[0] as Result<List<IncidentLocationDto>>;
    final team = results[1] as Result<List<IncidentTeamMember>>;
    _locationsLoaded = locations is Success<List<IncidentLocationDto>>;
    _teamLoaded = team is Success<List<IncidentTeamMember>>;
    emit(
      state.copyWith(
        optionsLoading: false,
        locations: _locationsLoaded
            ? (locations as Success<List<IncidentLocationDto>>).data
            : null,
        team: _teamLoaded
            ? (team as Success<List<IncidentTeamMember>>).data
            : null,
        optionsFailure: locations is FailureResult<List<IncidentLocationDto>>
            ? locations.failure
            : team is FailureResult<List<IncidentTeamMember>>
            ? team.failure
            : null,
      ),
    );
  }

  Map<int, String> get engineers => {
    if ((currentUser()?.numericId ?? 0) > 0)
      currentUser()!.numericId: currentUser()!.name ?? '—',
    for (final member in state.team)
      if (member.id > 0) member.id: member.name,
  };
  List<IdNameDto> _unique(Iterable<IdNameDto?> values) {
    final unique = <int, IdNameDto>{};
    for (final value in values) {
      if (value?.id != null) unique.putIfAbsent(value!.id!, () => value);
    }
    return List.unmodifiable(unique.values);
  }

  List<IdNameDto> get regions => _unique(state.locations.map((e) => e.region));
  List<IdNameDto> get areas {
    final filter = state.draft ?? state.active;
    return _unique(
      state.locations
          .where(
            (e) => filter.regionId == -1 || e.region?.id == filter.regionId,
          )
          .map((e) => e.area),
    );
  }

  List<IncidentLocationDto> get sites {
    final filter = state.draft ?? state.active;
    final unique = <String, IncidentLocationDto>{};
    for (final site in state.locations) {
      if (site.id?.isNotEmpty != true ||
          (filter.regionId != -1 && site.region?.id != filter.regionId) ||
          (filter.areaId != -1 && site.area?.id != filter.areaId)) {
        continue;
      }
      unique.putIfAbsent(site.id!, () => site);
    }
    return List.unmodifiable(unique.values);
  }

  void beginFilters() =>
      emit(state.copyWith(draft: state.active, filterError: false));
  void cancelFilters() => emit(state.copyWith(draft: null, filterError: false));
  void updateDraft(EngineersActivityReportFilter filter) {
    if (state.draft == null) return;
    final validArea =
        filter.areaId == -1 ||
        state.locations.any(
          (e) =>
              e.area?.id == filter.areaId &&
              (filter.regionId == -1 || e.region?.id == filter.regionId),
        );
    filter = filter.copyWith(areaId: validArea ? filter.areaId : -1);
    final validSite =
        filter.locationCode.isEmpty ||
        state.locations.any(
          (e) =>
              e.id == filter.locationCode &&
              (filter.regionId == -1 || e.region?.id == filter.regionId) &&
              (filter.areaId == -1 || e.area?.id == filter.areaId),
        );
    emit(
      state.copyWith(
        draft: filter.copyWith(
          locationCode: validSite ? filter.locationCode : '',
        ),
        filterError: false,
      ),
    );
  }

  void setDraftRange(IncidentReportDateRange range) {
    final draft = state.draft;
    if (draft == null) return;
    final current = now();
    final today = DateTime(current.year, current.month, current.day);
    final dates = switch (range) {
      IncidentReportDateRange.today => (today, today),
      IncidentReportDateRange.week => (
        today.subtract(Duration(days: today.weekday - 1)),
        today.add(Duration(days: 7 - today.weekday)),
      ),
      IncidentReportDateRange.month => (
        DateTime(today.year, today.month),
        DateTime(today.year, today.month + 1, 0),
      ),
      IncidentReportDateRange.custom => (draft.fromDate, draft.toDate),
    };
    updateDraft(
      draft.copyWith(range: range, fromDate: dates.$1, toDate: dates.$2),
    );
  }

  void resetDraft() => emit(
    state.copyWith(
      draft: EngineersActivityReportFilter.currentMonth(
        now(),
      ).copyWith(groupBy: state.active.groupBy),
      filterError: false,
    ),
  );
  Future<bool> applyFilters() async {
    final filter = state.draft;
    if (filter == null) return false;
    if (filter.fromDate.isAfter(filter.toDate)) {
      emit(state.copyWith(filterError: true));
      return false;
    }
    emit(
      state.copyWith(
        active: filter.copyWith(page: 1),
        draft: null,
        data: null,
        filterError: false,
      ),
    );
    await refresh();
    return true;
  }

  Future<void> changeGroup(EngineersActivityGroup group) async {
    if (group == state.active.groupBy) return;
    emit(
      state.copyWith(
        active: state.active.copyWith(groupBy: group, page: 1),
        draft: null,
        data: null,
      ),
    );
    await refresh();
  }

  Future<void> resetFilters() async {
    emit(
      state.copyWith(
        active: EngineersActivityReportFilter.currentMonth(
          now(),
        ).copyWith(groupBy: state.active.groupBy),
        draft: null,
        data: null,
      ),
    );
    await refresh();
  }

  Future<void> loadPage(int page) async {
    if (state.loading ||
        state.data == null ||
        page < 1 ||
        (page > state.data!.page && !state.canNext)) {
      return;
    }
    emit(state.copyWith(active: state.active.copyWith(page: page), data: null));
    await refresh();
  }

  EngineerLocationsReportFilter detailsFilter(int engineerId) =>
      EngineerLocationsReportFilter(
        fromDate: state.active.fromDate,
        toDate: state.active.toDate,
        engineerUserId: engineerId,
      );
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
