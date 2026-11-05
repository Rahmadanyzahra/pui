import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import '../services/platform_files.dart';

class ActivityCategory {
  final String key;
  final String label;
  final bool requiresPhoto;

  /// Kelompok usia yang memakai kategori ini (mis. 'baby'); null berarti semua usia.
  final String? ageGroup;

  const ActivityCategory(this.key, this.label, this.requiresPhoto, {this.ageGroup});

  IconData get icon => switch (key) {
    'menyusu' => Icons.water_drop_outlined,
    'popok' => Icons.baby_changing_station,
    'tengkurap' => Icons.accessibility_new,
    'makan' => Icons.restaurant,
    'tidur' => Icons.bedtime,
    'bermain' => Icons.toys,
    'belajar' => Icons.menu_book,
    'mandi' => Icons.bathtub,
    'bersama_orang_tua' => Icons.family_restroom,
    _ => Icons.event_note,
  };
}

class Choice {
  final String key;
  final String label;

  const Choice(this.key, this.label);
}

class FormOptions {
  final List<ActivityCategory> categories;
  final List<Choice> moods;
  final List<String> fussyLevels;

  /// Isian khusus aktivitas makan: porsi yang dihabiskan dan kelompok pangan.
  final List<Choice> mealPortions;
  final List<Choice> foodGroups;

  const FormOptions(
    this.categories,
    this.moods,
    this.fussyLevels, {
    this.mealPortions = const [],
    this.foodGroups = const [],
  });

  /// Ringkasan isian makan, misalnya "Habis • Makanan pokok, Sayur".
  String mealLabel(Map<String, dynamic>? meal) {
    if (meal == null) return '';
    String label(List<Choice> choices, Object? key) => choices
        .firstWhere((item) => item.key == key, orElse: () => Choice('$key', '$key'))
        .label;
    final groups = [
      for (final key in (meal['food_groups'] as List? ?? const [])) label(foodGroups, key),
    ];
    return [
      if (meal['portion'] != null) label(mealPortions, meal['portion']),
      if (groups.isNotEmpty) groups.join(', '),
    ].join(' • ');
  }

  String categoryLabel(String key) => categories
      .firstWhere(
        (item) => item.key == key,
        orElse: () => ActivityCategory(key, key, false),
      )
      .label;

  IconData categoryIcon(String key) => ActivityCategory(key, key, false).icon;

  String moodLabel(String? key) => key == null
      ? '-'
      : moods
            .firstWhere((item) => item.key == key, orElse: () => Choice(key, key))
            .label;
}

const moodEmoji = {
  'senang': '😄',
  'tenang': '😌',
  'biasa': '😐',
  'sedih': '😢',
  'marah': '😠',
};

/// Satu catatan aktivitas terstruktur.
class ActivityLog {
  final String id;
  final String category;
  final DateTime at;
  final String description;
  final String? moodBefore;
  final String? moodAfter;
  final int? fussyLevel;
  final int tantrumCount;
  final String status;
  final String performerName;
  final String performerRole;
  final String? photoPath;
  final DateTime? photoExpiredAt;

  /// Status validasi laporan Delegasi: pending, confirmed, atau rejected.
  final String validationStatus;
  final String validationNote;

  /// Durasi aktivitas; [durationSource] 'timer' berarti dihitung server dari
  /// tombol Mulai sampai laporan dikirim, 'manual' berarti diketik pelapor.
  final int? durationMinutes;
  final String? durationSource;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final Map<String, dynamic>? meal;

  bool get fromDelegate => performerRole == 'delegasi';

  const ActivityLog({
    required this.id,
    required this.category,
    required this.at,
    required this.description,
    required this.moodBefore,
    required this.moodAfter,
    required this.fussyLevel,
    required this.tantrumCount,
    required this.status,
    required this.performerName,
    required this.performerRole,
    required this.photoPath,
    required this.photoExpiredAt,
    this.validationStatus = 'confirmed',
    this.validationNote = '',
    this.durationMinutes,
    this.durationSource,
    this.startedAt,
    this.endedAt,
    this.meal,
  });

  /// Null untuk baris yang bukan catatan aktivitas (misalnya catatan sistem lama).
  static ActivityLog? fromRecord(BackendActivityRecord record, Set<String> keys) {
    if (!keys.contains(record.activityType)) return null;
    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(record.value);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Catatan lama tanpa struktur tetap ditampilkan dengan nilai kosong.
    }
    final at =
        DateTime.tryParse((data['event_at'] ?? record.createdAt).toString()) ??
        DateTime.now();
    return ActivityLog(
      id: record.id,
      category: record.activityType,
      at: at.toLocal(),
      description: (data['description'] ?? '').toString(),
      moodBefore: data['mood_before'] as String?,
      moodAfter: data['mood_after'] as String?,
      fussyLevel: (data['fussy_level'] as num?)?.toInt(),
      tantrumCount: (data['tantrum_count'] as num?)?.toInt() ?? 0,
      status: (data['status'] ?? 'selesai').toString(),
      performerName: (data['performer_name'] ?? '').toString(),
      performerRole: (data['performer_role'] ?? 'orang_tua').toString(),
      photoPath: record.photoPath,
      photoExpiredAt: DateTime.tryParse(record.photoExpiredAt ?? ''),
      validationStatus: (data['validation_status'] ?? 'confirmed').toString(),
      validationNote: (data['validation_note'] ?? '').toString(),
      durationMinutes: (data['duration_minutes'] as num?)?.toInt(),
      durationSource: data['duration_source'] as String?,
      startedAt: DateTime.tryParse('${data['started_at']}')?.toLocal(),
      endedAt: DateTime.tryParse('${data['ended_at']}')?.toLocal(),
      meal: data['meal'] is Map ? Map<String, dynamic>.from(data['meal'] as Map) : null,
    );
  }
}

class PataraApi {
  static FormOptions? _options;
  static DateTime? _optionsAt;

  // Kategori diatur admin (nama, wajib foto, aktif); salinannya dipakai paling lama 1 menit
  // supaya perubahan dari panel admin cepat terlihat tanpa membuka ulang aplikasi.
  static Future<FormOptions> formOptions({bool refresh = false}) async {
    final fresh = _optionsAt != null && DateTime.now().difference(_optionsAt!) < const Duration(minutes: 1);
    if (_options != null && !refresh && fresh) return _options!;
    _optionsAt = DateTime.now();
    final data =
        await BackendApiService.requestJson('GET', '/api/activity-categories')
            as Map<String, dynamic>;
    return _options = FormOptions(
      [
        for (final item in data['categories'] as List)
          ActivityCategory(
            item['key'] as String,
            item['label'] as String,
            item['requires_photo'] == true,
            ageGroup: item['age_group'] as String?,
          ),
      ],
      [
        for (final item in data['moods'] as List)
          Choice(item['key'] as String, item['label'] as String),
      ],
      [for (final item in data['fussy_levels'] as List) item['label'] as String],
      mealPortions: [
        for (final item in data['meal_portions'] as List? ?? const [])
          Choice(item['key'] as String, item['label'] as String),
      ],
      foodGroups: [
        for (final item in data['food_groups'] as List? ?? const [])
          Choice(item['key'] as String, item['label'] as String),
      ],
    );
  }

  /// Timer aktivitas Delegasi yang sedang berjalan, atau null.
  static Future<Map<String, dynamic>?> activeSession() async {
    final data =
        await BackendApiService.requestJson('GET', '/api/activity-sessions/active')
            as Map<String, dynamic>;
    final session = data['session'];
    return session is Map ? Map<String, dynamic>.from(session) : null;
  }

  /// Memulai timer; jam mulai dicatat server dan Orang Tua diberi tahu.
  static Future<Map<String, dynamic>> startSession(String category) async {
    final data =
        await BackendApiService.requestJson(
              'POST',
              '/api/activity-sessions',
              body: {'category': category},
            )
            as Map<String, dynamic>;
    return Map<String, dynamic>.from(data['session'] as Map);
  }

  static Future<void> cancelSession(String id) =>
      BackendApiService.send('DELETE', '/api/activity-sessions/$id');

  /// Saran aktivitas di luar aplikasi dan panduan gizi sesuai usia, beserta sumbernya.
  static Future<Map<String, dynamic>> guidance(String childId) async =>
      await BackendApiService.requestJson('GET', '/api/guidance/$childId')
          as Map<String, dynamic>;

  /// SPK AHP-SAW: rekomendasi ide aktivitas. [pairwise] berisi 6 nilai skala Saaty (C1-C2 ... C3-C4).
  static Future<Map<String, dynamic>> spkActivityIdeas(String childId, List<double> pairwise) async =>
      await BackendApiService.requestJson('POST', '/api/spk/activity-ideas/$childId', body: {'pairwise': pairwise})
          as Map<String, dynamic>;

  /// SPK AHP-SAW: waktu terbaik melakukan satu kegiatan ([category] = kunci kategori aktivitas).
  static Future<Map<String, dynamic>> spkBestTime(String childId, String category, List<double> pairwise) async =>
      await BackendApiService.requestJson('POST', '/api/spk/best-time/$childId', body: {'category': category, 'pairwise': pairwise})
          as Map<String, dynamic>;

  /// Pola anak yang sudah terbuka dari catatan dan misi berikutnya.
  static Future<Map<String, dynamic>> discovery(String childId) async =>
      await BackendApiService.requestJson('GET', '/api/discovery/$childId')
          as Map<String, dynamic>;

  /// Ringkasan perawatan bayi hari ini beserta anjuran rujukannya.
  static Future<Map<String, dynamic>> babyCare(String childId) async =>
      await BackendApiService.requestJson('GET', '/api/baby-care/$childId')
          as Map<String, dynamic>;

  /// Dokumen persetujuan penelitian dan apakah pengguna ini sudah menyetujuinya.
  static Future<Map<String, dynamic>> consent() async =>
      await BackendApiService.requestJson('GET', '/api/consent')
          as Map<String, dynamic>;

  static Future<void> agreeConsent(String version) =>
      BackendApiService.send(
        'POST',
        '/api/consent',
        body: {'agree': true, 'version': version},
      );

  static void clearCache() => _options = null;

  static Future<List<ActivityLog>> activityLogs(String childId) async {
    final options = await formOptions();
    final records = await BackendApiService.getActivities(childId: childId);
    final keys = options.categories.map((item) => item.key).toSet();
    final logs = [
      for (final record in records) ?ActivityLog.fromRecord(record, keys),
    ];
    logs.sort((a, b) => b.at.compareTo(a.at));
    return logs;
  }

  static Future<bool> saveActivity({
    required String childId,
    required String category,
    required Map<String, dynamic> data,
    String? photoPath,
  }) async {
    final response =
        await BackendApiService.requestJson(
              'POST',
              '/activities',
              body: {'child_id': childId, 'activity_type': category, 'value': data},
              filePath: photoPath,
            )
            as Map<String, dynamic>;
    return response['photo_upload_failed'] != true;
  }

  static Future<void> deleteActivity(String id) =>
      BackendApiService.send('DELETE', '/api/activity-logs/$id');

  /// Laporan Delegasi yang menunggu validasi Orang Tua.
  static Future<List<Map<String, dynamic>>> pendingValidations() async {
    final data =
        await BackendApiService.requestJson('GET', '/api/activity-validations')
            as Map<String, dynamic>;
    return [
      for (final item in data['items'] as List) Map<String, dynamic>.from(item),
    ];
  }

  static Future<void> validateActivity(
    String id, {
    required bool confirm,
    String note = '',
  }) => BackendApiService.send(
    'PATCH',
    '/api/activity-logs/$id/validation',
    body: {'action': confirm ? 'confirm' : 'reject', 'note': note},
  );

  static Future<Map<String, dynamic>> health(String childId) async =>
      await BackendApiService.requestJson('GET', '/api/health/$childId')
          as Map<String, dynamic>;

  /// Mencatat imunisasi ([vaccineKey] diisi) atau catatan kesehatan lain.
  static Future<void> addHealth(
    String childId, {
    required String recordType,
    String? vaccineKey,
    String title = '',
    required DateTime date,
    String notes = '',
  }) => BackendApiService.send(
    'POST',
    '/api/health/$childId',
    body: {
      'record_type': recordType,
      'vaccine_key': vaccineKey,
      'title': title,
      'record_date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'notes': notes,
    },
  );

  static Future<void> deleteHealth(String childId, Object id) =>
      BackendApiService.send('DELETE', '/api/health/$childId/$id');

  /// Rekap kinerja Delegasi untuk satu bulan (YYYY-MM).
  static Future<Map<String, dynamic>> delegateRecap(String month) async =>
      await BackendApiService.requestJson(
            'GET',
            '/api/delegate-recap?month=$month',
          )
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> growth(String childId) async =>
      await BackendApiService.requestJson('GET', '/api/growth/$childId')
          as Map<String, dynamic>;

  static Future<void> addGrowth(
    String childId, {
    required double weightKg,
    required double heightCm,
    double? headCm,
    required DateTime measuredAt,
  }) => BackendApiService.send(
    'POST',
    '/api/growth/$childId',
    body: {
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'head_circumference_cm': headCm,
      'measured_at': measuredAt.toUtc().toIso8601String(),
    },
  );

  static Future<void> deleteGrowth(String childId, Object id) =>
      BackendApiService.send('DELETE', '/api/growth/$childId/$id');

  static Future<Uint8List> photoBytes(String photoPath) async =>
      (await BackendApiService.send('GET', photoPath)).bodyBytes;

  static Future<Map<String, dynamic>> behavior(String childId, int days) async =>
      await BackendApiService.requestJson(
            'GET',
            '/api/behavior-tracking/$childId?days=$days',
          )
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> development(String childId) async =>
      await BackendApiService.requestJson('GET', '/api/development/$childId')
          as Map<String, dynamic>;

  static Future<void> saveDevelopmentItem(
    String childId,
    Object standardId,
    String status,
  ) => BackendApiService.send(
    'PUT',
    '/api/development/$childId/items/$standardId',
    body: {'status': status},
  );

  static Future<Map<String, dynamic>> monthlyReport(
    String childId,
    String month,
  ) async =>
      await BackendApiService.requestJson(
            'GET',
            '/api/monthly-report/$childId?month=$month',
          )
          as Map<String, dynamic>;

  /// Mengunduh PDF laporan dan mengembalikan lokasi berkasnya di perangkat.
  static Future<String> downloadMonthlyReport(
    String childId,
    String month,
    String childName,
  ) async {
    final response = await BackendApiService.send(
      'GET',
      '/api/monthly-report/$childId/pdf?month=$month',
    );
    final safeName = childName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return saveDownloadedFile(response.bodyBytes, 'Laporan_TARA_${safeName}_$month.pdf');
  }

  static Future<String> emailMonthlyReport(String childId, String month) async {
    final data =
        await BackendApiService.requestJson(
              'POST',
              '/api/monthly-report/$childId/email',
              body: {'month': month},
            )
            as Map<String, dynamic>;
    return (data['email'] ?? '').toString();
  }

  static Future<List<Map<String, dynamic>>> schedules(String childId) async {
    final data =
        await BackendApiService.requestJson(
              'GET',
              '/api/schedules?child_id=$childId',
            )
            as Map<String, dynamic>;
    return [
      for (final item in data['items'] as List) Map<String, dynamic>.from(item),
    ];
  }

  static Future<Map<String, dynamic>> createSchedule({
    required String childId,
    required String title,
    required String category,
    required DateTime reminderTime,
    required String repeatRule,
    String description = '',
  }) async =>
      await BackendApiService.requestJson(
            'POST',
            '/api/schedules',
            body: {
              'child_id': childId,
              'title': title,
              'category': category,
              'reminder_time': reminderTime.toUtc().toIso8601String(),
              'repeat_rule': repeatRule,
              if (description.isNotEmpty) 'description': description,
            },
          )
          as Map<String, dynamic>;

  static Future<void> setScheduleDone(String id, DateTime date, bool done) =>
      BackendApiService.send(
        'PATCH',
        '/api/schedules/$id/status',
        body: {
          'date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'done': done,
        },
      );

  static Future<void> deleteSchedule(String id) =>
      BackendApiService.send('DELETE', '/api/schedules/$id');

  /// [history] berisi giliran sebelumnya di layar chat: {role: user|assistant, content}.
  /// Bila pesan berupa cerita aktivitas, [ChatReply.draft] berisi draf catatan
  /// yang perlu dikonfirmasi orang tua sebelum disimpan.
  static Future<ChatReply> chat(
    String message,
    String? childId, {
    List<Map<String, String>> history = const [],
  }) async {
    final data =
        await BackendApiService.requestJson(
              'POST',
              '/api/ai-chat',
              body: {'message': message, 'child_id': ?childId, 'history': history},
              timeout: const Duration(seconds: 60),
            )
            as Map<String, dynamic>;
    final draft = data['activity_draft'];
    return ChatReply(
      (data['reply'] ?? '').toString(),
      draft is Map ? Map<String, dynamic>.from(draft) : null,
    );
  }
}

class ChatReply {
  final String text;
  final Map<String, dynamic>? draft;

  const ChatReply(this.text, this.draft);
}
