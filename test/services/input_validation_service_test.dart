import 'package:flutter_test/flutter_test.dart';
import 'package:patara_ai/services/input_validation_service.dart';

void main() {
  group('InputValidationService.isValidName', () {
    test('accepts names with Unicode letters and common separators', () {
      expect(InputValidationService.isValidName('Ayu Putri'), isTrue);
      expect(InputValidationService.isValidName("D'Angelo"), isTrue);
      expect(InputValidationService.isValidName('Siti-Nur'), isTrue);
      // Singkatan nama dengan titik lalu spasi umum dipakai.
      expect(InputValidationService.isValidName('M. Rizky'), isTrue);
      expect(InputValidationService.isValidName('Dr. Budi Santoso'), isTrue);
      expect(InputValidationService.isValidName('Élodie'), isTrue);
    });

    test('rejects digits, symbols, and names outside length limits', () {
      expect(InputValidationService.isValidName('123'), isFalse);
      expect(InputValidationService.isValidName('Ayu123'), isFalse);
      expect(InputValidationService.isValidName('@@@'), isFalse);
      expect(InputValidationService.isValidName('Ayu 2'), isFalse);
      expect(InputValidationService.isValidName('Ayu..Putri'), isFalse);
      expect(InputValidationService.isValidName('<b>Ayu</b>'), isFalse);
      expect(InputValidationService.isValidName('A'), isFalse);
      expect(InputValidationService.isValidName('A' * 81), isFalse);
    });
  });

  group('InputValidationService.isValidNumber', () {
    test('accepts finite decimal values in range', () {
      expect(
        InputValidationService.isValidNumber('12,5', minimum: 0, maximum: 20),
        isTrue,
      );
    });

    test('rejects mixed text, malformed decimals, and out-of-range values', () {
      expect(
        InputValidationService.isValidNumber('12kg', minimum: 0, maximum: 20),
        isFalse,
      );
      expect(
        InputValidationService.isValidNumber('1.2.3', minimum: 0, maximum: 20),
        isFalse,
      );
      expect(
        InputValidationService.isValidNumber('21', minimum: 0, maximum: 20),
        isFalse,
      );
    });
  });

  test('validates phone numbers by digit count and allowed characters', () {
    expect(InputValidationService.isValidPhone('+62 812-3456-7890'), isTrue);
    expect(InputValidationService.isValidPhone('12345'), isFalse);
    expect(InputValidationService.isValidPhone('0812ABCD'), isFalse);
  });
}
