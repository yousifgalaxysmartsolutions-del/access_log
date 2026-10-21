import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../cap/cap_parse_diagnostics.dart';

/// Full, unredacted HTTP logs for local debugging only.
/// Never enabled in profile/release; do not share these logs without sanitizing.
class SafeLoggingInterceptor extends Interceptor {
  final _started = Expando<Stopwatch>();
  static Object? redact(Object? value, [String key = '', int depth = 0]) =>
      redactCapPayload(value, key: key, depth: depth);

  void _log(
    String stage,
    RequestOptions request, {
    int? status,
    Object? headers,
    Object? body,
    String? error,
    Map<String, Object?>? details,
  }) {
    if (!kDebugMode) return;
    // Construct from host/path only: never print URL user-info or raw query.
    final uri = request.uri;
    final url = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
    final payload = {
      'method': request.method,
      'url': url,
      'query': request.queryParameters,
      'status': ?status,
      'error': ?error,
      'details': ?details,
      'headers': headers,
      'body': body,
    };
    try {
      final output = const JsonEncoder.withIndent('  ').convert(payload);
      debugPrint('[API $stage]\n$output');
    } catch (_) {
      debugPrint('[API $stage] Log content omitted');
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _started[options] = Stopwatch()..start();
    _log('REQUEST', options, headers: options.headers, body: options.data);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _started[response.requestOptions]?.stop();
    _log(
      'RESPONSE',
      response.requestOptions,
      status: response.statusCode,
      headers: response.headers.map,
      body: response.data,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    final timer = _started[request]?..stop();
    _log(
      'ERROR',
      err.requestOptions,
      status: err.response?.statusCode,
      error: err.type.name,
      details: {
        'message': err.message,
        'causeType': err.error?.runtimeType.toString(),
        'cause': err.error?.toString(),
        'stackTrace': err.stackTrace.toString(),
        'elapsedMs': timer?.elapsedMilliseconds,
        'hasResponse': err.response != null,
        'statusMessage': err.response?.statusMessage,
        'isRedirect': err.response?.isRedirect,
        'cancelled': request.cancelToken?.isCancelled ?? false,
        'connectTimeoutMs': request.connectTimeout?.inMilliseconds,
        'sendTimeoutMs': request.sendTimeout?.inMilliseconds,
        'receiveTimeoutMs': request.receiveTimeout?.inMilliseconds,
        'requestHeaders': request.headers,
        'requestBody': request.data,
      },
      headers: err.response?.headers.map,
      body: err.response?.data,
    );
    handler.next(err);
  }
}
