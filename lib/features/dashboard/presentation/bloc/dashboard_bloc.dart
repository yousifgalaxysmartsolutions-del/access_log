import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../../../models/models.dart';
import '../../domain/usecases/get_dashboard_stats_use_case.dart';
import '../../../incidents/domain/usecases/get_incident_list_use_case.dart';
import '../../data/models/dashboard_stats_models.dart';

sealed class DashboardEvent {
  const DashboardEvent();
}

/// First load, issued when the screen is created.
class DashboardRequested extends DashboardEvent {
  const DashboardRequested();
}

/// Pull-to-refresh. Reloads both sections with no artificial delay.
class DashboardRefreshed extends DashboardEvent {
  const DashboardRefreshed();
}

enum DashboardStatus { initial, loading, ready, failure }

/// Statistics and the day's incidents are tracked separately so one failing
/// endpoint cannot hide the other's data.
class DashboardState {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.stats,
    this.todayIncidents = const [],
    this.statsFailure,
    this.incidentsFailure,
  });

  final DashboardStatus status;
  final DashboardStatsData? stats;
  final List<CapIncident> todayIncidents;
  final Failure? statsFailure;
  final Failure? incidentsFailure;

  bool get isRefreshing => status == DashboardStatus.loading && hasContent;

  bool get hasContent => stats != null || todayIncidents.isNotEmpty;
}

/// Coordinates both dashboard reads behind a single bloc so the screen issues
/// one event instead of two independent ones.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required GetDashboardStatsUseCase getDashboardStats,
    required GetIncidentListUseCase getIncidentList,
    DateTime Function()? now,
  }) : _getDashboardStats = getDashboardStats,
       _getIncidentList = getIncidentList,
       _now = now ?? DateTime.now,
       super(const DashboardState()) {
    on<DashboardRequested>(_onRequested);
    on<DashboardRefreshed>(_onRefreshed);
  }

  final GetDashboardStatsUseCase _getDashboardStats;
  final GetIncidentListUseCase _getIncidentList;

  /// Injected so tests can pin "today" instead of depending on the wall clock.
  final DateTime Function() _now;

  Future<void> _onRequested(
    DashboardRequested event,
    Emitter<DashboardState> emit,
  ) => _load(emit);

  Future<void> _onRefreshed(
    DashboardRefreshed event,
    Emitter<DashboardState> emit,
  ) => _load(emit);

  Future<void> _load(Emitter<DashboardState> emit) async {
    // Guards against a refresh landing while the first load is still running.
    if (state.status == DashboardStatus.loading) return;
    emit(
      DashboardState(
        status: DashboardStatus.loading,
        stats: state.stats,
        todayIncidents: state.todayIncidents,
      ),
    );

    final requestedAt = _now();
    final results = await (
      _getDashboardStats(forMonth: requestedAt),
      _getIncidentList(day: requestedAt),
    ).wait;

    emit(
      DashboardState(
        status: DashboardStatus.ready,
        stats: _valueOf(results.$1),
        todayIncidents: _valueOf(results.$2) ?? const [],
        statsFailure: _failureOf(results.$1),
        incidentsFailure: _failureOf(results.$2),
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
