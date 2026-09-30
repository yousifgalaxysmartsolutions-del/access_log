import '../../../../core/network/result.dart';
import '../../data/models/auth_models.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this.repository);
  final AuthRepository repository;
  Future<Result<AuthUser>> call({
    required String username,
    required String password,
    bool remember = true,
  }) => repository.login(
    username: username,
    password: password,
    remember: remember,
  );
}
