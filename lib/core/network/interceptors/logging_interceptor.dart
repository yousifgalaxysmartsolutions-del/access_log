import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only structured logs. Credentials are redacted at every nesting level.
class SafeLoggingInterceptor extends Interceptor {
  final _started = Expando<Stopwatch>();
  static final _sensitive = RegExp(
    r'password|passwd|pwd|token|authorization|cookie|secret|apikey|api_key|credential',
    caseSensitive: false,
  );
  static Object? redact(Object? value, [String key = '', int depth = 0]) {
    if (_sensitive.hasMatch(key)) return '[REDACTED]';
    if (depth > 12) return '[nested content omitted]';
    if (value is FormData) {
      return {
        'fields': [
          for (final field in value.fields)
            {field.key: redact(field.value, field.key, depth + 1)},
        ],
        'files': [
          for (final file in value.files)
            {'field': file.key, 'bytes': file.value.length},
        ],
      };
    }
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k.toString(), redact(v, k.toString(), depth + 1)),
      );
    }
    if (value is List) {
      return value.take(100).map((v) => redact(v, key, depth + 1)).toList();
    }
    if (value is String) {
      try {
        final parsed = jsonDecode(value);
        if (parsed is Map || parsed is List) {
          return redact(parsed, key, depth + 1);
        }
      } on FormatException {
        /* Ordinary text. */
      }
      if (_sensitive.hasMatch(value) ||
          RegExp(
            r'Bearer\s|eyJ[A-Za-z0-9_-]+\.',
            caseSensitive: false,
          ).hasMatch(value)) {
        return '[sensitive text omitted]';
      }
      return value.length > 2000
          ? '${value.substring(0, 2000)}… [truncated]'
          : value;
    }
    if (value == null || value is num || value is bool) return value;
    return '[${value.runtimeType} omitted]';
  }

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
      'query': redact(request.queryParameters),
      'status': ?status,
      'error': ?error,
      if (details != null) 'details': redact(details),
      'headers': redact(headers),
      'body': redact(body),
    };
    try {
      var output = const JsonEncoder.withIndent('  ').convert(payload);
      // Also remove known credentials if the server/exception echoes them in text.
      void scrub(Object? value, [String key = '']) {
        if (_sensitive.hasMatch(key) && value is String && value.isNotEmpty) {
          final encoded = jsonEncode(value);
          output = output.replaceAll(
            encoded.substring(1, encoded.length - 1),
            '[REDACTED]',
          );
        } else if (value is Map) {
          value.forEach((k, v) => scrub(v, k.toString()));
        } else if (value is List) {
          for (final item in value) {
            scrub(item, key);
          }
        }
      }

      scrub(request.headers);
      scrub(request.queryParameters);
      scrub(request.data);
      debugPrint(
        '[API $stage]\n${output.length > 16000 ? '${output.substring(0, 16000)}\n[truncated]' : output}',
      );
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
