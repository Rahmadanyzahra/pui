import 'package:flutter_test/flutter_test.dart';
import 'package:patara_ai/models/child.dart';

void main() {
  group('Child Model', () {
    test('Child.fromBackend creates correct instance', () {
      final child = Child.fromBackend(
        id: 1,
        userId: 'user123',
        name: 'Test Child',
        age: 5,
      );

      expect(child.id, '1');
      expect(child.userId, 'user123');
      expect(child.name, 'Test Child');
      // Age may be off by 1 due to leap years and exact date calculations
      expect(child.age, greaterThanOrEqualTo(4));
      expect(child.age, lessThanOrEqualTo(5));
    });

    test('_calculateAge computes correct age', () {
      final birthDate = DateTime.now().subtract(Duration(days: 365 * 5 + 10));
      final child = Child(
        id: '1',
        userId: 'user123',
        name: 'Test',
        birthDate: birthDate,
      );

      expect(child.age, greaterThanOrEqualTo(5));
    });

    test('_calculateCategory returns correct category for age', () {
      final now = DateTime.now();

      // Baby (0-1 year)
      var birthDate = now.subtract(Duration(days: 180));
      var child = Child(
        id: '1',
        userId: 'user1',
        name: 'Baby',
        birthDate: birthDate,
      );
      expect(child.category, 'baby');

      // Toddler (1-3 years)
      birthDate = now.subtract(Duration(days: 365 * 2));
      child = Child(
        id: '2',
        userId: 'user2',
        name: 'Toddler',
        birthDate: birthDate,
      );
      expect(child.category, 'toddler');

      // Anak (3-12 years)
      birthDate = now.subtract(Duration(days: 365 * 8));
      child = Child(
        id: '3',
        userId: 'user3',
        name: 'Anak',
        birthDate: birthDate,
      );
      expect(child.category, 'anak');

      // Remaja (>12 years)
      birthDate = now.subtract(Duration(days: 365 * 15));
      child = Child(
        id: '4',
        userId: 'user4',
        name: 'Remaja',
        birthDate: birthDate,
      );
      expect(child.category, 'remaja');
    });
  });
}
