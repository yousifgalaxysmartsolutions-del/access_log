import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/network/dio_client.dart';
import 'package:access_log_plus/core/network/cap/cap_locale_holder.dart';
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
