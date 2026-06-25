import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_back_navigation.dart';
import '../models/backend_connection.dart';
import '../services/backend_api_service.dart';
// import '../services/realtime_service.dart';
import 'menu/five_menu_shell.dart';
import 'join_parent_token_screen.dart';

class RemajaDashboard extends StatefulWidget {
  final int? umur;
  final int? childId;
  final String? username;
  final String? avatarUrl;
  final String? sleepQuality;
  final String? activity;
  final String? body;
  final String? heartRate;
  final bool openedFromParentDashboard;

  const RemajaDashboard({
    super.key,
    this.umur,
    this.childId,
    this.username,
    this.avatarUrl,
    this.sleepQuality,
    this.activity,
    this.body,
    this.heartRate,
    this.openedFromParentDashboard = false,
  });

  @override
  State<RemajaDashboard> createState() => _RemajaDashboardState();
}

class _RemajaDashboardState extends State<RemajaDashboard> {
  static const Color _accentColor = Color(0xFF8B5FBF);
  static const List<String> _moodLabels = [
    'Amazing',
    'Good',
    'Flat',
    'Overwhelmed',
  ];
  static const List<String> _moodEmoji = ['😄', '🙂', '😐', '😵'];
  static const List<Color> _moodColors = [
    Color(0xFFFFD54F),
    Color(0xFFFFB74D),
    Color(0xFFC9B9E8),
    Color(0xFFB39DDB),
  ];

  final String _todayKey = DateTime.now().toIso8601String().substring(0, 10);

  int _moodIndex = 1;
  int _focusMinutes = 120;
  int _waterMl = 1400;
  double _sleepHours = 7.5;
  int _points = 245;
  bool _saving = false;
  bool _loaded = false;

  final Map<String, bool> _dailyGoals = {
    'Fokus belajar 2 jam': false,
    'Minum 8 gelas air': false,
    'Olahraga ringan': true,
    'Tidur 7-8 jam': false,
    'No phone sebelum tidur': true,
  };

  final List<int> _weekMood = [1, 1, 2, 1, 1, 2, 1]; // mood index for M-S
  Future<BackendConnectionStatus>? _connectionStatusFuture;

  @override
  void initState() {
    super.initState();

    _loadData();
    _connectionStatusFuture = BackendApiService.getConnectionStatus();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _refreshConnectionStatus() {
    setState(() {
      _connectionStatusFuture = BackendApiService.getConnectionStatus();
    });
    unawaited(_syncParentRecapsIfNeeded());
  }

  Future<void> _openJoinTokenPage() async {
    final joined = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            const JoinParentTokenScreen(roleLabel: 'Dashboard Remaja'),
      ),
    );
    if (joined == true && mounted) {
      _refreshConnectionStatus();
    }
  }

  Future<bool> _hasActiveParentConnection() async {
    try {
      final status = await BackendApiService.getConnectionStatus();
      return status.connected;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncParentRecapsIfNeeded() async {
    final user = await BackendApiService.getCurrentUser();
    final childId = widget.childId;
    if (user == null || childId == null) return;

    final connected = await _hasActiveParentConnection();
    if (!connected) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekKey =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    Future<void> sendOnce({
      required String recapType,
      required String periodKey,
      required Map<String, dynamic> summary,
    }) async {
      final sentKey = 'recap_sent_remaja_${recapType}_$periodKey';
      if (prefs.getBool(sentKey) == true) return;

      try {
        await BackendApiService.logActivity(
          childId: childId,
          activityType: 'remaja_${recapType}_recap',
          value: summary.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join(','),
        );
        await prefs.setBool(sentKey, true);
      } catch (_) {}
    }

    final activities = await BackendApiService.getActivities(childId: childId);
    final dailyStateDocs = activities
        .where((entry) => entry.activityType == 'remaja_dashboard_state')
        .map((entry) {
          try {
            final decoded = jsonDecode(entry.value);
            if (decoded is Map<String, dynamic>) return decoded;
          } catch (_) {}
          return <String, dynamic>{};
        })
        .where((entry) => entry.isNotEmpty)
        .toList();

    Map<String, dynamic> aggregate(Iterable<Map<String, dynamic>> docs) {
      final totalFocus = docs.fold<int>(
        0,
        (sum, doc) => sum + ((doc['focusMinutes'] as num?)?.toInt() ?? 0),
      );
      final totalWater = docs.fold<int>(
        0,
        (sum, doc) => sum + ((doc['waterMl'] as num?)?.toInt() ?? 0),
      );
      final totalPoints = docs.fold<int>(
        0,
        (sum, doc) => sum + ((doc['points'] as num?)?.toInt() ?? 0),
      );
      final sleepTotal = docs.fold<double>(
        0,
        (sum, doc) => sum + ((doc['sleepHours'] as num?)?.toDouble() ?? 0),
      );
      final goalsDone = docs.fold<int>(0, (sum, doc) {
        final dailyGoals = doc['dailyGoals'];
        if (dailyGoals is Map) {
          return sum + dailyGoals.values.where((value) => value == true).length;
        }
        return sum;
      });
      final days = docs.length;

      return {
        'focusMinutes': totalFocus,
        'waterMl': totalWater,
        'points': totalPoints,
        'avgSleepHours': days == 0 ? 0 : (sleepTotal / days).toStringAsFixed(1),
        'goalsDone': goalsDone,
        'days': days,
      };
    }

    final dailySummary = {
      'mood': _moodLabels[_moodIndex],
      'focusMinutes': _focusMinutes,
      'waterMl': _waterMl,
      'sleepHours': _sleepHours.toStringAsFixed(1),
      'points': _points,
      'goalsDone': _dailyGoals.values.where((value) => value).length,
    };

    final weekDocs = dailyStateDocs.where((doc) {
      final key = (doc['dateKey'] ?? '').toString();
      return key.compareTo(weekKey) >= 0 && key.compareTo(_todayKey) <= 0;
    });
    final monthDocs = dailyStateDocs.where(
      (doc) => (doc['dateKey'] ?? '').toString().startsWith(monthKey),
    );

    await sendOnce(
      recapType: 'daily',
      periodKey: _todayKey,
      summary: dailySummary,
    );
    await sendOnce(
      recapType: 'weekly',
      periodKey: weekKey,
      summary: aggregate(weekDocs),
    );
    await sendOnce(
      recapType: 'monthly',
      periodKey: monthKey,
      summary: aggregate(monthDocs),
    );
  }

  Future<void> _openProfileMenu() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FiveMenuShell(
          childId: widget.childId,
          themeColor: _accentColor,
          titlePrefix: 'Remaja',
          initialIndex: 3,
        ),
      ),
    );
  }

  void _showNotifications() {
    final items = [
      _TeenNotificationItem(
        icon: Icons.water_drop_outlined,
        color: const Color(0xFFFF7043),
        title: 'Minum segelas air',
        description: 'Tetap jaga hidrasi supaya fokus stabil.',
        isDone: true,
      ),
      _TeenNotificationItem(
        icon: Icons.self_improvement,
        color: const Color(0xFF4CAF50),
        title: 'Cek mood harian',
        description: 'Isi mood hari ini untuk pantau kesehatan mental.',
        isDone: true,
      ),
      _TeenNotificationItem(
        icon: Icons.fitness_center,
        color: const Color(0xFFE93CAC),
        title: 'Peregangan 10 menit',
        description: 'Ambil jeda singkat setelah belajar.',
        isDone: false,
      ),
      _TeenNotificationItem(
        icon: Icons.notifications_active_outlined,
        color: const Color(0xFF8B5FBF),
        title: 'Sinkron ke parent',
        description: 'Aktivitas hari ini akan terlihat di dashboard parent.',
        isDone: false,
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifikasi Anak Lanjutan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pengingat harian dan aktivitas yang tersinkron ke parent.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TeenNotificationTile(item: item),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionBanner() {
    return FutureBuilder<BackendConnectionStatus>(
      future: _connectionStatusFuture,
      builder: (context, snapshot) {
        final connected = snapshot.data?.connected == true;
        final accent = connected
            ? const Color(0xFF2E7D32)
            : const Color(0xFFF57C00);
        final statusText = connected
            ? 'Sudah terhubung ke parent'
            : 'Belum terhubung ke parent';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Token dan profil AI sudah dipindahkan ke menu Akun.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B6478)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: connected
                    ? _refreshConnectionStatus
                    : _openJoinTokenPage,
                child: Text(connected ? 'Refresh' : 'Join'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadData() async {
    final user = await BackendApiService.getCurrentUser();
    if (user == null) return;

    try {
      final activities = await BackendApiService.getActivities(
        childId: widget.childId ?? user.id,
      );
      final candidates =
          activities
              .where((entry) => entry.activityType == 'remaja_dashboard_state')
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (candidates.isNotEmpty && mounted) {
        final decoded = jsonDecode(candidates.first.value);
        if (decoded is! Map<String, dynamic>) {
          setState(() => _loaded = true);
          return;
        }
        final data = decoded;
        setState(() {
          final loadedMood = (data['moodIndex'] as num?)?.toInt() ?? _moodIndex;
          _moodIndex = loadedMood.clamp(0, _moodLabels.length - 1);
          _focusMinutes =
              (data['focusMinutes'] as num?)?.toInt() ?? _focusMinutes;
          _waterMl = (data['waterMl'] as num?)?.toInt() ?? _waterMl;
          _sleepHours = (data['sleepHours'] as num?)?.toDouble() ?? _sleepHours;
          _points = (data['points'] as num?)?.toInt() ?? _points;
          // Preserve existing daily goals and update with saved data
          if (data['dailyGoals'] is Map) {
            final savedGoals = data['dailyGoals'] as Map;
            _dailyGoals.forEach((key, _) {
              if (savedGoals.containsKey(key)) {
                _dailyGoals[key] = savedGoals[key] as bool;
              }
            });
          }
          // Preserve week mood history if exists
          if (data['weekMood'] is List) {
            final raw = (data['weekMood'] as List)
                .map((e) => (e as num?)?.toInt() ?? 1)
                .map((v) => v.clamp(0, _moodEmoji.length - 1))
                .toList();
            while (raw.length < 7) {
              raw.add(1);
            }
            _weekMood.clear();
            _weekMood.addAll(raw.take(7));
          }
          _loaded = true;
        });
        unawaited(_syncParentRecapsIfNeeded());
      } else if (mounted) {
        setState(() => _loaded = true);
        unawaited(_syncParentRecapsIfNeeded());
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
      unawaited(_syncParentRecapsIfNeeded());
    }
  }

  Future<void> _saveData() async {
    final user = await BackendApiService.getCurrentUser();
    if (user == null) return;
    // final userRef = user.id.toString();

    setState(() => _saving = true);
    try {
      final payload = {
        'dateKey': _todayKey,
        'moodIndex': _moodIndex,
        'moodLabel': _moodLabels[_moodIndex],
        'focusMinutes': _focusMinutes,
        'waterMl': _waterMl,
        'sleepHours': _sleepHours,
        'points': _points,
        'dailyGoals': _dailyGoals,
        'weekMood': _weekMood,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await BackendApiService.logActivity(
        childId: widget.childId ?? user.id,
        activityType: 'remaja_dashboard_state',
        value: jsonEncode(payload),
      );

      // RealtimeService removed — no-op placeholder
      unawaited(Future<void>.value());

      if (widget.childId != null) {
        Future.microtask(() {
          try {
            BackendApiService.logActivity(
              childId: widget.childId!,
              activityType: 'remaja_daily_summary',
              value:
                  'mood=${_moodLabels[_moodIndex]},focus=$_focusMinutes,water=$_waterMl,sleep=$_sleepHours',
            );
          } catch (e) {
            print('WARNING: Failed to log activity: $e');
          }
        });
      }

      unawaited(_syncParentRecapsIfNeeded());

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Progress tersimpan! 🎉')));
    } catch (e) {
      print('ERROR _saveData: Failed to save remaja progress: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan progress: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildProfileCard(String name) {
    final avatar = widget.avatarUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accentColor.withOpacity(0.95), const Color(0xFFB39DDB)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.18),
                backgroundImage: avatar != null && avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                child: avatar == null || avatar.isEmpty
                    ? Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profil Anak Lanjutan',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Ruang pribadi untuk fokus, mood, dan kebiasaan sehat.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _openProfileMenu,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.16),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit profil',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TeenMiniStat(
                  label: 'Mood',
                  value: _moodLabels[_moodIndex],
                  icon: Icons.emoji_emotions_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TeenMiniStat(
                  label: 'Fokus',
                  value: '$_focusMinutes m',
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TeenMiniStat(
                  label: 'Poin',
                  value: '$_points',
                  icon: Icons.stars_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAktivitasCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B5FBF).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_outlined,
                color: const Color(0xFF8B5FBF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Aktivitas Harian',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fokus',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_focusMinutes}m',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF8B5FBF),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Air',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_waterMl}ml',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF8B5FBF),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tidur',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_sleepHours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF8B5FBF),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Poin',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _points.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF8B5FBF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double get _wellnessScore {
    final goalsDone = _dailyGoals.values.where((v) => v).length;
    final goalsScore = goalsDone / _dailyGoals.length;
    final focusScore = (_focusMinutes / 200).clamp(0.0, 1.0);
    final waterScore = (_waterMl / 2000).clamp(0.0, 1.0);
    final sleepScore = (_sleepHours / 8.0).clamp(0.0, 1.0);
    return (goalsScore * 0.4) +
        (focusScore * 0.2) +
        (waterScore * 0.2) +
        (sleepScore * 0.2);
  }

  @override
  Widget build(BuildContext context) {
    if (_moodIndex < 0 || _moodIndex >= _moodLabels.length) {
      _moodIndex = 1;
    }
    final name =
        widget.username ??
        BackendApiService.lastEmail?.split('@').first ??
        'Anak';
    final score = _wellnessScore;
    final scorePercent = (score * 100).round();
    final todayGoalsDone = _dailyGoals.values.where((v) => v).length;

    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Anak Lanjutan'),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.openedFromParentDashboard
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => navigateBackToParentDashboard(
                  context,
                  openedFromParentDashboard: widget.openedFromParentDashboard,
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: _showNotifications,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFAF6F3),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),

                /// ===== GREETING HEADER =====
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFFFDFC9),
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF845342),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $name!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _buildConnectionBanner(),
                          const SizedBox(height: 18),
                          const Text(
                            'Kategori usia: Anak Lanjutan (13-17 tahun)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'Bangun versi terbaik Anda hari ini',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                /// ===== PROFILE CARD =====
                _buildProfileCard(name),
                const SizedBox(height: 12),

                /// ===== AKTIVITAS CARD =====
                _buildAktivitasCard(),
                const SizedBox(height: 18),

                /// ===== WELLNESS SCORE HERO =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFC8E6F7), Color(0xFFE8D5F2)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 90,
                            height: 90,
                            child: CircularProgressIndicator(
                              value: score,
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withOpacity(0.6),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF8B5FBF),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$scorePercent%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: Color(0xFF512B7A),
                                ),
                              ),
                              const Text(
                                'Score',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Wellness Score',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3D3D3D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$todayGoalsDone/${_dailyGoals.length} goals completed',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '⭐ $_points pts',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                /// ===== MOOD TRACKING SECTION =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5E1),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How are you really feeling today?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(_moodEmoji.length, (index) {
                          final isSelected = index == _moodIndex;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _moodIndex = index;
                                _points += 5;
                              });
                            },
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 60,
                                  height: 60,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _moodColors[index]
                                        : Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? _moodColors[index]
                                          : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: _moodColors[index]
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    _moodEmoji[index],
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _moodLabels[index],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                /// ===== TRACKING ROW: FOCUS & WATER =====
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 320,
                      child: _trackingCard(
                        title: 'Focus',
                        value: '$_focusMinutes min',
                        subtitle: 'Target 200 min',
                        icon: Icons.lightbulb_outline,
                        bgColor: const Color(0xFFE3F2FD),
                        action: () => setState(() {
                          _focusMinutes = (_focusMinutes + 30).clamp(0, 480);
                          _points += 3;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: _trackingCard(
                        title: 'Water',
                        value: '${(_waterMl / 250).toStringAsFixed(1)} cup',
                        subtitle: 'Target 8 cups',
                        icon: Icons.water_drop_outlined,
                        bgColor: const Color(0xFFE0F2F1),
                        action: () => setState(() {
                          _waterMl = (_waterMl + 250).clamp(0, 3000);
                          _points += 2;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                /// ===== SLEEP TRACKING =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sleep Quality',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_sleepHours.toStringAsFixed(1)} jam tidur',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF512B7A),
                            ),
                          ),
                          Text(
                            _sleepHours >= 7 ? '✓ Bagus!' : '⚠ Kurang',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _sleepHours >= 7
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Slider(
                        value: _sleepHours,
                        min: 4,
                        max: 12,
                        divisions: 16,
                        label: _sleepHours.toStringAsFixed(1),
                        activeColor: const Color(0xFFE84A89),
                        inactiveColor: Colors.grey.shade300,
                        onChanged: (value) {
                          setState(() => _sleepHours = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                /// ===== DAILY GOALS =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Goals',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._dailyGoals.entries.map((entry) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: entry.value,
                          activeColor: const Color(0xFF8B5FBF),
                          title: Text(entry.key),
                          onChanged: (val) {
                            setState(() {
                              _dailyGoals[entry.key] = val ?? false;
                              if (val ?? false) _points += 10;
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                /// ===== WEEK MOOD TRACKER =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mood This Week',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(7, (index) {
                          final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          final moodAtDay = index < _weekMood.length
                              ? _weekMood[index].clamp(0, _moodEmoji.length - 1)
                              : 1;
                          return Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _moodColors[moodAtDay],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _moodEmoji[moodAtDay],
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dayLabels[index],
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                /// ===== SAVE BUTTON =====
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveData,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _saving ? 'Menyimpan...' : 'Simpan Progress Hari Ini',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF512B7A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trackingCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required VoidCallback action,
  }) {
    return GestureDetector(
      onTap: action,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF666666)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeenMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TeenMiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeenNotificationItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool isDone;

  const _TeenNotificationItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.isDone,
  });
}

class _TeenNotificationTile extends StatelessWidget {
  final _TeenNotificationItem item;

  const _TeenNotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: item.isDone
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.isDone ? 'Done' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: item.isDone
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFF57C00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6478),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
