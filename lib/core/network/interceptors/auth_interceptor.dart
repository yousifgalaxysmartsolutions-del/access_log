import 'package:dio/dio.dart';
import '../../error/failure.dart';
import '../../session/session_manager.dart';
import '../../storage/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.dio, this.session, this.refresh);
  final Dio dio;
  final SessionManager session;
  final Future<SessionTokens> Function(String token) refresh;
  bool _protected(RequestOptions request) => request.extra['public'] != true;
  DioException _expired(RequestOptions request) => DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    error: const UnauthorizedFailure(),
  );

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_protected(options)) {
      handler.next(options);
      return;
    }
    try {
      if (options.uri.origin != Uri.parse(dio.options.baseUrl).origin) {
        throw _expired(options);
      }
      final epoch = session.generation;
      if (options.extra['authRetried'] == true &&
          options.extra['sessionGeneration'] != epoch) {
        throw _expired(options);
      }
      // Retried requests already refreshed once; never refresh them again.
      if (options.extra['authRetried'] != true) {
        await session.ensureFresh(refresh);
      }
      if (epoch != session.generation) throw _expired(options);
      if (!session.isAuthenticated || session.tokens == null) {
        throw _expired(options);
      }
      if (options.cancelToken?.isCancelled == true) {
        throw options.cancelToken!.cancelError!;
      }
      options.headers['Authorization'] =
          'Bearer ${session.tokens!.accessToken}';
      options.extra['sessionGeneration'] = session.generation;
      handler.next(options);
    } catch (error) {
      handler.reject(error is DioException ? error : _expired(options));
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final error = err;
    final request = error.requestOptions;
    if (!_protected(request) || error.response?.statusCode != 401) {
      handler.next(error);
      return;
    }
    final epoch = request.extra['sessionGeneration'];
    if (!session.isAuthenticated || epoch != session.generation) {
      handler.reject(_expired(request));
      return;
    }
    try {
      if (request.extra['authRetried'] == true) {
        await session.logout(expired: true);
        handler.reject(_expired(request));
        return;
      }
      if (request.headers['Authorization'] ==
          'Bearer ${session.tokens?.accessToken}') {
        await session.ensureFresh(refresh, force: true);
      }
      if (!session.isAuthenticated || epoch != session.generation) {
        throw _expired(request);
      }
      if (request.cancelToken?.isCancelled == true) {
        throw request.cancelToken!.cancelError!;
      }
      // Streams cannot be replayed; callers should use FormData or repeatable bytes.
      if (request.data is Stream) {
        handler.next(error);
        return;
      }
      final data = request.data is FormData
          ? (request.data as FormData).clone()
          : request.data;
      final retry = request.copyWith(
        data: data,
        extra: {...request.extra, 'authRetried': true},
        headers: {
          ...request.headers,
          'Authorization': 'Bearer ${session.tokens!.accessToken}',
        },
      );
      handler.resolve(await dio.fetch<dynamic>(retry));
    } catch (failure) {
      handler.reject(failure is DioException ? failure : _expired(request));
    }
  }
}
