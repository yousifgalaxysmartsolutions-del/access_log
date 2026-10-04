/// A CAP request body.
///
/// Implemented by the endpoint specific `data` payloads so [CapRequest] can
/// serialize them without knowing the concrete type.
abstract interface class CapPayload {
  Map<String, dynamic> toJson();
}

/// Common CAP request envelope shared by every CAP endpoint.
///
/// Dart properties use idiomatic camelCase, while the serialized payload keeps
/// the exact casing the backend expects:
///
/// ```json
/// {
///   "userid": 4098,
///   "ipaddress": "...",
///   "devicetoken": "...",
///   "osversion": "15.1",
///   "AppVersion": "1.0.0",
///   "devicetype": "iOS",
///   "data": { }
/// }
/// ```
class CapRequest<T> {
  const CapRequest({
    required this.userId,
    required this.deviceIdentifier,
    required this.deviceToken,
    required this.osVersion,
    required this.appVersion,
    required this.deviceType,
    required this.data,
  }) : _includeData = true;

  const CapRequest._metadataOnly({
    required this.userId,
    required this.deviceIdentifier,
    required this.deviceToken,
    required this.osVersion,
    required this.appVersion,
    required this.deviceType,
    required this.data,
  }) : _includeData = false;

  /// Explicit opt-in for CAP endpoints whose contract has metadata only.
  /// Ordinary requests, including `data: null`, keep their existing JSON.
  static CapRequest<Null> metadataOnly({
    required int userId,
    required String deviceIdentifier,
    required String deviceToken,
    required String osVersion,
    required String appVersion,
    required String deviceType,
  }) => CapRequest<Null>._metadataOnly(
    userId: userId,
    deviceIdentifier: deviceIdentifier,
    deviceToken: deviceToken,
    osVersion: osVersion,
    appVersion: appVersion,
    deviceType: deviceType,
    data: null,
  );

  final bool _includeData;

  /// The authenticated CAP user id (`User_PK_ID` from the login response).
  final int userId;

  /// The stable per-installation identifier.
  ///
  /// Needs Verification: the backend labels this field `ipaddress`, but every
  /// known value in this project is a device identifier such as
  /// `FUH0216913004222` rather than a network address. The internal name
  /// reflects what the value actually is.
  final String deviceIdentifier;

  final String deviceToken;
  final String osVersion;
  final String appVersion;
  final String deviceType;
  final T data;

  Map<String, dynamic> toJson() => {
    'userid': userId,
    'ipaddress': deviceIdentifier,
    'devicetoken': deviceToken,
    'osversion': osVersion,
    'AppVersion': appVersion,
    'devicetype': deviceType,
    if (_includeData) 'data': _encode(data),
  };
}

/// JSON encoding for [CapRequest] payloads.
///
/// Nested values are encoded recursively. Endpoint bodies are usually a [Map]
/// or a [CapPayload], but lists and primitives are supported too so the envelope
/// never needs to change per endpoint. Anything else is rendered as text rather
/// than being handed to `jsonEncode`, which would throw and fail the request.
Object? _encode(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', _encode(item)));
  }
  if (value is Iterable) return value.map(_encode).toList();
  if (value is CapPayload) return _encode(value.toJson());
  return value.toString();
}
