import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../../incidents/data/incident_lookup_store.dart';
import '../../../incidents/data/models/incident_details_models.dart';
import '../../../incidents/data/models/incident_lookup_models.dart';
import '../../data/models/incident_report_models.dart';
import '../../domain/usecases/incident_report_use_cases.dart';
import '../../../../models/models.dart';
import '../../data/mappers/incident_report_mapper.dart';

const _keep = Object();

class IncidentReportState {
  const IncidentReportState({
    required this.active,
    this.draft,
    this.data,
    this.lookup,
    this.locations = const [],
    this.loading = false,
    this.optionsLoading = false,
    this.failure,
    this.optionsFailure,
    this.filterError = false,
    this.sort = IncidentReportSort.newest,
  });
  final IncidentReportFilter active;
  final IncidentReportFilter? draft;
  final IncidentReportData? data;
  final IncidentLookupData? lookup;
  final List<IncidentLocationDto> locations;
  final bool loading, optionsLoading, filterError;
  final Failure? failure, optionsFailure;
  final IncidentReportSort sort;
  bool get canPrevious => !loading && (data?.page ?? 1) > 1;
  bool get canNext =>
      !loading &&
      data != null &&
      data!.pageSize > 0 &&
      data!.page * data!.pageSize < data!.totalCount;
  IncidentReportState copyWith({
    IncidentReportFilter? active,
    Object? draft = _keep,
    Object? data = _keep,
    IncidentLookupData? lookup,
    List<IncidentLocationDto>? locations,
    bool? loading,
    bool? optionsLoading,
    Object? failure = _keep,
    Object? optionsFailure = _keep,
    bool? filterError,
    IncidentReportSort? sort,
  }) => IncidentReportState(
    active: active ?? this.active,
    draft: identical(draft, _keep)
        ? this.draft
        : draft as IncidentReportFilter?,
    data: identical(data, _keep) ? this.data : data as IncidentReportData?,
    lookup: lookup ?? this.lookup,
    locations: locations ?? this.locations,
    loading: loading ?? this.loading,
    optionsLoading: optionsLoading ?? this.optionsLoading,
    failure: identical(failure, _keep) ? this.failure : failure as Failure?,
    optionsFailure: identical(optionsFailure, _keep)
        ? this.optionsFailure
        : optionsFailure as Failure?,
    filterError: filterError ?? this.filterError,
    sort: sort ?? this.sort,
  );
}

class IncidentReportCubit extends Cubit<IncidentReportState> {
  IncidentReportCubit({
    required this.getReport,
    required this.getLocations,
    required this.lookupStore,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(
         IncidentReportState(
           active: IncidentReportFilter.currentMonth((now ?? DateTime.now)()),
         ),
       );
  final GetIncidentReportUseCase getReport;
  final GetReportLocationsUseCase getLocations;
  final IncidentLookupStore lookupStore;
  final DateTime Function() now;
  int _revision = 0;
  bool _started = false;
  Timer? _searchTimer;
  List<CapIncident> get incidents {
    final items = (state.data?.items ?? const <IncidentReportItem>[])
        .map(IncidentReportMapper.toIncident)
        .toList();
    switch (state.sort) {
      case IncidentReportSort.newest:
        items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      case IncidentReportSort.oldest:
        items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      case IncidentReportSort.priority:
        const rank = {
          Priority.critical: 0,
          Priority.high: 1,
          Priority.medium: 2,
          Priority.low: 3,
        };
        items.sort((a, b) => rank[a.priority]!.compareTo(rank[b.priority]!));
    }
    return List.unmodifiable(items);
  }

  void changeSort(IncidentReportSort sort) => emit(state.copyWith(sort: sort));
  void setDraftRange(IncidentReportDateRange range) {
    final draft = state.draft;
    if (draft == null) return;
    final today = DateTime(now().year, now().month, now().day);
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

  void updateSearch(String keyword) {
    _searchTimer?.cancel();
    _revision++;
    emit(
      state.copyWith(
        active: state.active.copyWith(searchKeyword: keyword, page: 1),
        data: null,
        loading: true,
        failure: null,
      ),
    );
    _searchTimer = Timer(const Duration(milliseconds: 350), () => _load());
  }

  Future<void> loadInitial() async {
    if (_started) return;
    _started = true;
    await Future.wait([loadOptions(), _load()]);
  }

  Future<void> loadOptions() async {
    if (state.optionsLoading) return;
    emit(state.copyWith(optionsLoading: true, optionsFailure: null));
    final results = await Future.wait<Object>([
      lookupStore.current == null
          ? lookupStore.refresh()
          : Future.value(Success(lookupStore.current!)),
      getLocations(),
    ]);
    if (isClosed) return;
    final lookup = results[0] as Result<IncidentLookupData>;
    final locations = results[1] as Result<List<IncidentLocationDto>>;
    emit(
      state.copyWith(
        optionsLoading: false,
        lookup: lookup is Success<IncidentLookupData> ? lookup.data : null,
        locations: locations is Success<List<IncidentLocationDto>>
            ? locations.data
            : null,
        optionsFailure: lookup is FailureResult<IncidentLookupData>
            ? lookup.failure
            : locations is FailureResult<List<IncidentLocationDto>>
            ? locations.failure
            : null,
      ),
    );
  }

  List<IdNameDto> get regions => _unique(state.locations.map((e) => e.region));
  List<IdNameDto> get areas => _unique(
    state.locations
        .where(
          (e) =>
              (state.draft ?? state.active).regionId == -1 ||
              e.region?.id == (state.draft ?? state.active).regionId,
        )
        .map((e) => e.area),
  );
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

  List<IdNameDto> _unique(Iterable<IdNameDto?> values) {
    final byId = <int, IdNameDto>{};
    for (final value in values) {
      if (value?.id != null) byId.putIfAbsent(value!.id!, () => value);
    }
    return List.unmodifiable(byId.values);
  }

  void beginFilters() =>
      emit(state.copyWith(draft: state.active, filterError: false));
  void cancelFilters() => emit(state.copyWith(draft: null, filterError: false));
  void updateDraft(IncidentReportFilter filter) {
    if (state.draft == null) return;
    final compatibleArea =
        filter.areaId == -1 ||
        state.locations.any(
          (site) =>
              site.area?.id == filter.areaId &&
              (filter.regionId == -1 || site.region?.id == filter.regionId),
        );
    filter = filter.copyWith(areaId: compatibleArea ? filter.areaId : -1);
    final compatibleSite =
        filter.locationCode.isEmpty ||
        state.locations.any(
          (site) =>
              site.id == filter.locationCode &&
              (filter.regionId == -1 || site.region?.id == filter.regionId) &&
              (filter.areaId == -1 || site.area?.id == filter.areaId),
        );
    emit(
      state.copyWith(
        draft: filter.copyWith(
          locationCode: compatibleSite ? filter.locationCode : '',
        ),
        filterError: false,
      ),
    );
  }

  void resetDraft() => emit(
    state.copyWith(
      draft: IncidentReportFilter.currentMonth(now()),
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
    await _load();
    return true;
  }

  Future<void> search(String keyword) async {
    emit(
      state.copyWith(
        active: state.active.copyWith(searchKeyword: keyword, page: 1),
        data: null,
      ),
    );
    await _load();
  }

  Future<void> refresh() => _load();
  Future<void> loadPage(int page) async {
    if (state.loading ||
        page < 1 ||
        state.data == null ||
        (page > state.data!.page && !state.canNext)) {
      return;
    }
    emit(state.copyWith(active: state.active.copyWith(page: page), data: null));
    await _load();
  }

  Future<void> filterStatus(int id) async {
    emit(
      state.copyWith(
        active: state.active.copyWith(statusId: id, page: 1),
        data: null,
      ),
    );
    await _load();
  }

  /// Resolve only an unambiguous lookup code; never fall back to fixed IDs.
  int? statusIdForCode(String code) {
    final matches = (state.lookup?.status ?? const <IncidentLookupItem>[])
        .where(
          (item) =>
              item.code?.trim().toUpperCase() == code.trim().toUpperCase(),
        )
        .toList(growable: false);
    if (matches.length != 1) return null;
    final id = matches.single.id;
    return id != null && id > 0 ? id : null;
  }

  Future<void> _load() async {
    _searchTimer?.cancel();
    final revision = ++_revision;
    final filter = state.active;
    emit(state.copyWith(loading: true, failure: null));
    final result = await getReport(filter);
    if (isClosed || revision != _revision) return;
    switch (result) {
      case Success(:final data):
        emit(state.copyWith(data: data, loading: false));
      case FailureResult(:final failure):
        emit(state.copyWith(failure: failure, loading: false));
    }
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
