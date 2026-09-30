import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_copilot_models.dart';
import 'ai_copilot_prompts.dart';
import 'ai_provider_config.dart';
import '../features/copilot/data/retrofit_ai_transport.dart';

enum AiServiceErrorType {
  missingApiKey,
  network,
  timeout,
  rateLimit,
  modelUnavailable,
  invalidResponse,
  provider,
}

class AiServiceException implements Exception {
  const AiServiceException(this.type, [this.details]);
  final AiServiceErrorType type;
  final String? details;
}

class AiTransportResponse {
  const AiTransportResponse({required this.statusCode, required this.body});
  final int statusCode;
  final String body;
}

abstract interface class AiHttpTransport {
  Future<AiTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  });
}

class IoAiHttpTransport implements AiHttpTransport {
  IoAiHttpTransport({HttpClient? client}) : _client = client ?? HttpClient();
  final HttpClient _client;

  @override
  Future<AiTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final request = await _client.postUrl(uri);
    headers.forEach(request.headers.set);
    request.write(body);
    final response = await request.close();
    return AiTransportResponse(
      statusCode: response.statusCode,
      body: await utf8.decoder.bind(response).join(),
    );
  }
}

abstract interface class AiCopilotClient {
  AiCopilotMode get mode;

  Future<String> complete({
    required String incidentContext,
    required List<AiChatMessage> history,
  });
}

class AiCopilotService implements AiCopilotClient {
  factory AiCopilotService.fromEnvironment({
    AiHttpTransport? transport,
    String? apiKey,
    String? model,
    String? fallbackModel,
    Duration timeout = const Duration(seconds: 25),
  }) {
    final resolvedApiKey = (apiKey ?? AiProviderConfig.apiKey).trim();
    return AiCopilotService(
      mode: resolvedApiKey.isEmpty ? AiCopilotMode.mock : AiCopilotMode.groq,
      transport: transport,
      apiKey: resolvedApiKey,
      model: model ?? AiProviderConfig.model,
      fallbackModel: fallbackModel ?? AiProviderConfig.fallbackModel,
      timeout: timeout,
    );
  }

  AiCopilotService({
    this.mode = AiCopilotMode.groq,
    AiHttpTransport? transport,
    this.apiKey = AiProviderConfig.apiKey,
    this.model = AiProviderConfig.model,
    this.fallbackModel = AiProviderConfig.fallbackModel,
    this.timeout = const Duration(seconds: 25),
  }) : _transport = transport;

  @override
  final AiCopilotMode mode;
  AiHttpTransport? _transport;
  final String apiKey, model, fallbackModel;
  final Duration timeout;

  @override
  Future<String> complete({
    required String incidentContext,
    required List<AiChatMessage> history,
  }) async {
    if (mode == AiCopilotMode.mock) return _mockAnswer(history.last.content);
    if (apiKey.trim().isEmpty) {
      throw const AiServiceException(AiServiceErrorType.missingApiKey);
    }

    try {
      return await _request(
        selectedModel: model,
        incidentContext: incidentContext,
        history: history,
      );
    } on AiServiceException catch (error) {
      if (error.type != AiServiceErrorType.modelUnavailable ||
          model == fallbackModel) {
        rethrow;
      }
      return _request(
        selectedModel: fallbackModel,
        incidentContext: incidentContext,
        history: history,
      );
    }
  }

  Future<String> _request({
    required String selectedModel,
    required String incidentContext,
    required List<AiChatMessage> history,
  }) async {
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': '${AiCopilotPrompts.system}\n\n$incidentContext',
      },
      ...history
          .takeLast(10)
          .map(
            (message) => {
              'role': message.role == AiChatRole.user ? 'user' : 'assistant',
              'content': message.content,
            },
          ),
    ];
    AiTransportResponse response;
    try {
      response = await (_transport ??= RetrofitAiTransport())
          .post(
            Uri.parse('${AiProviderConfig.baseUrl}/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'model': selectedModel, 'messages': messages}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiServiceException(AiServiceErrorType.timeout);
    } on SocketException {
      throw const AiServiceException(AiServiceErrorType.network);
    } on HttpException {
      throw const AiServiceException(AiServiceErrorType.network);
    }

    if (response.statusCode == 429) {
      throw const AiServiceException(AiServiceErrorType.rateLimit);
    }
    if (_isModelUnavailable(response)) {
      throw const AiServiceException(AiServiceErrorType.modelUnavailable);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(
        AiServiceErrorType.provider,
        'HTTP ${response.statusCode}',
      );
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>;
      final first = choices.first as Map<String, dynamic>;
      final message = first['message'] as Map<String, dynamic>;
      final content = message['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const FormatException();
      }
      return content.trim();
    } on Object {
      throw const AiServiceException(AiServiceErrorType.invalidResponse);
    }
  }

  bool _isModelUnavailable(AiTransportResponse response) {
    if (response.statusCode == 404) return true;
    if (response.statusCode != 400) return false;
    final body = response.body.toLowerCase();
    return body.contains('model') &&
        (body.contains('not found') ||
            body.contains('unavailable') ||
            body.contains('decommissioned'));
  }

  String _mockAnswer(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('troubleshoot')) {
      return 'Suggested Guidance\n\n1. Confirm site safety and authorization.\n2. Review the latest alarm and visible indicators.\n3. Compare readings with the approved equipment procedure.\n4. Escalate if measurements remain outside limits.';
    }
    if (lower.contains('history')) {
      return 'The available local incident context contains the site history summary. Open Similar Incidents to review the matching records.';
    }
    if (lower.contains('missing') || lower.contains('next')) {
      return 'Complete the remaining local requirements shown in Completion Readiness. Signature and required attachments must be added before completion.';
    }
    return 'I reviewed the current incident context. The incident details, workflow state, and completion readiness shown here are derived from local prototype data.';
  }
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final list = toList();
    return list.skip(list.length > count ? list.length - count : 0);
  }
}
