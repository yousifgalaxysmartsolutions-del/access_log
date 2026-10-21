import 'dart:convert';
import '../../../forms/data/models/cap_form_models.dart';
import '../../../../core/network/cap/cap_request.dart';
import 'incident_available_action.dart';

/// One route-owned handoff from requirements through final execution.
class IncidentExecutionContext implements CapPayload {
  IncidentExecutionContext({
    required this.incidentId,
    required this.selectedAction,
    this.lat = '',
    this.long = '',
    this.photo = '',
    this.photoEvidence,
    this.questionFormId,
    List<CapFormAnswer> answers = const [],
    this.remark = '',
    this.assignedUserId,
  }) : answers = List.unmodifiable(answers);
  final int incidentId;
  final IncidentAvailableAction selectedAction;
  int get actionTypeId => selectedAction.actionTypeId;
  int? get newStatusId => selectedAction.newStatusId;
  final String lat, long, photo;

  /// Raw evidence retained for IncidentStatusChange; Assign keeps its existing
  /// independent Base64 contract in [photo].
  final CapFormEvidence? photoEvidence;
  final int? questionFormId;
  final List<CapFormAnswer> answers;
  final String remark;
  final int? assignedUserId;
  IncidentExecutionContext withInput({String? remark, int? assignedUserId}) =>
      IncidentExecutionContext(
        incidentId: incidentId,
        selectedAction: selectedAction,
        lat: lat,
        long: long,
        photo: photo,
        photoEvidence: photoEvidence,
        questionFormId: questionFormId,
        answers: answers,
        remark: remark ?? this.remark,
        assignedUserId: assignedUserId ?? this.assignedUserId,
      );
  factory IncidentExecutionContext.collected({
    required int incidentId,
    required IncidentAvailableAction action,
    String? location,
    CapFormEvidence? photo,
    int? formId,
    required List<CapFormAnswer> answers,
    String remark = '',
  }) {
    final parts = location?.split(',');
    if (parts != null &&
        (parts.length != 2 ||
            parts.any((s) => double.tryParse(s.trim())?.isFinite != true))) {
      throw const FormatException('Invalid collected coordinates');
    }
    return IncidentExecutionContext(
      incidentId: incidentId,
      selectedAction: action,
      lat: parts?[0].trim() ?? '',
      long: parts?[1].trim() ?? '',
      photo: photo == null ? '' : base64Encode(photo.bytes),
      photoEvidence: photo,
      questionFormId: formId,
      answers: answers,
      remark: remark,
    );
  }
  IncidentFormSubmission toStatusChange({String? availableLocation}) {
    List<String>? coordinates(String? raw) {
      final parts = raw?.split(',').map((part) => part.trim()).toList();
      if (parts?.length != 2) return null;
      final latitude = double.tryParse(parts![0]);
      final longitude = double.tryParse(parts[1]);
      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        return null;
      }
      return parts;
    }

    final gps = coordinates('$lat,$long') ?? coordinates(availableLocation);
    return IncidentFormSubmission(
      incidentId: incidentId,
      newStatusId: newStatusId!,
      actionTypeId: actionTypeId,
      formId: questionFormId,
      remark: remark,
      answers: answers,
      lat: gps?[0] ?? '',
      long: gps?[1] ?? '',
      photo: photoEvidence,
    );
  }

  /// Assign payload deliberately omits ActionTypeId and NewStatusId.
  @override
  Map<String, dynamic> toJson() => {
    'IncidentId': incidentId,
    'AssignedUserId': assignedUserId,
    'lat': lat,
    'long': long,
    'photo': photo,
    'Remark': remark,
    'QuestionFormId': questionFormId,
    'Answers': answers.map((a) => a.toJson()).toList(),
  };
}

class IncidentTeamMember {
  const IncidentTeamMember({
    required this.id,
    required this.name,
    required this.userName,
    required this.mobile,
  });
  final int id;
  final String name, userName, mobile;
  factory IncidentTeamMember.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    if (id <= 0) throw const FormatException('Invalid team member ID');
    return IncidentTeamMember(
      id: id,
      name: json['name'] as String,
      userName: json['userName'] as String,
      mobile: json['mobile'] as String,
    );
  }
}
