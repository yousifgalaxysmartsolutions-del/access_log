enum AiCopilotMode { groq, mock }

enum AiChatRole { user, assistant }

enum AiLocalAction {
  continueQuestionnaire,
  captureSignature,
  addAttachment,
  viewSimilarIncidents,
}

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
    this.isTroubleshooting = false,
    this.actions = const [],
  });

  final AiChatRole role;
  final String content;
  final bool isError, isTroubleshooting;
  final List<AiLocalAction> actions;
}

class CompletionReadiness {
  const CompletionReadiness({
    required this.locationVerified,
    required this.photosAttached,
    required this.requiredPhotos,
    required this.questionnaireCompleted,
    required this.signatureCaptured,
    required this.attachmentsAdded,
  });

  final bool locationVerified;
  final int photosAttached, requiredPhotos;
  final bool questionnaireCompleted, signatureCaptured, attachmentsAdded;

  int get remaining => [
    locationVerified,
    photosAttached >= requiredPhotos,
    questionnaireCompleted,
    signatureCaptured,
    attachmentsAdded,
  ].where((complete) => !complete).length;
}
