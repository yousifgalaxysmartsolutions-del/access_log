import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'U1: unawaited close after cancel, then pump',
    (tester) async {
      final c = StreamController<int>.broadcast();
      final s = c.stream.listen((_) {});
      await s.cancel();
      print('U1: canceled');
      c.close(); // deliberately not awaited
      print('U1: close issued');
      await tester.pump(const Duration(milliseconds: 5));
      print('U1: pumped ok');
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  testWidgets(
    'U2: close with live listener, then pump (no cancel)',
    (tester) async {
      final c = StreamController<int>.broadcast();
      c.stream.listen((_) {});
      final f = c.close();
      var done = false;
      unawaited(f.then((_) => done = true));
      await tester.pump(const Duration(milliseconds: 5));
      print('U2: pumped done=$done');
      await tester.pump(const Duration(milliseconds: 5));
      print('U2: pumped 2 done=$done');
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  testWidgets(
    'U3: never-listened close after cancel — does done complete with pump?',
    (tester) async {
      final c = StreamController<int>.broadcast();
      final s = c.stream.listen((_) {});
      await s.cancel();
      final f = c.close();
      var done = false;
      unawaited(f.then((_) => done = true));
      print('U3: issued');
      await tester.idle();
      print('U3: idle done=$done');
      await tester.pump();
      print('U3: pumped done=$done');
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );
}
