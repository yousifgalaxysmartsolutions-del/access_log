import '../../../../core/network/cap/cap_request.dart';

/// The `data` block of `CAP/CapIncident/SavePeriodicPhoto`.
///
/// Serialized exactly as the backend expects:
///
/// ```json
/// {
///   "IncidentId": 0,
///   "ImageData": "jpg",
///   "ImageBytes": [255, 216, 255, …]
/// }
/// ```
///
/// The outer CAP envelope (userid/ipaddress/devicetoken/osversion/AppVersion/
/// devicetype/lang) is added by the shared request context, never here.
///
/// ## Field contract
///
/// * [incidentId] comes from `ActiveIncidentContext.uploadIncidentId`
///   (`activeIncidentId ?? 0`) — never a hardcoded example value.
/// * [imageData] is the *actual* captured file extension (`.jpg` vs `.png`),
///   detected from the encoded content by `CapFormEvidence.extension`.
/// * [imageBytes] is **raw bytes serialized as a JSON array**. This follows the
///   project's only confirmed byte-field contract, `CapFormAnswer.AnswerBytes`,
///   which is explicitly documented as "Raw bytes serialize as a JSON array,
///   not a Base64 string". The base64 path used by
///   `IncidentExecutionContext.photo` belongs to a *string* field and is not
///   applicable here. `AnswerBytes` is a different API contract and is never
///   substituted for this endpoint.
class SavePeriodicPhotoRequestData implements CapPayload {
  const SavePeriodicPhotoRequestData({
    required this.incidentId,
    required this.imageData,
    required this.imageBytes,
  });

  final int incidentId;

  /// Real file extension without a dot, e.g. `jpg` or `png`.
  final String imageData;

  /// Encoded image bytes as a JSON array.
  final List<int> imageBytes;

  @override
  Map<String, dynamic> toJson() => {
    'IncidentId': incidentId,
    'ImageData': imageData,
    'ImageBytes': imageBytes,
  };
}
