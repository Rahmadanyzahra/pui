import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patara_ai/features/login_screen.dart';
import 'package:patara_ai/features/register_screen.dart';
import 'package:patara_ai/patara/activity_form_screen.dart';
import 'package:patara_ai/patara/baby_care_card.dart';
import 'package:patara_ai/patara/delegate_recap_screen.dart';
import 'package:patara_ai/patara/delegate_shell.dart';
import 'package:patara_ai/patara/guidance_screen.dart';
import 'package:patara_ai/patara/patara_api.dart';
import 'package:patara_ai/patara/research_screens.dart';
import 'package:patara_ai/patara/validation_screen.dart';
import 'package:patara_ai/services/backend_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String fixture(String name) => File('test/fixtures/$name.json').readAsStringSync();

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(body is String ? body : jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  final requests = <http.Request>[];
  Map<String, dynamic>? session;
  bool consentAgreed = false;
  late Map<String, dynamic> report;

  setUp(() {
    BackendApiService.resetForTest();
    SharedPreferences.setMockInitialValues({});
    PataraApi.clearCache();
    requests.clear();
    session = null;
    consentAgreed = false;
    report = {
      'id': 'act-1',
      'child_id': 'c1',
      'child_name': 'Raka',
      'category': 'bermain',
      'category_label': 'Bermain',
      'event_at': '2026-10-07T02:00:00.000Z',
      'description': 'Main di taman',
      'mood_before': null,
      'mood_after': 'senang',
      'fussy_level': null,
      'tantrum_count': 0,
      'status': 'selesai',
      'duration_minutes': 182,
      'duration_source': 'timer',
      'started_at': '2026-10-07T02:00:00.000Z',
      'ended_at': '2026-10-07T05:02:00.000Z',
      'meal': null,
      'performer_name': 'Mbak Tini',
      'validation_status': 'pending',
      'validation_note': '',
      'photo_path': null,
    };
  });

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final categories = jsonDecode(fixture('activity_categories')) as Map<String, dynamic>;
    return switch ('${request.method} ${request.url.path}') {
      'GET /api/activity-categories' => json({
        ...categories,
        'meal_portions': [
          {'key': 'habis', 'label': 'Habis'},
          {'key': 'sedikit', 'label': 'Sedikit'},
        ],
        'food_groups': [
          {'key': 'pokok', 'label': 'Makanan pokok'},
          {'key': 'sayur', 'label': 'Sayur'},
        ],
      }),
      'GET /api/activity-sessions/active' => json({'session': session}),
      'POST /api/activity-sessions' => json({
        'session': {'id': 's-new', 'child_id': 'c1', 'category': 'bermain', 'started_at': '2026-10-07T02:00:00.000Z'},
      }, 201),
      'POST /activities' => json('{"id":"new","photo_path":null,"photo_upload_failed":false}', 201),
      'GET /api/activity-validations' => json({'items': [report], 'count': 1}),
      'GET /api/delegate-recap' => json({
        'month': '2026-10',
        'label': 'Oktober 2026',
        'items': [
          {
            'child_id': 'c1',
            'child_name': 'Raka',
            'delegate_id': 'd1',
            'name': 'Mbak Tini',
            'total_reports': 2,
            'confirmed': 1,
            'rejected': 1,
            'pending': 0,
            'accuracy_percent': 50,
            'active_days': 2,
            'with_photo': 1,
            'with_description': 2,
            'timer_reports': 1,
            'timer_minutes': 182,
            'manual_duration_reports': 1,
            'by_category': [
              {'key': 'bermain', 'label': 'Bermain', 'count': 2},
            ],
            'rejection_notes': ['Durasi tidak sesuai'],
            'reports': [
              {...report, 'validation_status': 'confirmed', 'photo_path': '/activity-photos/p1'},
              {
                ...report,
                'id': 'act-2',
                'description': 'Main balok',
                'duration_minutes': 180,
                'duration_source': 'manual',
                'started_at': null,
                'ended_at': null,
                'validation_status': 'rejected',
                'validation_note': 'Durasi tidak sesuai',
              },
            ],
          },
        ],
      }),
      _ when request.url.path.startsWith('/api/guidance/') => json(fixture('guidance')),
      'GET /api/baby-care/bayi' => json({
        'applicable': true,
        'date': '2026-10-08',
        'feeds': 6,
        'meals': 0,
        'diapers': 4,
        'sleep_minutes': 135,
        'tummy_minutes': 20,
        'references': [
          {'key': 'sleep', 'text': 'Tidur 14-17 jam sehari termasuk tidur siang.', 'source': 'WHO (2019)'},
        ],
        'due_immunizations': [
          {'key': 'bcg', 'label': 'BCG', 'age_months': 1},
        ],
      }),
      'GET /api/consent' => json({
        'agreed': consentAgreed,
        'agreed_at': consentAgreed ? '2026-10-07T03:00:00.000Z' : null,
        'document': {
          'version': '2026-10-v1',
          'title': 'Persetujuan Ikut Serta dalam Penelitian',
          'points': [
            {'title': 'Tujuan', 'text': 'TARA dipakai dalam penelitian.'},
            {'title': 'Bukan layanan medis', 'text': 'Semua saran adalah informasi umum, bukan diagnosis.'},
          ],
          'role_note': 'Sebagai Orang Tua, Anda juga menyetujui pencatatan data anak Anda.',
          'contact': 'peneliti@kampus.ac.id',
          'statement': 'Saya telah membaca penjelasan di atas dan setuju ikut serta.',
        },
      }),
      'POST /api/consent' => json({'agreed': true, 'agreed_at': '2026-10-07T03:00:00.000Z', 'version': '2026-10-v1'}, 201),
      'GET /api/sus' => json({
        'items': [
          for (var number = 1; number <= 10; number++) {'number': number, 'text': 'Pernyataan $number'},
        ],
        'scale': ['Sangat tidak setuju', 'Tidak setuju', 'Ragu-ragu', 'Setuju', 'Sangat setuju'],
        'source': 'Brooke (1996); Sharfina & Santoso (2016).',
        'last_response': null,
      }),
      'POST /api/sus' => json({'score': 75, 'submitted_at': '2026-10-07T03:00:00.000Z'}, 201),
      _ => json('{"error":"not_found"}', 404),
    };
  }

  // Ukuran ponsel kecil agar overflow pada tampilan baru tertangkap.
  Future<void> run(WidgetTester tester, Widget screen, Future<void> Function() body) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Animasi karakter berulang tanpa henti; dimatikan agar pumpAndSettle selesai.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      await body();
    }, () => MockClient(handle));
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  BackendChild child() => BackendChild.fromJson(
    Map<String, dynamic>.from((jsonDecode(fixture('children')) as List).first as Map),
  );

  Map<String, dynamic> savedValue() =>
      (jsonDecode(requests.lastWhere((request) => request.method == 'POST' && request.url.path == '/activities').body)
              as Map<String, dynamic>)['value']
          as Map<String, dynamic>;

  testWidgets('guidance lists sensory ideas, nutrition tips, the meal recap and numbered sources', (tester) async {
    await run(tester, GuidanceScreen(child: child()), () async {
      expect(find.text('Sensori'), findsOneWidget);
      await scrollTo(tester, find.text('Menggambar dengan jari'));
      await scrollTo(tester, find.text('Makanan dan tekstur'));
      await scrollTo(tester, find.textContaining('Piring Makanku (sajian sekali makan): separuh piring'));
      await scrollTo(tester, find.text('Minuman'));
      await scrollTo(tester, find.textContaining('sekitar 1.700 ml sehari'));
      await scrollTo(tester, find.text('Kebiasaan makan'));
      await scrollTo(tester, find.text('Saran dari ahli'));
      await scrollTo(tester, find.text('Variasikan lauk hewani'));
      expect(find.text('Gizi dan makan • Contoh Ahli, Ahli gizi'), findsOneWidget);
      await scrollTo(tester, find.textContaining('Sayur baru tercatat pada 1 dari 4 hari'));
      await scrollTo(tester, find.textContaining('[1] Kementerian Kesehatan RI (2024). Buku Kesehatan Ibu dan Anak'));
      await scrollTo(tester, find.textContaining('bukan kutipan langsung'));
    });
  });

  // Kartu anak di beranda Delegasi menyesuaikan kelompok usia: bayi tanpa permainan, toddler dan balita dengan permainan.
  for (final (category, guide, hasGames) in [
    ('baby', 'Stimulasi bayi', false),
    ('toddler', 'Ide usia 1-2 tahun', true),
    ('balita', 'Ide usia 2-5 tahun', true),
  ]) {
    testWidgets('delegate child panel for $category offers age-matched ideas${hasGames ? ' and games' : ' only'}', (tester) async {
      final child = BackendChild(id: 'c1', nama: 'Raka', umur: 1, category: category);
      await run(tester, Scaffold(body: DelegateChildPanel(child: child)), () async {
        expect(find.text(guide), findsOneWidget);
        expect(find.text('Zona bermain'), hasGames ? findsOneWidget : findsNothing);
        await tester.tap(find.text(guide));
        await tester.pumpAndSettle();
        expect(requests.last.url.path, '/api/guidance/c1');
        expect(find.textContaining('Ide Aktivitas & Gizi'), findsOneWidget);
      });
    });
  }

  testWidgets('register screen offers both roles and rates the password as it is typed', (tester) async {
    await run(tester, const RegisterScreen(), () async {
      expect(find.text('Orang Tua'), findsOneWidget);
      await tester.tap(find.text('Delegasi'));
      await tester.pump();
      expect(find.textContaining('token undangan dari Orang Tua'), findsOneWidget);
      await scrollTo(tester, find.text('Belum 8 karakter'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'rahasia12');
      await tester.pump();
      expect(find.text('Baik'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Rahasia-2026');
      await tester.pump();
      expect(find.text('Kuat'), findsOneWidget);
    });
  });

  testWidgets('login screen fits a small phone', (tester) async {
    await run(tester, const LoginScreen(), () async {
      expect(find.text('Masuk ke akun Anda'), findsOneWidget);
      await scrollTo(tester, find.text('Belum punya akun?'));
    });
  });

  testWidgets('baby care card shows today\'s care, references, due immunizations and quick logging', (tester) async {
    const baby = BackendChild(id: 'bayi', nama: 'Sari', umur: 0, category: 'baby');
    await run(tester, const Scaffold(body: SingleChildScrollView(child: BabyCareCard(child: baby))), () async {
      expect(find.text('6×'), findsOneWidget);
      expect(find.text('4×'), findsOneWidget);
      expect(find.text('2 j 15 mnt'), findsOneWidget);
      expect(find.text('20 mnt'), findsOneWidget);
      expect(find.textContaining('Tidur 14-17 jam sehari'), findsOneWidget);
      expect(find.textContaining('belum dicatat: BCG.'), findsOneWidget);
      await tester.tap(find.text('Menyusu'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityFormScreen), findsOneWidget);
    });
  });

  test('photo uploads declare their image type so the server accepts them', () {
    expect('${BackendApiService.imageMediaType('/data/cache/scaled_bukti.JPG')}', 'image/jpeg');
    expect('${BackendApiService.imageMediaType('bukti.jpeg')}', 'image/jpeg');
    expect('${BackendApiService.imageMediaType('bukti.png')}', 'image/png');
    expect('${BackendApiService.imageMediaType('bukti.webp')}', 'image/webp');
    expect(BackendApiService.imageMediaType('catatan.txt'), isNull);
  });

  testWidgets('the app stays on the consent sheet until the participant agrees', (tester) async {
    await run(tester, const ConsentGate(child: Scaffold(body: Text('Beranda'))), () async {
      expect(find.text('Persetujuan Ikut Serta dalam Penelitian'), findsOneWidget);
      expect(find.text('Beranda'), findsNothing);
      await scrollTo(tester, find.text('Setuju dan lanjutkan'));
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Setuju dan lanjutkan'));
      await tester.pumpAndSettle();
      final request = requests.lastWhere((request) => request.url.path == '/api/consent' && request.method == 'POST');
      expect(jsonDecode(request.body), {'agree': true, 'version': '2026-10-v1'});
      expect(find.text('Beranda'), findsOneWidget);
    });
  });

  testWidgets('a participant who already agreed goes straight in', (tester) async {
    consentAgreed = true;
    await run(tester, const ConsentGate(child: Scaffold(body: Text('Beranda'))), () async {
      expect(find.text('Beranda'), findsOneWidget);
      expect(requests.where((request) => request.method == 'POST'), isEmpty);
    });
  });

  testWidgets('delegate starts a timer for the chosen activity', (tester) async {
    await run(tester, ActivityFormScreen(child: child(), isDelegate: true), () async {
      await tester.tap(find.text('Bermain'));
      await tester.pump();
      await scrollTo(tester, find.text('Mulai timer sekarang'));
      await tester.tap(find.text('Mulai timer sekarang'));
      await tester.pumpAndSettle();
      final request = requests.lastWhere((request) => request.url.path == '/api/activity-sessions' && request.method == 'POST');
      expect(jsonDecode(request.body), {'category': 'bermain'});
      expect(find.byType(ActivityFormScreen), findsNothing);
    });
  });

  testWidgets('a running timer locks the activity type and is sent instead of a typed duration', (tester) async {
    session = {'id': 's1', 'child_id': 'c1', 'category': 'bermain', 'started_at': '2026-10-07T02:00:00.000Z'};
    await run(tester, ActivityFormScreen(child: child(), isDelegate: true), () async {
      expect(find.textContaining('Timer berjalan sejak'), findsOneWidget);
      expect(find.text('Mulai timer sekarang'), findsNothing);
      expect(find.text('Tanggal dan waktu'), findsNothing);
      await tester.tap(find.text('Tidur'));
      await tester.pump();
      await scrollTo(tester, find.text('Simpan Aktivitas'));
      await tester.tap(find.text('Simpan Aktivitas'));
      await tester.pumpAndSettle();
      final request = requests.lastWhere((request) => request.method == 'POST');
      expect(jsonDecode(request.body)['activity_type'], 'bermain');
      expect(savedValue(), containsPair('session_id', 's1'));
      expect(savedValue().containsKey('duration_minutes'), false);
    });
  });

  testWidgets('a typed duration and the meal details are saved with the activity', (tester) async {
    await run(tester, ActivityFormScreen(child: child()), () async {
      expect(find.text('Mulai timer sekarang'), findsNothing);
      await tester.tap(find.text('Makan'));
      await tester.pump();
      await scrollTo(tester, find.text('Isi durasi manual'));
      await tester.tap(find.text('Isi durasi manual'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Jam'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'Menit'), '30');
      await tester.tap(find.text('Pakai'));
      await tester.pumpAndSettle();
      expect(find.text('1 jam 30 mnt (manual)'), findsOneWidget);
      await scrollTo(tester, find.text('Habis'));
      await tester.tap(find.text('Habis'));
      await tester.pump();
      await scrollTo(tester, find.text('Sayur'));
      await tester.tap(find.text('Sayur'));
      await tester.pump();
      await scrollTo(tester, find.text('Simpan Aktivitas'));
      await tester.tap(find.text('Simpan Aktivitas'));
      await tester.pumpAndSettle();
      expect(savedValue(), containsPair('duration_minutes', 90));
      expect(savedValue()['meal'], {'portion': 'habis', 'food_groups': ['sayur']});
    });
  });

  testWidgets('validation tells a server-timed duration apart from a typed one', (tester) async {
    await run(tester, const ValidationScreen(), () async {
      expect(find.textContaining('Durasi 3 jam 2 mnt (timer server'), findsOneWidget);
    });
    report = {...report, 'duration_minutes': 180, 'duration_source': 'manual', 'started_at': null, 'ended_at': null};
    await run(tester, ValidationScreen(key: UniqueKey()), () async {
      expect(find.text('Durasi 3 jam (diisi manual, tidak terverifikasi)'), findsOneWidget);
    });
  });

  testWidgets('delegate recap opens each report with its photo, duration evidence and decision', (tester) async {
    await run(tester, const DelegateRecapScreen(), () async {
      expect(find.textContaining('1 laporan dengan timer server (3 jam 2 mnt) • 1 durasi diisi manual'), findsOneWidget);
      await scrollTo(tester, find.text('Rincian 2 laporan, foto, dan validasi'));
      await tester.tap(find.text('Rincian 2 laporan, foto, dan validasi'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Tidak sesuai: Durasi tidak sesuai'));
      expect(find.text('Sesuai'), findsOneWidget);
      expect(find.byTooltip('Lihat foto bukti'), findsOneWidget);
      expect(find.byTooltip('Tanpa foto bukti'), findsOneWidget);
      expect(find.text('Durasi 3 jam (diisi manual, tidak terverifikasi)'), findsOneWidget);
    });
  });
}
