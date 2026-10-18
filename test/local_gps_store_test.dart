import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/features/gps_tracking/data/local/local_gps_store.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_location_record.dart';

void main() {
  late Directory base;
  late LocalGpsStore store;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('cap_gps_store_test');
    store = LocalGpsStore(baseDirectory: () async => base);
  });

  tearDown(() async {
    if (await base.exists()) await base.delete(recursive: true);
  });

  GpsLocationRecord record({
    required bool isOffline,
    double latitude = 30.0972208,
    double longitude = 31.2163613,
  }) => GpsLocationRecord(
    localId: 'local-1',
    locationDateTime: DateTime(2025, 9, 9, 12, 38, 49, 512, 127),
    latitude: latitude,
    longitude: longitude,
    isOffline: isOffline,
    accuracyMeters: 5,
  );

  test('online point is persisted with isoffline=false', () async {
    await store.append(record(isOffline: false));

    final records = await store.readAll();

    expect(records, hasLength(1));
    expect(records.single.isOffline, isFalse);
    expect(records.single.latitude, closeTo(30.0972208, 1e-7));
    expect(records.single.longitude, closeTo(31.2163613, 1e-7));
    expect(records.single.incidentId, 0);
  });

  test('offline point is persisted with isoffline=true', () async {
    await store.append(record(isOffline: true));

    final records = await store.readAll();

    expect(records.single.isOffline, isTrue);
  });

  test('records survive store re-creation (durable across restarts)', () async {
    await store.append(record(isOffline: false));
    await store.append(record(isOffline: true, latitude: 30.5, longitude: 31.5));

    final recreated = LocalGpsStore(baseDirectory: () async => base);
    final records = await recreated.readAll();

    expect(records, hasLength(2));
    expect(records[0].isOffline, isFalse);
    expect(records[1].isOffline, isTrue);
  });

  test('a truncated trailing line does not corrupt earlier history', () async {
    await store.append(record(isOffline: false));
    await store.append(record(isOffline: true));

    final file = await store.resolveFile();
    // Simulate an interrupted write leaving a partial JSON line at the end.
    await file.writeAsString('{"IncidentId":0,"TaskLat', mode: FileMode.append);

    final records = await store.readAll();

    expect(records, hasLength(2));
  });

  test('serialized payload matches the CAP contract keys', () {
    final json = record(isOffline: true).toJson();

    expect(json['IncidentId'], 0);
    expect(json['TaskLatitude'], '30.0972208');
    expect(json['TaskLongitude'], '31.2163613');
    expect(json['isoffline'], isTrue);
    expect(json['LocationDateTime'], '2025-09-09T12:38:49.512127');
  });

  test('malformed JSON lines are skipped without throwing', () async {
    final file = await store.resolveFile();
    await file.writeAsString('not json\n', mode: FileMode.append);
    await store.append(record(isOffline: false));

    final records = await store.readAll();

    expect(records, hasLength(1));
  });

  test('file is JSON Lines under cap_gps/locations.jsonl', () async {
    final file = await store.resolveFile();

    expect(file.path, endsWith('cap_gps${Platform.pathSeparator}locations.jsonl'));
  });

  test('readAll returns an empty list when nothing was stored', () async {
    expect(await store.readAll(), isEmpty);
  });

  test('decode tolerates an unknown extra field', () {
    final decoded = GpsLocationRecord.fromJson(
      jsonDecode(
            '{"localId":"x","IncidentId":7,"LocationDateTime":"2025-09-09T12:38:49.512127",'
            '"TaskLatitude":"30.1","TaskLongitude":"31.2","isoffline":false,"future":"ignore"}',
          )
          as Map<String, dynamic>,
    );

    expect(decoded.incidentId, 7);
    expect(decoded.isOffline, isFalse);
  });

  group('removeByIds', () {
    GpsLocationRecord withId(String id, {bool isOffline = false}) =>
        GpsLocationRecord(
          localId: id,
          locationDateTime: DateTime(2025, 9, 9, 12, 38, 49, 512, 127),
          latitude: 30.0972208,
          longitude: 31.2163613,
          isOffline: isOffline,
        );

    test('removes only the given ids and keeps the rest valid', () async {
      await store.append(withId('A'));
      await store.append(withId('B'));
      await store.append(withId('C'));
      await store.append(withId('D'));
      await store.append(withId('E'));

      final removed = await store.removeByIds({'A', 'B', 'C'});

      expect(removed, 3);
      final records = await store.readAll();
      expect(records.map((r) => r.localId), ['D', 'E']);
      // The remaining file is still well-formed JSON Lines.
      final file = await store.resolveFile();
      final lines = const LineSplitter()
          .convert(await file.readAsString())
          .where((line) => line.trim().isNotEmpty);
      expect(lines, hasLength(2));
      for (final line in lines) {
        expect(jsonDecode(line), isA<Map>());
      }
    });

    test('removing an unknown id changes nothing', () async {
      await store.append(withId('A'));
      await store.append(withId('B'));

      expect(await store.removeByIds({'missing'}), 0);
      expect((await store.readAll()).map((r) => r.localId), ['A', 'B']);
    });

    test('an empty id set is a no-op', () async {
      await store.append(withId('A'));

      expect(await store.removeByIds(const {}), 0);
      expect(await store.count(), 1);
    });

    test('removal survives re-creation of the store', () async {
      await store.append(withId('A'));
      await store.append(withId('B'));
      await store.removeByIds({'A'});

      final recreated = LocalGpsStore(baseDirectory: () async => base);
      expect((await recreated.readAll()).map((r) => r.localId), ['B']);
    });

    test('a trailing partial line is preserved, not truncated', () async {
      await store.append(withId('A'));
      await store.append(withId('B'));

      final file = await store.resolveFile();
      await file.writeAsString('{"IncidentId":0,"TaskLat', mode: FileMode.append);

      await store.removeByIds({'A'});

      // B still decodes; the partial tail is skipped by the reader and keeps
      // its bytes (it may be a native append in progress).
      final records = await store.readAll();
      expect(records.map((r) => r.localId), ['B']);
      expect(await file.readAsString(), contains('{"IncidentId":0,"TaskLat'));
    });

    test('concurrent appends and removal never lose a record', () async {
      final ids = List.generate(40, (index) => 'id-$index');
      for (final id in ids.take(20)) {
        await store.append(withId(id));
      }

      // Interleave appends of the remaining ids with a removal of the first
      // half. The store serializes Dart-side operations, so nothing is dropped.
      final futures = <Future<void>>[
        for (final id in ids.skip(20)) store.append(withId(id)),
        store.removeByIds(ids.take(10).toSet()),
      ];
      await Future.wait(futures);

      final remaining = (await store.readAll()).map((r) => r.localId).toSet();
      expect(remaining, ids.skip(10).toSet());
      expect(remaining, isNot(contains(ids.first)));
      expect(remaining, contains(ids.last));
    });
  });
}
