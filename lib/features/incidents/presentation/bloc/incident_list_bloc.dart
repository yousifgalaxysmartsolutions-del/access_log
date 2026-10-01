import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../../../models/models.dart';
import '../../domain/usecases/get_incident_list_use_case.dart';

class IncidentListState {
  const IncidentListState({
    required this.from,
    required this.to,
    this.loading = false,
    this.incidents = const [],
    this.failure,
  });
  final DateTime from, to;
  final bool loading;
  final List<CapIncident> incidents;
  final Failure? failure;
}

class LoadIncidentList {
  LoadIncidentList(this.from, this.to);
  final DateTime from, to;
  final done = Completer<void>();
}

class IncidentListBloc extends Bloc<LoadIncidentList, IncidentListState> {
  IncidentListBloc(this._getList, {DateTime? today})
    : super(
        IncidentListState(
          from: dayOnly(today ?? DateTime.now()),
          to: dayOnly(today ?? DateTime.now()),
        ),
      ) {
    on<LoadIncidentList>((event, emit) async {
      final request = ++_request;
      try {
        if (event.from.isAfter(event.to)) {
          emit(
            IncidentListState(
              from: state.from,
              to: state.to,
              incidents: state.incidents,
              failure: const ValidationFailure(),
            ),
          );
          return;
        }
        final sameRange = event.from == state.from && event.to == state.to;
        final previous = sameRange ? state.incidents : <CapIncident>[];
        emit(
          IncidentListState(
            from: event.from,
            to: event.to,
            loading: true,
            incidents: previous,
          ),
        );
        final result = _getList == null
            ? const FailureResult<List<CapIncident>>(UnauthorizedFailure())
            : await _getList(day: event.from, toDate: event.to);
        if (request != _request || emit.isDone) return;
        switch (result) {
          case Success(:final data):
            emit(
              IncidentListState(
                from: event.from,
                to: event.to,
                incidents: data,
              ),
            );
          case FailureResult(:final failure):
            emit(
              IncidentListState(
                from: event.from,
                to: event.to,
                incidents: previous,
                failure: failure,
              ),
            );
        }
      } finally {
        event.done.complete();
      }
    });
  }
  final GetIncidentListUseCase? _getList;
  int _request = 0;
  static DateTime dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  static (DateTime, DateTime) range(
    IncidentListFilter filter, {
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    return (
      dayOnly(filter.from ?? filter.to ?? now),
      dayOnly(filter.to ?? filter.from ?? now),
    );
  }

  Future<void> load(DateTime from, DateTime to) {
    final event = LoadIncidentList(dayOnly(from), dayOnly(to));
    add(event);
    return event.done.future;
  }
}
