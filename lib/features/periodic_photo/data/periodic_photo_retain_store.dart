import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../forms/data/models/cap_form_models.dart';

/// A photo that was captured and accepted locally but not yet confirmed by CAP.
class RetainedPeriodicPhoto {
  const RetainedPeriodicPhoto({
    required this.evidence,
    required this.incidentId,
    required this.capturedAt,
    required this.userId,
  });

  final CapFormEvidence evidence;

  /// The incident context captured at capture time, so a retry cannot pick up
  /// an unrelated incident the user navigated to afterwards.
  final int incidentId;
  final DateTime capturedAt;

  /// The CAP user who took the photo. Retention survives a restart but is only
  /// restored for this same user, so a photo can never be uploaded under a
  /// different identity.
  final int userId;
}

/// Persists a captured-but-unsubmitted periodic photo.
///
/// A network/API failure must never make the user take the same photo again, so
/// the captured bytes survive both a failed submission and an app restart:
///
/// ```text
/// <applicationSupportDirectory>/cap_photo/pending_photo.json   (metadata)
/// <applicationSupportDirectory>/cap_photo/pending_photo.<ext>  (raw bytes)
/// ```
///
/// The raw bytes are stored as-is (not base64): this is local storage, not the
/// API contract, and keeping the original encoded file means the resubmitted
/// bytes are byte-for-byte the same photo.
class PeriodicPhotoRetainStore {
  PeriodicPhotoRetainStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<void> _writes = Future.value();

  static const _directoryName = 'cap_photo';
  static const _metaName = 'pending_photo.json';
  static const _bytesName = 'pending_photo';

  Future<Directory> _dir() async {
    final base = await _directory();
    return Directory('${base.path}/$_directoryName');
  }

  Future<void> write(RetainedPeriodicPhoto photo) {
    final next = _writes.then((_) => _write(photo));
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write(RetainedPeriodicPhoto photo) async {
    final dir = await _dir();
    await dir.create(recursive: true);
    final extension = photo.evidence.extension;
    final bytesFile = File('${dir.path}/$_bytesName.$extension');
    final metaFile = File('${dir.path}/$_metaName');
    // Bytes first, metadata last: the metadata file is the commit point, so a
    // crash mid-write can only leave orphan bytes, never a reference to a
    // different (older) photo.
    await bytesFile.writeAsBytes(photo.evidence.bytes, flush: true);
    // Remove any stale sibling written with a different extension so a later
    // read can never resurrect an older, different photo.
    for (final other in const ['jpg', 'jpeg', 'png', 'heic', 'webp']) {
      if (other == extension) continue;
      final stale = File('${dir.path}/$_bytesName.$other');
      if (await stale.exists()) await stale.delete();
    }
    await metaFile.writeAsString(
      jsonEncode({
        'fileName': photo.evidence.name,
        'extension': extension,
        'incidentId': photo.incidentId,
        'capturedAt': photo.capturedAt.toIso8601String(),
        'userId': photo.userId,
      }),
      flush: true,
    );
  }

  Future<RetainedPeriodicPhoto?> read() async {
    try {
      final dir = await _dir();
      final metaFile = File('${dir.path}/$_metaName');
      if (!await metaFile.exists()) return null;
      final decoded = jsonDecode(await metaFile.readAsString());
      if (decoded is! Map) return null;
      final meta = Map<String, dynamic>.from(decoded);
      final extension = '${meta['extension'] ?? ''}'.trim();
      if (extension.isEmpty) return null;
      final bytesFile = File('${dir.path}/$_bytesName.$extension');
      if (!await bytesFile.exists()) return null;
      final bytes = await bytesFile.readAsBytes();
      if (bytes.isEmpty) return null;
      final capturedAt = DateTime.tryParse('${meta['capturedAt']}');
      return RetainedPeriodicPhoto(
        evidence: CapFormEvidence(
          name: '${meta['fileName'] ?? 'photo.$extension'}',
          mimeType: _mimeFor(extension),
          bytes: bytes,
        ),
        incidentId: meta['incidentId'] is int
            ? meta['incidentId'] as int
            : 0,
        capturedAt: capturedAt ?? DateTime.now(),
        userId: meta['userId'] is int ? meta['userId'] as int : 0,
      );
    } on Exception {
      // A damaged retention file must not block the gate: fall back to asking
      // for a photo rather than crashing.
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _dir();
      final metaFile = File('${dir.path}/$_metaName');
      if (await metaFile.exists()) await metaFile.delete();
      if (await dir.exists()) {
        await for (final entry in dir.list()) {
          if (entry is File && entry.path.contains(_bytesName)) {
            await entry.delete();
          }
        }
      }
    } on Exception {
      // Best effort: a leftover file is overwritten by the next capture.
    }
  }

  static String _mimeFor(String extension) => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'heic' => 'image/heic',
    'webp' => 'image/webp',
    _ => 'image/$extension',
  };
}
