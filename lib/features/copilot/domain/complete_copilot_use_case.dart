import '../../../ai_copilot/ai_copilot_models.dart';
import '../../../core/network/result.dart';
import '../data/copilot_repository.dart';

class CompleteCopilotUseCase {
  const CompleteCopilotUseCase(this.repository);
  final CopilotRepository repository;
  Future<Result<String>> call(String context, List<AiChatMessage> history) =>
      repository.complete(context, history);
}
