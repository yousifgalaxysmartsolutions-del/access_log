import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../data/models/auth_models.dart';
import '../repositories/auth_repository.dart';

class ForgotPasswordUseCase {
  const ForgotPasswordUseCase(this.repository);
  final AuthRepository repository;

  Future<Result<ForgotPasswordResetData>> call(String username) {
    final value = username.trim();
    if (value.isEmpty) {
      return Future.value(const FailureResult(ValidationFailure()));
    }
    return repository.requestPasswordReset(value);
  }
}
