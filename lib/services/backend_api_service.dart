import 'dart:convert';
import 'dart:async';

// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/backend_connection.dart';
import '../models/backend_analytics.dart';

class BackendChild {
  final int id;
  final String nama;
  final int umur;

  const BackendChild({
    required this.id,
    required this.nama,
    required this.umur,
  });

  factory BackendChild.fromJson(Map<String, dynamic> json) {
    return BackendChild(
      id: (json['id'] as num).toInt(),
      nama: (json['nama'] as String?) ?? 'Child',
      umur: (json['umur'] as num?)?.toInt() ?? 0,
    );
  }
}

class BackendCaptchaChallenge {
  final String sessionId;
  final String question;
  final bool disabled;

  const BackendCaptchaChallenge({
    required this.sessionId,
    required this.question,
    this.disabled = false,
  });

  factory BackendCaptchaChallenge.fromJson(Map<String, dynamic> json) {
    return BackendCaptchaChallenge(
      sessionId: (json['session_id'] as String?) ?? '',
      question: (json['question'] as String?) ?? '',
      disabled: (json['disabled'] as bool?) ?? false,
    );
  }
}

class BackendUser {
  final int id;
  final String email;
  final String role;

  const BackendUser({
    required this.id,
    required this.email,
    required this.role,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'parent',
    );
  }
}

class BackendGrowthRecord {
  final int id;
  final int childId;
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
      childId: (json['child_id'] as num?)?.toInt() ?? 0,
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
  final int id;
  final int? childId;
  final String activityType;
  final String value;
  final String createdAt;

  const BackendActivityRecord({
    required this.id,
    required this.childId,
    required this.activityType,
    required this.value,
    required this.createdAt,
  });

  factory BackendActivityRecord.fromJson(Map<String, dynamic> json) {
    return BackendActivityRecord(
      id: (json['id'] as num).toInt(),
      childId: (json['child_id'] as num?)?.toInt(),
      activityType: (json['activity_type'] as String?) ?? 'activity',
      value: (json['value'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
}

class BackendApiService {
  static const _kBaseUrlKey = 'backend_base_url';
  static const _kSessionCookieKey = 'backend_session_cookie';
  static const _kAuthTokenKey = 'backend_auth_token';
  static const _kLastEmailKey = 'backend_last_email';
  static const _kPasswordKey = 'backend_password_enc';
  static const _kPasswordTimestampKey = 'backend_password_timestamp';
  static const _kPasswordExpirySecs = 86400; // 1 day
  static const _kRequestTimeout = Duration(seconds: 15);

  static const _secureStorage = FlutterSecureStorage();

  static bool _initialized = false;
  static String baseUrl = _resolveDefaultBaseUrl();

  static String? _sessionCookie;
  static String? _authToken;
  static String? _lastEmail;

  static String _resolveDefaultBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator cannot reach host via 127.0.0.1.
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
      baseUrl = savedBaseUrl;
    }

    _sessionCookie = prefs.getString(_kSessionCookieKey);
    _authToken = prefs.getString(_kAuthTokenKey);
    _lastEmail = prefs.getString(_kLastEmailKey);
    _initialized = true;
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

  static Future<Map<String, String>> _headers({bool withJson = true}) async {
    final headers = <String, String>{};
    if (withJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      headers['Cookie'] = _sessionCookie!;
    } else if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
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

  static String _buildHttpError(String context, http.Response res) {
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

  static Future<void> _writePasswordSecurely(String value) async {
    try {
      await _secureStorage.write(key: _kPasswordKey, value: value);
    } catch (_) {
      // Keep app usable even when encrypted storage is unavailable/corrupted.
    }
  }

  static Future<String?> _readPasswordSecurely() async {
    try {
      return await _secureStorage.read(key: _kPasswordKey);
    } catch (_) {
      return null;
    }
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
      return 'Android emulator: gunakan http://10.0.2.2:5000. HP fisik: gunakan IP LAN PC, misalnya http://192.168.1.10:5000';
    }

    return 'Desktop lokal: gunakan http://127.0.0.1:5000. HP fisik: gunakan IP LAN PC.';
  }

  static bool get hasSession =>
      (_sessionCookie != null && _sessionCookie!.isNotEmpty) ||
      (_authToken != null && _authToken!.isNotEmpty);

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

  static Future<void> login({
    required String email,
    required String password,
    bool rememberPassword = true,
    String? captchaSessionId,
    String? captchaAnswer,
    String? turnstileToken,
  }) async {
    await initialize();
    _sessionCookie = null;
    _authToken = null;
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/login'),
          headers: await _headers(),
          body: jsonEncode({
            'email': email,
            'password': password,
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
      throw Exception(_buildHttpError('Login backend gagal', res));
    }

    final cookie = _extractSessionCookie(res);
    if (cookie.isNotEmpty) {
      _sessionCookie = cookie;
    }
    final token = _extractToken(res);
    if (token != null) {
      _authToken = token;
    }
    _lastEmail = email.trim();
    if (rememberPassword) {
      await _writePasswordSecurely(password);
      // Save timestamp for password expiry (1 day)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kPasswordTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    await _persistState();
  }

  static Future<void> register({
    required String email,
    required String password,
    String role = 'parent',
    int? childId,
    bool rememberPassword = true,
  }) async {
    await initialize();
    _sessionCookie = null;
    _authToken = null;
    final body = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': role,
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
      throw Exception(_buildHttpError('Register backend gagal', res));
    }

    final cookie = _extractSessionCookie(res);
    if (cookie.isNotEmpty) {
      _sessionCookie = cookie;
    }
    final token = _extractToken(res);
    if (token != null) {
      _authToken = token;
    }
    _lastEmail = email.trim();
    if (rememberPassword) {
      await _writePasswordSecurely(password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kPasswordTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
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
      throw Exception(_buildHttpError('Gagal ambil children', res));
    }

    final parsed = jsonDecode(res.body) as List<dynamic>;
    return parsed
        .map((e) => BackendChild.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<BackendChild> createChild({
    required String nama,
    required int umur,
  }) async {
    await initialize();
    final res = await http
        .post(
          Uri.parse('$baseUrl/children'),
          headers: await _headers(),
          body: jsonEncode({'nama': nama, 'umur': umur}),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal membuat child backend', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return BackendChild.fromJson(parsed);
  }

  static Future<void> updateChild({
    required int childId,
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
      throw Exception(_buildHttpError('Gagal update child backend', res));
    }
  }

  static Future<void> deleteChild(int childId) async {
    await initialize();
    final res = await http
        .delete(
          Uri.parse('$baseUrl/children/$childId'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal hapus child backend', res));
    }
  }

  static Future<void> logActivity({
    int? childId,
    required String activityType,
    required String value,
  }) async {
    await initialize();
    final payload = <String, dynamic>{
      'activity_type': activityType,
      'value': value,
    };
    if (childId != null) {
      payload['child_id'] = childId;
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/activities'),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal kirim activity', res));
    }
  }

  static Future<void> logParentActivity({
    required String activityType,
    required String value,
  }) async {
    await logActivity(childId: null, activityType: activityType, value: value);
  }

  static Future<List<BackendActivityRecord>> getActivities({
    int? childId,
  }) async {
    await initialize();
    final uri = childId == null
        ? Uri.parse('$baseUrl/activities')
        : Uri.parse('$baseUrl/activities?child_id=$childId');
    final res = await http
        .get(uri, headers: await _headers(withJson: false))
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal ambil activity', res));
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
      throw Exception(_buildHttpError('Gagal redeem invite', res));
    }
  }

  static Future<String> generateConnectionToken({
    String childRole = 'delegated_parent',
  }) async {
    await initialize();
    // Validate role on client side to avoid sending invalid requests.
    const allowed = {'delegated_parent'};
    if (!allowed.contains(childRole)) {
      throw ArgumentError.value(
        childRole,
        'childRole',
        'Only "delegated_parent" is allowed for connection tokens',
      );
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/tokens/generate'),
          headers: await _headers(),
          body: jsonEncode({'child_role': childRole}),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal generate connection token', res));
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
      throw Exception(_buildHttpError('Gagal connect dengan token', res));
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
      throw Exception(_buildHttpError('Gagal ambil daftar token', res));
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
      throw Exception(_buildHttpError('Gagal ambil status koneksi', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return BackendConnectionStatus.fromJson(parsed);
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
      throw Exception(_buildHttpError('Gagal ambil analytics parent', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return BackendParentAnalytics.fromJson(parsed);
  }

  static Future<BackendChildAnalytics> getChildAnalytics(int childId) async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/analytics/child/$childId'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal ambil analytics child', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return BackendChildAnalytics.fromJson(parsed);
  }

  static Future<List<BackendGrowthRecord>> getGrowthRecords(int childId) async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/growth/records/$childId'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal ambil growth records', res));
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

  static Future<Map<String, dynamic>> getGrowthBundle(int childId) async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/growth/records/$childId'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal ambil growth bundle', res));
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<Map<String, dynamic>> createGrowthRecord({
    required int childId,
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
      throw Exception(_buildHttpError('Gagal simpan growth record', res));
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
      throw Exception(_buildHttpError('Gagal ambil daftar makanan', res));
    }

    final parsed = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final items = (parsed['foods'] as List<dynamic>? ?? const []);
    return items.map((e) => e.toString()).toList(growable: false);
  }

  static Future<Map<String, dynamic>> recordFoodIntake({
    required int childId,
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
      throw Exception(_buildHttpError('Gagal simpan food intake', res));
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<Map<String, dynamic>> getDailyNutritionAnalysis({
    required int childId,
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
      throw Exception(_buildHttpError('Gagal ambil analisis nutrisi', res));
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  static Future<Map<String, dynamic>> getEmailPreferences() async {
    await initialize();
    final res = await http
        .get(
          Uri.parse('$baseUrl/notifications/email-preferences'),
          headers: await _headers(withJson: false),
        )
        .timeout(_kRequestTimeout);

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
      return null;
    }

    if (res.statusCode >= 400) {
      throw Exception(_buildHttpError('Gagal ambil user aktif', res));
    }

    return BackendUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(res.body) as Map),
    );
  }

  static Future<Map<String, dynamic>> updateEmailPreferences({
    required bool weeklyRecap,
    required bool alerts,
    required bool notifyDeviations,
  }) async {
    await initialize();
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

  static Future<bool> _isPasswordExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_kPasswordTimestampKey);
    if (timestamp == null) return true;

    final nowSecs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSecs = (nowSecs - timestamp) ~/ 1000;
    return elapsedSecs > _kPasswordExpirySecs;
  }

  static Future<bool> tryAutoRelogin() async {
    await initialize();

    if (hasSession) {
      try {
        await getChildren();
        return true;
      } catch (_) {
        _sessionCookie = null;
        _authToken = null;
      }
    }

    // Check if stored password has expired
    if (await _isPasswordExpired()) {
      await clearSession(clearPassword: true);
      return false;
    }

    final email = _lastEmail;
    final password = await _readPasswordSecurely();

    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      await _persistState();
      return false;
    }

    try {
      await login(email: email, password: password, rememberPassword: true);
      await getChildren();
      return true;
    } catch (_) {
      _sessionCookie = null;
      await _persistState();
      return false;
    }
  }

  static Future<void> clearSession({
    bool clearEmail = false,
    bool clearPassword = false,
  }) async {
    _sessionCookie = null;
    _authToken = null;
    // await FirebaseAuth.instance.signOut();
    if (clearEmail) {
      _lastEmail = null;
    }
    if (clearPassword) {
      await _deletePasswordSecurely();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPasswordTimestampKey);
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

  /// Kirim pesan ke Patara AI chat (GPT di backend).
  /// [history] berisi pasangan {role, content} percakapan sebelumnya.
  static Future<String> sendAiChat({
    required String message,
    int? childId,
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
