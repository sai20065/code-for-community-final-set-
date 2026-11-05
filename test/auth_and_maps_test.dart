import 'package:flutter_test/flutter_test.dart';
import 'package:praja_dhvani/core/services/auth_service.dart';
import 'package:praja_dhvani/shared/widgets/google_maps_directions_button.dart';

void main() {
  group('username rules', () {
    test('accepts letters, digits, _ and .', () {
      expect(AuthService.validateUsername('ravi_k.2024'), isNull);
    });

    test('is case-insensitive and trims spaces', () {
      expect(AuthService.normalizeUsername('  Ravi_K '), 'ravi_k');
      expect(AuthService.validateUsername('  Ravi_K '), isNull);
    });

    test('rejects too short / too long', () {
      expect(AuthService.validateUsername('abc'), UsernameProblem.tooShort);
      expect(AuthService.validateUsername('a' * 21), UsernameProblem.tooLong);
    });

    test('rejects spaces, @ and other symbols', () {
      expect(AuthService.validateUsername('ravi kumar'),
          UsernameProblem.badCharacters);
      expect(AuthService.validateUsername('ravi@home'),
          UsernameProblem.badCharacters);
    });

    test('maps to the synthetic citizen address', () {
      expect(AuthService.citizenEmailFor('Ravi_K'),
          'ravi_k@citizen.prajadhwani.app');
    });
  });

  group('Google Maps directions link', () {
    test('goes to the destination and lets Maps use current location', () {
      final uri = googleMapsDirectionsUri(12.9352, 77.6245);
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '12.935200,77.624500');
      // No origin: Google Maps then starts from the device's location.
      expect(uri.queryParameters.containsKey('origin'), isFalse);
    });
  });
}
