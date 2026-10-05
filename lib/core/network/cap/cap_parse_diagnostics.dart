import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../error/failure.dart';
import '../api_exception.dart';

/// Shared diagnostics for CAP response deserialization.
///
/// CAP payloads are decoded by `json_serializable`, which throws raw Dart
/// throwables rather than transport errors. Type mismatches can be `Error`s,
/// which do not enter the normal `on Exception` repository boundary.
///
/// [CapParseDiagnostics.decodeData] scopes containment to response decoding.
/// It reports the failure with endpoint, model, error and redacted response,
/// then converts it into the project's normal [ServiceFailure] flow.
abstract final class CapParseDiagnostics {
  /// Matches every credential-bearing key so it can never reach a log.
  static final RegExp sensitiveKeys = RegExp(
    r'password|passwd|pwd|token|authorization|cookie|secret|apikey|api_key'
    r'|credential|bearer|jwt|otp|signature|sessionid',
    caseSensitive: false,
  );

  /// JWT/Bearer shaped substrings echoed back inside free text.
  static final RegExp sensitiveText = RegExp(
    r'Bearer\s|eyJ[A-Za-z0-9_-]+\.',
    caseSensitive: false,
  );

  /// True when [error] is one of the throwables deserialization can raise.
  static bool isParseError(Object error) =>
      error is TypeError ||
      error is FormatException ||
      error is JsonUnsupportedObjectError ||
      error is CheckedFromJsonException;

  /// Decodes the CAP `data` value, reporting and normalising any failure.
  ///
  /// Returns the decoded model on success. On failure it logs a red
  /// `[CAP PARSE ERROR]` block in debug builds and throws an [ApiException]
  /// carrying a [ServiceFailure], so `apiGuard` yields a `FailureResult`.
  static T decodeData<T>(
    T Function(Object? value) decode,
    Object? raw, {
    required String endpoint,
    required String model,
    String fallbackMessage = 'Unable to read the server response',
  }) {
    try {
      return decode(raw);
    } on ApiException {
      rethrow;
    } on Object catch (error, stackTrace) {
      if (!isParseError(error)) rethrow;
      logParseError(
        endpoint: endpoint,
        model: model,
        error: error,
        responseData: raw,
        stackTrace: stackTrace,
      );
      throw ApiException(ServiceFailure('cap_parse_error', fallbackMessage));
    }
  }

  /// Logs the redacted parse-error report. No-op outside debug builds.
  static void logParseError({
    required String endpoint,
    required String model,
    required Object error,
    Object? responseData,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    final buffer = StringBuffer()
      ..writeln(_red('🔴 [CAP PARSE ERROR] RED'))
      ..writeln('   endpoint : ${endpoint.isEmpty ? '<unknown>' : endpoint}')
      ..writeln('   model    : ${model.isEmpty ? '<unknown>' : model}')
      ..writeln('   error    : ${_describe(error)}')
      ..write('   response : ${_pretty(responseData)}');
    if (stackTrace != null) {
      buffer
        ..writeln()
        ..write('   stack    : ${_firstFrames(stackTrace)}');
    }
    debugPrint(buffer.toString());
  }

  static String _describe(Object error) {
    // Exception messages can echo arbitrary field values (including secrets).
    // Report the error type; the payload below is structured and redacted.
    return '${error.runtimeType}: response deserialization failed';
  }

  static String _pretty(Object? value) {
    if (value == null) return 'null';
    try {
      return const JsonEncoder.withIndent(
        '  ',
      ).convert(redactCapPayload(value));
    } on Object {
      return redactCapPayload(value).toString();
    }
  }

  static String _firstFrames(StackTrace stackTrace) {
    final frames = stackTrace.toString().trim().split('\n');
    return frames.take(6).map(redactCapPayload).join('\n              ');
  }

  /// ANSI red, dropped when the terminal cannot render it.
  static String _red(String text) =>
      const String.fromEnvironment('NO_COLOR').isNotEmpty
      ? text
      : '\x1B[31m$text\x1B[0m';
}

/// Recursively removes credentials from any payload before it is logged.
///
/// Shared by the debug logging interceptor and the parse diagnostics so no log
/// path can print an access token, refresh token, device token or
/// `Authorization` header value.
Object? redactCapPayload(
  Object? value, {
  String key = '',
  int depth = 0,
  int maxDepth = 12,
  int maxItems = 100,
  int maxStringLength = 2000,
}) {
  if (CapParseDiagnostics.sensitiveKeys.hasMatch(key)) return '[REDACTED]';
  if (depth > maxDepth) return '[nested content omitted]';
  if (value is FormData) {
    return {
      'fields': [
        for (final field in value.fields)
          {
            field.key: redactCapPayload(
              field.value,
              key: field.key,
              depth: depth + 1,
              maxDepth: maxDepth,
              maxItems: maxItems,
              maxStringLength: maxStringLength,
            ),
          },
      ],
      'files': [
        for (final file in value.files)
          {'field': file.key, 'bytes': file.value.length},
      ],
    };
  }
  if (value is Map) {
    return value.map(
      (k, v) => MapEntry(
        k.toString(),
        redactCapPayload(
          v,
          key: k.toString(),
          depth: depth + 1,
          maxDepth: maxDepth,
          maxItems: maxItems,
          maxStringLength: maxStringLength,
        ),
      ),
    );
  }
  if (value is Iterable) {
    return value
        .take(maxItems)
        .map(
          (v) => redactCapPayload(
            v,
            key: key,
            depth: depth + 1,
            maxDepth: maxDepth,
            maxItems: maxItems,
            maxStringLength: maxStringLength,
          ),
        )
        .toList();
  }
  if (value is String) {
    try {
      final parsed = jsonDecode(value);
      if (parsed is Map || parsed is Iterable) {
        return redactCapPayload(
          parsed,
          key: key,
          depth: depth + 1,
          maxDepth: maxDepth,
          maxItems: maxItems,
          maxStringLength: maxStringLength,
        );
      }
    } on FormatException {
      // Ordinary text rather than an encoded structure.
    }
    if (CapParseDiagnostics.sensitiveText.hasMatch(value) ||
        CapParseDiagnostics.sensitiveKeys.hasMatch(value)) {
      return '[sensitive text omitted]';
    }
    return value.length > maxStringLength
        ? '${value.substring(0, maxStringLength)}… [truncated]'
        : value;
  }
  if (value == null || value is num || value is bool) return value;
  return '[${value.runtimeType} omitted]';
}
