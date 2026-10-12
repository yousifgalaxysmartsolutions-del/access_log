import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../data/models/request_models.dart';
import '../../domain/usecases/get_request_details_use_case.dart';

class RequestDetailsState {
  const RequestDetailsState({this.loading = false, this.data, this.failure});
  final bool loading;
  final RequestDetailsData? data;
  final Failure? failure;
}

class RequestDetailsCubit extends Cubit<RequestDetailsState> {
  RequestDetailsCubit(this._getDetails) : super(const RequestDetailsState());
  final GetRequestDetailsUseCase _getDetails;
  int _revision = 0;

  Future<void> load(int requestId) async {
    final revision = ++_revision;
    emit(const RequestDetailsState(loading: true));
    final result = await _getDetails(requestId);
    if (isClosed || revision != _revision) return;
    switch (result) {
      case Success(:final data):
        if (data.id != requestId) {
          emit(
            const RequestDetailsState(
              failure: ValidationFailure('Unexpected request details'),
            ),
          );
        } else {
          emit(RequestDetailsState(data: data));
        }
      case FailureResult(:final failure):
        emit(RequestDetailsState(failure: failure));
    }
  }
}
