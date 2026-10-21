import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../domain/usecases/forgot_password_use_case.dart';

enum ForgotPasswordStatus { initial, loading, success, failure }

class ForgotPasswordState {
  const ForgotPasswordState(this.status, {this.failure, this.expiresInMinutes});
  final ForgotPasswordStatus status;
  final Failure? failure;
  final int? expiresInMinutes;
}

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit(this._requestReset)
    : super(const ForgotPasswordState(ForgotPasswordStatus.initial));
  final ForgotPasswordUseCase _requestReset;

  Future<void> submit(String username) async {
    if (isClosed ||
        state.status == ForgotPasswordStatus.loading ||
        state.status == ForgotPasswordStatus.success) {
      return;
    }
    emit(const ForgotPasswordState(ForgotPasswordStatus.loading));
    final result = await _requestReset(username);
    if (isClosed) return;
    switch (result) {
      case Success(:final data):
        emit(
          ForgotPasswordState(
            ForgotPasswordStatus.success,
            expiresInMinutes: data.linkExpiresInMinutes,
          ),
        );
      case FailureResult(:final failure):
        emit(
          ForgotPasswordState(ForgotPasswordStatus.failure, failure: failure),
        );
    }
  }
}
