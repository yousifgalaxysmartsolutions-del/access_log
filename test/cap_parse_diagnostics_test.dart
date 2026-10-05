import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

import 'package:access_log_plus/core/error/exception_mapper.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/api_exception.dart';
import 'package:access_log_plus/core/network/cap/cap_parse_diagnostics.dart';
import 'package:access_log_plus/core/network/cap/general_response.dart';
import 'package:access_log_plus/core/network/api_response.dart';
import 'package:access_log_plus/core/network/result.dart';

/// Produces the exact throwable json_serializable raises on a type mismatch:
/// `type 'String' is not a subtype of type 'int'`.
int _asInt(Object? value) => value as int;

/// An `Error` the mapper has no specific rule for.
class _UnexpectedError extends Error {
  _UnexpectedError(this.message);
  final String message;
  @override
  String toString() => '_UnexpectedError: $message';
}

void main() {
  group('redaction never leaks credentials', () {
    test('credential keys are removed at every nesting level', () {
      final redacted = redactCapPayload({
        'Authorization': 'Bearer super-secret-value',
        'DeviceToken': 'device-secret',
        'AccessToken': 'access-secret',
        'RefreshToken': 'refresh-secret',
        'password': 'hunter2',
        'nested': {'devicetoken': 'deep-device-secret', 'safe': 'visible'},
        'list': [
          {'accesstoken': 'in-a-list'},
        ],
      });

      final encoded = jsonEncode(redacted);
      expect(encoded, isNot(contains('super-secret-value')));
      expect(encoded, isNot(contains('device-secret')));
      expect(encoded, isNot(contains('access-secret')));
      expect(encoded, isNot(contains('refresh-secret')));
      expect(encoded, isNot(contains('hunter2')));
      expect(encoded, isNot(contains('in-a-list')));
      expect(encoded, contains('visible'));
    });

    test('a JWT echoed inside free text is omitted', () {
      final redacted = redactCapPayload({
        'note': 'failed with eyJhbGciOiJIUzI1NiJ9.payload.signature',
      });

      expect(jsonEncode(redacted), isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(redacted.toString(), contains('[sensitive text omitted]'));
    });

    test('an encoded JSON string is redacted after decoding', () {
      final redacted = redactCapPayload({
        'payload': jsonEncode({'RefreshToken': 'refresh-secret'}),
      });

      expect(jsonEncode(redacted), isNot(contains('refresh-secret')));
    });

    test('non-string values survive untouched', () {
      expect(redactCapPayload({'n': 1, 'd': 1.5, 'b': true, 'z': null}), {
        'n': 1,
        'd': 1.5,
        'b': true,
        'z': null,
      });
    });

    test('deep nesting is truncated rather than recursed forever', () {
      Object nested = 'leaf';
      for (var i = 0; i < 40; i++) {
        nested = {'level': nested};
      }
      expect(jsonEncode(redactCapPayload(nested)), contains('omitted'));
    });
  });

  group('decode failures become the normal Failure flow', () {
    test('a TypeError from decoding is converted to ServiceFailure', () {
      const String raw = 'not-an-int';
      int decode(Object? _) => _asInt(raw);

      expect(
        () => CapParseDiagnostics.decodeData<int>(
          decode,
          const {},
          endpoint: 'CAP/CapIncident/GetIncidentDetails',
          model: 'IncidentDetailsData',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.failure,
            'failure',
            const TypeMatcher<ServiceFailure>(),
          ),
        ),
      );
    });

    test('an existing ApiException keeps its own failure', () {
      const original = ServiceFailure('cap_result_0', 'Denied');
      int decode(Object? _) => throw const ApiException(original);

      expect(
        () => CapParseDiagnostics.decodeData<int>(
          decode,
          const {},
          endpoint: 'CAP/CapX',
          model: 'X',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.failure, 'failure', original),
        ),
      );
    });

    test('a successful decode returns the model untouched', () {
      expect(
        CapParseDiagnostics.decodeData<int>(
          (raw) => (raw as Map)['n'] as int,
          const {'n': 7},
          endpoint: 'CAP/CapX',
          model: 'X',
        ),
        7,
      );
    });

    test('logging the parse error does not itself throw', () {
      expect(
        () => CapParseDiagnostics.logParseError(
          endpoint: 'CAP/CapIncident/GetIncidentDetails',
          model: 'IncidentDetailsData',
          error: StateError('boom'),
          responseData: const {'AccessToken': 'access-secret'},
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });
  });

  group('parse errors stay inside the Result boundary', () {
    test('apiGuard converts a decoding Error into FailureResult', () async {
      final result = await apiGuard<int>(
        () async => CapParseDiagnostics.decodeData(
          _asInt,
          'not-an-int',
          endpoint: 'CAP/Test',
          model: 'Test',
        ),
      );

      expect(result, isA<FailureResult<int>>());
      final failure = (result as FailureResult).failure;
      expect(failure, isA<ServiceFailure>());
      expect((failure as ServiceFailure).code, 'cap_parse_error');
    });

    test('apiGuard converts a FormatException into FailureResult', () async {
      final result = await apiGuard<int>(
        () async => CapParseDiagnostics.decodeData<int>(
          (_) => throw const FormatException('bad json'),
          {},
          endpoint: 'CAP/Test',
          model: 'Test',
        ),
      );

      final failure = (result as FailureResult).failure;
      expect(failure, isA<ServiceFailure>());
      expect((failure as ServiceFailure).code, 'cap_parse_error');
    });

    test('programming errors outside decoding remain visible', () async {
      await expectLater(
        apiGuard<int>(() async => throw _UnexpectedError('unmapped')),
        throwsA(isA<_UnexpectedError>()),
      );
      await expectLater(
        apiGuard<int>(() async => _asInt('bad')),
        throwsA(isA<TypeError>()),
      );
    });

    test('unexpected errors inside decoding are not swallowed', () {
      for (final error in <Error>[
        StateError('bug'),
        ArgumentError('bug'),
        _UnexpectedError('bug'),
      ]) {
        expect(
          () => CapParseDiagnostics.decodeData<int>(
            (_) => throw error,
            {},
            endpoint: 'CAP/Test',
            model: 'Test',
          ),
          throwsA(same(error)),
        );
      }
    });

    test('diagnostic output includes context without credential values', () {
      final output = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) =>
          output.add(message ?? '');
      addTearDown(() => debugPrint = original);
      CapParseDiagnostics.logParseError(
        endpoint: 'CAP/Test',
        model: 'TestModel',
        error: const FormatException('unlabelled-secret'),
        responseData: {
          'AccessToken': 'access-secret',
          'nested': {
            'RefreshToken': 'refresh-secret',
            'devicetoken': 'device-secret',
            'Authorization': 'auth-secret',
            'Password': 'password-secret',
          },
          'id': 7,
        },
        stackTrace: StackTrace.current,
      );
      final log = output.join();
      for (final secret in [
        'unlabelled-secret',
        'access-secret',
        'refresh-secret',
        'device-secret',
        'auth-secret',
        'password-secret',
      ]) {
        expect(log, isNot(contains(secret)));
      }
      for (final text in [
        'CAP PARSE ERROR',
        'CAP/Test',
        'TestModel',
        'FormatException',
        'stack',
        '7',
      ]) {
        expect(log, contains(text));
      }
    });

    test('apiGuard still returns Success for a normal value', () async {
      final result = await apiGuard<int>(() async => 3);
      expect(result, isA<Success<int>>());
      expect((result as Success<int>).data, 3);
    });
  });

  group('GeneralResponse routes decoding through the diagnostics', () {
    test(
      'flat business failures return the locale message through apiGuard',
      () async {
        for (final isArabic in [false, true]) {
          final result = await apiGuard<int>(
            () async => GeneralResponse.parseOrThrow<int>(
              const ApiResponse({
                'resultcode': 0,
                'resultmessageen': 'Denied',
                'resultmessagear': 'غير مسموح',
              }),
              _asInt,
              isArabic: isArabic,
              fallbackMessage: 'fallback',
            ).data!,
          );
          expect(
            (result as FailureResult<int>).failure.message,
            isArabic ? 'غير مسموح' : 'Denied',
          );
        }
        final response = GeneralResponse.parse<int>(
          const ApiResponse({
            'resultcode': 0,
            'resultmessageen': 'English',
            'resultmessagear': null,
          }),
          _asInt,
        );
        expect(response.messageFor(isArabic: true), 'English');
      },
    );

    test('flat messages support both locales and override legacy messages', () {
      final response = GeneralResponse.parse<int>(
        const ApiResponse({
          'resultcode': 1,
          'resultmessageen': ' English ',
          'resultmessagear': ' عربي ',
          'resultmessages': {'resultmessageen': 'Legacy'},
          'data': 1,
        }),
        _asInt,
      );
      expect(response.messageFor(isArabic: false), 'English');
      expect(response.messageFor(isArabic: true), 'عربي');
    });

    test(
      'empty messages use legacy, other language, then supplied fallback',
      () {
        final legacy = GeneralResponse.parse<int>(
          const ApiResponse({
            'resultcode': 0,
            'resultmessageen': ' ',
            'resultmessages': {'resultmessageen': 'Legacy'},
          }),
          _asInt,
        );
        expect(legacy.messageFor(isArabic: true), 'Legacy');
        const arabic = GeneralResponse<int>(
          resultCode: 0,
          resultMessageEn: ' ',
          resultMessageAr: 'عربي',
        );
        expect(arabic.messageFor(isArabic: false), 'عربي');
        for (final isArabic in [false, true]) {
          expect(
            () => GeneralResponse.parseOrThrow<int>(
              const ApiResponse({
                'resultcode': 0,
                'resultmessageen': ' ',
                'resultmessagear': '',
              }),
              _asInt,
              isArabic: isArabic,
              fallbackMessage: 'fallback',
            ),
            throwsA(
              isA<ApiException>().having(
                (e) => e.failure.message,
                'message',
                'fallback',
              ),
            ),
          );
        }
      },
    );

    ApiResponse envelope(Object? data) => ApiResponse({
      'resultcode': 1,
      'resultmessages': {'resultmessageen': 'OK'},
      'data': data,
    });

    test('a malformed data block surfaces as cap_parse_error', () {
      expect(
        () => GeneralResponse.parse<int>(
          envelope(const {'n': 'abc'}),
          (raw) => (raw as Map)['n'] as int,
          endpoint: 'CAP/CapIncident/GetIncidentDetails',
          model: 'IncidentDetailsData',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => (e.failure as ServiceFailure).code,
            'code',
            'cap_parse_error',
          ),
        ),
      );
    });

    test('a successful parse is unchanged', () {
      final parsed = GeneralResponse.parse<int>(
        envelope(const {'n': 5}),
        (raw) => (raw as Map)['n'] as int,
        endpoint: 'CAP/CapX',
        model: 'X',
      );

      expect(parsed.isSuccess, isTrue);
      expect(parsed.data, 5);
      expect(parsed.resultMessageEn, 'OK');
    });

    test('a CAP business failure keeps its own result code', () {
      final response = ApiResponse({
        'resultcode': 0,
        'resultmessages': {'resultmessageen': 'Denied'},
        'data': null,
      });

      expect(
        () => GeneralResponse.parseOrThrow<int>(
          response,
          (raw) => (raw as Map)['n'] as int,
          isArabic: false,
          fallbackMessage: 'fallback',
        ),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => (e.failure as ServiceFailure).code,
                'code',
                'cap_result_0',
              )
              .having((e) => e.failure.message, 'message', 'Denied'),
        ),
      );
    });
  });
}
