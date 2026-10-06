import 'dart:typed_data';
import '../../../../core/network/cap/cap_request.dart';

/// Local evidence is deliberately separate from the CAP wire contract.
class CapFormEvidence {
  CapFormEvidence({
    required this.name,
    required this.mimeType,
    required Uint8List bytes,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String name, mimeType;
  final Uint8List bytes;
}

int _id(Object? value) {
  final result = value is int ? value : int.tryParse('$value');
  if (result == null || result <= 0) {
    throw const FormatException('Invalid form identifier');
  }
  return result;
}

/// STC question type IDs. Unknown types remain visible and block confirmation.
enum CapQuestionType {
  text(1),
  number(2),
  singleChoice(3),
  image(4),
  dateTime(5),
  video(6),
  signature(7),
  qr(8),
  barcode(9),
  rating(10),
  audio(11),
  location(13),
  multiChoice(14),
  unsupported(-1);

  const CapQuestionType(this.id);
  final int id;
  static CapQuestionType fromId(int id) =>
      values.firstWhere((type) => type.id == id, orElse: () => unsupported);
}

class CapFormOption {
  const CapFormOption(this.id, this.label);
  final int id;
  final String label;
  factory CapFormOption.fromJson(Map<String, dynamic> json) =>
      CapFormOption(_id(json['AnswerID']), json['AnswerName'] as String? ?? '');
}

class CapFormQuestion {
  CapFormQuestion({
    required this.id,
    required this.title,
    required this.typeId,
    this.required = false,
    this.relatedQuestionId = 0,
    this.relatedAnswerId = 0,
    List<CapFormOption> options = const [],
  }) : options = List.unmodifiable(options);
  final int id, typeId, relatedQuestionId, relatedAnswerId;
  final String title;
  final bool required;
  final List<CapFormOption> options;
  CapQuestionType get type => CapQuestionType.fromId(typeId);
  factory CapFormQuestion.fromJson(Map<String, dynamic> json) {
    final raw = json['QuestionAnswer'];
    final options = raw == null
        ? <CapFormOption>[]
        : (raw as List)
              .map(
                (item) => CapFormOption.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
    if (options.map((o) => o.id).toSet().length != options.length) {
      throw const FormatException('Duplicate option IDs');
    }
    return CapFormQuestion(
      id: _id(json['QuestionID']),
      title: json['QuestionName'] as String? ?? '',
      typeId: _id(json['QuestionTypeID']),
      required: json['QuestionMendatory'] == true,
      relatedQuestionId: json['RelatedQuestionId'] as int? ?? 0,
      relatedAnswerId: json['RelatedAnswerID'] as int? ?? 0,
      options: options,
    );
  }
}

class CapQuestionForm {
  CapQuestionForm({
    required this.id,
    required this.title,
    this.description = '',
    required List<CapFormQuestion> questions,
  }) : questions = List.unmodifiable(questions);
  final int id;
  final String title, description;
  final List<CapFormQuestion> questions;
  factory CapQuestionForm.fromJson(Map<String, dynamic> json) {
    final questions = (json['taskquestion'] as List)
        .map(
          (item) =>
              CapFormQuestion.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final ids = questions.map((q) => q.id).toSet();
    if (ids.length != questions.length) {
      throw const FormatException('Duplicate question IDs');
    }
    for (final question in questions) {
      final visited = <int>{question.id};
      var parent = question.relatedQuestionId;
      while (parent != 0) {
        if (!ids.contains(parent) || !visited.add(parent)) {
          throw const FormatException('Invalid conditional question reference');
        }
        parent = questions.firstWhere((q) => q.id == parent).relatedQuestionId;
      }
    }
    return CapQuestionForm(
      id: _id(json['FormId']),
      title: json['Title'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      questions: questions,
    );
  }
}

class GetCapFormPayload implements CapPayload {
  const GetCapFormPayload(this.formId);
  final int formId;
  @override
  Map<String, dynamic> toJson() => {'FormId': formId};
}

class CapFormAnswer implements CapPayload {
  const CapFormAnswer({
    required this.questionId,
    required this.questionTypeId,
    this.text = '',
    this.answerBytes,
    this.optionId = 0,
    this.evidence,
  });
  final int questionId, questionTypeId, optionId;
  final String text;

  /// Preserved as a wire string; binary encoding must be supplied by the host.
  final String? answerBytes;
  final CapFormEvidence? evidence;
  @override
  Map<String, dynamic> toJson() {
    if (evidence != null) {
      throw const FormatException(
        'Encode local evidence using the confirmed CAP contract before submission',
      );
    }
    return {
      'QuestionId': questionId,
      'QuestionTypeId': questionTypeId,
      'TextAnswer': text,
      'AnswerBytes': answerBytes,
      'OptionAnswer': optionId,
    };
  }
}

class IncidentFormSubmission implements CapPayload {
  IncidentFormSubmission({
    required this.incidentId,
    required this.newStatusId,
    required this.actionTypeId,
    required this.formId,
    required this.remark,
    required List<CapFormAnswer> answers,
  }) : answers = List.unmodifiable(answers);
  final int incidentId, newStatusId, actionTypeId, formId;
  final String remark;
  final List<CapFormAnswer> answers;
  @override
  Map<String, dynamic> toJson() => {
    'IncidentId': incidentId,
    'NewStatusId': newStatusId,
    'ActionTypeId': actionTypeId,
    'Remark': remark,
    'QuestionFormId': formId,
    'Answers': answers.map((a) => a.toJson()).toList(),
  };
}
