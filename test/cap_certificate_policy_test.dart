import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/network/dio_client.dart';

void main() {
  test(
    'temporary certificate exception is restricted to CAP host and port',
    () {
      expect(
        DioClient.acceptsInvalidCertificate('test.talentlink360.com', 443),
        DioClient.allowCapInvalidCertificate,
      );
      expect(DioClient.acceptsInvalidCertificate('api.groq.com', 443), false);
      expect(
        DioClient.acceptsInvalidCertificate(
          'test.talentlink360.com.attacker.test',
          443,
        ),
        false,
      );
      expect(
        DioClient.acceptsInvalidCertificate('test.talentlink360.com', 8765),
        false,
      );
    },
  );
}
