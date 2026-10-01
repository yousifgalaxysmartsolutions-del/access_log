import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/network/api_response.dart';
import 'package:access_log_plus/core/network/cap/cap_request.dart';
import 'package:access_log_plus/core/network/cap/general_response.dart';

void main() {
  test('CapRequest.toJson uses exact CAP casing', () {
    const request = CapRequest<String>(
      userId: 4098,
      deviceIdentifier: 'DEV-1',
      deviceToken: 'tok',
      osVersion: '15.1',
      appVersion: '1',
      deviceType: 'iOS',
      data: 'payload',
    );
    expect(request.toJson(), {
      'userid': 4098,
      'ipaddress': 'DEV-1',
      'devicetoken': 'tok',
      'osversion': '15.1',
      'AppVersion': '1',
      'devicetype': 'iOS',
      'data': 'payload',
    });
  });

  test('CapRequest encodes map data', () {
    const request = CapRequest<Map<String, dynamic>>(
      userId: 1,
      deviceIdentifier: 'D',
      deviceToken: 't',
      osVersion: '15.1',
      appVersion: '1',
      deviceType: 'iOS',
      data: {'Month': 8, 'Year': 2026},
    );
    expect(request.toJson()['data'], {'Month': 8, 'Year': 2026});
  });

  test('CapRequest serializes a CapPayload body, not an opaque object', () {
    final request = CapRequest<_Body>(
      userId: 1,
      deviceIdentifier: 'D',
      deviceToken: 't',
      osVersion: '15.1',
      appVersion: '1',
      deviceType: 'iOS',
      data: const _Body('CAP-1'),
    );
    // Regression: a payload object left unserialized makes `jsonEncode` throw
    // inside Dio, so the request never leaves the device.
    expect(request.toJson()['data'], {'IncidentNo': 'CAP-1'});
    expect(() => jsonEncode(request.toJson()), returnsNormally);
  });

  test('CapRequest falls back to text for unsupported values', () {
    final request = CapRequest<Object>(
      userId: 1,
      deviceIdentifier: 'D',
      deviceToken: 't',
      osVersion: '15.1',
      appVersion: '1',
      deviceType: 'iOS',
      data: Duration(days: 1, seconds: 30),
    );
    expect(() => jsonEncode(request.toJson()), returnsNormally);
  });

  group('GeneralResponse', () {
    const successResponse = ApiResponse({
      'resultcode': 1,
      'resultmessages': {'resultmessageen': 'OK', 'resultmessagear': 'تم'},
      'data': {'value': 7},
    });

    test('parses success and decodes data', () {
      final parsed = GeneralResponse.parse<int>(
        successResponse,
        (raw) => (raw! as Map)['value'] as int,
      );
      expect(parsed.isSuccess, isTrue);
      expect(parsed.data, 7);
      expect(parsed.messageFor(isArabic: false), 'OK');
      expect(parsed.messageFor(isArabic: true), 'تم');
    });

    test('throws on non-success with localized message', () {
      const failureResponse = ApiResponse({
        'resultcode': 0,
        'resultmessages': {
          'resultmessageen': 'Bad request',
          'resultmessagear': 'طلب غير صالح',
        },
      });
      expect(
        () => GeneralResponse.parseOrThrow<int>(
          failureResponse,
          (_) => 0,
          isArabic: true,
          fallbackMessage: 'fallback',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('falls back to other language when one is missing', () {
      const partial = ApiResponse({
        'resultcode': 0,
        'resultmessages': {'resultmessageen': 'Only English'},
      });
      final parsed = GeneralResponse.parse<int>(partial, (_) => 0);
      expect(parsed.messageFor(isArabic: true), 'Only English');
    });
  });
}

class _Body implements CapPayload {
  const _Body(this.incidentNo);
  final String incidentNo;
  @override
  Map<String, dynamic> toJson() => {'IncidentNo': incidentNo};
}
