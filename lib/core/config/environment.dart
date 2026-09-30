import 'package:flutter/foundation.dart';

enum Environment { development, staging, production }

class AppEnvironment {
  const AppEnvironment({
    required this.environment,
    required this.baseUrl,
    this.apiVersion = 'v1',
    this.mockAuthentication = true,
    this.logging = false,
  });
  final Environment environment;
  final String baseUrl, apiVersion;
  final bool mockAuthentication, logging;
  String get apiUrl =>
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/${apiVersion.isEmpty ? '' : '$apiVersion/'}';

  factory AppEnvironment.fromDefines() {
    const name = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    final environment = Environment.values.byName(name);
    const mock = bool.fromEnvironment('MOCK_AUTH', defaultValue: false);
    const url = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue:
          'https://test.talentlink360.com/Developmnet/BridgeForce_Dev/BridgeFoce_API_Dev/api',
    );
    if (!mock &&
        (Uri.tryParse(url)?.hasAuthority != true ||
            (environment != Environment.development &&
                !url.startsWith('https://')))) {
      throw StateError(
        'A valid API_BASE_URL is required. Staging/production require HTTPS.',
      );
    }
    return AppEnvironment(
      environment: environment,
      baseUrl: url.isEmpty ? 'https://api.invalid' : url,
      apiVersion: const String.fromEnvironment('API_VERSION', defaultValue: ''),
      mockAuthentication: mock,
      logging:
          kDebugMode &&
          const bool.fromEnvironment('API_LOGGING', defaultValue: true),
    );
  }
}
