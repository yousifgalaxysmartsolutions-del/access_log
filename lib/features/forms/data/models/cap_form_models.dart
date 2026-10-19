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

  /// Extension without a dot. Inspect encoded content before picker metadata,
  /// which can be absent or generic on Android and iOS.
  String get extension {
    bool startsWith(List<int> header) =>
        bytes.length >= header.length &&
        List.generate(
          header.length,
          (i) => bytes[i] == header[i],
        ).every((matches) => matches);
    if (startsWith([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10])) return 'png';
    if (startsWith([0xff, 0xd8, 0xff])) return 'jpg';
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp') {
      final brand = String.fromCharCodes(bytes.sublist(8, 12));
      if (brand == 'qt  ') return 'mov';
      if (['heic', 'heix', 'hevc', 'hevx'].contains(brand)) return 'heic';
      if (['mif1', 'msf1'].contains(brand)) return 'heif';
      if (['avif', 'avis'].contains(brand)) return 'avif';
      if (['M4A ', 'M4B '].contains(brand)) return 'm4a';
      if (['isom', 'iso2', 'mp41', 'mp42', 'avc1', 'M4V '].contains(brand)) {
        return mimeType.startsWith('audio/') ? 'm4a' : 'mp4';
      }
    }
    final suffix = name.split('.').last.toLowerCase();
    if (name.contains('.') &&
        const {
          'png',
          'jpg',
          'jpeg',
          'heic',
          'heif',
          'webp',
          'gif',
          'avif',
          'mov',
          'mp4',
          'm4v',
          '3gp',
          'm4a',
          'mp3',
          'aac',
          'wav',
          'ogg',
          'flac',
        }.contains(suffix)) {
      return suffix == 'jpeg' ? 'jpg' : suffix;
    }
    final type = mimeType.split(';').first.trim().toLowerCase();
    final fallback = const {
      'image/png': 'png',
      'image/jpeg': 'jpg',
      'image/heic': 'heic',
      'image/heif': 'heif',
      'image/webp': 'webp',
      'image/gif': 'gif',
      'video/quicktime': 'mov',
      'video/mp4': 'mp4',
      'video/3gpp': '3gp',
      'audio/mp4': 'm4a',
      'audio/x-m4a': 'm4a',
      'audio/mpeg': 'mp3',
      'audio/aac': 'aac',
      'audio/wav': 'wav',
      'audio/ogg': 'ogg',
    }[type];
    if (fallback != null) return fallback;
    throw const FormatException('Unknown evidence file extension');
  }
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

  /// Raw bytes serialize as a JSON array, not a Base64 string.
  final List<int>? answerBytes;
  final CapFormEvidence? evidence;
  @override
  Map<String, dynamic> toJson() {
    return {
      'QuestionId': questionId,
      'QuestionTypeId': questionTypeId,
      'TextAnswer': evidence?.extension ?? text,
      'AnswerBytes': evidence?.bytes.toList() ?? answerBytes,
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
    this.lat = '',
    this.long = '',
    this.photo = '',
  }) : answers = List.unmodifiable(answers);
  final int incidentId, newStatusId, actionTypeId;
  final int? formId;
  final String lat, long, photo;
  final String remark;
  final List<CapFormAnswer> answers;
  @override
  Map<String, dynamic> toJson() => {
    'IncidentId': incidentId,
    'NewStatusId': newStatusId,
    'ActionTypeId': actionTypeId,
    'Remark': remark,
    'lat': lat,
    'long': long,
    'photo': photo,
    'QuestionFormId': formId,
    'Answers': answers.map((a) => a.toJson()).toList(),
  };
}
