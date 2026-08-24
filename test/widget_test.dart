import 'package:access_log_plus/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Arabic Access Log+ login in light mode', (tester) async {
    await tester.pumpWidget(const AccessLogApp());
    expect(find.text('Access Log+'), findsOneWidget);
    expect(find.text('مرحباً بعودتك'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
