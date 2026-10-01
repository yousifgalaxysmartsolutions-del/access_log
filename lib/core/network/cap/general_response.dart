import '../../error/failure.dart';
import '../api_exception.dart';
import '../api_response.dart';

/// Generic CAP response envelope shared by every CAP endpoint.
///
/// The wire format uses the backend's own casing, which is intentionally kept
/// distinct from the Dart property names:
///
/// ```json
/// {
///   "resultcode": 1,
///   "resultmessages": {
///     "resultmessageen": "OK",
///     "resultmessagear": "تم"
///   },
///   "data": { }
/// }
/// ```
///
/// Decoding stays explicit: [decodeData] receives the raw `data` value and turns
/// it into the endpoint specific type, which keeps `GeneralResponse<T>` free of
/// any dependency on concrete models.
class GeneralResponse<T> {
  const GeneralResponse({
    required this.resultCode,
    this.resultMessageEn,
    this.resultMessageAr,
    this.data,
  });

  /// Backend convention: `1` always means the call succeeded.
  static const int successResultCode = 1;

  final int resultCode;
  final String? resultMessageEn;
  final String? resultMessageAr;
  final T? data;

  bool get isSuccess => resultCode == successResultCode;

  /// Returns the message matching the active app language, falling back to the
  /// other language when the backend did not translate it.
  String? messageFor({required bool isArabic}) {
    final english = _text(resultMessageEn);
    final arabic = _text(resultMessageAr);
    if (isArabic) return arabic.isNotEmpty ? arabic : english;
    return english.isNotEmpty ? english : arabic;
  }

  /// Parses the raw Retrofit payload without throwing.
  static GeneralResponse<T> parse<T>(
    ApiResponse response,
    T Function(Object? value) decodeData,
  ) {
    final json = response.data;
    final messages = json['resultmessages'];
    final rawData = json['data'];
    return GeneralResponse<T>(
      resultCode: _readResultCode(json['resultcode']),
      resultMessageEn: _readMessage(messages, 'resultmessageen'),
      resultMessageAr: _readMessage(messages, 'resultmessagear'),
      data: rawData == null ? null : decodeData(rawData),
    );
  }

  /// Parses the raw Retrofit payload and enforces the backend success code.
  ///
  /// Throwing `ApiException` lets callers wrap the call with `apiGuard` and keep
  /// the project's normal `Result<T>` / `Failure` error flow.
  static GeneralResponse<T> parseOrThrow<T>(
    ApiResponse response,
    T Function(Object? value) decodeData, {
    required bool isArabic,
    required String fallbackMessage,
  }) => parse<T>(
    response,
    decodeData,
  ).requireData(isArabic: isArabic, fallbackMessage: fallbackMessage);

  /// Returns the decoded payload, or throws when the call failed.
  ///
  /// Throwing [ApiException] lets callers wrap the call with `apiGuard` and keep
  /// the project's normal `Result<T>` / `Failure` error flow.
  GeneralResponse<T> requireData({
    required bool isArabic,
    required String fallbackMessage,
  }) {
    if (!isSuccess || data == null) {
      throw ApiException(
        ServiceFailure(
          'cap_result_$resultCode',
          messageFor(isArabic: isArabic) ?? fallbackMessage,
        ),
      );
    }
    return this;
  }
}

String _text(String? value) => (value ?? '').trim();

int _readResultCode(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? -1;
  return -1;
}

String? _readMessage(Object? rawMessages, String key) {
  if (rawMessages is! Map) return null;
  final value = rawMessages[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
