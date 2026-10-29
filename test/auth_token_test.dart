import 'package:flutter_test/flutter_test.dart';
import 'package:pushtrial/api/auth_token.dart';

void main() {
  group('which requests carry the sign-in token', () {
    test('v2 endpoints that need a signed-in student do', () {
      for (final endpoint in [
        'alerts',
        'messages',
        'grading_setup',
        'api_studledger',
        'api_enrolledstud',
        'api_uploadrequirement',
      ]) {
        expect(
          AuthToken.needsToken(Uri.parse('https://school.example/api/mobile/v2/$endpoint?studid=1')),
          isTrue,
          reason: endpoint,
        );
      }
    });

    test('the v2 endpoints that work before signing in do not', () {
      for (final endpoint in ['ping', 'login', 'schoolinfo']) {
        expect(
          AuthToken.needsToken(Uri.parse('https://school.example/api/mobile/v2/$endpoint')),
          isFalse,
          reason: endpoint,
        );
      }
    });

    test('v1 addresses never do, so an old server sees exactly what it always saw', () {
      expect(AuthToken.needsToken(Uri.parse('https://school.example/api/mobile/api_studledger?studid=1')), isFalse);
      expect(AuthToken.needsToken(Uri.parse('https://school.example/api/mobile/api_login?x=1')), isFalse);
    });

    test('a school installed in a sub-folder is handled', () {
      expect(AuthToken.needsToken(Uri.parse('https://host.example/school/api/mobile/v2/alerts')), isTrue);
    });

    test('no token held means no headers', () {
      expect(AuthToken.headersFor(Uri.parse('https://school.example/api/mobile/v2/alerts')), isEmpty);
    });
  });
}
