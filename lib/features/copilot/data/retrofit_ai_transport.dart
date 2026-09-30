import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../ai_copilot/ai_copilot_service.dart';
import '../../../ai_copilot/ai_provider_config.dart';
import '../../../core/network/dio_client.dart';
import 'api/copilot_api_service.dart';

/// Provider credentials stay isolated from the application's session client.
class RetrofitAiTransport implements AiHttpTransport {
  RetrofitAiTransport({Dio? dio, CopilotApiService? api})
    : api =
          api ??
          CopilotApiService(
            dio ?? DioClient.create(baseUrl: AiProviderConfig.baseUrl),
          );
  final CopilotApiService api;
  @override
  Future<AiTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    try {
      final result = await api.complete(
        jsonDecode(body) as Map<String, dynamic>,
        headers['Authorization'] ?? '',
        null,
      );
      return AiTransportResponse(
        statusCode: 200,
        body: jsonEncode(result.data),
      );
    } on DioException catch (error) {
      if (error.response != null) {
        return AiTransportResponse(
          statusCode: error.response!.statusCode ?? 500,
          body: jsonEncode(error.response!.data),
        );
      }
      rethrow;
    }
  }
}
