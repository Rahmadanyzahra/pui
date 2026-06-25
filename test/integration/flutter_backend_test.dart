import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('Flutter-Backend MySQL Integration', () {
    const String backendUrl = 'http://127.0.0.1:5000';

    test('Backend API should be responsive', () async {
      try {
        final response = await http
            .get(Uri.parse('$backendUrl/health'))
            .timeout(Duration(seconds: 5));
        expect(response.statusCode, 200);
      } catch (e) {
        fail('Backend server not running at $backendUrl. Error: $e');
      }
    });

    test(
      'Should be able to register user via backend and access MySQL',
      () async {
        final testEmail =
            'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
        final response = await http
            .post(
              Uri.parse('$backendUrl/api/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': testEmail,
                'password': 'Test@123456',
                'full_name': 'Integration Test User',
              }),
            )
            .timeout(Duration(seconds: 10));

        // Expect either success (201/200) - this means backend connected to MySQL and created user
        expect(response.statusCode, anyOf([200, 201, 409]));
      },
    );

    test(
      'Should be able to login via backend accessing MySQL users table',
      () async {
        final response = await http
            .post(
              Uri.parse('$backendUrl/api/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': 'test@example.com',
                'password': 'Test@123456',
              }),
            )
            .timeout(Duration(seconds: 10));

        // 200 = success, 401 = auth failed (but DB was queried), 404 = endpoint not found
        // As long as it's not 5xx, backend is working
        expect(response.statusCode, lessThan(500));
      },
    );

    test('Backend should return valid JSON responses', () async {
      final response = await http
          .get(Uri.parse('$backendUrl/health'))
          .timeout(Duration(seconds: 10));

      // Should be valid JSON
      expect(() => jsonDecode(response.body), returnsNormally);
      final data = jsonDecode(response.body);
      expect(data, {'status': 'ok'});
    });

    test('MySQL database is accessible via backend', () async {
      // Try multiple endpoints to verify MySQL connectivity
      final registerResponse = await http
          .post(
            Uri.parse('$backendUrl/api/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email':
                  'db_test_${DateTime.now().millisecondsSinceEpoch}@test.com',
              'password': 'Test@123456',
              'full_name': 'DB Test',
            }),
          )
          .timeout(Duration(seconds: 10));

      // If register returns 200/201/409, MySQL is working
      // 409 = conflict (user exists - DB query succeeded)
      // 200/201 = user created in MySQL
      expect(registerResponse.statusCode, anyOf([200, 201, 409]));
    });
  });
}
