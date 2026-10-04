import '../../../../core/network/result.dart';
import '../../data/models/auth_models.dart';
import '../repositories/auth_repository.dart';

class GetUserProfileUseCase {
  const GetUserProfileUseCase(this.repository);
  final AuthRepository repository;

  Future<Result<UserProfile>> call(int userId) =>
      repository.getUserProfile(userId);
}
