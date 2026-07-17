import 'package:flutter_test/flutter_test.dart';
import 'package:syno_app/presentation/utils/error_localization.dart';

void main() {
  group('normalizeErrorMessage', () {
    test('strips Exception prefixes from backend translation keys', () {
      expect(normalizeErrorMessage('Exception: otp.invalid_phone_format'), 'otp.invalid_phone_format');
    });

    test('leaves ordinary user-facing messages unchanged', () {
      expect(normalizeErrorMessage('This email is already registered.'), 'This email is already registered.');
    });
  });
}
