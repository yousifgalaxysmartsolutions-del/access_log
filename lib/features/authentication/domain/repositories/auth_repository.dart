import '../../../../core/network/result.dart';
import '../../data/models/auth_models.dart';

import '../../../../core/storage/secure_storage_service.dart';

abstract interface class AuthRepository {
  Future<Result<AuthUser>> login({
    required String username,
    required String password,
    bool remember = true,
  });

  Future<SessionTokens> refresh(String refreshToken);

  Future<Result<UserProfile>> getUserProfile(int userId);
}
