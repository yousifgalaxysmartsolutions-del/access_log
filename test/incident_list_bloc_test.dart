import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_repository.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_list_use_case.dart';
import 'package:access_log_plus/features/incidents/presentation/bloc/incident_list_bloc.dart';
import 'package:access_log_plus/features/incidents/data/mappers/incident_mapper.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_list_models.dart';
import 'package:access_log_plus/models/models.dart';

class ListRepositoryFake implements IncidentRepository {
  final calls = <(DateTime, DateTime)>[];
  Result<List<CapIncident>> result = const Success([]);
  Completer<Result<List<CapIncident>>>? gate;
  @override
  Future<Result<List<CapIncident>>> getIncidentsForDay({
    required DateTime day,
    DateTime? toDate,
  }) {
    calls.add((day, toDate ?? day));
    return gate?.future ?? Future.value(result);
  }
}

CapIncident apiIncident(
  int id, {
  String status = 'Pending',
  String priority = 'High',
  String? date,
}) => IncidentMapper.toIncident(
  IncidentListItem.fromJson({
    'incidentId': id,
    'incidentNo': 'INC-$id',
    'incidentTitle': 'Power $id',
    'locationName': 'Cairo Tower $id',
    'regionName': 'Cairo',
    'areaName': 'Central',
    'incidentType': 'Power',
    'status': {'name': status},
    'priority': {'name': priority},
    'incidentDate': ?date,
  }),
  requestedOn: DateTime(2026, 9, 1),
);

void main() {
  test('normalizes today, explicit and one-sided ranges', () {
    final today = DateTime(2030, 2, 3, 15);
    final day = DateTime(2030, 2, 3);
    expect(IncidentListBloc.range(const IncidentListFilter(), today: today), (
      day,
      day,
    ));
    for (final filter in [
      IncidentListFilter(from: day),
      IncidentListFilter(to: day),
    ]) {
      expect(IncidentListBloc.range(filter), (day, day));
    }
  });
  test(
    'loading, range, refresh failure retains list, empty success, invalid range',
    () async {
      final repo = ListRepositoryFake()..result = Success([apiIncident(71)]);
      final bloc = IncidentListBloc(GetIncidentListUseCase(repo));
      final from = DateTime(2026, 9, 1), to = DateTime(2026, 9, 30);
      await bloc.load(from, to);
      expect(repo.calls.single, (from, to));
      expect(bloc.state.incidents.single.incidentId, 71);
      expect(bloc.state.incidents.single.hasRealDate, false);
      repo.result = const FailureResult(NetworkFailure());
      await bloc.load(from, to);
      expect(bloc.state.incidents.single.incidentId, 71);
      expect(bloc.state.failure, isA<NetworkFailure>());
      repo.result = const Success([]);
      await bloc.load(from, to);
      expect(bloc.state.incidents, isEmpty);
      expect(bloc.state.failure, isNull);
      await bloc.load(to, from);
      expect(repo.calls.length, 3);
      expect(bloc.state.failure, isA<ValidationFailure>());
      await bloc.close();
    },
  );
  test(
    'newest request wins and changed range does not mislabel old rows',
    () async {
      final repo = ListRepositoryFake();
      final bloc = IncidentListBloc(GetIncidentListUseCase(repo));
      final gate = Completer<Result<List<CapIncident>>>();
      repo.gate = gate;
      final old = bloc.load(DateTime(2026, 1, 1), DateTime(2026, 1, 1));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.loading, true);
      repo.gate = null;
      repo.result = Success([apiIncident(2)]);
      await bloc.load(DateTime(2026, 2, 1), DateTime(2026, 2, 1));
      gate.complete(Success([apiIncident(1)]));
      await old;
      expect(bloc.state.incidents.single.incidentId, 2);
      await bloc.close();
    },
  );
}
