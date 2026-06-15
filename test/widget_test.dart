import 'package:flutter_test/flutter_test.dart';
import 'package:pearmo/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('phone requires E.164 format', () {
      expect(Validators.phone('+94771234567'), isNull);
      expect(Validators.phone('0771234567'), isNotNull);
      expect(Validators.phone(''), isNotNull);
    });

    test('otp requires 6 digits', () {
      expect(Validators.otp('123456'), isNull);
      expect(Validators.otp('12345'), isNotNull);
    });

    test('dateOfBirthAdult enforces 18+', () {
      final now = DateTime.now();
      final adult = DateTime(now.year - 20, now.month, now.day);
      final minor = DateTime(now.year - 10, now.month, now.day);
      expect(Validators.dateOfBirthAdult(adult), isNull);
      expect(Validators.dateOfBirthAdult(minor), isNotNull);
    });
  });
}
