import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/context/active_incident_context.dart';

/// `ActiveIncidentContext` is the single source for "which incident is the user
/// inside right now". The periodic-photo requirement reads `uploadIncidentId`
/// from it, so these semantics guard against stale IncidentIds leaking into an
/// upload (stack order, out-of-order disposal, sign-out clearing).
void main() {
  late ActiveIncidentContext context;

  setUp(() => context = ActiveIncidentContext());

  tearDown(() => context.dispose());

  test('starts with no incident → uploadIncidentId 0', () {
    expect(context.activeIncidentId, isNull);
    expect(context.uploadIncidentId, 0);
  });

  test('enter publishes the id, leave returns to 0', () {
    context.enter(26);

    expect(context.activeIncidentId, 26);
    expect(context.uploadIncidentId, 26);

    context.leave(26);

    expect(context.activeIncidentId, isNull);
    expect(context.uploadIncidentId, 0);
  });

  test('nested incident screens resolve to the innermost, leave walks back',
      () {
    context.enter(26);
    context.enter(30);

    expect(context.uploadIncidentId, 30);

    context.leave(30);
    expect(context.uploadIncidentId, 26);

    context.leave(26);
    expect(context.uploadIncidentId, 0);
  });

  test('an older screen disposing cannot clear a newer incident', () {
    context.enter(26);
    context.enter(30);

    // Screen 26's dispose runs late (route popped out of order).
    context.leave(26);

    // The stale 26 entry is dropped from the middle while 30 stays active —
    // disposing an older screen never clears a newer incident, and 26 can
    // never come back afterwards.
    expect(context.uploadIncidentId, 30);

    context.leave(30);
    expect(context.uploadIncidentId, 0);
  });

  test('duplicate leave is harmless', () {
    context.enter(26);
    context.leave(26);
    context.leave(26);

    expect(context.uploadIncidentId, 0);
  });

  test('invalid ids are ignored', () {
    context.enter(0);
    context.enter(-5);
    expect(context.uploadIncidentId, 0);

    context.enter(26);
    expect(context.uploadIncidentId, 26);
  });

  test('clear (sign-out) drops the whole stack', () {
    context.enter(26);
    context.enter(30);

    context.clear();

    expect(context.activeIncidentId, isNull);
    expect(context.uploadIncidentId, 0);
  });

  test('changes notify listeners on enter, leave and clear', () async {
    final events = <int?>[];
    final sub = context.changes.listen(events.add);

    context.enter(26);
    await Future<void>.delayed(Duration.zero);
    context.leave(26);
    await Future<void>.delayed(Duration.zero);
    context.enter(40);
    context.clear();
    await Future<void>.delayed(Duration.zero);

    expect(events, [26, null, 40, null]);

    await sub.cancel();
  });
}
