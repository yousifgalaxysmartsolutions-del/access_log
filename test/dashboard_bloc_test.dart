import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/dashboard/domain/usecases/get_dashboard_stats_use_case.dart';
import 'package:access_log_plus/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:access_log_plus/features/dashboard/data/models/dashboard_stats_models.dart';
import 'package:access_log_plus/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_repository.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_list_use_case.dart';
import 'package:access_log_plus/models/models.dart';

class _FakeDashboardRepository implements DashboardRepository {
  int calls = 0;
  @override
  Future<Result<DashboardStatsData>> getStats({
    required DateTime forMonth,
  }) async {
    calls++;
    return Success(
      DashboardStatsData(
        totalIncidents: 5,
        openIncidents: 2,
        inProgress: 1,
        completed: 3,
        onHold: 0,
        todaysActivities: 1,
        needApproval: 0,
        monthSummary: MonthSummary(
          year: forMonth.year,
          month: forMonth.month,
          totalIncident: 5,
          completed: 3,
          percentage: 60,
        ),
      ),
    );
  }
}

class _FakeIncidentRepository implements IncidentRepository {
  int calls = 0;
  @override
  Future<Result<List<CapIncident>>> getIncidentsForDay({
    required DateTime day,
  }) async {
    calls++;
    return Success(const []);
  }
}

void main() {
  test('DashboardBloc loads both sections in one event', () async {
    final dashRepo = _FakeDashboardRepository();
    final incRepo = _FakeIncidentRepository();
    final bloc = DashboardBloc(
      getDashboardStats: GetDashboardStatsUseCase(dashRepo),
      getIncidentList: GetIncidentListUseCase(incRepo),
      now: () => DateTime(2026, 8, 10),
    );

    bloc.add(const DashboardRequested());
    await expectLater(
      bloc.stream,
      emitsInOrder([
        predicate<DashboardState>((s) => s.status == DashboardStatus.loading),
        predicate<DashboardState>(
          (s) => s.status == DashboardStatus.ready && s.stats != null,
        ),
      ]),
    );

    expect(dashRepo.calls, 1);
    expect(incRepo.calls, 1);
    await bloc.close();
  });

  test('DashboardBloc refresh triggers a second load of both repos', () async {
    final dashRepo = _FakeDashboardRepository();
    final incRepo = _FakeIncidentRepository();
    final bloc = DashboardBloc(
      getDashboardStats: GetDashboardStatsUseCase(dashRepo),
      getIncidentList: GetIncidentListUseCase(incRepo),
      now: () => DateTime(2026, 8, 10),
    );

    bloc.add(const DashboardRequested());
    await bloc.stream.firstWhere((s) => s.status == DashboardStatus.ready);

    bloc.add(const DashboardRefreshed());
    await bloc.stream.firstWhere((s) => s.status == DashboardStatus.ready);

    expect(dashRepo.calls, 2);
    expect(incRepo.calls, 2);
    await bloc.close();
  });

  test('DashboardBloc reloads when a refresh is queued after ready', () async {
    final gate = Completer<void>();
    final dashRepo = _GatedDashboardRepository(gate);
    final incRepo = _FakeIncidentRepository();
    final bloc = DashboardBloc(
      getDashboardStats: GetDashboardStatsUseCase(dashRepo),
      getIncidentList: GetIncidentListUseCase(incRepo),
      now: () => DateTime(2026, 8, 10),
    );

    bloc.add(const DashboardRequested());
    bloc.add(const DashboardRefreshed());
    gate.complete();
    // The second handler runs after the first has settled to ready, so it is a
    // genuine reload rather than a duplicate of an in-flight request.
    await bloc.stream.firstWhere((s) => s.status == DashboardStatus.ready);
    await Future<void>.delayed(Duration.zero);

    expect(dashRepo.calls, 2);
    expect(incRepo.calls, 2);
    await bloc.close();
  });

  test('DashboardBloc surfaces failure per section', () async {
    final bloc = DashboardBloc(
      getDashboardStats: GetDashboardStatsUseCase(_FailingDashboardRepo()),
      getIncidentList: GetIncidentListUseCase(_FakeIncidentRepository()),
      now: () => DateTime(2026, 8, 10),
    );

    bloc.add(const DashboardRequested());
    final state = await bloc.stream.firstWhere(
      (s) => s.status == DashboardStatus.ready,
    );

    expect(state.statsFailure, isA<ServerFailure>());
    expect(state.incidentsFailure, isNull);
    await bloc.close();
  });
}

class _FailingDashboardRepo implements DashboardRepository {
  @override
  Future<Result<DashboardStatsData>> getStats({
    required DateTime forMonth,
  }) async => const FailureResult(ServerFailure('cap offline'));
}

/// Holds the stats request open so overlapping events can be tested.
class _GatedDashboardRepository implements DashboardRepository {
  _GatedDashboardRepository(this._gate);
  final Completer<void> _gate;
  int calls = 0;
  @override
  Future<Result<DashboardStatsData>> getStats({
    required DateTime forMonth,
  }) async {
    calls++;
    await _gate.future;
    return Success(
      DashboardStatsData(
        totalIncidents: 1,
        openIncidents: 0,
        inProgress: 0,
        completed: 1,
        onHold: 0,
        todaysActivities: 0,
        needApproval: 0,
        monthSummary: MonthSummary(
          year: forMonth.year,
          month: forMonth.month,
          totalIncident: 1,
          completed: 1,
          percentage: 100,
        ),
      ),
    );
  }
}
