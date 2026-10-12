import 'dart:async';
import 'package:flutter/foundation.dart';
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
    this.statusId = -1,
    this.filter = const IncidentListFilter(),
  });
  final DateTime from, to;
  final bool loading;
  final List<CapIncident> incidents;
  final Failure? failure;
  final int statusId;
  final IncidentListFilter filter;
}

class LoadIncidentList {
  LoadIncidentList(
    this.from,
    this.to, {
    this.statusId = -1,
    this.filter = const IncidentListFilter(),
  });
  final int statusId;
  final IncidentListFilter filter;
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
      debugPrint('[IncidentList load] StatusId=${event.statusId}');
      final request = ++_request;
      try {
        if (event.from.isAfter(event.to)) {
          emit(
            IncidentListState(
              from: state.from,
              to: state.to,
              incidents: state.incidents,
              statusId: state.statusId,
              filter: state.filter,
              failure: const ValidationFailure(),
            ),
          );
          return;
        }
        final sameRange =
            event.from == state.from &&
            event.to == state.to &&
            event.statusId == state.statusId &&
            event.filter.priorityId == state.filter.priorityId &&
            event.filter.incidentTypeId == state.filter.incidentTypeId &&
            event.filter.locationCode == state.filter.locationCode &&
            event.filter.incidentNumber == state.filter.incidentNumber;
        final previous = sameRange ? state.incidents : <CapIncident>[];
        emit(
          IncidentListState(
            from: event.from,
            to: event.to,
            loading: true,
            incidents: previous,
            statusId: event.statusId,
            filter: event.filter,
          ),
        );
        final result = _getList == null
            ? const FailureResult<List<CapIncident>>(UnauthorizedFailure())
            : await _getList(
                day: event.from,
                toDate: event.to,
                statusId: event.statusId,
                filter: event.filter,
              );
        if (request != _request || emit.isDone) return;
        switch (result) {
          case Success(:final data):
            emit(
              IncidentListState(
                from: event.from,
                to: event.to,
                incidents: data,
                statusId: event.statusId,
                filter: event.filter,
              ),
            );
          case FailureResult(:final failure):
            emit(
              IncidentListState(
                from: event.from,
                to: event.to,
                incidents: previous,
                failure: failure,
                statusId: event.statusId,
                filter: event.filter,
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

  Future<void> load(
    DateTime from,
    DateTime to, {
    int statusId = -1,
    IncidentListFilter filter = const IncidentListFilter(),
  }) {
    final event = LoadIncidentList(
      dayOnly(from),
      dayOnly(to),
      statusId: filter.statusId ?? statusId,
      filter: filter,
    );
    add(event);
    return event.done.future;
  }
}
