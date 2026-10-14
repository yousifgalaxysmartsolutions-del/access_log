import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../../../models/models.dart';
import '../../data/models/incident_details_models.dart';
import '../../domain/usecases/get_incident_list_use_case.dart';
import '../../domain/usecases/get_incident_requests_use_case.dart';
import '../../domain/usecases/incident_geofence_use_case.dart';

class IncidentMapSite {
  IncidentMapSite({
    required this.key,
    required this.tower,
    required List<CapIncident> incidents,
  }) : incidents = List.unmodifiable(incidents);
  final String key;
  final TowerSite tower;
  final List<CapIncident> incidents;
}

class IncidentMapState {
  const IncidentMapState({
    this.loading = false,
    this.failure,
    this.sites = const [],
    this.query = '',
    this.missingCoordinates = 0,
    this.requestsLoading = false,
    this.requestsFailure,
    this.requests = const [],
  });
  final bool loading, requestsLoading;
  final Failure? failure, requestsFailure;
  final List<IncidentMapSite> sites;
  final String query;
  final int missingCoordinates;
  final List<IncidentRequestItemDto> requests;
  IncidentMapState copyWith({
    bool? loading,
    Failure? failure,
    bool clearFailure = false,
    List<IncidentMapSite>? sites,
    String? query,
    int? missingCoordinates,
    bool? requestsLoading,
    Failure? requestsFailure,
    bool clearRequestsFailure = false,
    List<IncidentRequestItemDto>? requests,
  }) => IncidentMapState(
    loading: loading ?? this.loading,
    failure: clearFailure ? null : failure ?? this.failure,
    sites: sites ?? this.sites,
    query: query ?? this.query,
    missingCoordinates: missingCoordinates ?? this.missingCoordinates,
    requestsLoading: requestsLoading ?? this.requestsLoading,
    requestsFailure: clearRequestsFailure
        ? null
        : requestsFailure ?? this.requestsFailure,
    requests: requests ?? this.requests,
  );
}

class IncidentMapCubit extends Cubit<IncidentMapState> {
  IncidentMapCubit({
    required this.getIncidents,
    required this.getRequests,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(const IncidentMapState());
  final GetIncidentListUseCase getIncidents;
  final GetIncidentRequestsUseCase getRequests;
  final DateTime Function() now;
  int _revision = 0, _requestRevision = 0;
  List<IncidentMapSite> get visibleSites {
    final query = state.query.trim().toLowerCase();
    return state.sites
        .where(
          (site) =>
              query.isEmpty ||
              [
                site.tower.name,
                site.tower.code,
                site.tower.region,
                site.tower.area,
                ...site.incidents.map((e) => e.number),
              ].any((e) => e.toLowerCase().contains(query)),
        )
        .toList(growable: false);
  }

  void search(String query) => emit(state.copyWith(query: query));
  Future<void> refresh() async {
    final revision = ++_revision;
    final current = now();
    final today = DateTime(current.year, current.month, current.day);
    emit(state.copyWith(loading: true, clearFailure: true));
    final result = await getIncidents(day: today, toDate: today);
    if (isClosed || revision != _revision) return;
    switch (result) {
      case FailureResult(:final failure):
        emit(state.copyWith(loading: false, failure: failure));
      case Success(:final data):
        final groups = <String, List<CapIncident>>{};
        for (final incident in data) {
          final key = incident.siteCode.trim().isNotEmpty
              ? 'code:${incident.siteCode}'
              : '${incident.siteName}|${incident.region}|${incident.area}|${incident.latitude}|${incident.longitude}';
          groups.putIfAbsent(key, () => []).add(incident);
        }
        var missing = 0;
        final sites = <IncidentMapSite>[];
        for (final group in groups.entries) {
          final located = group.value.where(
            (e) => IncidentGeofenceUseCase.validCoordinates(
              e.latitude,
              e.longitude,
            ),
          );
          if (located.isEmpty) {
            missing += group.value.length;
            continue;
          }
          final first = located.first;
          sites.add(
            IncidentMapSite(
              key: group.key,
              tower: TowerSite(
                name: first.siteName,
                code: first.siteCode,
                region: first.region,
                area: first.area,
                latitude: first.latitude!,
                longitude: first.longitude!,
              ),
              incidents: group.value,
            ),
          );
        }
        emit(
          state.copyWith(
            loading: false,
            sites: List.unmodifiable(sites),
            missingCoordinates: missing,
          ),
        );
    }
  }

  Future<void> loadRequests(IncidentMapSite site) async {
    final revision = ++_requestRevision;
    emit(
      state.copyWith(
        requestsLoading: true,
        clearRequestsFailure: true,
        requests: const [],
      ),
    );
    final requests = <IncidentRequestItemDto>[];
    final seen = <int>{};
    for (final incident in site.incidents) {
      if (incident.incidentId <= 0) continue;
      final result = await getRequests(incidentId: incident.incidentId);
      if (isClosed || revision != _requestRevision) return;
      switch (result) {
        case FailureResult(:final failure):
          emit(
            state.copyWith(requestsLoading: false, requestsFailure: failure),
          );
          return;
        case Success(:final data):
          for (final item in data.items ?? const <IncidentRequestItemDto>[]) {
            if (item.id == null || seen.add(item.id!)) requests.add(item);
          }
      }
    }
    if (!isClosed && revision == _requestRevision) {
      emit(
        state.copyWith(
          requestsLoading: false,
          requests: List.unmodifiable(requests),
        ),
      );
    }
  }
}
