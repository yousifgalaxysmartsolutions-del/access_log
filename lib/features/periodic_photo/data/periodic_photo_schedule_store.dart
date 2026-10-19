import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/periodic_photo_schedule.dart';

/// Durable storage for the periodic-photo timing state.
///
/// Path contract:
///
/// ```text
/// <applicationSupportDirectory>/cap_photo/schedule.json
/// ```
///
/// Only Dart writes this file, but a partial write must still never lose the
/// deadline, so [write] goes through a sibling temp file followed by an atomic
/// [File.rename]. A missing or malformed file simply means "not scheduled yet"
/// and never throws.
class PeriodicPhotoScheduleStore {
  PeriodicPhotoScheduleStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<void> _writes = Future.value();

  static const _directoryName = 'cap_photo';
  static const _fileName = 'schedule.json';

  Future<File> _file() async {
    final base = await _directory();
    return File('${base.path}/$_directoryName/$_fileName');
  }

  Future<PeriodicPhotoSchedule?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is! Map) return null;
      return PeriodicPhotoSchedule.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on Exception {
      // Unreadable state must never block the app or the requirement: treat it
      // as "not scheduled yet" rather than crashing or inventing a deadline.
      return null;
    }
  }

  /// Serializes writes so two rapid updates can never interleave.
  Future<void> write(PeriodicPhotoSchedule schedule) {
    final next = _writes.then((_) => _write(schedule));
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write(PeriodicPhotoSchedule schedule) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(schedule.toJson()), flush: true);
    await temp.rename(file.path);
  }
}
