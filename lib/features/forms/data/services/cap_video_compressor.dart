import 'dart:io';
import 'package:video_compress/video_compress.dart';
import '../models/cap_form_models.dart';

typedef CompressCapVideo =
    Future<MediaInfo?> Function(String path, VideoQuality quality);

/// Native transcoding only: never truncate or rewrite encoded video bytes.
class CapVideoCompressor {
  CapVideoCompressor({
    Future<MediaInfo> Function(String)? inspect,
    CompressCapVideo? compress,
  }) : inspect = inspect ?? VideoCompress.getMediaInfo,
       compress = compress ?? _compress;

  final Future<MediaInfo> Function(String) inspect;
  final CompressCapVideo compress;

  static Future<MediaInfo?> _compress(String path, VideoQuality quality) =>
      VideoCompress.compressVideo(
        path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );

  static bool _valid(MediaInfo info) =>
      (info.width ?? 0) > 0 &&
      (info.height ?? 0) > 0 &&
      (info.duration ?? 0).isFinite &&
      (info.duration ?? 0) > 0;

  Future<CapFormEvidence> prepare(
    File original, {
    required int maxBytes,
  }) async {
    final originalSize = await original.length();
    File selected = original;
    File? output;
    try {
      try {
        final source = await inspect(original.path);
        if (_valid(source)) {
          // Avoid requesting a resolution larger than a small source.
          final longSide = source.width! > source.height!
              ? source.width!
              : source.height!;
          final shortSide = source.width! < source.height!
              ? source.width!
              : source.height!;
          final quality = longSide >= 1280 && shortSide >= 720
              ? VideoQuality.Res1280x720Quality
              : VideoQuality.HighestQuality;
          final result = await compress(original.path, quality);
          final candidate = result?.file;
          if (candidate != null &&
              candidate.absolute.path != original.absolute.path &&
              await candidate.exists() &&
              await candidate.resolveSymbolicLinks() !=
                  await original.resolveSymbolicLinks()) {
            output = candidate;
            if (result?.isCancel != true) {
              final size = await candidate.length();
              if (size > 0 && size < originalSize) {
                final info = await inspect(candidate.path);
                // Reject incomplete exports or unexpectedly truncated clips.
                if (_valid(info) &&
                    (info.duration! - source.duration!).abs() <= 250 &&
                    info.width! <= longSide &&
                    info.height! <= longSide) {
                  selected = candidate;
                }
              }
            }
          }
        }
      } on Exception {
        // Native failure: retain the untouched original if within the upload limit.
        selected = original;
      }
      final size = await selected.length();
      if (size == 0 || size > maxBytes) {
        throw const FormatException(
          'Video exceeds 16 MB or is empty after compression',
        );
      }
      return CapFormEvidence(
        name: selected.uri.pathSegments.last,
        mimeType: selected.path.toLowerCase().endsWith('.mov')
            ? 'video/quicktime'
            : 'video/mp4',
        bytes: await selected.readAsBytes(),
      );
    } finally {
      // Only this operation's exported file; never clear the plugin's global cache.
      if (output != null) {
        try {
          await output.delete();
        } on FileSystemException {
          /* Cache cleanup is best effort. */
        }
      }
    }
  }
}
