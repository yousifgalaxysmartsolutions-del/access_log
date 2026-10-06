import '../../../../core/network/result.dart';
import '../../data/models/cap_form_models.dart';
import '../repositories/cap_form_repository.dart';

class GetCapFormUseCase {
  const GetCapFormUseCase(this.repository);
  final CapFormRepository repository;
  Future<Result<CapQuestionForm>> call(int formId) => repository.load(formId);
}

class SubmitIncidentFormUseCase {
  const SubmitIncidentFormUseCase(this.repository);
  final CapFormRepository repository;
  Future<Result<void>> call(IncidentFormSubmission submission) =>
      repository.submit(submission);
}
