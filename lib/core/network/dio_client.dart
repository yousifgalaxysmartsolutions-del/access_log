import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'interceptors/logging_interceptor.dart';
import 'cap/cap_locale_holder.dart';
import 'cap/cap_device_app_info.dart';

abstract final class DioClient {
  // Temporary CAP server exception, explicitly enabled for every mobile build.
  // Remove after the server certificate chain is repaired.
  static const allowCapInvalidCertificate = bool.fromEnvironment(
    'CAP_ALLOW_INVALID_CERTIFICATE',
    defaultValue: true,
  );
  static bool acceptsInvalidCertificate(String host, int port) =>
      allowCapInvalidCertificate &&
      host.toLowerCase() == 'test.talentlink360.com' &&
      port == 443;

  static Dio create({
    required String baseUrl,
    bool logging = false,
    Future<CapUserCoordinates?> Function()? availableCoordinates,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        headers: {'Accept': 'application/json'},
        followRedirects: false,
      ),
    );
    final target = Uri.parse(baseUrl);
    final readCoordinates =
        availableCoordinates ??
        CapDeviceAppInfoProvider.readAvailableCoordinates;
    Future<CapUserCoordinates?>? pendingCoordinates;
    Future<CapUserCoordinates?> optionalCoordinates() async {
      final loading = pendingCoordinates ??= Future<CapUserCoordinates?>.sync(
        readCoordinates,
      );
      try {
        return await loading.timeout(const Duration(seconds: 2));
      } catch (_) {
        // Unsupported platform, missing permission, disabled GPS or timeout
        // must never fail a CAP request just because optional metadata is absent.
        return null;
      } finally {
        if (identical(pendingCoordinates, loading)) pendingCoordinates = null;
      }
    }

    if (target.scheme == 'https' &&
        acceptsInvalidCertificate(target.host, target.port)) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () =>
            HttpClient()
              ..badCertificateCallback = (_, host, port) =>
                  acceptsInvalidCertificate(host, port),
      );
    }
    // Resolve at request time, including retries and the separate refresh client.
    // Place before logging so diagnostics show the actual outgoing language.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers.removeWhere((key, _) => key.toLowerCase() == 'lang');
          options.headers['lang'] = CapLocaleHolder.instance.languageCode;
          // Transport-level metadata covers CapRequest AND legacy Login/Profile
          // envelopes, including the separate refresh Dio. Never touch `data`,
          // non-CAP payloads (e.g. Copilot), uploads, or another origin.
          if (options.uri.origin == target.origin &&
              options.uri.path.toLowerCase().contains('/cap/') &&
              options.data is Map &&
              (options.data as Map).containsKey('userid') &&
              (options.data as Map).containsKey('ipaddress')) {
            final body = Map<String, dynamic>.from(options.data as Map)
              ..remove('User_Latitude')
              ..remove('User_Longitude');
            final location = await optionalCoordinates();
            if (location != null &&
                location.latitude.isFinite &&
                location.longitude.isFinite &&
                location.latitude.abs() <= 90 &&
                location.longitude.abs() <= 180) {
              body['User_Latitude'] = location.latitude;
              body['User_Longitude'] = location.longitude;
            }
            options.data = body;
          }
          handler.next(options);
        },
      ),
    );
    if (logging) dio.interceptors.add(SafeLoggingInterceptor());
    return dio;
  }
}
