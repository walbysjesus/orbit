import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService.testCurrentUser = null;
  });

  group('AuthService', () {
    test('isLoggedIn retorna false si no hay usuario', () async {
      expect(await AuthService.isLoggedIn(), false);
    });

    test('getCurrentUser retorna null si no hay usuario', () {
      expect(AuthService.getCurrentUser(), null);
    });
  });
}
