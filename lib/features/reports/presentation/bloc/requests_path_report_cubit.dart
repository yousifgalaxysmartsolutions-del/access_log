import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../../incidents/data/models/incident_details_models.dart';
import '../../../requests/data/models/request_models.dart';
import '../../../requests/domain/usecases/get_request_lookup_use_case.dart';
import '../../data/models/incident_report_models.dart';
import '../../data/models/requests_path_report_models.dart';
import '../../domain/usecases/get_requests_path_report_use_case.dart';
import '../../domain/usecases/incident_report_use_cases.dart';

const _keep = Object();

class RequestsPathReportState {
  const RequestsPathReportState({
    required this.active,
    this.draft,
    this.data,
    this.lookup,
    this.locations = const [],
    this.loading = false,
    this.optionsLoading = false,
    this.filterError = false,
    this.failure,
    this.optionsFailure,
  });
  final RequestsPathReportFilter active;
  final RequestsPathReportFilter? draft;
  final RequestsPathReportData? data;
  final RequestLookupData? lookup;
  final List<IncidentLocationDto> locations;
  final bool loading, optionsLoading, filterError;
  final Failure? failure, optionsFailure;
  bool get canPrevious => !loading && (data?.page ?? 1) > 1;
  bool get canNext =>
      !loading &&
      data != null &&
      data!.pageSize > 0 &&
      data!.page * data!.pageSize < data!.totalCount;
  RequestsPathReportState copyWith({
    RequestsPathReportFilter? active,
    Object? draft = _keep,
    Object? data = _keep,
    RequestLookupData? lookup,
    List<IncidentLocationDto>? locations,
    bool? loading,
    bool? optionsLoading,
    bool? filterError,
    Object? failure = _keep,
    Object? optionsFailure = _keep,
  }) => RequestsPathReportState(
    active: active ?? this.active,
    draft: identical(draft, _keep)
        ? this.draft
        : draft as RequestsPathReportFilter?,
    data: identical(data, _keep) ? this.data : data as RequestsPathReportData?,
    lookup: lookup ?? this.lookup,
    locations: locations ?? this.locations,
    loading: loading ?? this.loading,
    optionsLoading: optionsLoading ?? this.optionsLoading,
    filterError: filterError ?? this.filterError,
    failure: identical(failure, _keep) ? this.failure : failure as Failure?,
    optionsFailure: identical(optionsFailure, _keep)
        ? this.optionsFailure
        : optionsFailure as Failure?,
  );
}

class RequestsPathReportCubit extends Cubit<RequestsPathReportState> {
  RequestsPathReportCubit({
    required this.getReport,
    required this.getLookup,
    required this.getLocations,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(
         RequestsPathReportState(
           active: RequestsPathReportFilter.currentMonth(
             (now ?? DateTime.now)(),
           ),
         ),
       );
  final GetRequestsPathReportUseCase getReport;
  final GetRequestLookupUseCase getLookup;
  final GetReportLocationsUseCase getLocations;
  final DateTime Function() now;
  bool _started = false;
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
      state.lookup == null ? getLookup() : Future.value(Success(state.lookup!)),
      state.locations.isEmpty
          ? getLocations()
          : Future.value(Success(state.locations)),
    ]);
    if (isClosed) return;
    final lookup = results[0] as Result<RequestLookupData>;
    final locations = results[1] as Result<List<IncidentLocationDto>>;
    emit(
      state.copyWith(
        optionsLoading: false,
        lookup: lookup is Success<RequestLookupData> ? lookup.data : null,
        locations: locations is Success<List<IncidentLocationDto>>
            ? locations.data
            : null,
        optionsFailure: lookup is FailureResult<RequestLookupData>
            ? lookup.failure
            : locations is FailureResult<List<IncidentLocationDto>>
            ? locations.failure
            : null,
      ),
    );
  }

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

  String? statusCode(int? id) {
    final matches =
        (state.lookup?.requestStatus ?? const <RequestLookupItemDto>[])
            .where((e) => e.id == id)
            .toList();
    return matches.length == 1 ? matches.single.code : null;
  }

  void beginFilters() =>
      emit(state.copyWith(draft: state.active, filterError: false));
  void cancelFilters() => emit(state.copyWith(draft: null, filterError: false));
  void updateDraft(RequestsPathReportFilter filter) {
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
      draft: RequestsPathReportFilter.currentMonth(now()),
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

  Future<void> resetFilters() async {
    emit(
      state.copyWith(
        active: RequestsPathReportFilter.currentMonth(now()),
        draft: null,
        data: null,
        filterError: false,
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
