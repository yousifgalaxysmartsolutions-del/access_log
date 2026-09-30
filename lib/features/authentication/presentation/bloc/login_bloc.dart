import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../domain/usecases/login_use_case.dart';

class LoginSubmitted {
  const LoginSubmitted(this.username, this.password, this.remember);
  final String username, password;
  final bool remember;
}

enum LoginStatus { initial, loading, success, failure }

class LoginState {
  const LoginState(this.status, [this.failure]);
  final LoginStatus status;
  final Failure? failure;
}

class LoginBloc extends Bloc<LoginSubmitted, LoginState> {
  LoginBloc(LoginUseCase login) : super(const LoginState(LoginStatus.initial)) {
    on<LoginSubmitted>((event, emit) async {
      if (state.status == LoginStatus.loading) return;
      emit(const LoginState(LoginStatus.loading));
      final result = await login(
        username: event.username,
        password: event.password,
        remember: event.remember,
      );
      switch (result) {
        case Success():
          emit(const LoginState(LoginStatus.success));
        case FailureResult(:final failure):
          emit(LoginState(LoginStatus.failure, failure));
      }
    });
  }
}
