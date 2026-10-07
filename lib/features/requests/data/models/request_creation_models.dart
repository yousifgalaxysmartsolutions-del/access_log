import '../../../../core/network/cap/cap_request.dart';
import '../../../forms/data/models/cap_form_models.dart';
import '../../../incidents/data/models/incident_action_configuration_models.dart';
import '../../../incidents/data/models/incident_details_models.dart';

class RequestConfigurationInput implements CapPayload {
  const RequestConfigurationInput(this.requestTypeId, this.incidentId);
  final int requestTypeId, incidentId;
  @override
  Map<String, dynamic> toJson() => {
    'RequestTypeId': requestTypeId,
    'IncidentId': incidentId,
  };
}

/// Adapts the shared requirement fields without inventing approval policies.
class RequestConfiguration extends IncidentActionConfiguration {
  const RequestConfiguration({
    super.id,
    super.userType,
    super.questionFormId,
    required super.gpsRequired,
    super.photoRequiredLevel,
    super.isActive,
    this.requestType,
    this.channelType,
    this.locationType,
    this.incidentType,
    this.approvalRequired,
    this.autoApproval,
    this.confirmationCodeRequired,
    this.approvalWorkflow,
  });
  final IdNameDto? requestType;
  final Object? channelType, locationType, incidentType, approvalWorkflow;
  final bool? approvalRequired, autoApproval, confirmationCodeRequired;
  factory RequestConfiguration.fromJson(Map<String, dynamic> json) =>
      RequestConfiguration(
        id: json['id'] as int?,
        userType: json['userType'] as int?,
        questionFormId: json['questionFormId'] as String?,
        gpsRequired: json['gpsRequired'] as bool,
        photoRequiredLevel: json['photoRequiredLevel'] as int?,
        isActive: json['isActive'] as bool?,
        requestType: json['requestType'] == null
            ? null
            : IdNameDto.fromJson(
                Map<String, dynamic>.from(json['requestType'] as Map),
              ),
        channelType: json['channelType'],
        locationType: json['locationType'],
        incidentType: json['incidentType'],
        approvalRequired: json['approvalRequired'] as bool?,
        autoApproval: json['autoApproval'] as bool?,
        confirmationCodeRequired: json['confirmationCodeRequired'] as bool?,
        approvalWorkflow: json['approvalWorkflow'],
      );
}

/// NewStatusId is explicit, nullable while preparing, and mandatory at execution.
class RequestExecutionContext implements CapPayload {
  RequestExecutionContext({
    required this.incidentId,
    required this.requestTypeId,
    required this.newStatusId,
    this.remark = '',
    this.lat = '',
    this.long = '',
    this.photo = '',
    this.questionFormId,
    this.noOfMinute = 0,
    List<CapFormAnswer> answers = const [],
  }) : answers = List.unmodifiable(answers);
  final int incidentId, requestTypeId, noOfMinute;
  final int? newStatusId, questionFormId;
  final String remark, lat, long, photo;
  final List<CapFormAnswer> answers;
  bool get canSubmit => newStatusId != null && newStatusId! > 0;
  @override
  Map<String, dynamic> toJson() {
    if (!canSubmit) throw StateError('Request NewStatusId is not confirmed');
    return {
      'IncidentId': incidentId,
      'RequestTypeId': requestTypeId,
      'Remark': remark,
      'QuestionFormId': questionFormId,
      'NewStatusId': newStatusId,
      'lat': lat,
      'long': long,
      'photo': photo,
      'NoOfMinute': noOfMinute,
      'Answers': answers.map((a) => a.toJson()).toList(),
    };
  }
}
