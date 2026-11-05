import 'package:flutter_test/flutter_test.dart';
import 'package:patara_ai/utils/child_age.dart';

void main() {
  group('ChildAge in Asia/Jakarta', () {
    test('classifies the first birthday as toddler', () {
      final age = ChildAge.calculate(
        DateTime(2025, 10, 7),
        now: DateTime.utc(2026, 10, 6, 17),
      );

      expect(age?.formatted, '1 tahun 0 bulan 0 hari');
      expect(age?.category, 'toddler');
    });

    test('classifies the fifth birthday as balita', () {
      final age = ChildAge.calculate(
        DateTime(2021, 10, 7),
        now: DateTime.utc(2026, 10, 6, 17),
      );

      expect(age?.category, 'balita');
    });

    test('moves outside range the day after the fifth birthday', () {
      final age = ChildAge.calculate(
        DateTime(2021, 10, 7),
        now: DateTime.utc(2026, 10, 7, 17),
      );

      expect(age?.category, 'di_luar_rentang');
    });

    test('rejects future birth dates', () {
      expect(
        ChildAge.calculate(
          DateTime(2026, 10, 9),
          now: DateTime.utc(2026, 10, 7, 17),
        ),
        isNull,
      );
    });

    test('formats completed years, months, and days', () {
      final age = ChildAge.calculate(
        DateTime(2025, 5, 30),
        now: DateTime.utc(2026, 8, 1, 17),
      );

      expect(age?.formatted, '1 tahun 2 bulan 3 hari');
    });
  });
}
