import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// One atomic, user/day-scoped cache. Never contains photo bytes or tokens.
class TodayInProcessStore {
  TodayInProcessStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;
  Future<void> _writes = Future.value();
  Future<File> _file() async =>
      File('${(await _directory()).path}/cap_photo/in_process_today.json');

  Future<Map<String, dynamic>?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return Map<String, dynamic>.from(
        jsonDecode(await file.readAsString()) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> value) {
    final next = _writes.then((_) async {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(value), flush: true);
      await temp.rename(file.path);
    });
    _writes = next.catchError((Object _) {});
    return next;
  }
}
