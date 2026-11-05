import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patara_ai/features/change_password_screen.dart';
import 'package:patara_ai/features/forgot_password_screen.dart';
import 'package:patara_ai/services/backend_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final requests = <http.Request>[];

  setUp(() {
    requests.clear();
    BackendApiService.resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    switch (request.url.path) {
      case '/auth/forgot-password':
        return http.Response(
          jsonEncode({'message': 'Bila email itu terdaftar, password sementara sudah dikirim ke email tersebut.', 'email_sent': true}),
          200,
        );
      case '/api/login':
        return http.Response(
          jsonEncode({'message': 'ok', 'access_token': 'a', 'refresh_token': 'r', 'must_change_password': true}),
          200,
        );
      case '/api/account/password':
        return http.Response('{"success":true}', 200);
    }
    return http.Response('{"error":"Unauthorized"}', 401);
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  Map<String, dynamic> bodyOf(String path) =>
      jsonDecode(requests.lastWhere((request) => request.url.path == path).body) as Map<String, dynamic>;

  testWidgets('forgot password sends a temporary password in one step', (tester) async {
    await http.runWithClient(() async {
      await pump(tester, const ForgotPasswordScreen(initialEmail: 'ibu@contoh.id'));
      expect(find.textContaining('Kode'), findsNothing);
      await tester.tap(find.text('Kirim password sementara'));
      await tester.pumpAndSettle();

      expect(bodyOf('/auth/forgot-password'), {'email': 'ibu@contoh.id'});
      expect(find.text('Periksa email Anda'), findsOneWidget);
      expect(find.textContaining('password sementara dari email'), findsOneWidget);
      expect(find.text('Kembali ke halaman masuk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient(handle));
  });

  test('login with a temporary password asks for a new one and remembers it', () async {
    await http.runWithClient(() async {
      final mustChange = await BackendApiService.login(email: 'ibu@contoh.id', password: 'ABCD-EFGH');
      expect(mustChange, isTrue);
      expect(await BackendApiService.needsPasswordChange(), isTrue);

      await BackendApiService.changePassword(currentPassword: 'ABCD-EFGH', newPassword: 'PasswordBaru1');
      expect(bodyOf('/api/account/password'), {'current_password': 'ABCD-EFGH', 'new_password': 'PasswordBaru1'});
      expect(await BackendApiService.needsPasswordChange(), isFalse);
    }, () => MockClient(handle));
  });

  testWidgets('the new-password screen after a temporary login cannot be skipped', (tester) async {
    await http.runWithClient(() async {
      await pump(tester, const ChangePasswordScreen(mustChange: true, temporaryPassword: 'ABCD-EFGH'));
      expect(find.text('Buat password baru'), findsOneWidget);
      // Password sementara sudah diketahui, jadi tidak ditanya lagi; tidak ada tombol kembali.
      expect(find.text('Password sementara dari email'), findsNothing);
      expect(find.byTooltip('Kembali'), findsNothing);
      expect(find.text('Keluar dari akun'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Password baru'), 'PasswordBaru1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ulangi password baru'), 'PasswordBeda2');
      await tester.tap(find.text('Simpan password baru'));
      await tester.pump();
      expect(find.text('Password belum sama'), findsOneWidget);
      expect(requests.where((request) => request.url.path == '/api/account/password'), isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Ulangi password baru'), 'PasswordBaru1');
      await tester.tap(find.text('Simpan password baru'));
      await tester.pump();
      await tester.pump();
      expect(bodyOf('/api/account/password'), {'current_password': 'ABCD-EFGH', 'new_password': 'PasswordBaru1'});
    }, () => MockClient(handle));
  });

  testWidgets('changing the password from the account menu asks for the old one', (tester) async {
    await http.runWithClient(() async {
      await pump(tester, const ChangePasswordScreen());
      expect(find.text('Ganti password'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Password lama'), 'PasswordLama1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password baru'), 'PasswordBaru1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ulangi password baru'), 'PasswordBaru1');
      await tester.tap(find.text('Simpan password baru'));
      await tester.pumpAndSettle();
      expect(bodyOf('/api/account/password'), {'current_password': 'PasswordLama1', 'new_password': 'PasswordBaru1'});
      expect(tester.takeException(), isNull);
    }, () => MockClient(handle));
  });
}
