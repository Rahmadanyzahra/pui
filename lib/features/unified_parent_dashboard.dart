import 'dart:convert';

import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';

import '../models/backend_analytics.dart';
import '../models/backend_connection.dart';
import '../services/backend_api_service.dart';
import 'add_child_screen.dart';
import 'dashboard_anak.dart';
import 'dashboard_baby.dart';
import 'dashboard_toddler.dart';
import 'menu/five_menu_shell.dart';
import 'child_dashboard_screen.dart';
import 'dashboard_config.dart';

class UnifiedParentDashboard extends StatefulWidget {
  const UnifiedParentDashboard({super.key});

  @override
  State<UnifiedParentDashboard> createState() => _UnifiedParentDashboardState();
}

class _UnifiedParentDashboardState extends State<UnifiedParentDashboard> {
  final ScrollController _scrollController = ScrollController();
  static const List<String> _weekdayOrder = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];
  final String _tokenChildRole = 'delegated_parent';
  bool _tokenLoading = false;
  String? _lastGeneratedToken;
  String? _tokenError;
  String? _aiInsight;
  String? _aiInsightError;
  bool _aiInsightLoading = false;
  bool _aiInsightAutoFetchScheduled = false;

  late Future<BackendParentAnalytics> _parentAnalyticsFuture;
  late Future<List<BackendConnectionToken>> _connectionTokensFuture;
  late Future<List<BackendChild>> _connectedChildrenFuture;
  late Future<List<BackendActivityRecord>> _activityRecordsFuture;

  @override
  void initState() {
    super.initState();
    _parentAnalyticsFuture = BackendApiService.getParentAnalytics();
    _connectionTokensFuture = _safeConnectionTokensFuture();
    _connectedChildrenFuture = BackendApiService.getChildren();
    _activityRecordsFuture = BackendApiService.getActivities();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshDashboardData() async {
    setState(() {
      _parentAnalyticsFuture = BackendApiService.getParentAnalytics();
      _connectionTokensFuture = _safeConnectionTokensFuture();
      _connectedChildrenFuture = BackendApiService.getChildren();
      _activityRecordsFuture = BackendApiService.getActivities();
    });

    await Future.wait<void>([
      _parentAnalyticsFuture,
      _connectionTokensFuture,
      _connectedChildrenFuture,
      _activityRecordsFuture,
    ]);
  }

  void _refreshConnectionTokens() {
    setState(() {
      _connectionTokensFuture = _safeConnectionTokensFuture();
    });
  }

  Future<List<BackendConnectionToken>> _safeConnectionTokensFuture() async {
    try {
      return await BackendApiService.listConnectionTokens();
    } catch (error) {
      if (mounted) {
        setState(() {
          _tokenError = error.toString().replaceFirst('Exception: ', '');
        });
      }
      return <BackendConnectionToken>[];
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _generateConnectionToken() async {
    if (_tokenLoading) return;
    setState(() => _tokenLoading = true);

    try {
      final token = await BackendApiService.generateConnectionToken(
        childRole: _tokenChildRole,
      );
      try {
        await BackendApiService.logParentActivity(
          activityType: 'token_generated',
          value: 'role=$_tokenChildRole, source=unified_parent_dashboard',
        );
      } catch (e) {
        debugPrint('Warning: failed to log token generation to backend: $e');
      }
      if (!mounted) return;
      setState(() {
        _lastGeneratedToken = token;
        _tokenError = null;
        _connectionTokensFuture = _safeConnectionTokensFuture();
      });
      _showSnackBar('Token: $token');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tokenError = error.toString().replaceFirst('Exception: ', '');
      });
      _showSnackBar('Error: $error');
    } finally {
      if (mounted) setState(() => _tokenLoading = false);
    }
  }

  Future<void> _loadAiInsight(BackendDashboardAnalytics dashboard) async {
    if (_aiInsightLoading) return;

    setState(() {
      _aiInsightLoading = true;
      _aiInsightError = null;
    });

    final prompt =
        '''
Buat ringkasan parenting singkat dalam bahasa Indonesia berdasarkan dashboard ini:
- Konsistensi check-in: ${dashboard.checkinRate}%
- Aktivitas minggu ini: ${dashboard.weekActivities}
- Aktivitas bulan ini: ${dashboard.monthActivities}
- Hari aktif minggu ini: ${dashboard.activeDaysWeek ?? 0}/7

Berikan 3 saran praktis dan 1 kalimat kesimpulan.
''';

    try {
      final reply = await BackendApiService.sendAiChat(
        message: prompt,
        childId: null,
      );
      if (!mounted) return;
      setState(() {
        _aiInsight = reply;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _aiInsightError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _aiInsightLoading = false);
    }
  }

  Map<String, dynamic>? _decodeActivityValue(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  int _activityCalories(BackendActivityRecord record) {
    final payload = _decodeActivityValue(record.value);
    return (payload?['calories'] as num?)?.toInt() ?? 0;
  }

  Widget _buildActivitySummaryCard() {
    return _buildTapCard(
      title: 'Aktivitas & Progres Anak',
      subtitle: 'Ringkasan aktivitas terbaru dan kalori makan',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEDE7F6), Color(0xFFE8F5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FutureBuilder<List<BackendActivityRecord>>(
          future: _activityRecordsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gagal memuat aktivitas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF725E78),
                    ),
                  ),
                ],
              );
            }

            final records = snapshot.data ?? <BackendActivityRecord>[];
            final mealRecords = records
                .where((record) => record.activityType == 'meal')
                .toList();
            final totalCalories = mealRecords.fold<int>(
              0,
              (sum, record) => sum + _activityCalories(record),
            );
            final recent = records.take(5).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildMiniStat('Total Aktivitas', '${records.length} item'),
                    _buildMiniStat('Meal', '${mealRecords.length} item'),
                    _buildMiniStat('Kalori', '$totalCalories kcal'),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Aktivitas terbaru',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF51375F),
                  ),
                ),
                const SizedBox(height: 10),
                if (recent.isEmpty)
                  const Text(
                    'Belum ada aktivitas tercatat.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF725E78)),
                  )
                else
                  ...recent
                      .map((record) {
                        final payload = _decodeActivityValue(record.value);
                        final menu =
                            payload?['menu']?.toString() ?? record.value;
                        final calories = _activityCalories(record);
                        final childLabel = record.childId == null
                            ? 'Parent'
                            : 'Child #${record.childId}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.timeline_rounded,
                                  color: Color(0xFF8F74DA),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$childLabel • ${record.activityType}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF51375F),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        menu,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF725E78),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  calories > 0 ? '$calories kcal' : '-',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFF06292),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      ,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddChildShortcutCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _openManualAddChildPage,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFDE7F3), Color(0xFFFFF8E1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person_add_alt_1,
                  color: Color(0xFFF06292),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tambah Anak Manual',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF51375F),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Token tidak diperlukan untuk add manual',
                      style: TextStyle(fontSize: 12, color: Color(0xFF725E78)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFF06292)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF725E78),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF51375F),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _openFeaturePage(String title, int initialIndex) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => FiveMenuShell(
          childId: null,
          themeColor: const Color(0xFFF06292),
          titlePrefix: title,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openManualAddChildPage() async {
    final result = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<Object?>(MaterialPageRoute(builder: (_) => const AddChildScreen()));
    if (result is Map && result['saved'] == true) {
      setState(() {
        _parentAnalyticsFuture = BackendApiService.getParentAnalytics();
        _connectedChildrenFuture = BackendApiService.getChildren();
        _activityRecordsFuture = BackendApiService.getActivities();
      });
      _openSavedChildDashboard(result);
    }
  }

  List<MapEntry<String, int>> _orderedWeekSeries(
    Map<String, int> weeklySeries,
  ) {
    String normalizeKey(String key) {
      final value = key.trim().toLowerCase();
      switch (value) {
        case 'sen':
        case 'senin':
        case 'mon':
        case 'monday':
          return 'Sen';
        case 'sel':
        case 'selasa':
        case 'tue':
        case 'tuesday':
          return 'Sel';
        case 'rab':
        case 'rabu':
        case 'wed':
        case 'wednesday':
          return 'Rab';
        case 'kam':
        case 'kamis':
        case 'thu':
        case 'thursday':
          return 'Kam';
        case 'jum':
        case 'jumat':
        case 'fri':
        case 'friday':
          return 'Jum';
        case 'sab':
        case 'sabtu':
        case 'sat':
        case 'saturday':
          return 'Sab';
        case 'min':
        case 'minggu':
        case 'sun':
        case 'sunday':
          return 'Min';
        default:
          return key;
      }
    }

    final normalized = <String, int>{for (final day in _weekdayOrder) day: 0};

    for (final entry in weeklySeries.entries) {
      final day = normalizeKey(entry.key);
      normalized[day] = (normalized[day] ?? 0) + entry.value;
    }

    return _weekdayOrder
        .map((day) => MapEntry(day, normalized[day] ?? 0))
        .toList(growable: false);
  }

  Widget _buildWeeklyGraphCard(Map<String, int> weeklySeries) {
    final rows = _orderedWeekSeries(weeklySeries);
    final maxValue = rows.fold<int>(
      1,
      (max, item) => item.value > max ? item.value : max,
    );
    final hasData = rows.any((item) => item.value > 0);

    return _buildTapCard(
      title: 'Grafik Mingguan',
      subtitle: hasData
          ? 'Aktivitas 7 hari terakhir'
          : 'Belum ada aktivitas, grafik akan muncul otomatis',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFE3F2FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Aktivitas per Hari',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E4057),
                  ),
                ),
                Text(
                  'Total: ${rows.fold<int>(0, (sum, item) => sum + item.value)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5E7388),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: rows
                    .map((item) {
                      final ratio = maxValue <= 0
                          ? 0.0
                          : (item.value / maxValue).clamp(0.0, 1.0);
                      final barHeight = hasData
                          ? (22 + (78 * ratio)).toDouble()
                          : 10.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${item.value}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4F6375),
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOut,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7E57C2),
                                      Color(0xFF42A5F5),
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.key,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5E7388),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSavedChildDashboard(Map result) {
    final category = (result['category'] as String?) ?? 'anak';
    final age = (result['age'] as int?) ?? 0;

    Widget dashboard;
    switch (category) {
      case 'baby':
        dashboard = BabyDashboard(umur: age, openedFromParentDashboard: true);
        break;
      case 'toddler':
        dashboard = ToddlerDashboard(
          umur: age,
          openedFromParentDashboard: true,
        );
        break;
      case 'balita':
        dashboard = AnakDashboard(umur: age, openedFromParentDashboard: true);
        break;
      case 'anak':
      default:
        dashboard = AnakDashboard(umur: age, openedFromParentDashboard: true);
        break;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => dashboard));
  }

  Future<void> _deleteChild(BackendChild child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus anak?'),
        content: Text(
          'Hapus data ${child.nama}? Aksi ini juga menghapus aktivitas terkait.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await BackendApiService.deleteChild(child.id);
      if (!mounted) return;
      setState(() {
        _connectedChildrenFuture = BackendApiService.getChildren();
        _parentAnalyticsFuture = BackendApiService.getParentAnalytics();
        _activityRecordsFuture = BackendApiService.getActivities();
      });
      _showSnackBar('Data anak berhasil dihapus');
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    // final user = FirebaseAuth.instance.currentUser;
    // TODO: Integrate backend user session check

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<BackendParentAnalytics>(
        future: _parentAnalyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Error loading dashboard'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _parentAnalyticsFuture =
                            BackendApiService.getParentAnalytics();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload'),
                  ),
                ],
              ),
            );
          }

          final dashboard = snapshot.data!.dashboard;
          final weeklySeries =
              snapshot.data!.menus['info']?.weeklySeries ??
              const <String, int>{};

          if (_aiInsight == null &&
              !_aiInsightLoading &&
              _aiInsightError == null &&
              !_aiInsightAutoFetchScheduled) {
            _aiInsightAutoFetchScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _aiInsight != null || _aiInsightLoading) {
                return;
              }
              _loadAiInsight(dashboard);
            });
          }

          return RefreshIndicator(
            onRefresh: _refreshDashboardData,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTapCard(
                    title: 'Your Progress',
                    subtitle:
                        '${dashboard.checkinRate}% consistency, ${dashboard.weekActivities} activities this week',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF3E8FF), Color(0xFFEDE7F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your Progress',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8F74DA),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${dashboard.checkinRate}%',
                                      style: const TextStyle(
                                        fontSize: 64,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF8F74DA),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value:
                                          (dashboard.weekActivities /
                                                  (dashboard.activeDaysWeek ??
                                                      7))
                                              .clamp(0.0, 1.0),
                                      strokeWidth: 8,
                                      backgroundColor: const Color(
                                        0xFFEDE7F6,
                                      ).withOpacity(0.5),
                                      valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFF8F74DA),
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${dashboard.weekActivities}',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF8F74DA),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'aktif',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF8F74DA),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'November 19',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(
                                    0xFF8F74DA,
                                  ).withOpacity(0.7),
                                ),
                              ),
                              Icon(
                                Icons.expand_more,
                                color: const Color(0xFF8F74DA).withOpacity(0.7),
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildMiniStat(
                        'Child Terkoneksi',
                        '${snapshot.data!.childrenCount}',
                      ),
                      _buildMiniStat(
                        'Monitoring Aktif',
                        '${dashboard.activeChildrenWeek ?? 0}',
                      ),
                      _buildMiniStat(
                        'Tidak Aktif',
                        '${dashboard.inactiveChildrenWeek ?? 0}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildWeeklyGraphCard(weeklySeries),
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Activity Recaps',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1B24),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Everything you need to know about your health',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildSmallMetricCard(
                              'Proteins',
                              '${dashboard.monthActivities}',
                              const Color(0xFFFFCCB3),
                            ),
                            _buildSmallMetricCard(
                              'Fats',
                              '${dashboard.weekActivities}',
                              const Color(0xFFB3E5D8),
                            ),
                            _buildSmallMetricCard(
                              'Carbs',
                              '${dashboard.activeDaysWeek ?? 0}',
                              const Color(0xFFE8D5F7),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildBottomQuickMenu(
                    weekActivities: dashboard.weekActivities,
                    checkinRate: dashboard.checkinRate,
                    activeDaysWeek: dashboard.activeDaysWeek ?? 0,
                  ),
                  const SizedBox(height: 24),

                  _buildAiInsightCard(dashboard),
                  const SizedBox(height: 24),

                  _buildAddChildShortcutCard(),
                  const SizedBox(height: 24),

                  _buildActivitySummaryCard(),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTapCard(
                          title: 'Sport Data',
                          subtitle: '${dashboard.weekActivities} activities',
                          borderRadius: 20,
                          child: _buildMiniCard(
                            'Sport Data',
                            '${dashboard.weekActivities}',
                            'activities',
                            const Color(0xFFFFCCB3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTapCard(
                          title: 'Health Health',
                          subtitle: '${dashboard.checkinRate}% consistency',
                          borderRadius: 20,
                          child: _buildMiniCard(
                            'Health Health',
                            '${dashboard.checkinRate}%',
                            'consistency',
                            const Color(0xFFB3D9E8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildTapCard(
                    title: 'Sleep Quality',
                    subtitle: '${dashboard.activeDaysWeek ?? 0}/7 days tracked',
                    borderRadius: 20,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5F4E6),
                        borderRadius: BorderRadius.circular(20),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Sleep Quality',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00796B),
                                ),
                              ),
                              const Icon(
                                Icons.stars,
                                color: Color(0xFF00796B),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${dashboard.activeDaysWeek ?? 0}/7 days',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00796B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFF00796B),
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Check',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00796B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTapCard(
                    title: 'Generate Token',
                    subtitle:
                        'Generate token delegasi orang tua untuk input kegiatan',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFDCDDC), Color(0xFFFBCCD0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Generate Token',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF51375F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Gunakan token ini untuk menghubungkan delegasi orang tua',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF725E78),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Material(
                            color: Colors.transparent,
                            child: DropdownButtonFormField<String>(
                              value: _tokenChildRole,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.7),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'delegated_parent',
                                  child: Text('Delegasi Orang Tua'),
                                ),
                              ],
                              onChanged: _tokenLoading ? null : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _tokenLoading
                                  ? null
                                  : _generateConnectionToken,
                              icon: _tokenLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.qr_code_2),
                              label: const Text('Generate Token'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8BAA),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          if (_lastGeneratedToken != null) ...[
                            const SizedBox(height: 12),
                            _buildLatestTokenCard(_lastGeneratedToken!),
                          ],
                          if (_tokenError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE57373),
                                ),
                              ),
                              child: Text(
                                _tokenError!,
                                style: const TextStyle(
                                  color: Color(0xFFB71C1C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildTokenListSection(),
                          const SizedBox(height: 12),
                          _buildConnectedChildrenSection(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildParentBottomBar(),
    );
  }

  Widget _buildParentBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildBottomBarItem(
                icon: Icons.home_rounded,
                label: 'Home',
                onTap: _scrollToTop,
              ),
            ),
            Expanded(
              child: _buildBottomBarItem(
                icon: Icons.info_outline_rounded,
                label: 'Info',
                onTap: () => _openFeaturePage('Parent', 1),
              ),
            ),
            SizedBox(
              width: 72,
              child: Align(
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => _openFeaturePage('Parent', 2),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5FA2), Color(0xFFF06292)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF06292).withOpacity(0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildBottomBarItem(
                icon: Icons.calendar_month_rounded,
                label: 'Jadwal',
                onTap: () => _openFeaturePage('Parent', 3),
              ),
            ),
            Expanded(
              child: _buildBottomBarItem(
                icon: Icons.person_rounded,
                label: 'Akun',
                onTap: () => _openFeaturePage('Parent', 4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF7A6288), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A6288),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomQuickMenu({
    required int weekActivities,
    required int checkinRate,
    required int activeDaysWeek,
  }) {
    final activitySubtitle = weekActivities > 0
        ? '$weekActivities aktivitas minggu ini'
        : 'Belum ada aktivitas, menu tetap bisa dibuka';
    final progressSubtitle = activeDaysWeek > 0
        ? '$activeDaysWeek/7 hari aktif'
        : 'Belum ada data, tetap bisa dibuka';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Menu Cepat',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF51375F),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQuickActionButton(
                icon: Icons.directions_run_rounded,
                label: 'Aktivitas',
                subtitle: activitySubtitle,
                color: const Color(0xFFFFD9C7),
              ),
              const SizedBox(width: 10),
              _buildQuickActionButton(
                icon: Icons.insights_rounded,
                label: 'Info Perkembangan',
                subtitle: progressSubtitle,
                color: const Color(0xFFDDF5E8),
              ),
              const SizedBox(width: 10),
              _buildQuickActionButton(
                icon: Icons.smart_toy_rounded,
                label: 'Profil AI',
                subtitle: 'Konsistensi $checkinRate%',
                color: const Color(0xFFEADDFB),
              ),
              const SizedBox(width: 10),

              _buildQuickActionButton(
                icon: Icons.child_care_rounded,
                label: 'Menu Anak TB',
                subtitle: 'Akses menu anak',
                color: const Color(0xFFD8EAF9),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsightCard(BackendDashboardAnalytics dashboard) {
    return _buildTapCard(
      title: 'AI Parenting Insight',
      subtitle: 'Ringkasan otomatis dari Gemini atau GPT',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEDE7F6), Color(0xFFF8EAF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFFF8BAA).withOpacity(0.16),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: Color(0xFF8F74DA),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Parenting Insight',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF51375F),
                        ),
                      ),
                      Text(
                        'Dipanggil dari backend AI yang bisa diarahkan ke Gemini atau GPT',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: const Color(0xFF725E78).withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _aiInsightLoading
                      ? null
                      : () => _loadAiInsight(dashboard),
                  icon: const Icon(Icons.refresh_rounded),
                  color: const Color(0xFF8F74DA),
                  tooltip: 'Perbarui insight',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_aiInsightLoading)
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sedang membuat ringkasan AI...',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF51375F),
                      ),
                    ),
                  ),
                ],
              )
            else if (_aiInsightError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _aiInsightError!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFB71C1C),
                  ),
                ),
              )
            else if (_aiInsight != null)
              Text(
                _aiInsight!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Color(0xFF36253F),
                ),
              )
            else
              const Text(
                'Tekan ikon refresh untuk membuat insight AI berdasarkan dashboard terkini.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Color(0xFF725E78),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenListSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<List<BackendConnectionToken>>(
        future: _connectionTokensFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gagal memuat daftar token',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _refreshConnectionTokens,
                  child: const Text('Coba Lagi'),
                ),
              ],
            );
          }

          final tokens = snapshot.data ?? <BackendConnectionToken>[];
          if (tokens.isEmpty) {
            return const Text(
              'Belum ada token. Tekan Generate Token untuk membuat token baru.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF725E78),
                fontWeight: FontWeight.w600,
              ),
            );
          }

          final latest = tokens.take(3).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daftar Token',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF51375F),
                ),
              ),
              const SizedBox(height: 8),
              ...latest.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: item.isUsed
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF7FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: item.isUsed
                            ? const Color(0xFFA5D6A7)
                            : const Color(0xFFF8BBD0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.token,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF36253F),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.isUsed ? 'Terpakai' : 'Aktif',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: item.isUsed
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFD81B60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLatestTokenCard(String token) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Token Terbaru',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF51375F),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            token,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF36253F),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bagikan token ini ke delegasi orang tua untuk mengakses input kegiatan.',
            style: TextStyle(fontSize: 11, color: Color(0xFF725E78)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return SizedBox(
      width: 132,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openMenuDetail(label, subtitle),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
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
                Icon(icon, size: 18, color: const Color(0xFF51375F)),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF51375F),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTapCard({
    required String title,
    required String subtitle,
    required Widget child,
    double borderRadius = 24,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap ?? () => _openMenuDetail(title, subtitle),
        child: child,
      ),
    );
  }

  void _openMenuDetail(String title, String subtitle) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF51375F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF725E78),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8BAA),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectedChildrenSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<List<BackendChild>>(
        future: _connectedChildrenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gagal memuat anak terhubung',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _connectedChildrenFuture =
                          BackendApiService.getChildren();
                    });
                  },
                  child: const Text('Coba Lagi'),
                ),
              ],
            );
          }

          final children = snapshot.data ?? <BackendChild>[];
          if (children.isEmpty) {
            return const Text(
              'Belum ada anak terhubung.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF725E78),
                fontWeight: FontWeight.w600,
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map(
                  (c) => ListTile(
                    leading: const Icon(Icons.child_care),
                    title: Text('${c.nama} (${c.umur} th)'),
                    subtitle: Text(
                      'Buka dashboard: ${mapCategoryFromAge(c.umur)}',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Hapus anak',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteChild(c),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _openChildDashboard(c),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  void _openChildDashboard(BackendChild child) {
    final category = mapCategoryFromAge(child.umur);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChildDashboardScreen(
          category: category,
          umur: child.umur,
          childId: child.id,
          openedFromParentDashboard: true,
        ),
      ),
    );
  }

  Widget _buildSmallMetricCard(String label, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(
    String title,
    String value,
    String subtitle,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF51375F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF999999),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
