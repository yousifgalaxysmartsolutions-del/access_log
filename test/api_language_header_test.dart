import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/network/dio_client.dart';
import 'package:access_log_plus/core/network/cap/cap_locale_holder.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/app.dart';

class _Transport implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'resultcode': 1, 'data': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Map<String, dynamic> envelope() => {
    'userid': 4099,
    'ipaddress': 'installation',
    'lang': 'ar',
    'data': {'GpsLat': '30', 'GpsLong': '31', 'Photo': '', 'PhotoBytes': null},
  };

  test(
    'all CAP envelope families and refresh get optional numeric user GPS at the outer level',
    () async {
      final locationDio = DioClient.create(
        baseUrl: 'https://cap.test/api/',
        availableCoordinates: () async => (latitude: 0.0, longitude: -31.25),
      );
      final adapter = _Transport();
      locationDio.httpClientAdapter = adapter;
      addTearDown(locationDio.close);
      for (final endpoint in [
        'CAP/CapAuth/Login',
        'CAP/CapAuth/RefreshToken',
        'CAP/CapAuth/GetUserProfile',
        'CAP/CapAuth/ForgotPasswordRequestReset',
        'CAP/CapIncident/GetIncidentList',
        'CAP/CapIncident/IncidentStatusChange',
        'CAP/CapRequest/CreateRequest',
        'CAP/CapLookup/GetAllRequestLookup',
      ]) {
        final original = envelope();
        if (endpoint.endsWith('GetAllRequestLookup')) original.remove('data');
        final snapshot = jsonDecode(jsonEncode(original));
        await locationDio.post<dynamic>(endpoint, data: original);
        final sent = adapter.requests.last.data as Map;
        expect(sent['User_Latitude'], 0.0);
        expect(sent['User_Longitude'], -31.25);
        expect(sent['User_Latitude'], isA<double>());
        expect(
          original,
          snapshot,
          reason: 'caller payload must not be mutated',
        );
        final unchanged = Map.of(sent)
          ..remove('User_Latitude')
          ..remove('User_Longitude');
        expect(unchanged, original);
        expect(
          adapter.requests.last.headers.containsKey('User_Latitude'),
          false,
        );
        if (endpoint.endsWith('GetAllRequestLookup')) {
          expect(sent.containsKey('data'), false);
        }
      }
    },
  );

  test(
    'absent/disabled/invalid/failed GPS never stops requests or sends placeholder coordinates',
    () async {
      for (final lookup in <Future<CapUserCoordinates?> Function()>[
        () async => null,
        () async => throw StateError('GPS disabled or permission unavailable'),
        () async => (latitude: double.nan, longitude: 31.0),
        () async => (latitude: 30.0, longitude: double.infinity),
        () async => (latitude: 91.0, longitude: 181.0),
      ]) {
        final client = DioClient.create(
          baseUrl: 'https://cap.test/api/',
          availableCoordinates: lookup,
        );
        final adapter = _Transport();
        client.httpClientAdapter = adapter;
        await client.post<dynamic>(
          'CAP/CapIncident/GetIncidentList',
          data: envelope(),
        );
        expect(adapter.requests.single.data, envelope());
        client.close();
      }
    },
  );

  test(
    'retry removes old GPS metadata when location becomes unavailable',
    () async {
      CapUserCoordinates? coordinates = (latitude: 30.0, longitude: 31.0);
      final client = DioClient.create(
        baseUrl: 'https://cap.test/api/',
        availableCoordinates: () async => coordinates,
      );
      final adapter = _Transport();
      client.httpClientAdapter = adapter;
      addTearDown(client.close);
      await client.post<dynamic>(
        'CAP/CapIncident/GetIncidentList',
        data: envelope(),
      );
      final retry = adapter.requests.single.copyWith();
      coordinates = null;
      await client.fetch<dynamic>(retry);
      expect(
        (adapter.requests.last.data as Map).containsKey('User_Latitude'),
        false,
      );
      expect(
        (adapter.requests.last.data as Map).containsKey('User_Longitude'),
        false,
      );
    },
  );

  test(
    'Copilot, foreign origin, GET and multipart bodies are not decorated or inspected for GPS',
    () async {
      var calls = 0;
      final client = DioClient.create(
        baseUrl: 'https://cap.test/api/',
        availableCoordinates: () async {
          calls++;
          return (latitude: 30.0, longitude: 31.0);
        },
      );
      final adapter = _Transport();
      client.httpClientAdapter = adapter;
      addTearDown(client.close);
      await client.post<dynamic>(
        'chat/completions',
        data: {'model': 'test', 'messages': []},
      );
      await client.post<dynamic>(
        'https://other.test/CAP/test',
        data: envelope(),
      );
      await client.get<dynamic>('CAP/test');
      await client.post<dynamic>(
        'CAP/upload',
        data: FormData.fromMap({'userid': 1}),
      );
      expect(calls, 0);
      expect(
        (adapter.requests.first.data as Map).containsKey('User_Latitude'),
        false,
      );
    },
  );

  test('parallel CAP requests share the optional GPS read', () async {
    var reads = 0;
    final pending = Completer<CapUserCoordinates?>();
    final client = DioClient.create(
      baseUrl: 'https://cap.test/api/',
      availableCoordinates: () {
        reads++;
        return pending.future;
      },
    );
    final adapter = _Transport();
    client.httpClientAdapter = adapter;
    addTearDown(client.close);
    final requests = List.generate(
      3,
      (_) => client.post<dynamic>('CAP/test', data: envelope()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(reads, 1);
    pending.complete((latitude: 30.0, longitude: 31.0));
    await Future.wait(requests);
    expect(adapter.requests.length, 3);
    expect(
      adapter.requests.every((r) => (r.data as Map)['User_Longitude'] == 31.0),
      true,
    );
  });

  test('optional GPS timeout still sends the CAP request', () async {
    final pending = Completer<CapUserCoordinates?>();
    final client = DioClient.create(
      baseUrl: 'https://cap.test/api/',
      availableCoordinates: () => pending.future,
    );
    final adapter = _Transport();
    client.httpClientAdapter = adapter;
    addTearDown(client.close);
    await client.post<dynamic>('CAP/test', data: envelope());
    expect(adapter.requests.single.data, envelope());
  });

  testWidgets(
    'Language selection updates the API language before the next frame',
    (tester) async {
      final key = GlobalKey<AccessLogAppState>();
      await tester.pumpWidget(AccessLogApp(key: key));
      key.currentState!.setLocale(const Locale('en'));
      expect(CapLocaleHolder.instance.locale.languageCode, 'en');
      await tester.pump();
      key.currentState!.toggleLocale();
      expect(CapLocaleHolder.instance.locale.languageCode, 'ar');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  late Dio dio, refresh;
  late _Transport transport, refreshTransport;
  late Locale original;
  setUp(() {
    original = CapLocaleHolder.instance.locale;
    dio = DioClient.create(baseUrl: 'https://example.invalid/api/');
    refresh = DioClient.create(baseUrl: 'https://example.invalid/api/');
    transport = _Transport();
    refreshTransport = _Transport();
    dio.httpClientAdapter = transport;
    refresh.httpClientAdapter = refreshTransport;
  });
  tearDown(() {
    dio.close(force: true);
    refresh.close(force: true);
    CapLocaleHolder.instance.update(original);
  });
  test(
    'All endpoint requests and refresh use current selected language without modifying JSON',
    () async {
      final body = {'userid': 4098, 'data': null};
      for (final language in ['ar', 'en']) {
        CapLocaleHolder.instance.update(Locale(language));
        for (final endpoint in [
          'CAP/CapAuth/Login',
          'CAP/CapIncident/GetIncidentList',
          'CAP/CapLookup/GetAllIncidentLookup',
          'CAP/CapConfiguration/GetSystemConfiguration',
          'CAP/CapRequest/CreateRequest',
          'CAP/CapLookup/GetFormQuestion',
        ]) {
          await dio.post<dynamic>(endpoint, data: body);
          expect(transport.requests.last.headers['lang'], language);
          expect(transport.requests.last.data, body);
          expect(transport.requests.last.headers['Accept'], 'application/json');
        }
        await refresh.post<dynamic>('CAP/CapAuth/RefreshToken', data: body);
        expect(refreshTransport.requests.last.headers['lang'], language);
      }
    },
  );
  test(
    'Retry and explicit stale header are updated to selected language',
    () async {
      CapLocaleHolder.instance.update(const Locale('ar'));
      await dio.get<dynamic>(
        'CAP/test',
        options: Options(headers: {'Lang': 'en'}),
      );
      final originalRequest = transport.requests.last;
      expect(originalRequest.headers['lang'], 'ar');
      expect(
        originalRequest.headers.keys
            .where((key) => key.toLowerCase() == 'lang')
            .length,
        1,
      );
      CapLocaleHolder.instance.update(const Locale('en'));
      await dio.fetch<dynamic>(originalRequest.copyWith());
      expect(transport.requests.last.headers['lang'], 'en');
    },
  );
}
