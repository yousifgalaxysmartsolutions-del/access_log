import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'ai_copilot_context_builder.dart';
import 'ai_copilot_models.dart';
import 'ai_copilot_service.dart';

class AiCopilotController extends ChangeNotifier {
  AiCopilotController({
    required this.incident,
    required this.client,
    this.contextBuilder = const AiCopilotContextBuilder(),
  }) : readiness = contextBuilder.readiness(incident),
       messages = [
         const AiChatMessage(
           role: AiChatRole.assistant,
           content:
               'I am ready to help with this incident. Ask what to do next, what evidence is missing, or request troubleshooting guidance.',
         ),
       ];

  final CapIncident incident;
  final AiCopilotClient client;
  final AiCopilotContextBuilder contextBuilder;
  final CompletionReadiness readiness;
  final List<AiChatMessage> messages;
  bool loading = false;
  String? lastPrompt;

  Future<void> send(String rawPrompt) async {
    final prompt = rawPrompt.trim();
    if (prompt.isEmpty || loading) return;
    lastPrompt = prompt;
    messages.add(AiChatMessage(role: AiChatRole.user, content: prompt));
    loading = true;
    notifyListeners();
    try {
      final answer = await client.complete(
        incidentContext: contextBuilder.build(incident),
        history: messages.where((message) => !message.isError).toList(),
      );
      messages.add(
        AiChatMessage(
          role: AiChatRole.assistant,
          content: answer,
          isTroubleshooting: _isTroubleshooting(prompt),
          actions: _actionsFor(prompt),
        ),
      );
    } on AiServiceException catch (error) {
      messages.add(
        AiChatMessage(
          role: AiChatRole.assistant,
          content: _friendlyError(error.type),
          isError: true,
        ),
      );
    } on Object {
      messages.add(
        const AiChatMessage(
          role: AiChatRole.assistant,
          content:
              'AI Copilot is temporarily unavailable.\n\nYour incident data is still available and you can continue the workflow normally.',
          isError: true,
        ),
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> retry() async {
    if (loading || lastPrompt == null) return;
    if (messages.isNotEmpty && messages.last.isError) messages.removeLast();
    if (messages.isNotEmpty && messages.last.role == AiChatRole.user) {
      messages.removeLast();
    }
    await send(lastPrompt!);
  }

  List<AiLocalAction> _actionsFor(String prompt) {
    final lower = prompt.toLowerCase();
    final actions = <AiLocalAction>[];
    if (lower.contains('history') || lower.contains('similar')) {
      actions.add(AiLocalAction.viewSimilarIncidents);
    }
    if (lower.contains('next') ||
        lower.contains('missing') ||
        lower.contains('evidence') ||
        lower.contains('completion') ||
        lower.contains('بعد') ||
        lower.contains('ناقص')) {
      if (!readiness.questionnaireCompleted) {
        actions.add(AiLocalAction.continueQuestionnaire);
      }
      if (!readiness.signatureCaptured) {
        actions.add(AiLocalAction.captureSignature);
      }
      if (!readiness.attachmentsAdded) {
        actions.add(AiLocalAction.addAttachment);
      }
    }
    return actions;
  }

  bool _isTroubleshooting(String prompt) {
    final lower = prompt.toLowerCase();
    return lower.contains('troubleshoot') ||
        lower.contains('diagnos') ||
        lower.contains('عطل') ||
        lower.contains('مشكلة');
  }

  String _friendlyError(AiServiceErrorType type) => switch (type) {
    AiServiceErrorType.missingApiKey =>
      'AI Copilot is not configured on this build.\n\nRun the prototype with GROQ_API_KEY using --dart-define, or use local mock mode for demonstrations.',
    AiServiceErrorType.rateLimit =>
      'AI Copilot is receiving too many requests. Please wait briefly and retry.\n\nYour incident workflow remains available.',
    AiServiceErrorType.timeout =>
      'AI Copilot took too long to respond. Check the connection and retry.\n\nYour incident workflow remains available.',
    AiServiceErrorType.modelUnavailable =>
      'The configured AI model is temporarily unavailable. Please retry later.\n\nYour incident workflow remains available.',
    _ =>
      'AI Copilot is temporarily unavailable.\n\nYour incident data is still available and you can continue the workflow normally.',
  };
}
