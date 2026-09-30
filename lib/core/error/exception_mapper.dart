import 'package:dio/dio.dart';
import '../network/result.dart';
import 'failure.dart';
import '../network/api_exception.dart';

abstract final class ExceptionMapper {
  static Failure map(Object error) {
    if (error is ApiException) return error.failure;
    if (error is DioException) {
      if (error.error is Failure) return error.error! as Failure;
      return switch (error.type) {
        DioExceptionType.cancel => const CancelledFailure(),
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => const TimeoutFailure(),
        DioExceptionType.connectionError ||
        DioExceptionType.badCertificate => const NetworkFailure(),
        _ => switch (error.response?.statusCode) {
          401 || 403 => const UnauthorizedFailure(),
          400 || 422 => const ValidationFailure(),
          final int code when code >= 500 => const ServerFailure(),
          _ => const UnknownFailure(),
        },
      };
    }
    return const UnknownFailure();
  }
}

/// Single error boundary shared by repositories; never exposes transport errors.
Future<Result<T>> apiGuard<T>(Future<T> Function() operation) async {
  try {
    return Success(await operation());
  } on Exception catch (error) {
    return FailureResult(ExceptionMapper.map(error));
  }
}
