sealed class Failure {
  const Failure(this.message);
  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network unavailable']);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Please sign in again']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Service unavailable']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Please check your information']);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'Request timed out']);
}

class CancelledFailure extends Failure {
  const CancelledFailure([super.message = 'Request cancelled']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unable to complete request']);
}

class ServiceFailure extends Failure {
  const ServiceFailure(this.code, [super.message = 'Service unavailable']);
  final String code;
}
