import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../data/models/request_models.dart';
import '../../domain/usecases/get_request_lookup_use_case.dart';
import '../../domain/usecases/get_request_list_use_case.dart';
import '../../domain/usecases/approve_request_use_case.dart';
import '../../domain/usecases/reject_request_use_case.dart';

enum RequestActionKind { approve, reject }

/// Global action lookup is not permission data. Only the confirmed Pending
/// workflow enables decisions, using the status lookup when available.
bool canDecideRequest(RequestListItemDto item, RequestLookupData? lookup) {
  if (item.id == null || item.id! <= 0) return false;
  final statuses = lookup?.requestStatus;
  if (statuses != null && statuses.isNotEmpty) {
    final matched = statuses
        .where((s) => s.id != null && s.id == item.requestStatus?.id)
        .firstOrNull;
    return matched != null &&
        (matched.code ?? matched.name ?? '').trim().toLowerCase() == 'pending';
  }
  return item.requestStatus?.name?.trim().toLowerCase() == 'pending';
}

sealed class RequestListEvent {
  const RequestListEvent();
}

class LoadRequestLookup extends RequestListEvent {
  const LoadRequestLookup();
}

class LoadRequests extends RequestListEvent {
  const LoadRequests();
}

class RefreshRequests extends RequestListEvent {
  const RefreshRequests();
}

class LoadMoreRequests extends RequestListEvent {
  const LoadMoreRequests();
}

class ApproveRequest extends RequestListEvent {
  const ApproveRequest({required this.requestId, required this.remark});
  final int requestId;
  final String remark;
}

class RejectRequest extends RequestListEvent {
  const RejectRequest({required this.requestId, required this.reason});
  final int requestId;
  final String reason;
}

class ApplyRequestFilters extends RequestListEvent {
  const ApplyRequestFilters({
    required this.fromDate,
    required this.toDate,
    required this.requestTypeId,
    required this.requestStatusId,
    required this.locationCode,
    required this.incidentNo,
  });
  final DateTime fromDate, toDate;
  final int requestTypeId, requestStatusId;
  final String locationCode, incidentNo;
}

const _unchanged = Object();

class RequestListState {
  RequestListState({
    required this.fromDate,
    required this.toDate,
    this.lookupData,
    this.lookupLoading = false,
    this.lookupFailure,
    List<RequestListItemDto> items = const [],
    this.loading = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.failure,
    this.loadMoreFailure,
    this.totalCount = 0,
    this.page = 1,
    this.pageSize = 20,
    this.requestTypeId = -1,
    this.requestStatusId = -1,
    this.locationCode = '',
    this.incidentNo = '',
    this.actingRequestId,
    this.actingAction,
    this.actionFailure,
    this.lastDecision,
    this.completedAction,
    this.actionRevision = 0,
  }) : items = List.unmodifiable(items);
  final RequestLookupData? lookupData;
  final bool lookupLoading;
  final Failure? lookupFailure;
  final List<RequestListItemDto> items;
  final bool loading, refreshing, loadingMore;
  final Failure? failure, loadMoreFailure;
  final int totalCount, page, pageSize;
  final DateTime fromDate, toDate;
  final int requestTypeId, requestStatusId;
  final String locationCode, incidentNo;
  final int? actingRequestId;
  final RequestActionKind? actingAction, completedAction;
  final Failure? actionFailure;
  final RequestDecisionData? lastDecision;
  final int actionRevision;
  bool get hasMore => items.length < totalCount;

  // Sentinel parameters distinguish preserving an error from explicitly
  // clearing it. Lookup/list updates always copy from the latest state.
  RequestListState copyWith({
    RequestLookupData? lookupData,
    bool? lookupLoading,
    Object? lookupFailure = _unchanged,
    List<RequestListItemDto>? items,
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    Object? failure = _unchanged,
    Object? loadMoreFailure = _unchanged,
    int? totalCount,
    int? page,
    int? pageSize,
    DateTime? fromDate,
    DateTime? toDate,
    int? requestTypeId,
    int? requestStatusId,
    String? locationCode,
    String? incidentNo,
    Object? actingRequestId = _unchanged,
    Object? actingAction = _unchanged,
    Object? actionFailure = _unchanged,
    Object? lastDecision = _unchanged,
    RequestActionKind? completedAction,
    int? actionRevision,
  }) => RequestListState(
    lookupData: lookupData ?? this.lookupData,
    lookupLoading: lookupLoading ?? this.lookupLoading,
    lookupFailure: identical(lookupFailure, _unchanged)
        ? this.lookupFailure
        : lookupFailure as Failure?,
    items: items ?? this.items,
    loading: loading ?? this.loading,
    refreshing: refreshing ?? this.refreshing,
    loadingMore: loadingMore ?? this.loadingMore,
    failure: identical(failure, _unchanged)
        ? this.failure
        : failure as Failure?,
    loadMoreFailure: identical(loadMoreFailure, _unchanged)
        ? this.loadMoreFailure
        : loadMoreFailure as Failure?,
    totalCount: totalCount ?? this.totalCount,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    fromDate: fromDate ?? this.fromDate,
    toDate: toDate ?? this.toDate,
    requestTypeId: requestTypeId ?? this.requestTypeId,
    requestStatusId: requestStatusId ?? this.requestStatusId,
    locationCode: locationCode ?? this.locationCode,
    incidentNo: incidentNo ?? this.incidentNo,
    actingRequestId: identical(actingRequestId, _unchanged)
        ? this.actingRequestId
        : actingRequestId as int?,
    actingAction: identical(actingAction, _unchanged)
        ? this.actingAction
        : actingAction as RequestActionKind?,
    actionFailure: identical(actionFailure, _unchanged)
        ? this.actionFailure
        : actionFailure as Failure?,
    lastDecision: identical(lastDecision, _unchanged)
        ? this.lastDecision
        : lastDecision as RequestDecisionData?,
    completedAction: completedAction ?? this.completedAction,
    actionRevision: actionRevision ?? this.actionRevision,
  );
}

class RequestListBloc extends Bloc<RequestListEvent, RequestListState> {
  RequestListBloc({
    required GetRequestLookupUseCase getRequestLookup,
    required GetRequestListUseCase getRequestList,
    required ApproveRequestUseCase approveRequest,
    required RejectRequestUseCase rejectRequest,
    DateTime Function()? now,
  }) : _lookup = getRequestLookup,
       _list = getRequestList,
       _approve = approveRequest,
       _reject = rejectRequest,
       super(_initial((now ?? DateTime.now)())) {
    on<LoadRequestLookup>(_loadLookup);
    on<LoadRequests>((event, emit) async {
      if (state.loading || state.refreshing) return;
      await _reload(emit);
    });
    on<RefreshRequests>((event, emit) => _reload(emit, refresh: true));
    on<ApplyRequestFilters>((event, emit) async {
      if (event.fromDate.isAfter(event.toDate)) {
        emit(state.copyWith(failure: const ValidationFailure()));
        return;
      }
      emit(
        state.copyWith(
          fromDate: event.fromDate,
          toDate: event.toDate,
          requestTypeId: event.requestTypeId,
          requestStatusId: event.requestStatusId,
          locationCode: event.locationCode,
          incidentNo: event.incidentNo,
          items: [],
          totalCount: 0,
          page: 1,
        ),
      );
      await _reload(emit);
    });
    on<LoadMoreRequests>(_loadMore);
    on<ApproveRequest>(
      (event, emit) => _decide(
        event.requestId,
        event.remark,
        RequestActionKind.approve,
        emit,
      ),
    );
    on<RejectRequest>(
      (event, emit) => _decide(
        event.requestId,
        event.reason,
        RequestActionKind.reject,
        emit,
      ),
    );
  }
  final GetRequestLookupUseCase _lookup;
  final GetRequestListUseCase _list;
  final ApproveRequestUseCase _approve;
  final RejectRequestUseCase _reject;
  int _lookupVersion = 0;
  int _queryVersion = 0;

  Future<void> _decide(
    int id,
    String text,
    RequestActionKind kind,
    Emitter<RequestListState> emit,
  ) async {
    if (state.actingRequestId != null) return;
    final row = state.items.where((item) => item.id == id).firstOrNull;
    if (id <= 0 || row == null || !canDecideRequest(row, state.lookupData)) {
      emit(
        state.copyWith(
          actionFailure: const ValidationFailure(),
          lastDecision: null,
          completedAction: kind,
          actionRevision: state.actionRevision + 1,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        actingRequestId: id,
        actingAction: kind,
        actionFailure: null,
        lastDecision: null,
      ),
    );
    final result = kind == RequestActionKind.approve
        ? await _approve(requestId: id, remark: text)
        : await _reject(requestId: id, reason: text);
    if (emit.isDone) return;
    switch (result) {
      case FailureResult(:final failure):
        emit(
          state.copyWith(
            actingRequestId: null,
            actingAction: null,
            actionFailure: failure,
            completedAction: kind,
            actionRevision: state.actionRevision + 1,
          ),
        );
      case Success(:final data):
        // Never apply a mismatched/missing decision to another row. Refresh
        // the current query in all cases; backend decides filter membership.
        final safe = data.id == id && data.requestStatus != null;
        emit(
          state.copyWith(
            items: safe
                ? state.items
                      .map(
                        (item) => item.id == data.id
                            ? item.withRequestStatus(data.requestStatus!)
                            : item,
                      )
                      .toList()
                : state.items,
            actingRequestId: null,
            actingAction: null,
            actionFailure: null,
            lastDecision: data,
            completedAction: kind,
            actionRevision: state.actionRevision + 1,
          ),
        );
        // Intentionally resets pagination to page 1 without resetting filters.
        // _reload also invalidates older reads/pages already in flight.
        await _reload(emit, refresh: true);
    }
  }

  static RequestListState _initial(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return RequestListState(fromDate: day, toDate: day);
  }

  Future<void> _loadLookup(
    LoadRequestLookup event,
    Emitter<RequestListState> emit,
  ) async {
    final version = ++_lookupVersion;
    emit(state.copyWith(lookupLoading: true, lookupFailure: null));
    final result = await _lookup();
    if (emit.isDone || version != _lookupVersion) return;
    switch (result) {
      case Success(:final data):
        emit(
          state.copyWith(
            lookupLoading: false,
            lookupData: data,
            lookupFailure: null,
          ),
        );
      case FailureResult(:final failure):
        emit(state.copyWith(lookupLoading: false, lookupFailure: failure));
    }
  }

  Future<Result<RequestListData>> _fetch(RequestListState query, int page) =>
      _list(
        fromDate: query.fromDate,
        toDate: query.toDate,
        requestTypeId: query.requestTypeId,
        requestStatusId: query.requestStatusId,
        locationCode: query.locationCode,
        incidentNo: query.incidentNo,
        page: page,
        pageSize: query.pageSize,
      );

  Future<void> _reload(
    Emitter<RequestListState> emit, {
    bool refresh = false,
  }) async {
    final version = ++_queryVersion;
    final keepVisible = refresh || state.items.isNotEmpty;
    emit(
      state.copyWith(
        loading: !keepVisible,
        refreshing: keepVisible,
        loadingMore: false,
        failure: null,
        loadMoreFailure: null,
      ),
    );
    final result = await _fetch(state, 1);
    if (emit.isDone || version != _queryVersion) return;
    switch (result) {
      case Success(:final data):
        emit(
          state.copyWith(
            items: _unique(data.items),
            totalCount: data.totalCount,
            page: data.page,
            pageSize: data.pageSize > 0 ? data.pageSize : state.pageSize,
            loading: false,
            refreshing: false,
            failure: null,
            loadMoreFailure: null,
          ),
        );
      case FailureResult(:final failure):
        emit(
          state.copyWith(loading: false, refreshing: false, failure: failure),
        );
    }
  }

  Future<void> _loadMore(
    LoadMoreRequests event,
    Emitter<RequestListState> emit,
  ) async {
    if (state.loading ||
        state.refreshing ||
        state.loadingMore ||
        !state.hasMore) {
      return;
    }
    final version = _queryVersion;
    final query = state;
    emit(state.copyWith(loadingMore: true, loadMoreFailure: null));
    final result = await _fetch(query, query.page + 1);
    if (emit.isDone || version != _queryVersion) return;
    switch (result) {
      case Success(:final data):
        if (data.page <= query.page) {
          emit(
            state.copyWith(
              loadingMore: false,
              loadMoreFailure: const ServerFailure(),
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            items: _unique([...query.items, ...data.items]),
            page: data.page,
            totalCount: data.totalCount,
            loadingMore: false,
            loadMoreFailure: null,
          ),
        );
      case FailureResult(:final failure):
        emit(state.copyWith(loadingMore: false, loadMoreFailure: failure));
    }
  }

  static List<RequestListItemDto> _unique(List<RequestListItemDto> items) {
    final seen = <int>{};
    return items
        .where((item) => item.id == null || seen.add(item.id!))
        .toList();
  }
}
