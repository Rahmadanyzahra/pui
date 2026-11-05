import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patara_ai/patara/activity_form_screen.dart';
import 'package:patara_ai/patara/behavior_screen.dart';
import 'package:patara_ai/patara/child_dashboard_screen.dart';
import 'package:patara_ai/patara/delegate_recap_screen.dart';
import 'package:patara_ai/patara/growth_screen.dart';
import 'package:patara_ai/patara/health_screen.dart';
import 'package:patara_ai/patara/validation_screen.dart';
import 'package:patara_ai/patara/delegate_shell.dart';
import 'package:patara_ai/patara/delegation_screen.dart';
import 'package:patara_ai/patara/development_screen.dart';
import 'package:patara_ai/patara/monthly_report_screen.dart';
import 'package:patara_ai/patara/parent_shell.dart';
import 'package:patara_ai/patara/patara_api.dart';
import 'package:patara_ai/models/backend_connection.dart';
import 'package:patara_ai/services/backend_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend tiruan yang menjawab dengan respons asli hasil rekaman (test/fixtures).
class FakeBackend {
  final requests = <http.Request>[];
  final overrides = <String, http.Response>{};

  final pendingReports = [
    {
      'id': 'act-9',
      'child_id': 'c1',
      'child_name': 'Raka',
      'category': 'makan',
      'category_label': 'Makan',
      'event_at': '2026-10-07T05:00:00.000Z',
      'description': 'Makan siang habis satu porsi',
      'mood_before': 'biasa',
      'mood_after': 'senang',
      'fussy_level': 0,
      'tantrum_count': 0,
      'status': 'selesai',
      'performer_name': 'Mbak Tini',
      'validation_status': 'pending',
      'photo_path': null,
    },
  ];

  String whoCase = 'inside';

  final growth = <String, dynamic>{
    'records': [
      {'id': 1, 'weight_kg': 14.1, 'height_cm': 95.6, 'head_circumference_cm': 49.2, 'measured_at': '2026-09-07T05:00:00.000Z'},
      {'id': 2, 'weight_kg': 14.5, 'height_cm': 96.4, 'head_circumference_cm': 49.5, 'measured_at': '2026-10-07T05:00:00.000Z'},
    ],
    'latest': {'id': 2, 'weight_kg': 14.5, 'height_cm': 96.4, 'head_circumference_cm': 49.5, 'measured_at': '2026-10-07T05:00:00.000Z'},
    'previous': {'id': 1, 'weight_kg': 14.1, 'height_cm': 95.6, 'head_circumference_cm': 49.2, 'measured_at': '2026-09-07T05:00:00.000Z'},
    'change': {'weight_kg': 0.4, 'height_cm': 0.8, 'head_circumference_cm': 0.3},
    'total_records': 2,
  };

  final health = {
    'types': [
      {'key': 'imunisasi', 'label': 'Imunisasi'},
      {'key': 'sakit', 'label': 'Sakit'},
      {'key': 'kunjungan', 'label': 'Kunjungan dokter/posyandu'},
      {'key': 'alergi', 'label': 'Alergi'},
      {'key': 'lainnya', 'label': 'Lainnya'},
    ],
    'records': [
      {'id': 7, 'record_type': 'sakit', 'title': 'Batuk pilek', 'record_date': '2026-10-02', 'notes': 'Sembuh dalam 4 hari'},
      {'id': 3, 'record_type': 'imunisasi', 'vaccine_key': 'hb0', 'title': 'Hepatitis B (HB-0)', 'record_date': '2023-03-11', 'notes': ''},
    ],
    'immunizations': [
      {'key': 'hb0', 'label': 'Hepatitis B (HB-0)', 'age_months': 0, 'record_id': 3, 'given_date': '2023-03-11'},
      {'key': 'bcg', 'label': 'BCG', 'age_months': 1, 'record_id': null, 'given_date': null},
    ],
    'immunizations_given': 1,
    'immunizations_total': 2,
  };

  final delegatePerformance = [
    {
      'child_id': 'c1',
      'child_name': 'Raka',
      'delegate_id': 'd1',
      'name': 'Mbak Tini',
      'total_reports': 4,
      'confirmed': 3,
      'rejected': 1,
      'pending': 0,
      'accuracy_percent': 75,
      'active_days': 3,
      'with_photo': 2,
      'with_description': 4,
      'by_category': [
        {'key': 'makan', 'label': 'Makan', 'count': 3},
        {'key': 'tidur', 'label': 'Tidur', 'count': 1},
      ],
      'rejection_notes': ['Jam tidur tidak sesuai'],
    },
  ];

  String monthlyReport() {
    final report = jsonDecode(fixture('monthly_report')) as Map<String, dynamic>;
    report['growth'] = {...growth, 'who': (jsonDecode(fixture('growth_who')) as Map<String, dynamic>)['inside']};
    report['health'] = {
      'immunizations_given': 1,
      'immunizations_total': 2,
      'records_in_period': [(health['records'] as List).first],
    };
    report['delegate_performance'] = delegatePerformance;
    return jsonEncode(report);
  }

  String fixture(String name) => File('test/fixtures/$name.json').readAsStringSync();

  http.Response _json(String body, [int status = 200]) => http.Response.bytes(
    utf8.encode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> handle(http.BaseRequest base) async {
    final request = base is http.Request
        ? base
        : (http.Request(base.method, base.url)..body = jsonEncode((base as http.MultipartRequest).fields));
    requests.add(request);
    final path = request.url.path;
    final key = '${request.method} $path';
    if (overrides.containsKey(key)) return overrides[key]!;
    return switch (key) {
      'GET /children' => _json(fixture('children')),
      'GET /api/activity-categories' => _json(fixture('activity_categories')),
      'GET /activities' => _json(fixture('activities')),
      'POST /activities' => _json('{"id":"new","photo_path":null,"photo_upload_failed":false}', 201),
      'GET /api/schedules' => _json(fixture('schedules')),
      'GET /api/profile' => _json(fixture('profile')),
      'GET /tokens/pending-count' => _json('{"count":1}'),
      'GET /api/activity-validations' => _json(jsonEncode({'items': pendingReports, 'count': pendingReports.length})),
      'GET /tokens/list' => _json(fixture('tokens')),
      'POST /api/ai-chat' => _json(fixture('chat')),
      'GET /api/delegate-recap' => _json(jsonEncode({'month': '2026-10', 'label': 'Oktober 2026', 'items': delegatePerformance})),
      _ when path.startsWith('/api/health/') && request.method == 'GET' => _json(jsonEncode(health)),
      _ when path.startsWith('/api/health/') => _json('{"ok":true}', 201),
      _ when path.startsWith('/api/growth/') => _json(jsonEncode({
        ...growth,
        'who': (jsonDecode(fixture('growth_who')) as Map<String, dynamic>)[whoCase],
      })),
      _ when path.endsWith('/validation') => _json('{"validation_status":"confirmed"}'),
      _ when path.startsWith('/api/behavior-tracking/') => _json(fixture('behavior')),
      _ when path.startsWith('/api/development/') && request.method == 'GET' => _json(fixture('development')),
      _ when path.startsWith('/api/development/') => _json('{"status":"tercapai"}'),
      _ when path.startsWith('/api/monthly-report/') && path.endsWith('/email') => _json(
        '{"error":"Pengiriman email belum dikonfigurasi di server (SMTP). Gunakan Download PDF."}',
        503,
      ),
      _ when path.startsWith('/api/monthly-report/') => _json(monthlyReport()),
      _ => _json('{"error":"not_found"}', 404),
    };
  }

  http.Request last(String method, String pathPrefix) => requests.lastWhere(
    (request) => request.method == method && request.url.path.startsWith(pathPrefix),
  );
}

void main() {
  late FakeBackend backend;

  setUp(() {
    BackendApiService.resetForTest();
    SharedPreferences.setMockInitialValues({});
    PataraApi.clearCache();
    backend = FakeBackend();
  });

  // Semua layar diuji di ukuran ponsel kecil agar overflow tertangkap.
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
    }, () => MockClient(backend.handle));
  }

  // Menggulir daftar vertikal sampai widget dibangun dan terlihat.
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
    Map<String, dynamic>.from((jsonDecode(backend.fixture('children')) as List).first as Map),
  );

  testWidgets('home greets the parent, flags reports to validate, and opens the child dashboard', (tester) async {
    await run(tester, const ParentShell(), () async {
      expect(find.textContaining('Halo, Ibu'), findsOneWidget);
      expect(find.text('1 laporan Delegasi perlu divalidasi'), findsOneWidget);
      expect(find.text('Raka'), findsOneWidget);
      expect(find.text('Balita'), findsOneWidget);

      await tester.tap(find.text('Raka'));
      await tester.pumpAndSettle();
      expect(find.byType(ChildDashboardScreen), findsOneWidget);
      expect(find.text('Laki-laki'), findsOneWidget);
      expect(backend.last('GET', '/api/behavior-tracking/').url.queryParameters['days'], '7');
      expect(find.text('Catat aktivitas'), findsOneWidget);
      // Dashboard dibagi tiga bagian; pemilihnya tetap terlihat saat halaman digulir.
      for (final section in ['Aktivitas terbaru', 'Zona bermain']) {
        await scrollTo(tester, find.text(section));
      }
      expect(find.text('14,5 kg'), findsNothing);

      await tester.tap(find.text('Tumbuh kembang'));
      await tester.pumpAndSettle();
      expect(find.text('14,5 kg'), findsOneWidget);
      expect(find.text('96,4 cm'), findsOneWidget);
      await scrollTo(tester, find.text('1/2 imunisasi'));
      expect(find.textContaining('Catatan terakhir: Batuk pilek'), findsOneWidget);
      await scrollTo(tester, find.text('Perkembangan'));

      await tester.tap(find.text('Laporan'));
      await tester.pumpAndSettle();
      for (final section in ['Pola Perilaku', 'Laporan Bulanan']) {
        await scrollTo(tester, find.text(section));
      }
    });
  });

  testWidgets('quick log on the home card saves the activity at the current time with one tap', (tester) async {
    await run(tester, const ParentShell(), () async {
      final before = DateTime.now().toUtc().subtract(const Duration(seconds: 2));
      await scrollTo(tester, find.byKey(ValueKey('quick-${child().id}-makan')));
      await tester.tap(find.byKey(ValueKey('quick-${child().id}-makan')));
      await tester.pumpAndSettle();
      final body = jsonDecode(backend.last('POST', '/activities').body) as Map<String, dynamic>;
      expect(body['child_id'], child().id);
      expect(body['activity_type'], 'makan');
      final value = body['value'] is String ? jsonDecode(body['value'] as String) as Map : body['value'] as Map;
      expect(DateTime.parse(value['event_at'] as String).isAfter(before), isTrue);
      expect(find.textContaining('Makan Raka dicatat pukul'), findsOneWidget);
      // Tetap di beranda: tidak ada formulir yang terbuka.
      expect(find.byType(ChildDashboardScreen), findsNothing);
      expect(find.text('Lengkap'), findsWidgets);
    });
  });

  testWidgets('growth screen shows the latest measurement, its change and the history', (tester) async {
    await run(tester, GrowthScreen(child: child()), () async {
      expect(find.text('14,5 kg'), findsOneWidget);
      expect(find.text('+0,4 kg'), findsOneWidget);
      await scrollTo(tester, find.text('Grafik'));
      await scrollTo(tester, find.text('Riwayat pengukuran'));
      await scrollTo(tester, find.textContaining('LK 49,2 cm'));
      await scrollTo(tester, find.textContaining('dilakukan oleh tenaga kesehatan'));
    });
  });

  testWidgets('growth screen places the latest measurement on the WHO curve without a nutrition label', (tester) async {
    await run(tester, GrowthScreen(child: child()), () async {
      await scrollTo(tester, find.text('Posisi pada kurva WHO'));
      await scrollTo(tester, find.text('Berat badan menurut umur (BB/U)'));
      expect(find.text('z -0,26'), findsOneWidget);
      expect(find.textContaining('Median WHO 15 kg; -2 SD 11,7; +2 SD 19,2.'), findsOneWidget);
      await scrollTo(tester, find.textContaining('Dihitung untuk usia 1210 hari memakai tinggi badan'));
      expect(find.textContaining('Bawa catatan ini ke Posyandu'), findsNothing);
      expect(find.textContaining(RegExp('gizi (buruk|kurang|baik|lebih)|stunting|tidak normal', caseSensitive: false)), findsNothing);
    });
  });

  testWidgets('growth screen suggests a check-up when a value is outside -2 SD to +2 SD', (tester) async {
    backend.whoCase = 'outside';
    await run(tester, GrowthScreen(child: child()), () async {
      await scrollTo(tester, find.text('z -2,61'));
      await scrollTo(tester, find.textContaining('Bawa catatan ini ke Posyandu, Puskesmas, atau dokter anak'));
      expect(find.textContaining('Ini bukan diagnosis'), findsOneWidget);
    });
  });

  testWidgets('growth screen explains why no WHO position is shown when the sex is unknown', (tester) async {
    backend.whoCase = 'unavailable';
    await run(tester, GrowthScreen(child: child()), () async {
      await scrollTo(tester, find.textContaining('Jenis kelamin anak belum diisi'));
    });
  });

  testWidgets('health screen lists immunizations and records, and saves a vaccine date', (tester) async {
    await run(tester, HealthScreen(child: child()), () async {
      expect(find.text('1 dari 2'), findsOneWidget);
      expect(find.textContaining('Diberikan 11 Maret 2023'), findsOneWidget);
      await tester.tap(find.text('BCG'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final body = jsonDecode(backend.last('POST', '/api/health/').body) as Map<String, dynamic>;
      expect(body['record_type'], 'imunisasi');
      expect(body['vaccine_key'], 'bcg');
      expect(body['record_date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      await scrollTo(tester, find.text('Batuk pilek'));
      await scrollTo(tester, find.textContaining('arahan posyandu'));
    });
  });

  testWidgets('delegate recap shows accuracy and the notes behind rejected reports', (tester) async {
    await run(tester, const DelegateRecapScreen(), () async {
      expect(find.text('Mbak Tini'), findsOneWidget);
      expect(find.text('Mendampingi Raka'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.textContaining('3 sesuai • 1 tidak sesuai'), findsOneWidget);
      await scrollTo(tester, find.textContaining('Jam tidur tidak sesuai'));
      expect(backend.last('GET', '/api/delegate-recap').url.queryParameters['month'], matches(RegExp(r'^\d{4}-\d{2}$')));
    });
  });

  testWidgets('parent validates a delegate report as correct', (tester) async {
    await run(tester, const ValidationScreen(), () async {
      expect(find.text('Makan • Raka'), findsOneWidget);
      expect(find.textContaining('Dilaporkan Mbak Tini'), findsOneWidget);
      expect(find.text('Makan siang habis satu porsi'), findsOneWidget);
      await tester.tap(find.text('Sesuai'));
      await tester.pumpAndSettle();
      final request = backend.last('PATCH', '/api/activity-logs/');
      expect(request.url.path, '/api/activity-logs/act-9/validation');
      expect(jsonDecode(request.body), {'action': 'confirm', 'note': ''});
    });
  });

  testWidgets('every parent tab renders with real backend data', (tester) async {
    await run(tester, const ParentShell(), () async {
      await tester.tap(find.text('Aktivitas'));
      await tester.pumpAndSettle();
      expect(find.text('Bermain'), findsWidgets);
      expect(find.textContaining('Ibu Sari'), findsWidgets);
      expect(find.textContaining('Tantrum 1×'), findsWidgets);

      await tester.tap(find.text('Jadwal'));
      await tester.pumpAndSettle();
      expect(find.text('Membaca buku'), findsOneWidget);
      expect(find.textContaining('Setiap hari'), findsOneWidget);

      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Tips agar anak mudah tidur'));
      await tester.tap(find.text('Tips agar anak mudah tidur'));
      await tester.pumpAndSettle();
      expect(find.textContaining('10-13 jam'), findsOneWidget);
      expect(jsonDecode(backend.last('POST', '/api/ai-chat').body)['child_id'], child().id);

      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      expect(find.text('Ibu Sari'), findsOneWidget);
      expect(find.text('1 permintaan menunggu persetujuan'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
    });
  });

  testWidgets('a story told in chat becomes a draft that is saved only after confirmation', (tester) async {
    backend.overrides['POST /api/ai-chat'] = http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'reply': 'Saya menangkap cerita Anda sebagai catatan tidur untuk Raka.',
          'activity_draft': {
            'category': 'tidur',
            'category_label': 'Tidur',
            'requires_photo': false,
            'description': 'Tadi Raka tantrum 2 kali waktu mau tidur',
            'event_at': '2026-10-07T08:00:00.000Z',
            'mood_before': null,
            'mood_after': 'marah',
            'fussy_level': 3,
            'tantrum_count': 2,
            'status': 'selesai',
          },
        }),
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    await run(tester, const ParentShell(), () async {
      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tadi Raka tantrum 2 kali waktu mau tidur');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('Draf catatan aktivitas'), findsOneWidget);
      expect(backend.requests.where((request) => request.method == 'POST' && request.url.path == '/activities'), isEmpty);

      await scrollTo(tester, find.text('Simpan'));
      expect(find.text('2 kali'), findsOneWidget);
      expect(find.text('Sangat rewel'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final body = jsonDecode(backend.last('POST', '/activities').body) as Map<String, dynamic>;
      expect(body['child_id'], child().id);
      expect(body['activity_type'], 'tidur');
      expect(body['value'], containsPair('tantrum_count', 2));
      expect(body['value'], containsPair('mood_after', 'marah'));
      expect(find.textContaining('Tersimpan di catatan aktivitas'), findsOneWidget);
    });
  });

  testWidgets('activity form sends the structured log the backend expects', (tester) async {
    await run(tester, ActivityFormScreen(child: child()), () async {
      await tester.tap(find.text('Bermain'));
      await scrollTo(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Main balok bersama');
      await scrollTo(tester, find.text('Mood sebelum aktivitas'));
      await tester.tap(find.textContaining('Biasa saja').first);
      await scrollTo(tester, find.text('Mood setelah aktivitas'));
      await tester.tap(find.textContaining('Senang').last);
      await scrollTo(tester, find.text('Rewel ringan'));
      await tester.tap(find.text('Rewel ringan'));
      await scrollTo(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await scrollTo(tester, find.text('Simpan Aktivitas'));
      await tester.tap(find.text('Simpan Aktivitas'));
      await tester.pumpAndSettle();

      final body = jsonDecode(backend.last('POST', '/activities').body) as Map<String, dynamic>;
      expect(body['child_id'], child().id);
      expect(body['activity_type'], 'bermain');
      expect(body['value'], containsPair('description', 'Main balok bersama'));
      expect(body['value'], containsPair('mood_before', 'biasa'));
      expect(body['value'], containsPair('mood_after', 'senang'));
      expect(body['value'], containsPair('fussy_level', 1));
      expect(body['value'], containsPair('tantrum_count', 1));
      expect(body['value'], containsPair('status', 'selesai'));
      expect(DateTime.parse(body['value']['event_at'] as String).isUtc, true);
    });
  });

  testWidgets('delegate must attach a photo for categories that require proof', (tester) async {
    await run(tester, ActivityFormScreen(child: child(), isDelegate: true), () async {
      await tester.tap(find.text('Makan'));
      await tester.pump();
      await scrollTo(tester, find.text('Foto bukti (wajib)'));
      await scrollTo(tester, find.text('Simpan Aktivitas'));
      await tester.tap(find.text('Simpan Aktivitas'));
      await tester.pump();
      expect(find.textContaining('wajib menyertakan foto bukti'), findsOneWidget);
      expect(backend.requests.where((request) => request.method == 'POST'), isEmpty);
    });
  });

  testWidgets('behavior tracking shows patterns and can switch period', (tester) async {
    await run(tester, BehaviorScreen(child: child()), () async {
      expect(find.textContaining('Mood anak cenderung lebih positif setelah aktivitas bermain'), findsOneWidget);
      expect(find.text('Pola yang terbaca'), findsOneWidget);
      await tester.tap(find.text('90 hari'));
      await tester.pumpAndSettle();
      expect(backend.last('GET', '/api/behavior-tracking/').url.queryParameters['days'], '90');
      await scrollTo(tester, find.textContaining('bukan diagnosis'));
    });
  });

  testWidgets('development monitoring saves an indicator status', (tester) async {
    await run(tester, DevelopmentScreen(child: child()), () async {
      for (final aspect in ['Motorik', 'Bahasa']) {
        expect(find.text(aspect), findsOneWidget);
      }
      await tester.tap(find.text('Belum terlihat').first);
      await tester.pumpAndSettle();
      final request = backend.last('PUT', '/api/development/');
      expect(jsonDecode(request.body), {'status': 'belum_terlihat'});
      expect(request.url.path, matches(RegExp(r'/items/\d+$')));
    });
  });

  testWidgets('monthly report shows every section and reports email failure honestly', (tester) async {
    await run(tester, MonthlyReportScreen(child: child()), () async {
      expect(find.textContaining('Imunisasi tercatat: 1 dari 2'), findsOneWidget);
      expect(find.textContaining('Kurva WHO BB/U: z-score -0,26. Di antara -2 SD dan +2 SD'), findsOneWidget);
      for (final section in ['Pertumbuhan dan kesehatan', 'Kinerja Delegasi', 'AI Insight', 'AI Recommendation', 'Perkembangan', 'Aktivitas dan perilaku']) {
        await scrollTo(tester, find.text(section));
      }
      expect(find.text('Download PDF'), findsOneWidget);
      await tester.tap(find.text('Kirim ke Email'));
      await tester.pumpAndSettle();
      expect(find.textContaining('belum dikonfigurasi di server'), findsOneWidget);
      expect(backend.last('POST', '/api/monthly-report/').url.path, endsWith('/email'));
    });
  });

  testWidgets('delegation screen lists invitations and their tokens', (tester) async {
    await run(tester, const DelegationScreen(), () async {
      expect(find.text('Mbak Tini'), findsOneWidget);
      expect(find.text('Token belum dipakai'), findsOneWidget);
      expect(find.textContaining('PATARA-'), findsOneWidget);
      expect(find.text('Undang Delegasi'), findsOneWidget);
    });
  });

  testWidgets('delegate only gets activity logging and account', (tester) async {
    const status = BackendConnectionStatus(connected: true, message: '', approved: true, childId: 'c', childName: 'Raka');
    await run(tester, const DelegateShell(status: status), () async {
      expect(find.text('Raka'), findsOneWidget);
      expect(find.text('Catat'), findsOneWidget);
      expect(find.byTooltip('Hapus catatan'), findsNothing);
      for (final hidden in ['Laporan Bulanan', 'Jadwal', 'AI Chat', 'Perkembangan']) {
        expect(find.text(hidden), findsNothing);
      }
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      expect(find.text('Delegasi'), findsOneWidget);
      expect(find.textContaining('Undang, setujui'), findsNothing);
    });
  });

  testWidgets('an expired session is refreshed and the request retried', (tester) async {
    BackendApiService.resetForTest();
    SharedPreferences.setMockInitialValues({
      'backend_auth_token': 'old',
      'backend_refresh_token': 'refresh-1',
    });
    var calls = 0;
    await http.runWithClient(() async {
      final data = await BackendApiService.requestJson('GET', '/api/activity-categories');
      expect((data as Map)['categories'], isNotEmpty);
    }, () => MockClient((request) async {
      if (request.url.path == '/api/refresh') {
        return http.Response('{"access_token":"new","refresh_token":"refresh-2"}', 200);
      }
      calls++;
      return request.headers['Authorization'] == 'Bearer new'
          ? http.Response(backend.fixture('activity_categories'), 200)
          : http.Response('{"error":"Unauthorized"}', 401);
    }));
    expect(calls, 2);
  });
}
