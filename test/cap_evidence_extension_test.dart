import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/features/forms/data/models/cap_form_models.dart';

void main() {
  final cases = [
    ('Android JPEG', 'camera.png', 'image/png', [255, 216, 255, 224], 'jpg'),
    (
      'iOS HEIC',
      'camera.jpg',
      'image/jpeg',
      [0, 0, 0, 24, ...'ftypheic'.codeUnits],
      'heic',
    ),
    (
      'iOS QuickTime',
      'capture.mp4',
      'video/mp4',
      [0, 0, 0, 24, ...'ftypqt  '.codeUnits],
      'mov',
    ),
    (
      'Android MP4',
      'capture.mov',
      'video/quicktime',
      [0, 0, 0, 24, ...'ftypmp42'.codeUnits],
      'mp4',
    ),
    (
      'AAC recording',
      'answer.m4a',
      'audio/mp4',
      [0, 0, 0, 24, ...'ftypM4A '.codeUnits],
      'm4a',
    ),
    (
      'signature / edited PNG',
      'edited.jpg',
      'image/jpeg',
      [137, 80, 78, 71, 13, 10, 26, 10],
      'png',
    ),
    ('uppercase picker filename', 'CAPTURE.MOV', 'video/mp4', [1], 'mov'),
    ('missing filename extension', 'capture', 'video/quicktime', [1], 'mov'),
  ];
  for (final c in cases) {
    test('${c.$1} sends extension and unchanged raw bytes', () {
      final payload = CapFormAnswer(
        questionId: 1,
        questionTypeId: 4,
        evidence: CapFormEvidence(
          name: c.$2,
          mimeType: c.$3,
          bytes: Uint8List.fromList(c.$4),
        ),
      ).toJson();
      expect(payload['TextAnswer'], c.$5);
      expect(payload['AnswerBytes'], c.$4);
    });
  }
  test('ordinary text and GPS answers retain their content', () {
    for (final type in [1, 13]) {
      final payload = CapFormAnswer(
        questionId: 1,
        questionTypeId: type,
        text: '27.2112,43.3565',
      ).toJson();
      expect(payload['TextAnswer'], '27.2112,43.3565');
      expect(payload['AnswerBytes'], isNull);
    }
  });
}
