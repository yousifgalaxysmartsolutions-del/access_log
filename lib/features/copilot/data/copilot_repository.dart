import '../../../core/error/exception_mapper.dart';
import '../../../core/network/result.dart';
import '../../../ai_copilot/ai_copilot_models.dart';
import '../../../ai_copilot/ai_copilot_service.dart';
import '../../../core/error/failure.dart';

class CopilotRepository {
  const CopilotRepository(this.client);
  final AiCopilotClient client;
  Future<Result<String>> complete(
    String context,
    List<AiChatMessage> history,
  ) async {
    try {
      return Success(
        await client.complete(incidentContext: context, history: history),
      );
    } on AiServiceException catch (error) {
      return FailureResult(ServiceFailure(error.type.name));
    } on Exception catch (error) {
      return FailureResult(ExceptionMapper.map(error));
    }
  }
}
