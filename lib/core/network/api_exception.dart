import '../error/failure.dart';

class ApiException implements Exception {
  const ApiException(this.failure);
  final Failure failure;
}
