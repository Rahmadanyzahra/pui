import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/backend_connection.dart';
import '../models/backend_analytics.dart';
import '../utils/child_age.dart';

class BackendChild {
  final String id;
  final String nama;
  final int umur;
  final DateTime? birthDate;
  final String category;
  final String ageFormatted;
  final String? gender;

  const BackendChild({
    required this.id,
    required this.nama,
    required this.umur,
    this.birthDate,
    this.category = 'di_luar_rentang',
    this.ageFormatted = '',
    this.gender,
  });

  String get categoryLabel => switch (category) {
    'baby' => 'Bayi',
    'toddler' => 'Toddler',
    'balita' => 'Balita',
    _ => 'Di luar rentang',
  };

  /// Usia ringkas untuk tampilan, misalnya "2 tahun 4 bulan".
  String get ageLabel {
    final age = birthDate == null ? null : ChildAge.calculate(birthDate!);
    if (age == null) return '$umur tahun';
    if (age.years == 0) return '${age.months} bulan ${age.days} hari';
    return '${age.years} tahun ${age.months} bulan';
  }

  factory BackendChild.fromJson(Map<String, dynamic> json) {
    DateTime? birthDate;
    final birthValue = (json['birth_date'] as String?)?.trim();
    if (birthValue != null && birthValue.isNotEmpty) {
      birthDate = DateTime.tryParse(birthValue);
    }

    final age = birthDate == null ? null : ChildAge.calculate(birthDate);
    final umur = (json['umur'] as num?)?.toInt() ?? age?.years ?? 0;
    return BackendChild(
      id: (json['id'] ?? '').toString(),
      nama: (json['nama'] as String?) ?? 'Child',
      umur: umur,
      birthDate: birthDate,
      category:
          (json['category'] as String?) ??
          age?.category ??
          ChildAge.categoryForAge(umur),
      ageFormatted:
          (json['age_formatted'] as String?) ??
          age?.formatted ??
          '$umur tahun 0 bulan 0 hari',
      gender: (json['gender'] as String?)?.trim(),
    );
  }
}

/// Status mode pemeliharaan yang dinyalakan admin; selama ada, aplikasi menampilkan layar pemeliharaan.
class MaintenanceInfo {
  final String message;
  final DateTime? until;

  const MaintenanceInfo(this.message, this.until);

  factory MaintenanceInfo.fromJson(Map json) => MaintenanceInfo(
        (json['message'] ?? 'TARA sedang dalam pemeliharaan. Silakan coba lagi beberapa saat lagi.').toString(),
        DateTime.tryParse((json['until'] ?? '').toString())?.toLocal(),
      );
}

/// Kesalahan dari backend dengan pesan yang layak ditampilkan ke pengguna.
class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class BackendCaptchaChallenge {
  final String sessionId;
  final String question;
  final bool disabled;
  final bool enabled;
  final String type;
  final String siteKey;

  const BackendCaptchaChallenge({
    required this.sessionId,
    required this.question,
    this.disabled = false,
    this.enabled = false,
    this.type = 'legacy',
    this.siteKey = '',
  });

  factory BackendCaptchaChallenge.fromJson(Map<String, dynamic> json) {
    return BackendCaptchaChallenge(
      sessionId: (json['session_id'] as String?) ?? '',
      question: (json['question'] as String?) ?? '',
      disabled: (json['disabled'] as bool?) ?? false,
      enabled: (json['enabled'] as bool?) ?? false,
      type: (json['type'] as String?) ?? 'legacy',
      siteKey: (json['site_key'] as String?) ?? '',
    );
  }
}

class BackendUser {
  // ID bisa berupa angka (skema lama) atau UUID (MySQL), jadi disimpan sebagai teks.
  final String id;
  final String email;
  final String role;

  const BackendUser({
    required this.id,
    required this.email,
    required this.role,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'orang_tua',
    );
  }
}

class BackendGrowthRecord {
  final int id;
  final String childId;
  final double heightCm;
  final double weightKg;
  final double headCircumferenceCm;
  final String immunizationNotes;
  final String milestonesNotes;
  final String createdAt;

  const BackendGrowthRecord({
    required this.id,
    required this.childId,
    required this.heightCm,
    required this.weightKg,
    required this.headCircumferenceCm,
    required this.immunizationNotes,
    required this.milestonesNotes,
    required this.createdAt,
  });

  factory BackendGrowthRecord.fromJson(Map<String, dynamic> json) {
    return BackendGrowthRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      childId: (json['child_id'] ?? '').toString(),
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? 0,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      headCircumferenceCm:
          (json['head_circumference_cm'] as num?)?.toDouble() ?? 0,
      immunizationNotes: (json['immunization_notes'] as String?) ?? '',
      milestonesNotes: (json['milestones_notes'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
}

class BackendFoodItem {
  final String name;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  const BackendFoodItem({
    required this.name,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
  });

  factory BackendFoodItem.fromJson(Map<String, dynamic> json) {
    return BackendFoodItem(
      name: (json['name'] as String?) ?? (json['food_name'] as String?) ?? '',
      calories: (json['calories'] as num?)?.toDouble(),
      protein: (json['protein_g'] as num?)?.toDouble(),
      carbs: (json['carbs_g'] as num?)?.toDouble(),
      fat: (json['fat_g'] as num?)?.toDouble(),
    );
  }
}

class BackendActivityRecord {
  final String id;
  final String? childId;
  final String activityType;
  final String value;
  final String createdAt;
  final String? photoPath;
  final String? photoCreatedAt;
  final String? photoExpiredAt;

  const BackendActivityRecord({
    required this.id,
    required this.childId,
    required this.activityType,
    required this.value,
    required this.createdAt,
    this.photoPath,
    this.photoCreatedAt,
    this.photoExpiredAt,
  });

  factory BackendActivityRecord.fromJson(Map<String, dynamic> json) {
    return BackendActivityRecord(
      id: (json['id'] ?? '').toString(),
      childId: json['child_id']?.toString(),
      activityType: (json['activity_type'] as String?) ?? 'activity',
      value: (json['value'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
      photoPath: json['photo_path']?.toString(),
      photoCreatedAt: json['photo_created_at']?.toString(),
      photoExpiredAt: json['photo_expired_at']?.toString(),
    );
  }
}

class BackendApiService {
  static const _kBaseUrlKey = 'backend_base_url';
  static const _kSessionCookieKey = 'backend_session_cookie';
  static const _kAuthTokenKey = 'backend_auth_token';
  static const _kRefreshTokenKey = 'backend_refresh_token';
  static const _kLastEmailKey = 'backend_last_email';
  static const _kPasswordKey = 'backend_password_enc';
  static const _kPasswordTimestampKey = 'backend_password_timestamp';
  // Diisi saat masuk dengan password sementara dari email; dihapus setelah password baru disimpan.
  static const _kMustChangePasswordKey = 'backend_must_change_password';
  static const _kRequestTimeout = Duration(seconds: 15);

  static const _secureStorage = FlutterSecureStorage();

  static bool _initialized = false;
  static String baseUrl = _resolveDefaultBaseUrl();

  static String? _sessionCookie;
  static String? _authToken;
  static String? _refreshToken;
  static String? _lastEmail;

  // Alamat server yang ditanam saat APK dibangun:
  //   flutter build apk --dart-define=TARA_SERVER_URL=https://alamat-server
  // Bila kosong, dipakai alamat bawaan untuk pengembangan di bawah ini.
  static const _builtInServer = String.fromEnvironment('TARA_SERVER_URL');

  static String _resolveDefaultBaseUrl() {
    if (_builtInServer.isNotEmpty) return _builtInServer;
    if (kIsWeb) {
      // Versi web disajikan oleh server yang sama, jadi alamat server adalah alamat halaman itu sendiri.
      return Uri.base.origin;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Emulator Android harus memakai localhost PC via 10.0.2.2.
        return 'http://10.0.2.2:5000';
      default:
        return 'http://127.0.0.1:5000';
    }
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    final savedBaseUrl = prefs.getString(_kBaseUrlKey);
    if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
      baseUrl = savedBaseUrl == 'http://192.168.137.67:5000'
          ? _resolveDefaultBaseUrl()
          : savedBaseUrl;
      if (baseUrl != savedBaseUrl) {
        await prefs.setString(_kBaseUrlKey, baseUrl);
      }
    }

    _sessionCookie = prefs.getString(_kSessionCookieKey);
    _authToken = prefs.getString(_kAuthTokenKey);
    _refreshToken = prefs.getString(_kRefreshTokenKey);
    _lastEmail = prefs.getString(_kLastEmailKey);
    _initialized = true;
  }

  /// Mengosongkan sesi di memori agar tes dapat memuat ulang keadaan tersimpan.
  @visibleForTesting
  static void resetForTest() {
    _initialized = false;
    _sessionCookie = null;
    _authToken = null;
    _refreshToken = null;
    _lastEmail = null;
  }

  static Future<void> setBaseUrl(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    baseUrl = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    await _persistState();
  }

  static String? get lastEmail => _lastEmail;

  static bool _refreshing = false;

  // Access token hanya berlaku 15 menit; periksa masa berlakunya dari isi token.
  static bool _accessTokenExpiresSoon() {
    final parts = (_authToken ?? '').split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = ((payload as Map)['exp'] as num?)?.toInt();
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 30;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>> _headers({bool withJson = true}) async {
    if (!_refreshing && _accessTokenExpiresSoon()) {
      _refreshing = true;
      try {
        await refreshSession();
      } catch (_) {
        // Permintaan tetap dikirim; backend akan menjawab 401 bila sesi habis.
      } finally {
        _refreshing = false;
      }
    }
    // ngrok gratis menyelipkan halaman peringatan untuk permintaan mirip peramban; header ini melewatinya.
    final headers = <String, String>{'ngrok-skip-browser-warning': '1'};
    if (withJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    } else if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
  }

  static String _extractSessionCookie(http.Response res) {
    final raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return '';
    return raw.split(';').first;
  }

  static String? _extractToken(http.Response res) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        // Support different backend field names: `token` (legacy) or `access_token` (current)
        final token = (data['token'] ?? data['access_token'])?.toString();
        if (token != null && token.trim().isNotEmpty) {
          return token.trim();
        }
      }
    } catch (_) {
      // Ignore non-JSON responses.
    }
    return null;
  }

  // ---------- Mode pemeliharaan ----------
  /// Berisi info pemeliharaan selama admin menutup aplikasi; null bila aplikasi dapat dipakai.
  static final ValueNotifier<MaintenanceInfo?> maintenance = ValueNotifier<MaintenanceInfo?>(null);

  /// Jawaban 503 bertanda `maintenance` dari server menyalakan layar pemeliharaan.
  /// Dipanggil oleh ketiga pembentuk pesan kesalahan, sehingga berlaku untuk semua permintaan.
  static void _noteMaintenance(http.Response res) {
    if (res.statusCode != 503) return;
    try {
      final parsed = jsonDecode(res.body);
      if (parsed is Map && parsed['maintenance'] == true) maintenance.value = MaintenanceInfo.fromJson(parsed);
    } catch (_) {
      // Bukan jawaban pemeliharaan.
    }
  }

  /// Menanyakan status pemeliharaan ke server (tanpa login). Mengembalikan true bila sedang pemeliharaan.
  /// Bila server tidak terjangkau, status sebelumnya dipertahankan.
  static Future<bool> checkMaintenance() async {
    await initialize();
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/maintenance'), headers: {'ngrok-skip-browser-warning': '1'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        maintenance.value = parsed is Map && parsed['enabled'] == true ? MaintenanceInfo.fromJson(parsed) : null;
      }
    } catch (_) {
      // Tidak terhubung; layar lain yang menampilkan pesan koneksi.
    }
    return maintenance.value != null;
  }

  static String _buildHttpError(String context, http.Response res) {
    _noteMaintenance(res);
    final raw = res.body.trim();
    if (raw.isEmpty) {
      return '$context (${res.statusCode}): empty response';
    }

    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        final message = (parsed['error'] ?? parsed['message'])?.toString();
        if (message != null && message.isNotEmpty) {
          return '$context (${res.statusCode}): $message';
        }
      }
    } catch (_) {
      // Fall back to plain body if response isn't JSON.
    }

    final short = raw.length > 220 ? '${raw.substring(0, 220)}...' : raw;
    return '$context (${res.statusCode}): $short';
  }

  static String _buildRoleHttpError(String context, http.Response res) {
    _noteMaintenance(res);
    String backendError = '';
    try {
      final parsed = jsonDecode(res.body);
      if (parsed is Map<String, dynamic>) {
        backendError = (parsed['error'] ?? parsed['message'] ?? '')
            .toString()
            .toLowerCase();
      }
    } catch (_) {
      // Never surface raw backend responses to users.
    }

    late final String message;
    if (backendError.contains('captcha') ||
        backendError.contains('turnstile')) {
      message = 'Verifikasi CAPTCHA gagal. Coba lagi.';
    } else if (backendError.contains('invalid_credentials')) {
      message = 'Nama, email, atau password tidak cocok.';
    } else if (backendError.contains('email_exists')) {
      message = 'Email sudah terdaftar.';
    } else if (backendError.contains('token') ||
        backendError.contains('undangan')) {
      message = 'Token tidak valid atau undangan sudah tidak berlaku.';
    } else if (backendError.contains('menunggu persetujuan')) {
      message = 'Akses Delegasi menunggu persetujuan Orang Tua.';
    } else if (backendError.contains('not_found') ||
        backendError.contains('tidak ditemukan')) {
      message = 'Data tidak ditemukan atau akses tidak tersedia.';
    } else if (backendError.contains('akses') ||
        backendError.contains('role') ||
        res.statusCode == 403) {
      message = 'Akses ditolak untuk akun ini.';
    } else if (res.statusCode == 401) {
      message = 'Login atau verifikasi gagal.';
    } else if (res.statusCode == 400) {
      message = 'Periksa kembali data yang dimasukkan.';
    } else if (res.statusCode == 409) {
      message = 'Permintaan tidak dapat diproses saat ini.';
    } else if (res.statusCode >= 500) {
      message = 'Terjadi kesalahan server. Silakan coba lagi.';
    } else {
      message = 'Terjadi kesalahan. Silakan coba lagi.';
    }
    return '$context: $message';
  }

  static Future<void> _deletePasswordSecurely() async {
    try {
      await _secureStorage.delete(key: _kPasswordKey);
    } catch (_) {
      // Ignore secure storage cleanup failures.
    }
  }

  static bool isConnectionIssue(Object error) {
    if (error is TimeoutException) return true;

    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection refused') ||
        message.contains('network is unreachable') ||
        message.contains('timed out') ||
        message.contains('xmlhttprequest error') ||
        message.contains('clientexception') ||
        message.contains('connection closed');
  }

  static String backendUrlHint() {
    if (kIsWeb) {
      return 'Web lokal: gunakan http://127.0.0.1:5000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Android emulator: gunakan http://10.0.2.2:5000. HP fisik: gunakan IP LAN PC yang mengarah ke backend lokal.';
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'iOS Simulator: gunakan http://127.0.0.1:5000. iPhone fisik: gunakan IP LAN komputer yang menjalankan backend.';
    }

    return 'Desktop lokal: gunakan http://127.0.0.1:5000. HP fisik: gunakan IP LAN PC.';
  }

  static bool get hasSession =>
      (_sessionCookie != null && _sessionCookie!.isNotEmpty) ||
      (_authToken != null && _authToken!.isNotEmpty) ||
      (_refreshToken != null && _refreshToken!.isNotEmpty);

  static Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrlKey, baseUrl);
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      await prefs.setString(_kSessionCookieKey, _sessionCookie!);
    } else {
      await prefs.remove(_kSessionCookieKey);
    }
    if (_authToken != null && _authToken!.isNotEmpty) {
      await prefs.setString(_kAuthTokenKey, _authToken!);
    } else {
      await prefs.remove(_kAuthTokenKey);
    }
    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      await prefs.setString(_kRefreshTokenKey, _refreshToken!);
    } else {
      await prefs.remove(_kRefreshTokenKey);
    }
    if (_lastEmail != null && _lastEmail!.isNotEmpty) {
      await prefs.setString(_kLastEmailKey, _lastEmail!);
    } else {
      await prefs.remove(_kLastEmailKey);
    }
  }

  static Future<BackendCaptchaChallenge?> getLoginCaptcha() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/auth/captcha'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal ambil captcha', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return BackendCaptchaChallenge.fromJson(parsed);
  }

  static Future<bool> verifyLoginCaptcha({
    required String sessionId,
    required String answer,
  }) async {
    await initialize();
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/captcha/verify'),
          headers: await _headers(),
          body: jsonEncode({'session_id': sessionId, 'answer': answer}),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal verifikasi captcha', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return parsed['valid'] == true;
  }

  /// Mengembalikan true bila pengguna masuk dengan password sementara dan harus membuat password baru.
  static Future<bool> login({
    required String email,
    required String password,
    String? fullName,
    bool rememberPassword = true,
    String? captchaSessionId,
    String? captchaAnswer,
    String? turnstileToken,
  }) async {
    await initialize();
    _sessionCookie = null;
    _authToken = null;
    _refreshToken = null;
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/login'),
          headers: await _headers(),
          body: jsonEncode({
            'email': email,
            'password': password,
            if (fullName?.trim().isNotEmpty ?? false)
              'full_name': fullName!.trim(),
            if (captchaSessionId != null && captchaSessionId.isNotEmpty)
              'captcha_session_id': captchaSessionId,
            if (captchaAnswer != null && captchaAnswer.isNotEmpty)
              'captcha_answer': captchaAnswer,
            if (turnstileToken?.isNotEmpty ?? false)
              'turnstile_token': turnstileToken,
          }),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Login gagal', res));
    }

    final cookie = _extractSessionCookie(res);
    if (cookie.isNotEmpty) {
      _sessionCookie = cookie;
    }
    final parsed = jsonDecode(res.body) as Map<String, dynamic>;
    final token = _extractToken(res);
    final refreshToken = (parsed['refresh_token'] as String?)?.trim();
    if (token != null) {
      _authToken = token;
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
    _lastEmail = email.trim();
    // Password tidak disimpan di perangkat; sesi diperpanjang lewat refresh token.
    await _deletePasswordSecurely();
    await _persistState();
    final mustChange = parsed['must_change_password'] == true;
    final prefs = await SharedPreferences.getInstance();
    if (mustChange) {
      await prefs.setBool(_kMustChangePasswordKey, true);
    } else {
      await prefs.remove(_kMustChangePasswordKey);
    }
    return mustChange;
  }

  /// Masih harus membuat password baru (masuk dengan password sementara, lalu aplikasi sempat ditutup).
  static Future<bool> needsPasswordChange() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMustChangePasswordKey) ?? false;
  }

  /// [currentPassword] boleh password lama atau password sementara dari email.
  static Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await requestJson(
      'POST',
      '/api/account/password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMustChangePasswordKey);
  }

  static Future<void> registerUser({
    required String fullName,
    required String email,
    required String password,
    String phone = '',
    String role = 'orang_tua',
    int? childId,
    bool rememberPassword = true,
  }) async {
    await initialize();
    _sessionCookie = null;
    _authToken = null;
    _refreshToken = null;
    final body = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': role,
      'full_name': fullName.trim(),
      'phone': phone.trim(),
    };

    if (childId != null) {
      body['child_id'] = childId;
    }

    final res = await http
        .post(
          Uri.parse('$baseUrl/api/register'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Registrasi gagal', res));
    }

    final cookie = _extractSessionCookie(res);
    if (cookie.isNotEmpty) {
      _sessionCookie = cookie;
    }
    final parsed = jsonDecode(res.body) as Map<String, dynamic>;
    final token = _extractToken(res);
    final refreshToken = (parsed['refresh_token'] as String?)?.trim();
    if (token != null) {
      _authToken = token;
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
    _lastEmail = email.trim();
    // Password tidak disimpan di perangkat; sesi diperpanjang lewat refresh token.
    await _deletePasswordSecurely();
    await _persistState();
  }

  static Future<List<BackendChild>> getChildren() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/children'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal memuat data anak', res));
    }

    final parsed = jsonDecode(res.body) as List<dynamic>;
    return parsed
        .map((e) => BackendChild.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<BackendChild> getChild(Object childId) async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/children/$childId'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal memuat data anak', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return BackendChild.fromJson(parsed);
  }

  static const _genericErrors = {
    'internal_error',
    'not_found',
    'unauthorized',
    'forbidden',
  };

  static ApiException _apiError(http.Response res) {
    _noteMaintenance(res);
    String? detail;
    try {
      final parsed = jsonDecode(res.body);
      if (parsed is Map) detail = (parsed['error'] ?? parsed['message'])?.toString();
    } catch (_) {
      // Respons bukan JSON.
    }
    final readable =
        detail != null &&
        detail.contains(' ') &&
        !_genericErrors.contains(detail.toLowerCase());
    final message = readable
        ? detail
        : switch (res.statusCode) {
            401 => 'Sesi berakhir. Silakan login kembali.',
            403 => 'Akun ini tidak memiliki akses ke fitur tersebut.',
            404 => 'Data tidak ditemukan.',
            >= 500 => 'Server sedang bermasalah. Coba lagi beberapa saat.',
            _ => 'Permintaan tidak dapat diproses. Periksa kembali isian Anda.',
          };
    return ApiException(message, res.statusCode);
  }

  /// Permintaan umum ke backend. Melempar [ApiException] dengan pesan siap tampil.
  /// [filePath] mengirim permintaan sebagai multipart dengan berkas pada [fileField].
  /// Jenis berkas foto menurut ekstensinya. Tanpa ini unggahan terkirim sebagai
  /// application/octet-stream dan ditolak server.
  /// Berkas foto untuk diunggah. Di browser foto pilihan hanya berupa alamat sementara tanpa nama,
  /// jadi isinya dibaca lebih dulu lalu diberi nama.
  static Future<http.MultipartFile> _photoPart(String field, String path) async {
    if (!kIsWeb) {
      return http.MultipartFile.fromPath(field, path, contentType: imageMediaType(path));
    }
    final bytes = await XFile(path).readAsBytes();
    return http.MultipartFile.fromBytes(field, bytes, filename: 'foto.jpg', contentType: MediaType('image', 'jpeg'));
  }

  static MediaType? imageMediaType(String path) {
    return switch (path.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => null,
    };
  }

  static Future<http.Response> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? filePath,
    String fileField = 'photo',
    Duration timeout = _kRequestTimeout,
  }) async {
    await initialize();
    Future<http.Response> attempt() async {
      final uri = Uri.parse('$baseUrl$path');
      if (filePath != null && filePath.isNotEmpty) {
        final request = http.MultipartRequest(method, uri);
        request.headers.addAll(await _headers(withJson: false));
        (body ?? const {}).forEach((key, value) {
          request.fields[key] = value is String ? value : jsonEncode(value);
        });
        request.files.add(await _photoPart(fileField, filePath));
        return http.Response.fromStream(
          await request.send().timeout(const Duration(seconds: 60)),
        );
      }
      final request = http.Request(method, uri);
      request.headers.addAll(await _headers(withJson: body != null));
      if (body != null) request.body = jsonEncode(body);
      return http.Response.fromStream(await request.send().timeout(timeout));
    }

    http.Response res;
    try {
      res = await attempt();
      if (res.statusCode == 401 && await refreshSession()) res = await attempt();
    } on ApiException {
      rethrow;
    } catch (error) {
      if (isConnectionIssue(error)) {
        throw const ApiException(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
          0,
        );
      }
      rethrow;
    }
    if (res.statusCode >= 400) throw _apiError(res);
    return res;
  }

  static Future<dynamic> requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? filePath,
    Duration timeout = _kRequestTimeout,
  }) async {
    final res = await send(
      method,
      path,
      body: body,
      filePath: filePath,
      timeout: timeout,
    );
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Tambah ([childId] null) atau ubah data anak beserta tanggal lahir dan jenis kelamin.
  static Future<void> saveChild({
    String? childId,
    required String nama,
    required DateTime birthDate,
    required String gender,
  }) async {
    await send(
      childId == null ? 'POST' : 'PUT',
      childId == null ? '/children' : '/children/$childId',
      body: {'nama': nama, 'birth_date': _dateOnly(birthDate), 'gender': gender},
    );
  }

  static Future<BackendChild> createChild({
    required String nama,
    required int umur,
    DateTime? birthDate,
  }) async {
    await initialize();
    final payload = <String, dynamic>{'nama': nama, 'umur': umur};
    if (birthDate != null) {
      payload['birth_date'] =
          '${birthDate.year.toString().padLeft(4, '0')}-'
          '${birthDate.month.toString().padLeft(2, '0')}-'
          '${birthDate.day.toString().padLeft(2, '0')}';
    }

    final res = await http
        .post(
          Uri.parse('$baseUrl/children'),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal menambahkan anak', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return BackendChild.fromJson(parsed);
  }

  static Future<void> updateChild({
    required Object childId,
    required String nama,
    required int umur,
  }) async {
    await initialize();
    final res = await http
        .put(
          Uri.parse('$baseUrl/children/$childId'),
          headers: await _headers(),
          body: jsonEncode({'nama': nama, 'umur': umur}),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal memperbarui data anak', res));
    }
  }

  static Future<void> deleteChild(Object childId) async {
    await initialize();
    final res = await http
        .delete(
          Uri.parse('$baseUrl/children/$childId'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal menghapus data anak', res));
    }
  }

  static Future<bool> logActivity({
    Object? childId,
    required String activityType,
    required String value,
    String? photoPath,
  }) async {
    await initialize();
    final payload = <String, dynamic>{
      'activity_type': activityType,
      'value': value,
    };
    if (childId != null) {
      payload['child_id'] = childId;
    }
    final res = await _retryWithRefresh<http.Response>(() async {
      if (photoPath == null || photoPath.trim().isEmpty) {
        return http
            .post(
              Uri.parse('$baseUrl/activities'),
              headers: await _headers(),
              body: jsonEncode(payload),
            )
            .timeout(_kRequestTimeout);
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/activities'),
      );
      request.headers.addAll(await _headers(withJson: false));
      request.fields.addAll(
        payload.map((key, value) => MapEntry(key, '$value')),
      );
      request.files.add(await _photoPart('photo', photoPath));
      final streamed = await request.send().timeout(_kRequestTimeout);
      return http.Response.fromStream(streamed);
    });

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal mencatat aktivitas', res));
    }
    if (photoPath != null && photoPath.trim().isNotEmpty) {
      try {
        final response = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
        return response['photo_upload_failed'] != true &&
            response['photo_path'] != null;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  static Future<void> logParentActivity({
    required String activityType,
    required String value,
  }) async {
    await logActivity(childId: null, activityType: activityType, value: value);
  }

  static Future<List<BackendActivityRecord>> getActivities({
    Object? childId,
  }) async {
    await initialize();
    final uri = childId == null
        ? Uri.parse('$baseUrl/activities')
        : Uri.parse('$baseUrl/activities?child_id=$childId');
    final res = await _retryWithRefresh<http.Response>(() async {
      return await http
          .get(uri, headers: await _headers(withJson: false))
          .timeout(_kRequestTimeout);
    });

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal memuat aktivitas', res));
    }

    final parsed = jsonDecode(res.body) as List<dynamic>;
    return parsed
        .map(
          (item) => BackendActivityRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  static Future<void> redeemInviteCode(String code) async {
    await initialize();
    final res = await http
        .post(
          Uri.parse('$baseUrl/invites/redeem'),
          headers: await _headers(),
          body: jsonEncode({'code': code}),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal menggunakan undangan', res));
    }
  }

  static Future<String> generateConnectionToken({
    String childRole = 'delegasi',
    String? childId,
    String inviteeName = '',
    String inviteeContact = '',
  }) async {
    await initialize();
    // Validate role on client side to avoid sending invalid requests.
    const allowed = {'delegasi'};
    if (!allowed.contains(childRole)) {
      throw ArgumentError.value(
        childRole,
        'childRole',
        'Only "delegasi" is allowed for connection tokens',
      );
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/tokens/generate'),
          headers: await _headers(),
          body: jsonEncode({
            'child_role': childRole,
            'child_id': ?childId,
            if (inviteeName.trim().isNotEmpty)
              'invitee_name': inviteeName.trim(),
            if (inviteeContact.trim().isNotEmpty)
              'invitee_contact': inviteeContact.trim(),
          }),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal membuat undangan Delegasi', res),
      );
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return (parsed['token'] as String?)?.trim() ?? '';
  }

  static Future<void> connectWithToken(String token) async {
    await initialize();
    final res = await http
        .post(
          Uri.parse('$baseUrl/tokens/connect'),
          headers: await _headers(),
          body: jsonEncode({'token': token.trim()}),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Token tidak dapat digunakan', res));
    }
  }

  static Future<BackendDelegationInvitation> previewDelegationInvitation(
    String token,
  ) async {
    await initialize();
    final res = await http
        .get(
          Uri.parse(
            '$baseUrl/tokens/preview/${Uri.encodeComponent(token.trim())}',
          ),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);
    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Kode undangan tidak dapat digunakan', res),
      );
    }
    return BackendDelegationInvitation.fromJson(
      Map<String, dynamic>.from(jsonDecode(res.body) as Map),
    );
  }

  static Future<void> declineDelegationInvitation(String token) async {
    await initialize();
    final res = await http
        .post(
          Uri.parse('$baseUrl/tokens/decline'),
          headers: await _headers(),
          body: jsonEncode({'token': token.trim()}),
        )
        .timeout(_kRequestTimeout);
    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Undangan tidak dapat ditolak', res));
    }
  }

  static Future<void> decideDelegationRequest({
    required String token,
    required bool approve,
  }) async {
    await initialize();
    final action = approve ? 'approve' : 'reject';
    final res = await http
        .patch(
          Uri.parse('$baseUrl/tokens/${Uri.encodeComponent(token)}/$action'),
          headers: await _headers(),
        )
        .timeout(_kRequestTimeout);
    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError(
          approve
              ? 'Permintaan Delegasi belum dapat divalidasi'
              : 'Permintaan Delegasi belum dapat ditolak',
          res,
        ),
      );
    }
  }

  static Future<void> revokeDelegation(String token) async {
    await initialize();
    final res = await http
        .patch(
          Uri.parse('$baseUrl/tokens/${Uri.encodeComponent(token)}/revoke'),
          headers: await _headers(),
        )
        .timeout(_kRequestTimeout);
    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Akses Delegasi belum dapat dicabut', res),
      );
    }
  }

  static Future<List<BackendConnectionToken>> listConnectionTokens() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/tokens/list'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal memuat daftar Delegasi', res));
    }

    final parsed = jsonDecode(res.body) as List<dynamic>;
    return parsed
        .map(
          (item) => BackendConnectionToken.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  static Future<BackendConnectionStatus> getConnectionStatus() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/tokens/status'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memeriksa status Delegasi', res),
      );
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return BackendConnectionStatus.fromJson(parsed);
  }

  static Future<int> getPendingDelegationRequestCount() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/tokens/pending-count'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);
    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memuat permintaan Delegasi', res),
      );
    }
    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return (parsed['count'] as num?)?.toInt() ?? 0;
  }

  static Future<List<Map<String, dynamic>>> getDelegationNotifications() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/tokens/notifications'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);
    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memuat pemberitahuan Delegasi', res),
      );
    }
    return (jsonDecode(res.body) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  static Future<BackendParentAnalytics> getParentAnalytics() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/analytics/parent'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memuat ringkasan Orang Tua', res),
      );
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return BackendParentAnalytics.fromJson(parsed);
  }

  static Future<BackendChildAnalytics> getChildAnalytics(Object childId) async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/analytics/child/$childId'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal memuat ringkasan anak', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return BackendChildAnalytics.fromJson(parsed);
  }

  static Future<List<BackendGrowthRecord>> getGrowthRecords(
    Object childId,
  ) async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/growth/records/$childId'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memuat data pertumbuhan', res),
      );
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final items = (parsed['records'] as List<dynamic>? ?? const []);
    return items
        .map(
          (item) => BackendGrowthRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  static Future<Map<String, dynamic>> getGrowthBundle(Object childId) async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/growth/records/$childId'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memuat data pertumbuhan', res),
      );
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<Map<String, dynamic>> createGrowthRecord({
    required Object childId,
    required double heightCm,
    required double weightKg,
    double? headCircumferenceCm,
    String immunizationNotes = '',
    String milestonesNotes = '',
  }) async {
    await initialize();
    final headCircumferenceField = headCircumferenceCm == null
        ? null
        : <String, dynamic>{'head_circumference_cm': headCircumferenceCm};
    final res = await http
        .post(
          Uri.parse('$baseUrl/growth/record'),
          headers: await _headers(),
          body: jsonEncode({
            'child_id': childId,
            'height_cm': heightCm,
            'weight_kg': weightKg,
            ...?headCircumferenceField,
            'immunization_notes': immunizationNotes,
            'milestones_notes': milestonesNotes,
          }),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal menyimpan data pertumbuhan', res),
      );
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<List<String>> getNutritionFoods() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/nutrition/foods'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal memuat daftar makanan', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final items = (parsed['foods'] as List<dynamic>? ?? const []);
    return items.map((e) => e.toString()).toList(growable: false);
  }

  static Future<Map<String, dynamic>> recordFoodIntake({
    required Object childId,
    required String foodName,
    required double quantityGrams,
    String mealType = 'main',
  }) async {
    await initialize();
    final res = await http
        .post(
          Uri.parse('$baseUrl/nutrition/food-intake'),
          headers: await _headers(),
          body: jsonEncode({
            'child_id': childId,
            'food_name': foodName,
            'quantity_grams': quantityGrams,
            'meal_type': mealType,
          }),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal menyimpan asupan makanan', res),
      );
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<Map<String, dynamic>> getDailyNutritionAnalysis({
    required Object childId,
    required String date,
  }) async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/nutrition/daily-analysis/$childId/$date'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memuat analisis nutrisi', res),
      );
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> _getFeatureItems(
    String path, {
    Object? childId,
    required String errorContext,
  }) async {
    await initialize();
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: childId == null ? null : {'child_id': '$childId'},
    );
    final res = await _retryWithRefresh<http.Response>(() async {
      return http
          .get(uri, headers: await _headers(withJson: false))
          .timeout(_kRequestTimeout);
    });
    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError(errorContext, res));
    }
    final response = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final items = response['items'] as List<dynamic>? ?? const [];
    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<Map<String, dynamic>> _saveFeatureItem(
    String path,
    Map<String, dynamic> payload, {
    required String errorContext,
  }) async {
    await initialize();
    final res = await _retryWithRefresh<http.Response>(() async {
      return http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: await _headers(),
            body: jsonEncode(payload),
          )
          .timeout(_kRequestTimeout);
    });
    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError(errorContext, res));
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> getValidationResults({
    Object? childId,
  }) => _getFeatureItems(
    '/api/validation-results',
    childId: childId,
    errorContext: 'Gagal memuat hasil validasi',
  );

  static Future<Map<String, dynamic>> saveValidationResult({
    required Object childId,
    required String ruleName,
    String status = 'ok',
    double? score,
    String? message,
    Map<String, dynamic>? details,
  }) => _saveFeatureItem('/api/validation-results', {
    'child_id': childId,
    'rule_name': ruleName,
    'status': status,
    'score': ?score,
    'message': ?message,
    'details': ?details,
  }, errorContext: 'Gagal menyimpan hasil validasi');

  static Future<List<Map<String, dynamic>>> getMonthlyReports({
    Object? childId,
  }) => _getFeatureItems(
    '/api/monthly-reports',
    childId: childId,
    errorContext: 'Gagal memuat rekap bulanan',
  );

  static Future<Map<String, dynamic>> saveMonthlyReport({
    required Object childId,
    required String reportMonth,
    String? pdfPath,
    Map<String, dynamic>? summary,
  }) => _saveFeatureItem('/api/monthly-reports', {
    'child_id': childId,
    'report_month': reportMonth,
    'pdf_path': ?pdfPath,
    'summary_json': ?summary,
  }, errorContext: 'Gagal menyimpan rekap bulanan');

  static Future<List<Map<String, dynamic>>> getAiRecommendations({
    Object? childId,
  }) => _getFeatureItems(
    '/api/ai-recommendations',
    childId: childId,
    errorContext: 'Gagal memuat rekomendasi',
  );

  static Future<Map<String, dynamic>> saveAiRecommendation({
    required Object childId,
    required String category,
    required String recommendation,
    double? confidence,
  }) => _saveFeatureItem('/api/ai-recommendations', {
    'child_id': childId,
    'category': category,
    'recommendation': recommendation,
    'confidence': ?confidence,
  }, errorContext: 'Gagal menyimpan rekomendasi');

  static Future<Map<String, dynamic>> extractBehaviorDraft({
    required String childId,
    required String narrative,
  }) async {
    await initialize();
    final res = await _retryWithRefresh<http.Response>(() async {
      return http
          .post(
            Uri.parse('$baseUrl/api/behavior/extract'),
            headers: await _headers(),
            body: jsonEncode({'child_id': childId, 'narrative': narrative}),
          )
          .timeout(_kRequestTimeout);
    });
    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal mengekstrak catatan perilaku', res),
      );
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<Map<String, dynamic>> saveBehaviorEvent(
    Map<String, dynamic> event,
  ) async {
    await initialize();
    final res = await _retryWithRefresh<http.Response>(() async {
      return http
          .post(
            Uri.parse('$baseUrl/api/behavior-events'),
            headers: await _headers(),
            body: jsonEncode(event),
          )
          .timeout(_kRequestTimeout);
    });
    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal menyimpan catatan perilaku', res),
      );
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> getBehaviorEvents({
    required String childId,
    String? query,
    String? status,
  }) async {
    await initialize();
    final params = <String, String>{'child_id': childId};
    if (query?.trim().isNotEmpty ?? false) params['q'] = query!.trim();
    if (status?.isNotEmpty ?? false) params['status'] = status!;
    final uri = Uri.parse(
      '$baseUrl/api/behavior-events',
    ).replace(queryParameters: params);
    final res = await _retryWithRefresh<http.Response>(() async {
      return http
          .get(uri, headers: await _headers(withJson: false))
          .timeout(_kRequestTimeout);
    });
    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memuat catatan perilaku', res),
      );
    }
    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final items = parsed['items'] as List<dynamic>? ?? const [];
    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<Map<String, dynamic>> validateBehaviorEvent({
    required String eventId,
    required String action,
    Map<String, dynamic>? event,
    String? note,
  }) async {
    await initialize();
    final res = await _retryWithRefresh<http.Response>(() async {
      return http
          .patch(
            Uri.parse(
              '$baseUrl/api/behavior-events/${Uri.encodeComponent(eventId)}/validation',
            ),
            headers: await _headers(),
            body: jsonEncode({
              'action': action,
              'event': ?event,
              'note': ?note,
            }),
          )
          .timeout(_kRequestTimeout);
    });
    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memvalidasi catatan perilaku', res),
      );
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<Map<String, dynamic>> getBehaviorInsights({
    required String childId,
    int days = 7,
  }) async {
    await initialize();
    final uri = Uri.parse(
      '$baseUrl/api/behavior-insights/${Uri.encodeComponent(childId)}',
    ).replace(queryParameters: {'days': '$days'});
    final res = await _retryWithRefresh<http.Response>(() async {
      return http
          .get(uri, headers: await _headers(withJson: false))
          .timeout(_kRequestTimeout);
    });
    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memuat insight perilaku', res),
      );
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static String _formatReportDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Future<Uint8List> downloadActivityReport({
    Object? childId,
    DateTime? from,
    DateTime? to,
  }) async {
    await initialize();
    final params = <String, String>{};
    if (childId != null) params['child_id'] = childId.toString();
    if (from != null) params['from'] = _formatReportDate(from);
    if (to != null) params['to'] = _formatReportDate(to);
    final uri = Uri.parse(
      '$baseUrl/api/reports/activity/download',
    ).replace(queryParameters: params);
    final res = await http
        .get(uri, headers: await _headers(withJson: false))
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal unduh laporan aktivitas', res));
    }

    return res.bodyBytes;
  }

  static Future<String> downloadActivityReportToFile({
    Object? childId,
    DateTime? from,
    DateTime? to,
  }) async {
    final bytes = await downloadActivityReport(
      childId: childId,
      from: from,
      to: to,
    );

    final directory = await getApplicationDocumentsDirectory();
    final filename =
        'laporan_aktivitas_${childId ?? 'semua'}_${_formatReportDate(from ?? DateTime.now())}_${_formatReportDate(to ?? DateTime.now())}.pdf';
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<Uint8List> downloadActivityHealthReport({
    Object? childId,
    DateTime? from,
    DateTime? to,
  }) async {
    await initialize();
    final params = <String, String>{};
    if (childId != null) params['child_id'] = childId.toString();
    if (from != null) params['from'] = _formatReportDate(from);
    if (to != null) params['to'] = _formatReportDate(to);
    final uri = Uri.parse(
      '$baseUrl/api/reports/activity-health/download',
    ).replace(queryParameters: params);
    final res = await http
        .get(uri, headers: await _headers(withJson: false))
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildHttpError('Gagal unduh laporan activity & health', res),
      );
    }

    return res.bodyBytes;
  }

  static Future<String> downloadActivityHealthReportToFile({
    Object? childId,
    DateTime? from,
    DateTime? to,
  }) async {
    final bytes = await downloadActivityHealthReport(
      childId: childId,
      from: from,
      to: to,
    );

    final directory = await getApplicationDocumentsDirectory();
    final filename =
        'laporan_activity_health_${childId ?? 'semua'}_${_formatReportDate(from ?? DateTime.now())}_${_formatReportDate(to ?? DateTime.now())}.pdf';
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<Map<String, dynamic>> requestActivityReportEmail({
    Object? childId,
    DateTime? from,
    DateTime? to,
    String? email,
  }) async {
    await initialize();
    final trimmedEmail = email?.trim();
    final payload = <String, dynamic>{};
    if (childId != null) payload['child_id'] = childId;
    if (from != null) payload['from'] = _formatReportDate(from);
    if (to != null) payload['to'] = _formatReportDate(to);
    if (trimmedEmail?.isNotEmpty ?? false) payload['email'] = trimmedEmail;
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/reports/activity/email'),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildHttpError('Gagal kirim laporan aktivitas via email', res),
      );
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<Map<String, dynamic>> requestActivityHealthReportEmail({
    Object? childId,
    DateTime? from,
    DateTime? to,
    String? email,
  }) async {
    await initialize();
    final trimmedEmail = email?.trim();
    final payload = <String, dynamic>{};
    if (childId != null) payload['child_id'] = childId;
    if (from != null) payload['from'] = _formatReportDate(from);
    if (to != null) payload['to'] = _formatReportDate(to);
    if (trimmedEmail?.isNotEmpty ?? false) payload['email'] = trimmedEmail;
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/reports/activity-health/email'),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(
        _buildHttpError('Gagal kirim laporan activity & health via email', res),
      );
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<Map<String, dynamic>> getEmailPreferences() async {
    await initialize();
    final res = await _retryWithRefresh<http.Response>(() async {
      return await http
          .get(
            Uri.parse('$baseUrl/notifications/email-preferences'),
            headers: await _headers(withJson: false),
          )
          .timeout(_kRequestTimeout);
    });

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal ambil preferensi email', res));
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<BackendUser?> getCurrentUser() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/api/me'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode == 401) {
      final refreshed = await refreshSession();
      if (refreshed) {
        return getCurrentUser();
      }
      return null;
    }

    if (res.statusCode >= 400) {
      throw Exception(
        _buildRoleHttpError('Gagal memeriksa sesi pengguna', res),
      );
    }

    return BackendUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(res.body) as Map),
    );
  }

  static Future<Map<String, dynamic>> getProfile() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/api/profile'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);
    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal memuat profil', res));
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<Map<String, dynamic>> saveProfile({
    required String fullName,
    required String phone,
    String? photoPath,
  }) async {
    await initialize();
    final res = await _retryWithRefresh<http.Response>(() async {
      if (photoPath == null || photoPath.trim().isEmpty) {
        return http
            .put(
              Uri.parse('$baseUrl/api/profile'),
              headers: await _headers(),
              body: jsonEncode({'full_name': fullName, 'phone': phone}),
            )
            .timeout(_kRequestTimeout);
      }
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/profile'),
      );
      request.headers.addAll(await _headers(withJson: false));
      request.fields['full_name'] = fullName;
      request.fields['phone'] = phone;
      request.files.add(await _photoPart('photo', photoPath));
      return http.Response.fromStream(
        await request.send().timeout(_kRequestTimeout),
      );
    });
    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Profil tidak dapat disimpan', res));
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<List<int>> getProfilePhotoBytes() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/api/profile/photo'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);
    if (res.statusCode >= 400) {
      throw Exception(_buildRoleHttpError('Gagal memuat foto profil', res));
    }
    return res.bodyBytes;
  }

  static Future<Map<String, dynamic>> updateEmailPreferences({
    required bool weeklyRecap,
    required bool alerts,
    required bool notifyDeviations,
  }) async {
    await initialize();
    return await _retryWithRefresh<Map<String, dynamic>>(() async {
      final res = await http
          .post(
            Uri.parse('$baseUrl/notifications/email-preferences'),
            headers: await _headers(),
            body: jsonEncode({
              'weekly_recap': weeklyRecap,
              'alerts': alerts,
              'notify_deviations': notifyDeviations,
            }),
          )
          .timeout(_kRequestTimeout);

      if (res.statusCode >= 400) {
        throw Exception(_buildHttpError('Gagal update preferensi email', res));
      }

      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    });
  }

  static Future<bool> refreshSession() async {
    await initialize();
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return false;
    }

    final res = await http
        .post(
          Uri.parse('$baseUrl/api/refresh'),
          headers: await _headers(),
          body: jsonEncode({'refresh_token': _refreshToken}),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      return false;
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final token = (parsed['access_token'] as String?)?.trim();
    final refreshToken = (parsed['refresh_token'] as String?)?.trim();

    if (token == null || token.isEmpty) {
      return false;
    }

    _authToken = token;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
    await _persistState();
    return true;
  }

  static Future<T> _retryWithRefresh<T>(Future<T> Function() requestFn) async {
    try {
      return await requestFn();
    } catch (error) {
      final message = error.toString();
      if ((message.contains('Unauthorized') || message.contains('(401)')) &&
          await refreshSession()) {
        return await requestFn();
      }
      rethrow;
    }
  }

  static Future<void> testConnection() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/login'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Test koneksi backend gagal', res));
    }
  }

  static Future<bool> tryAutoRelogin() async {
    await initialize();

    if (hasSession) {
      try {
        final user = await getCurrentUser();
        if (user != null) {
          return true;
        }
        _sessionCookie = null;
        _authToken = null;
      } catch (_) {
        _sessionCookie = null;
        _authToken = null;
      }
    }

    // Password tidak disimpan di perangkat; sesi diperpanjang dengan refresh token saja.
    await _deletePasswordSecurely();
    if (await refreshSession()) {
      try {
        return await getCurrentUser() != null;
      } catch (_) {
        return false;
      }
    }
    await _persistState();
    return false;
  }

  static Future<void> clearSession({
    bool clearEmail = false,
    bool clearPassword = false,
  }) async {
    _sessionCookie = null;
    _authToken = null;
    _refreshToken = null;
    // await FirebaseAuth.instance.signOut();
    if (clearEmail) {
      _lastEmail = null;
    }
    if (clearPassword) {
      await _deletePasswordSecurely();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPasswordTimestampKey);
      await prefs.remove(_kMustChangePasswordKey);
    }
    await _persistState();
  }

  static Future<void> clearAllLocalData() async {
    try {
      // await FirebaseAuth.instance.signOut();
    } catch (_) {}

    try {
      await clearSession(clearEmail: true, clearPassword: true);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    try {
      await _secureStorage.deleteAll();
    } catch (_) {}

    _initialized = false;
    baseUrl = _resolveDefaultBaseUrl();
    _sessionCookie = null;
    _authToken = null;
    _lastEmail = null;
  }

  /// Kirim pesan ke TARA chat (GPT di backend).
  /// [history] berisi pasangan {role, content} percakapan sebelumnya.
  static Future<String> sendAiChat({
    required String message,
    Object? childId,
    List<Map<String, String>> history = const [],
  }) async {
    await initialize();
    final body = <String, dynamic>{
      'message': message,
      'history': history,
      'child_id': childId,
    };
    final res = await http
        .post(
          Uri.parse('$baseUrl/ai/chat'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(_kRequestTimeout);
    if (res.statusCode == 200) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['reply'] as String?) ?? '';
      } catch (_) {
        return '';
      }
    }
    throw Exception(_buildHttpError('AI chat error', res));
  }
}
