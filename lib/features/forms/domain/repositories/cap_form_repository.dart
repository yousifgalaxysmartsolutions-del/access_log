import '../../../../core/network/result.dart';
import '../../data/models/cap_form_models.dart';

abstract interface class CapFormRepository {
  Future<Result<CapQuestionForm>> load(int formId);
  Future<Result<void>> submit(IncidentFormSubmission submission);
}
