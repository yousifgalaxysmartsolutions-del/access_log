import '../../../../core/network/cap/cap_request.dart';
import 'incident_details_models.dart';

class IncidentActionConfigurationRequest implements CapPayload {
  const IncidentActionConfigurationRequest(this.actionTypeId);
  final int actionTypeId;
  @override
  Map<String, dynamic> toJson() => {'ActionTypeId': actionTypeId};
}

/// Preserve server values; no policy is inferred from userType/isActive/photo level.
class IncidentActionConfiguration {
  const IncidentActionConfiguration({
    this.id,
    this.actionType,
    this.userType,
    this.questionFormId,
    required this.gpsRequired,
    this.photoRequiredLevel,
    this.isActive,
  });
  final int? id, userType, photoRequiredLevel;
  final IdNameDto? actionType;
  final String? questionFormId;
  final bool gpsRequired;
  final bool? isActive;
  factory IncidentActionConfiguration.fromJson(Map<String, dynamic> json) =>
      IncidentActionConfiguration(
        id: json['id'] as int?,
        actionType: json['actionType'] == null
            ? null
            : IdNameDto.fromJson(
                Map<String, dynamic>.from(json['actionType'] as Map),
              ),
        userType: json['userType'] as int?,
        questionFormId: json['questionFormId'] as String?,
        gpsRequired: json['gpsRequired'] as bool,
        photoRequiredLevel: json['photoRequiredLevel'] as int?,
        isActive: json['isActive'] as bool?,
      );
}
