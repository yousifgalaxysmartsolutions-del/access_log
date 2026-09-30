import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'interceptors/logging_interceptor.dart';

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

  static Dio create({required String baseUrl, bool logging = false}) {
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
    if (target.scheme == 'https' &&
        acceptsInvalidCertificate(target.host, target.port)) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () =>
            HttpClient()
              ..badCertificateCallback = (_, host, port) =>
                  acceptsInvalidCertificate(host, port),
      );
    }
    if (logging) dio.interceptors.add(SafeLoggingInterceptor());
    return dio;
  }
}
