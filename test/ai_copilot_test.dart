import 'dart:convert';

import 'package:access_log_plus/ai_copilot/ai_copilot_context_builder.dart';
import 'package:access_log_plus/ai_copilot/ai_copilot_controller.dart';
import 'package:access_log_plus/ai_copilot/ai_copilot_models.dart';
import 'package:access_log_plus/ai_copilot/ai_copilot_screen.dart';
import 'package:access_log_plus/ai_copilot/ai_copilot_service.dart';
import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/screens/incidents/incident_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light(),
    home: home,
  );

  Future<void> phone(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  test('context builder derives incident and completion facts locally', () {
    final incident = MockData.capIncidents.first;
    const builder = AiCopilotContextBuilder();
    final context = builder.build(incident);
    final readiness = builder.readiness(incident);

    expect(context, contains(incident.number));
    expect(context, contains(incident.siteName));
    expect(context, contains(MockData.engineer.name));
    expect(context, contains('Engineer Signature: Missing'));
    expect(readiness.remaining, 2);
  });

  test(
    'Groq service sends compact history and parses assistant content',
    () async {
      final transport = _FakeTransport([
        const AiTransportResponse(
          statusCode: 200,
          body: '{"choices":[{"message":{"content":"Operational answer"}}]}',
        ),
      ]);
      final service = AiCopilotService(
        transport: transport,
        apiKey: 'test-only-key',
        model: 'test-model',
      );
      final history = List.generate(
        14,
        (index) => AiChatMessage(
          role: index.isEven ? AiChatRole.user : AiChatRole.assistant,
          content: 'message-$index',
        ),
      );

      final answer = await service.complete(
        incidentContext: 'INCIDENT CONTEXT',
        history: history,
      );
      final request =
          jsonDecode(transport.bodies.single) as Map<String, dynamic>;
      final messages = request['messages'] as List<dynamic>;

      expect(answer, 'Operational answer');
      expect(request['model'], 'test-model');
      expect(messages, hasLength(11));
      expect((messages.first as Map)['content'], contains('INCIDENT CONTEXT'));
      expect((messages[1] as Map)['content'], 'message-4');
      expect(transport.headers.single['Authorization'], 'Bearer test-only-key');
    },
  );

  test(
    'Groq service retries once with fallback model when unavailable',
    () async {
      final transport = _FakeTransport([
        const AiTransportResponse(
          statusCode: 404,
          body: '{"error":{"message":"model not found"}}',
        ),
        const AiTransportResponse(
          statusCode: 200,
          body: '{"choices":[{"message":{"content":"Fallback answer"}}]}',
        ),
      ]);
      final service = AiCopilotService(
        transport: transport,
        apiKey: 'test-only-key',
        model: 'primary-model',
        fallbackModel: 'fallback-model',
      );

      final result = await service.complete(
        incidentContext: 'context',
        history: const [AiChatMessage(role: AiChatRole.user, content: 'Help')],
      );

      expect(result, 'Fallback answer');
      expect(transport.bodies, hasLength(2));
      expect(jsonDecode(transport.bodies[0])['model'], 'primary-model');
      expect(jsonDecode(transport.bodies[1])['model'], 'fallback-model');
    },
  );

  test('environment factory falls back to mock when no API key is set', () {
    final service = AiCopilotService.fromEnvironment(apiKey: '');

    expect(service.mode, AiCopilotMode.mock);
  });

  test(
    'controller keeps AI informational and derives actions locally',
    () async {
      final controller = AiCopilotController(
        incident: MockData.capIncidents.first,
        client: _FakeClient('Complete the missing requirements.'),
      );

      await controller.send('What is missing before completion?');
      final answer = controller.messages.last;
      expect(answer.role, AiChatRole.assistant);
      expect(answer.actions, contains(AiLocalAction.captureSignature));
      expect(answer.actions, contains(AiLocalAction.addAttachment));
      expect(
        answer.actions,
        isNot(contains(AiLocalAction.continueQuestionnaire)),
      );
      controller.dispose();
    },
  );

  testWidgets('Copilot UI sends prompt and exposes local workflow actions', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      app(
        AiCopilotScreen(
          incident: MockData.capIncidents.first,
          client: _FakeClient('Signature and attachment are still required.'),
        ),
      ),
    );

    expect(find.text('AI Field Copilot'), findsOneWidget);
    expect(find.text('Completion Readiness'), findsOneWidget);
    await tester.ensureVisible(find.text('What is missing before completion?'));
    await tester.tap(find.text('What is missing before completion?'));
    await tester.pumpAndSettle();
    expect(find.text('Capture Signature'), findsOneWidget);
    expect(find.text('Add Attachment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing API key displays friendly retry state without crash', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      app(
        AiCopilotScreen(
          incident: MockData.capIncidents.first,
          client: AiCopilotService(
            apiKey: '',
            transport: _FakeTransport(const []),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Summarize this incident'));
    await tester.tap(find.text('Summarize this incident'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not configured'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Incident Details no longer exposes the Copilot icon', (
    tester,
  ) async {
    await phone(tester, scale: 1.35);
    await tester.pumpWidget(
      app(
        IncidentDetailsScreen(incident: MockData.capIncidents.first),
        locale: const Locale('ar'),
      ),
    );

    expect(find.byTooltip('مساعد المهندس الذكي'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeTransport implements AiHttpTransport {
  _FakeTransport(List<AiTransportResponse> responses)
    : responses = List.of(responses);
  final List<AiTransportResponse> responses;
  final List<String> bodies = [];
  final List<Map<String, String>> headers = [];

  @override
  Future<AiTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    this.headers.add(Map.of(headers));
    bodies.add(body);
    return responses.removeAt(0);
  }
}

class _FakeClient implements AiCopilotClient {
  _FakeClient(this.answer);
  final String answer;
  @override
  AiCopilotMode get mode => AiCopilotMode.mock;

  @override
  Future<String> complete({
    required String incidentContext,
    required List<AiChatMessage> history,
  }) async => answer;
}
