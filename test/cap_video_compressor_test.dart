import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_compress/video_compress.dart';
import 'package:access_log_plus/features/forms/data/services/cap_video_compressor.dart';

void main() {
  late Directory dir;
  late File original, output;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cap-compression-test');
    original = await File(
      '${dir.path}/camera.mov',
    ).writeAsBytes(List.filled(100, 1));
    output = await File(
      '${dir.path}/export.mp4',
    ).writeAsBytes(List.filled(40, 2));
  });
  tearDown(() => dir.delete(recursive: true));
  MediaInfo info(
    String path, {
    double duration = 10000,
    int width = 1920,
    int height = 1080,
  }) => MediaInfo(
    path: path,
    file: File(path),
    duration: duration,
    width: width,
    height: height,
  );

  test(
    'compresses before size limit, preserves original and removes export',
    () async {
      final service = CapVideoCompressor(
        inspect: (path) async => info(path),
        compress: (path, quality) async {
          expect(quality, VideoQuality.Res1280x720Quality);
          return info(output.path);
        },
      );
      final result = await service.prepare(original, maxBytes: 50);
      expect(result.bytes.length, 40);
      expect(result.extension, 'mp4');
      expect(await original.length(), 100);
      expect(await output.exists(), false);
    },
  );
  for (final scenario in [
    'larger',
    'truncated',
    'invalid',
    'cancelled',
    'failure',
  ]) {
    test('$scenario export falls back to original', () async {
      if (scenario == 'larger') await output.writeAsBytes(List.filled(120, 2));
      final service = CapVideoCompressor(
        inspect: (path) async => info(
          path,
          duration: path == output.path && scenario == 'truncated'
              ? 5000
              : 10000,
          width: path == output.path && scenario == 'invalid' ? 0 : 1920,
        ),
        compress: (_, quality) async {
          if (scenario == 'failure') {
            throw const FormatException('Native failure');
          }
          return info(output.path)..isCancel = scenario == 'cancelled';
        },
      );
      final result = await service.prepare(original, maxBytes: 100);
      expect(result.bytes, List.filled(100, 1));
      expect(result.extension, 'mov');
      expect(await original.exists(), true);
    });
  }
  test(
    'small source uses highest quality and oversize original is rejected on failure',
    () async {
      final service = CapVideoCompressor(
        inspect: (path) async => info(path, width: 640, height: 480),
        compress: (_, quality) async {
          expect(quality, VideoQuality.HighestQuality);
          return null;
        },
      );
      await expectLater(
        service.prepare(original, maxBytes: 50),
        throwsFormatException,
      );
      expect(await original.exists(), true);
    },
  );
}
