import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dashboard_back_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/backend_connection.dart';
import '../services/backend_api_service.dart';
import '../services/dashboard_theme_service.dart';
import '../services/local_notification_service.dart';
// import '../services/realtime_service.dart';
import 'join_parent_token_screen.dart';

class AnakDashboard extends StatefulWidget {
  final int? umur;
  final int? childId;
  final bool openedFromParentDashboard;

  const AnakDashboard({
    super.key,
    required this.umur,
    this.childId,
    this.openedFromParentDashboard = false,
  });

  @override
  State<AnakDashboard> createState() => _AnakDashboardState();
}

class _AnakDashboardState extends State<AnakDashboard> {
  int _belajarMenit = 0;
  int _poin = 0;
  final Map<String, bool> _dailyChecklist = {
    'Sarapan': false,
    'Gosok gigi': false,
    'Belajar': false,
    'Main sore': false,
    'Tidur tepat waktu': false,
  };
  final List<String> _tasks = [];
  final TextEditingController _taskController = TextEditingController();
  bool _saving = false;
  StreamSubscription<void>? _familySettingsSubscription;
  DashboardThemeProfile _theme = DashboardThemeProfile.defaultTheme('anak');
  Future<BackendConnectionStatus>? _connectionStatusFuture;

  final String _todayKey = DateTime.now().toIso8601String().substring(0, 10);

  bool get _isYoungChild => (widget.umur ?? 0) < 10;

  Null get RealtimeService => null;

  Future<void> _save() async {
    final user = await BackendApiService.getCurrentUser();
    if (user == null) return;
    // final userRef = user.id.toString();
    setState(() => _saving = true);
    try {
      final payload = {
        'dateKey': _todayKey,
        'belajarMenit': _belajarMenit,
        'poin': _poin,
        'checklist': _dailyChecklist,
        'tasks': _tasks,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await BackendApiService.logActivity(
        childId: widget.childId ?? user.id,
        activityType: 'anak_dashboard_state',
        value: jsonEncode(payload),
      );
      // RealtimeService.pushLiveStatus removed (Firebase migration)
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data tersimpan!')));

      // Backend API non-blocking call at the end (fire-and-forget)
      if (widget.childId != null) {
        Future.microtask(() {
          try {
            BackendApiService.logActivity(
              childId: widget.childId!,
              activityType: 'anak_daily_summary',
              value: 'poin=$_poin,belajarMenit=$_belajarMenit',
            );
          } catch (e) {
            print('WARNING: Failed to log activity: $e');
          }
        });
      }

      unawaited(_syncParentRecapsIfNeeded());
    } catch (e) {
      print('ERROR _save anak: Failed to save data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan data: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _load() async {
    final user = await BackendApiService.getCurrentUser();
    if (user == null) return;
    try {
      final activities = await BackendApiService.getActivities(
        childId: widget.childId ?? user.id,
      );
      final candidates =
          activities
              .where((entry) => entry.activityType == 'anak_dashboard_state')
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (candidates.isNotEmpty && mounted) {
        final decoded = jsonDecode(candidates.first.value);
        if (decoded is! Map<String, dynamic>) return;
        final d = decoded;
        setState(() {
          _belajarMenit = (d['belajarMenit'] as num?)?.toInt() ?? 0;
          _poin = (d['poin'] as num?)?.toInt() ?? 0;
          if (d['checklist'] is Map) {
            _dailyChecklist.clear();
            (d['checklist'] as Map).forEach((k, v) {
              _dailyChecklist[k.toString()] = v as bool;
            });
          }
          if (d['tasks'] is List) {
            _tasks.clear();
            _tasks.addAll((d['tasks'] as List).map((e) => e.toString()));
          }
        });
        unawaited(_syncParentRecapsIfNeeded());
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _load();
    _listenToFamilySettings();
    _connectionStatusFuture = BackendApiService.getConnectionStatus();
  }

  @override
  void dispose() {
    _familySettingsSubscription?.cancel();
    _taskController.dispose();
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
            const JoinParentTokenScreen(roleLabel: 'Dashboard Anak'),
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
      final sentKey = 'recap_sent_anak_${recapType}_$periodKey';
      if (prefs.getBool(sentKey) == true) return;

      try {
        await BackendApiService.logActivity(
          childId: childId,
          activityType: 'anak_${recapType}_recap',
          value: summary.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join(','),
        );
        await prefs.setBool(sentKey, true);
      } catch (_) {}
    }

    final activities = await BackendApiService.getActivities(childId: childId);
    final dailyStateDocs = activities
        .where((entry) => entry.activityType == 'anak_dashboard_state')
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
      final totalBelajar = docs.fold<int>(
        0,
        (sum, doc) => sum + ((doc['belajarMenit'] as num?)?.toInt() ?? 0),
      );
      final totalPoin = docs.fold<int>(
        0,
        (sum, doc) => sum + ((doc['poin'] as num?)?.toInt() ?? 0),
      );
      final checklistDone = docs.fold<int>(0, (sum, doc) {
        final checklist = doc['checklist'];
        if (checklist is Map) {
          return sum + checklist.values.where((value) => value == true).length;
        }
        return sum;
      });
      final tasksCount = docs.fold<int>(0, (sum, doc) {
        final tasks = doc['tasks'];
        if (tasks is List) return sum + tasks.length;
        return sum;
      });

      return {
        'belajarMenit': totalBelajar,
        'poin': totalPoin,
        'checklistDone': checklistDone,
        'tasksCount': tasksCount,
        'days': docs.length,
      };
    }

    final dailySummary = {
      'belajarMenit': _belajarMenit,
      'poin': _poin,
      'checklistDone': _dailyChecklist.values.where((value) => value).length,
      'tasksCount': _tasks.length,
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

  Widget _buildConnectionBanner() {
    return FutureBuilder<BackendConnectionStatus>(
      future: _connectionStatusFuture,
      builder: (context, snapshot) {
        final connected = snapshot.data?.connected == true;
        final statusText = connected
            ? 'Sudah terhubung ke parent'
            : 'Belum terhubung ke parent';
        final accent = connected
            ? const Color(0xFF2E7D32)
            : const Color(0xFFF57C00);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
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

  void _listenToFamilySettings() {
    _familySettingsSubscription =
        Stream<void>.periodic(const Duration(minutes: 15), (_) {}).listen((_) {
          LocalNotificationService.syncFamilyReminders(
            autoReminderEnabled: true,
            learnReminderHour: 19,
            sleepReminderHour: 21,
          );
        });
  }

  Future<void> _loadTheme() async {
    final theme = await DashboardThemeService.getTheme('anak');
    if (mounted) setState(() => _theme = theme);
  }

  @override
  Widget build(BuildContext context) {
    final themedContext = Theme.of(context).copyWith(
      textTheme: Theme.of(
        context,
      ).textTheme.apply(fontFamily: _theme.fontFamily),
      primaryTextTheme: Theme.of(
        context,
      ).primaryTextTheme.apply(fontFamily: _theme.fontFamily),
    );

    final userName = BackendApiService.lastEmail?.split('@').first ?? 'Pelajar';

    final isLoggedIn = BackendApiService.lastEmail != null;

    if (!isLoggedIn) {
      return Theme(
        data: themedContext,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    size: 64,
                    color: _theme.primaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Silakan login untuk menggunakan fitur dashboard anak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Theme(
      data: themedContext,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: _theme.primaryColor,
          elevation: 0,
          leading: widget.openedFromParentDashboard
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: _theme.primaryColor),
                  onPressed: () => navigateBackToParentDashboard(
                    context,
                    openedFromParentDashboard: widget.openedFromParentDashboard,
                  ),
                )
              : null,
          title: Text(
            'Dashboard Anak (4-12 th)',
            style: TextStyle(
              color: _theme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              onPressed: () => BackendApiService.clearSession(
                clearPassword: true,
                clearEmail: true,
              ),
              icon: Icon(Icons.logout, color: _theme.primaryColor),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(userName),
              const SizedBox(height: 12),
              _buildConnectionBanner(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isYoungChild
                                  ? 'Petualangan Belajar'
                                  : 'Zona Produktif',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              _isYoungChild
                                  ? 'Usia: ${widget.umur} th'
                                  : 'Kelola aktivitasmu',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_isYoungChild) ...[
                      _buildYoungChildInterface(),
                    ] else ...[
                      _buildOlderChildInterface(),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYoungChildInterface() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Checklist Harian',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: _dailyChecklist.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          final nextValue = !entry.value;
                          _dailyChecklist[entry.key] = nextValue;
                          if (nextValue) {
                            _poin += 10;
                          } else if (_poin >= 10) {
                            _poin -= 10;
                          }
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.value
                              ? _theme.primaryColor
                              : Colors.grey[300],
                        ),
                        child: entry.value
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Pengingat Penting',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 110,
              child: _buildReminderCard('Belajar', Colors.purple),
            ),
            SizedBox(
              width: 110,
              child: _buildReminderCard('Istirahat', Colors.pink),
            ),
            SizedBox(
              width: 110,
              child: _buildReminderCard('Bermain', Colors.cyan),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Poin Belajarmu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _theme.primaryColor.withOpacity(0.15),
                _theme.accentColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _theme.primaryColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Poin',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_poin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _theme.primaryColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _theme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Checklist',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '${_dailyChecklist.values.where((v) => v).length}/${_dailyChecklist.length}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildQuickMenuSection(),
        const SizedBox(height: 20),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildOlderChildInterface() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Checklist Harian',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: _dailyChecklist.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          final nextValue = !entry.value;
                          _dailyChecklist[entry.key] = nextValue;
                          if (nextValue) {
                            _poin += 15;
                          } else if (_poin >= 15) {
                            _poin -= 15;
                          }
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.value
                              ? _theme.primaryColor
                              : Colors.grey[300],
                        ),
                        child: entry.value
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Sistem Reward',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.amber[100]!.withOpacity(0.5),
                Colors.orange[100]!.withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber[300]!, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Poin Reward',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_poin',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Level',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '${(_poin ~/ 100) + 1}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tugas Harimu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width > 500
                  ? 380
                  : double.infinity,
              child: TextField(
                controller: _taskController,
                decoration: InputDecoration(
                  hintText: 'Tambah tugas...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (_taskController.text.isNotEmpty) {
                  setState(() {
                    _tasks.add(_taskController.text);
                    _taskController.clear();
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _theme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tasks.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: _tasks
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                _tasks.removeAt(entry.key);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 20),
        _buildQuickMenuSection(),
        const SizedBox(height: 20),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildHeader(String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_theme.primaryColor, _theme.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $userName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kategori usia: Anak (6-12 tahun)',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  _isYoungChild
                      ? 'Mari belajar hari ini!'
                      : 'Produktif itu keren!',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: Center(
                child: Text(
                  _isYoungChild ? 'C' : 'T',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await BackendApiService.clearSession(
                  clearPassword: true,
                  clearEmail: true,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Berhasil logout')),
                );
              },
              tooltip: 'Logout',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline, color: color, size: 16),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fokus Aktivitas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildFeatureCard(
              'MPASI',
              Icons.restaurant_menu,
              Colors.orange,
              () => _showFeatureAction('MPASI'),
            ),
            const SizedBox(width: 10),
            _buildFeatureCard(
              'Sensorik',
              Icons.touch_app,
              Colors.purple,
              () => _showFeatureAction('Sensorik'),
            ),
            const SizedBox(width: 10),
            _buildFeatureCard(
              'Play',
              Icons.toys,
              Colors.cyan,
              () => _showFeatureAction('Play'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25), width: 1.2),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeatureAction(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Buka $feature untuk rekomendasi kegiatan hari ini.'),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          _saving ? 'Menyimpan...' : 'Simpan Progress',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _theme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}
