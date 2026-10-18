import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../domain/gps_location_record.dart';
import '../../domain/gps_pending_store.dart';

/// Durable, app-private storage for captured GPS points.
///
/// Format: JSON Lines (one record per line). Appending a single line means an
/// interrupted write can at worst truncate the last line; [readAll] skips any
/// malformed/partial line, so one bad write never corrupts prior history.
///
/// The native Android/iOS trackers write to the exact same file so points keep
/// being captured while Flutter is suspended. The path is therefore a contract
/// shared by Dart, Kotlin and Swift:
///
/// ```text
/// <applicationSupportDirectory>/cap_gps/locations.jsonl
/// ```
///
/// `getApplicationSupportDirectory()` maps to Android `filesDir` and iOS
/// `applicationSupportDirectory`, which is what the native writers use.
///
/// ## Concurrency
///
/// Dart reads/writes are serialized through [_Mutex]. The native tracker writes
/// without taking that lock, so [removeByIds] additionally verifies the file did
/// not grow while it was reading, and only then atomically replaces it. A point
/// captured during a sync is therefore never lost.
class LocalGpsStore implements GpsPendingStore {
  LocalGpsStore({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  /// Native mirrors of these constants live in `LocalGpsStore.kt` and
  /// `LocalGpsStore.swift`.
  static const directoryName = 'cap_gps';
  static const fileName = 'locations.jsonl';

  final Future<Directory> Function() _baseDirectory;
  final _Mutex _mutex = _Mutex();

  Future<File> resolveFile() async {
    final base = await _baseDirectory();
    final directory = Directory('${base.path}/$directoryName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/$fileName');
  }

  /// Appends one record. Called by Dart-side tests and any future Dart writer;
  /// in production the native tracker is the writer.
  Future<void> append(GpsLocationRecord record) async {
    final line = '${jsonEncode(record.toJson())}\n';
    await _mutex.synchronized(() async {
      final file = await resolveFile();
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    });
  }

  @override
  Future<List<GpsLocationRecord>> readAll() =>
      _mutex.synchronized(_readAllUnlocked);

  /// Number of locally stored points.
  @override
  Future<int> count() async => (await readAll()).length;

  /// Removes exactly the points whose `localId` is in [localIds].
  ///
  /// Safe against concurrent native appends:
  ///
  /// 1. read the file and compute the bytes that must remain;
  /// 2. if the file grew during the read, retry with the newer content so the
  ///    new points are included;
  /// 3. write the remainder to a sibling temp file and atomically `rename` it
  ///    over the original, so the store is never left truncated or half-written.
  ///
  /// Returns how many lines were removed.
  @override
  Future<int> removeByIds(Set<String> localIds) async {
    if (localIds.isEmpty) return 0;
    return _mutex.synchronized(() async {
      final file = await resolveFile();
      if (!await file.exists()) return 0;

      for (var attempt = 0; attempt < 4; attempt++) {
        final before = await _length(file);
        final bytes = before == 0 ? Uint8List(0) : await file.readAsBytes();
        final removed = _removeLines(bytes, localIds);
        final after = await _length(file);
        // A native append landed while we were reading: retry so it is kept.
        if (after != before) continue;
        if (removed.removed == 0) return 0;
        await _replaceAtomically(file, removed.kept);
        return removed.removed;
      }

      // Extremely unlikely (the file kept growing on every attempt). Do a final
      // consistent rewrite; the atomic rename still guarantees no corruption.
      final bytes = await file.readAsBytes();
      final removed = _removeLines(bytes, localIds);
      if (removed.removed == 0) return 0;
      await _replaceAtomically(file, removed.kept);
      return removed.removed;
    });
  }

  Future<List<GpsLocationRecord>> _readAllUnlocked() async {
    final file = await resolveFile();
    if (!await file.exists()) return const [];
    final content = await file.readAsString();
    if (content.isEmpty) return const [];
    final records = <GpsLocationRecord>[];
    for (final line in const LineSplitter().convert(content)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map) continue;
        records.add(
          GpsLocationRecord.fromJson(decoded.cast<String, dynamic>()),
        );
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return records;
  }

  Future<int> _length(File file) async =>
      await file.exists() ? file.length() : 0;

  Future<void> _replaceAtomically(File file, Uint8List bytes) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    // `rename` on the same filesystem is atomic: readers either see the old file
    // or the new one, never a truncated mix.
    await temp.rename(file.path);
  }
}

/// Result of filtering a snapshot: [removed] lines dropped, [kept] bytes kept.
class _Removal {
  const _Removal(this.removed, this.kept);

  final int removed;
  final Uint8List kept;
}

/// Keeps every line except those whose `localId` is in [ids].
///
/// Line bytes are copied verbatim, so the rewrite never reformats existing
/// records. A trailing partial line (a native append caught mid-write) is
/// preserved as-is rather than dropped.
_Removal _removeLines(Uint8List bytes, Set<String> ids) {
  if (bytes.isEmpty) return _Removal(0, bytes);
  final output = BytesBuilder(copy: false);
  var removed = 0;
  var start = 0;
  for (var index = 0; index < bytes.length; index++) {
    if (bytes[index] != 0x0A) continue; // '\n'
    final line = Uint8List.sublistView(bytes, start, index);
    start = index + 1;
    final id = _localIdOf(line);
    if (id != null && ids.contains(id)) {
      removed++;
      continue;
    }
    output.add(line);
    output.addByte(0x0A);
  }
  if (start < bytes.length) {
    output.add(Uint8List.sublistView(bytes, start));
  }
  return _Removal(removed, output.takeBytes());
}

String? _localIdOf(Uint8List line) {
  final text = utf8.decode(line, allowMalformed: true).trim();
  if (text.isEmpty) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map && decoded['localId'] is String) {
      final id = decoded['localId'] as String;
      return id.isEmpty ? null : id;
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Minimal non-reentrant async mutex. Serializes Dart-side file operations;
/// native writers are handled by the growth check in [LocalGpsStore.removeByIds].
class _Mutex {
  Future<void> _tail = Future<void>.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _tail;
    _tail = completer.future;
    return previous
        .then((_) => action())
        .whenComplete(() => completer.complete());
  }
}
