// Uji alur utama TARA di aplikasi sungguhan (emulator atau HP), terhadap SERVER UJI:
//   Delegasi login -> mencatat Makan dengan foto bukti dan Bermain tanpa foto -> keluar ->
//   Orang Tua login -> membuka Validasi -> melihat foto bukti -> menyatakan satu laporan sesuai
//   dan satu tidak sesuai.
// Hasilnya diperiksa ulang langsung ke server.
//
// Pakai (server uji harus hidup: `npm run test:server` di backend/node_backend):
//   flutter test integration_test/alur_utama_test.dart -d emulator-5554
//   flutter test integration_test --dart-define=TARA_TEST_SERVER=http://192.168.1.10:5055 -d <id HP>
//
// Akun uji dibuat lewat API di awal dan dihapus di akhir. Pengaturan aplikasi di perangkat (alamat
// server, sesi login) disimpan dulu lalu dikembalikan, jadi aplikasi kembali seperti semula.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patara_ai/main.dart' as app;
import 'package:patara_ai/patara/patara_api.dart';
import 'package:patara_ai/patara/patara_ui.dart';
import 'package:patara_ai/services/backend_api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 10.0.2.2 adalah alamat laptop dilihat dari emulator Android.
const server = String.fromEnvironment('TARA_TEST_SERVER', defaultValue: 'http://10.0.2.2:5055');
const password = 'Uji-Antarmuka-2026';

/// Pemilih foto tiruan: selalu mengembalikan berkas gambar yang sudah disiapkan uji.
class FakeImagePicker extends ImagePickerPlatform {
  final String path;
  FakeImagePicker(this.path);

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile(path);
}

Future<Map<String, dynamic>> api(String method, String path, {String? token, Object? body}) async {
  final request = http.Request(method, Uri.parse('$server$path'))
    ..headers['Content-Type'] = 'application/json'
    ..body = body == null ? '' : jsonEncode(body);
  if (token != null) request.headers['Authorization'] = 'Bearer $token';
  final response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 20)));
  final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
  if (response.statusCode >= 400) fail('$method $path -> ${response.statusCode} ${response.body}');
  return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Delegasi melapor dengan foto, Orang Tua menyetujui dan menolak', (tester) async {
    // ---------- Simpan pengaturan aplikasi di perangkat, lalu arahkan ke server uji ----------
    final prefs = await SharedPreferences.getInstance();
    final saved = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    addTearDown(() async {
      final current = await SharedPreferences.getInstance();
      await current.clear();
      for (final entry in saved.entries) {
        final value = entry.value;
        if (value is String) await current.setString(entry.key, value);
        if (value is bool) await current.setBool(entry.key, value);
        if (value is int) await current.setInt(entry.key, value);
        if (value is double) await current.setDouble(entry.key, value);
        if (value is List) await current.setStringList(entry.key, value.cast<String>());
      }
    });
    await prefs.clear();
    // Layar perkenalan (tampil sekali di perangkat baru) bukan bagian alur yang diuji di sini.
    await prefs.setBool('tara_onboarding_seen', true);
    BackendApiService.resetForTest();
    await BackendApiService.setBaseUrl(server);
    PataraApi.clearCache();

    // ---------- Data uji lewat API: satu keluarga dengan Delegasi yang sudah disetujui ----------
    final run = DateTime.now().millisecondsSinceEpoch;
    final parentEmail = 'ui_ortu_$run@contoh.id';
    final delegateEmail = 'ui_asuh_$run@contoh.id';
    final parent = await api('POST', '/api/register', body: {
      'email': parentEmail, 'password': password, 'full_name': 'Ibu Antarmuka', 'role': 'orang_tua',
    });
    final delegate = await api('POST', '/api/register', body: {
      'email': delegateEmail, 'password': password, 'full_name': 'Mbak Antarmuka', 'role': 'delegasi', 'phone': '081234567890',
    });
    final parentToken = parent['access_token'] as String;
    final delegateToken = delegate['access_token'] as String;
    addTearDown(() async {
      // Akun uji dihapus apa pun hasil ujinya (Delegasi dulu, lalu Orang Tua).
      for (final email in [delegateEmail, parentEmail]) {
        try {
          final captcha = await api('GET', '/auth/captcha');
          final numbers = RegExp(r'\d+').allMatches('${captcha['question']}').map((m) => int.parse(m.group(0)!)).toList();
          final login = await api('POST', '/api/login', body: {
            'email': email, 'password': password,
            'captcha_session_id': captcha['session_id'], 'captcha_answer': '${numbers.isEmpty ? '' : numbers[0] + numbers[1]}',
          });
          await api('DELETE', '/api/account', token: login['access_token'] as String, body: {'password': password});
        } catch (_) {}
      }
    });
    final child = await api('POST', '/children', token: parentToken, body: {'nama': 'Raka Uji', 'birth_date': '2024-06-01', 'gender': 'L'});
    final childId = '${child['id']}';
    final invite = await api('POST', '/tokens/generate', token: parentToken, body: {
      'child_id': childId, 'invitee_name': 'Mbak Antarmuka', 'invitee_contact': delegateEmail,
    });
    await api('POST', '/tokens/connect', token: delegateToken, body: {'token': invite['token']});
    await api('PATCH', '/tokens/${invite['token']}/approve', token: parentToken);
    // Lembar persetujuan penelitian disetujui lebih dulu supaya tidak menghalangi alur yang diuji.
    for (final token in [parentToken, delegateToken]) {
      final consent = await api('GET', '/api/consent', token: token);
      await api('POST', '/api/consent', token: token, body: {'agree': true, 'version': (consent['document'] as Map)['version']});
    }

    // ---------- Foto bukti tiruan ----------
    final bytes = await rootBundle.load('asset/image/tara_logo.png');
    final photo = File('${(await getTemporaryDirectory()).path}/foto_bukti_uji.png');
    await photo.writeAsBytes(bytes.buffer.asUint8List());
    ImagePickerPlatform.instance = FakeImagePicker(photo.path);

    // ---------- Pembantu ----------
    Future<void> waitFor(Finder finder, {String? what, Duration timeout = const Duration(seconds: 40)}) async {
      final end = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
        if (finder.evaluate().isNotEmpty) return;
      }
      await binding.takeScreenshot('gagal_${DateTime.now().millisecondsSinceEpoch}').catchError((_) => <int>[]);
      fail('Tidak muncul dalam ${timeout.inSeconds} detik: ${what ?? finder}');
    }

    Future<void> settle([int ms = 800]) => tester.pump(Duration(milliseconds: ms));

    // Pesan di bagian bawah layar (snackbar) menutupi tombol; tunggu sampai hilang sebelum mengetuk.
    Future<void> waitSnackBarGone() async {
      final end = DateTime.now().add(const Duration(seconds: 10));
      while (find.byType(SnackBar).evaluate().isNotEmpty && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    // Menggulir daftar utama layar sampai widget terlihat, lalu mengetuknya.
    Future<void> scrollAndTap(Finder finder, {String? what}) async {
      final list = find.byType(ListView).last;
      for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
        await tester.drag(list, const Offset(0, -260));
        await settle(250);
      }
      expect(finder, findsWidgets, reason: 'tidak ditemukan: ${what ?? finder}');
      await tester.ensureVisible(finder.first);
      await settle(300);
      await tester.tap(finder.first);
      await settle();
    }

    Future<void> login(String email) async {
      await waitFor(find.text('Masuk ke akun Anda'), what: 'layar masuk');
      final captchaField = find.byWidgetPredicate(
        (widget) => widget is TextField && (widget.decoration?.labelText ?? '').startsWith('Verifikasi'),
      );
      await waitFor(captchaField, what: 'soal verifikasi (server uji terhubung)');
      final question = tester.widget<TextField>(captchaField).decoration!.labelText!;
      final numbers = RegExp(r'\d+').allMatches(question).map((m) => int.parse(m.group(0)!)).toList();
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
      await tester.enterText(captchaField, '${numbers[0] + numbers[1]}');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle();
      // Menekan "selesai" di kolom verifikasi sudah mengirim formulir; tombol Masuk hanya cadangan.
      if (find.text('Masuk').evaluate().isNotEmpty) {
        await tester.ensureVisible(find.text('Masuk'));
        await settle(300);
        if (find.text('Masuk').evaluate().isNotEmpty) await tester.tap(find.text('Masuk'), warnIfMissed: false);
      }
    }

    Future<void> logout() async {
      await waitSnackBarGone();
      await tester.tap(find.text('Akun').last);
      await settle();
      await scrollAndTap(find.text('Keluar'), what: 'menu Keluar');
      await waitFor(find.text('Keluar dari akun?'), what: 'konfirmasi keluar');
      await tester.tap(find.widgetWithText(FilledButton, 'Keluar').evaluate().isNotEmpty
          ? find.widgetWithText(FilledButton, 'Keluar')
          : find.text('Keluar').last);
      await waitFor(find.text('Masuk ke akun Anda'), what: 'kembali ke layar masuk');
    }

    Future<void> report(String category, String description, {required bool withPhoto}) async {
      await waitFor(find.text('Catat'), what: 'tombol Catat');
      await waitSnackBarGone();
      await tester.tap(find.text('Catat'));
      await waitFor(find.text(category), what: 'formulir catat aktivitas');
      await tester.tap(find.text(category));
      await settle(400);
      final field = find.byWidgetPredicate(
        (widget) => widget is TextField && (widget.decoration?.hintText ?? '').startsWith('Contoh: makan siang'),
      );
      final list = find.byType(ListView).last;
      for (var i = 0; i < 20 && field.evaluate().isEmpty; i++) {
        await tester.drag(list, const Offset(0, -260));
        await settle(250);
      }
      await tester.enterText(field, description);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(400);
      if (withPhoto) {
        await scrollAndTap(find.text('Galeri'), what: 'tombol Galeri');
        await waitFor(find.text('Foto terpilih'), what: 'foto terpilih');
      }
      await scrollAndTap(find.text('Simpan Aktivitas'), what: 'tombol Simpan Aktivitas');
      await waitFor(find.text('Aktivitas tersimpan.'), what: 'pesan "Aktivitas tersimpan."');
      await waitFor(find.textContaining(description), what: 'catatan "$description" di riwayat');
    }

    // ---------- 1. Aplikasi dibuka ----------
    app.main();
    await waitFor(find.text('Masuk ke akun Anda'), what: 'layar masuk setelah splash');

    // ---------- 2. Delegasi login dan melapor ----------
    await login(delegateEmail);
    await waitFor(find.text('Aktivitas Raka Uji'), what: 'beranda Delegasi');
    // Delegasi tidak mendapat menu laporan milik Orang Tua.
    expect(find.text('Jadwal'), findsNothing);
    expect(find.text('Beranda'), findsNothing);

    // Makan wajib foto untuk Delegasi: tanpa foto, aplikasi menolak sebelum mengirim.
    await waitFor(find.text('Catat'), what: 'tombol Catat');
    await tester.tap(find.text('Catat'));
    await waitFor(find.text('Makan'), what: 'formulir catat aktivitas');
    await tester.tap(find.text('Makan'));
    await settle(400);
    await scrollAndTap(find.text('Simpan Aktivitas'), what: 'tombol Simpan Aktivitas');
    await waitFor(find.textContaining('wajib menyertakan foto bukti'), what: 'peringatan foto bukti wajib');
    await tester.pageBack();
    await settle();

    await report('Makan', 'Makan siang habis satu porsi', withPhoto: true);
    await report('Bermain', 'Main balok di ruang tengah', withPhoto: false);
    await logout();

    // ---------- 3. Orang Tua login dan memvalidasi ----------
    await login(parentEmail);
    await waitFor(find.text('Validasi'), what: 'beranda Orang Tua');
    await scrollAndTap(find.text('Validasi'), what: 'menu Validasi');
    await waitFor(find.text('Lihat foto bukti'), what: 'laporan berfoto di daftar validasi');
    expect(find.textContaining('Makan siang habis satu porsi'), findsOneWidget);
    expect(find.textContaining('Main balok di ruang tengah'), findsOneWidget);
    expect(find.textContaining('Dilaporkan Mbak Antarmuka'), findsNWidgets(2));

    // Foto bukti terbuka (gambar diambil dari server dengan sesi Orang Tua).
    await tester.tap(find.text('Lihat foto bukti'));
    await waitFor(find.byType(Image), what: 'foto bukti tampil');
    expect(find.text('Foto sudah tidak tersedia.'), findsNothing);
    // Dialog foto ditutup dengan mengetuk area di luarnya.
    await tester.tapAt(const Offset(12, 60));
    await settle();
    expect(find.byType(Dialog), findsNothing, reason: 'dialog foto bukti belum tertutup');

    // Laporan berfoto dinyatakan sesuai.
    final photoCard = find.ancestor(of: find.text('Lihat foto bukti'), matching: find.byType(PataraCard)).first;
    await tester.ensureVisible(find.descendant(of: photoCard, matching: find.text('Sesuai')));
    await settle(300);
    await tester.tap(find.descendant(of: photoCard, matching: find.text('Sesuai')));
    final gone = DateTime.now().add(const Duration(seconds: 30));
    while (find.text('Lihat foto bukti').evaluate().isNotEmpty && DateTime.now().isBefore(gone)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Lihat foto bukti'), findsNothing, reason: 'laporan yang sudah diputuskan masih tampil');

    // Laporan tanpa foto dinyatakan tidak sesuai, dengan catatan untuk Delegasi.
    // Daftar dimuat ulang setelah keputusan pertama; tunggu sampai laporan kedua tampil lagi.
    await waitFor(find.text('Tidak sesuai'), what: 'laporan kedua setelah daftar dimuat ulang');
    await tester.ensureVisible(find.text('Tidak sesuai'));
    await settle(300);
    await tester.tap(find.text('Tidak sesuai'));
    await waitFor(find.text('Catatan untuk Delegasi (opsional)'), what: 'dialog catatan penolakan');
    await tester.enterText(find.byType(TextField).last, 'Waktunya tidak sesuai');
    await tester.tap(find.text('Tandai tidak sesuai'));
    await waitFor(find.text('Semua laporan sudah divalidasi'), what: 'daftar validasi kosong');

    // ---------- 4. Periksa ulang langsung ke server ----------
    final pending = await api('GET', '/api/activity-validations', token: parentToken);
    expect(pending['count'], 0);
    final activities = (await api('GET', '/activities?child_id=$childId', token: parentToken))['data'] as List;
    Map<String, dynamic> logOf(String text) => jsonDecode(
      '${activities.firstWhere((item) => '${item['value']}'.contains(text))['value']}',
    ) as Map<String, dynamic>;
    final meal = activities.firstWhere((item) => '${item['value']}'.contains('Makan siang habis satu porsi'));
    expect(meal['photo_path'], isNotNull, reason: 'foto bukti tidak tersimpan di server');
    expect(logOf('Makan siang habis satu porsi')['validation_status'], 'confirmed');
    expect(logOf('Makan siang habis satu porsi')['performer_role'], 'delegasi');
    expect(logOf('Main balok di ruang tengah')['validation_status'], 'rejected');
    expect(logOf('Main balok di ruang tengah')['validation_note'], 'Waktunya tidak sesuai');

    await tester.pageBack();
    await settle();
    await logout();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
