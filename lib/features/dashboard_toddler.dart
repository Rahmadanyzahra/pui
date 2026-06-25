import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dashboard_back_navigation.dart';
import '../services/backend_api_service.dart';
import '../services/dashboard_theme_service.dart';
// import '../services/realtime_service.dart';
import '../widgets/activity_stats_card.dart';
import 'toddler_reading_module.dart';

class ToddlerDashboard extends StatefulWidget {
  final int? umur;
  final int? childId;
  final bool openedFromParentDashboard;

  const ToddlerDashboard({
    super.key,
    required this.umur,
    this.childId,
    this.openedFromParentDashboard = false,
  });

  @override
  State<ToddlerDashboard> createState() => _ToddlerDashboardState();
}

class _ToddlerDashboardState extends State<ToddlerDashboard> {
  int _tantrum = 0;
  int _bicara = 0;
  int _aktivitas = 0;
  int _stars = 0;
  bool _autoLock = false;
  double _heightCm = 92;
  double _weightKg = 13.4;
  int _pottySuccess = 0;
  int _pottyAccident = 0;
  final TextEditingController _aiToddlerController = TextEditingController();

  final Map<String, bool> _habitChecklist = {
    'Bangun pagi': false,
    'Mandi': false,
    'Gosok gigi': false,
    'Makan teratur': false,
    'Tidur siang': false,
  };

  final List<_BehaviorLog> _behaviorLogs = [];
  final List<_PlayIdea> _playIdeas = [
    _PlayIdea(
      'Indoor: Puzzle warna',
      'Melatih fokus & motorik halus',
      'indoor',
    ),
    _PlayIdea('Indoor: Susun balok', 'Latih koordinasi tangan-mata', 'indoor'),
    _PlayIdea(
      'Outdoor: Bola lempar tangkap',
      'Latih sosial & motorik kasar',
      'outdoor',
    ),
    _PlayIdea('Outdoor: Jalan di taman', 'Eksplorasi sensori alami', 'outdoor'),
  ];

  final Map<String, int> _learningProgress = {
    'Alphabet': 25,
    'Angka': 30,
    'Warna & Bentuk': 40,
  };

  final Map<String, bool> _growthMilestone = {
    'Bicara 2-3 kata': false,
    'Jalan/Lari stabil': false,
    'Bermain sosial': false,
  };

  bool _saving = false;
  final DashboardThemeProfile _theme = DashboardThemeProfile.defaultTheme(
    'toddler',
  );

  final String _todayKey = DateTime.now().toIso8601String().substring(0, 10);

  // Jadwal harian sederhana
  final List<Map<String, dynamic>> _jadwal = [
    {'waktu': '07:00', 'kegiatan': 'Bangun & sarapan', 'done': false},
    {'waktu': '09:00', 'kegiatan': 'Bermain bebas', 'done': false},
    {'waktu': '11:00', 'kegiatan': 'Edukasi / buku cerita', 'done': false},
    {'waktu': '12:00', 'kegiatan': 'Makan siang & tidur siang', 'done': false},
    {'waktu': '15:00', 'kegiatan': 'Bermain di luar', 'done': false},
    {'waktu': '19:00', 'kegiatan': 'Mandi & persiapan tidur', 'done': false},
  ];

  Future<void> _save() async {
    final user = await BackendApiService.getCurrentUser();
    if (user == null) return;
    // final userRef = user.id.toString();
    setState(() => _saving = true);
    try {
      final payload = {
        'dateKey': _todayKey,
        'tantrum': _tantrum,
        'bicara': _bicara,
        'aktivitas': _aktivitas,
        'jadwal': _jadwal,
        'stars': _stars,
        'habitChecklist': _habitChecklist,
        'behaviorLogs': _behaviorLogs.map((e) => e.toMap()).toList(),
        'playIdeas': _playIdeas.map((e) => e.toMap()).toList(),
        'learningProgress': _learningProgress,
        'autoLock': _autoLock,
        'heightCm': _heightCm,
        'weightKg': _weightKg,
        'growthMilestone': _growthMilestone,
        'pottySuccess': _pottySuccess,
        'pottyAccident': _pottyAccident,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await BackendApiService.logActivity(
        childId: widget.childId ?? user.id,
        activityType: 'toddler_dashboard_state',
        value: jsonEncode(payload),
      );
      // RealtimeService.pushLiveStatus removed (Firebase migration)
      if (widget.childId != null) {
        try {
          await BackendApiService.logActivity(
            childId: widget.childId!,
            activityType: 'toddler_daily_summary',
            value: 'tantrum=$_tantrum,bicara=$_bicara,aktivitas=$_aktivitas',
          );
        } catch (e) {
          print('WARNING: Failed to log activity: $e');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data tersimpan!')));
    } catch (e) {
      print('ERROR _save toddler: Failed to save data: $e');
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
              .where((entry) => entry.activityType == 'toddler_dashboard_state')
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (candidates.isNotEmpty && mounted) {
        final decoded = jsonDecode(candidates.first.value);
        if (decoded is! Map<String, dynamic>) return;
        final d = decoded;
        setState(() {
          _tantrum = (d['tantrum'] as num?)?.toInt() ?? 0;
          _bicara = (d['bicara'] as num?)?.toInt() ?? 0;
          _aktivitas = (d['aktivitas'] as num?)?.toInt() ?? 0;
          _stars = (d['stars'] as num?)?.toInt() ?? _stars;
          _autoLock = d['autoLock'] == true;
          _heightCm = (d['heightCm'] as num?)?.toDouble() ?? _heightCm;
          _weightKg = (d['weightKg'] as num?)?.toDouble() ?? _weightKg;
          _pottySuccess = (d['pottySuccess'] as num?)?.toInt() ?? _pottySuccess;
          _pottyAccident =
              (d['pottyAccident'] as num?)?.toInt() ?? _pottyAccident;

          final habit = d['habitChecklist'] as Map<String, dynamic>?;
          if (habit != null) {
            habit.forEach((k, v) {
              if (_habitChecklist.containsKey(k)) {
                _habitChecklist[k] = v == true;
              }
            });
          }

          final learning = d['learningProgress'] as Map<String, dynamic>?;
          if (learning != null) {
            learning.forEach((k, v) {
              if (_learningProgress.containsKey(k)) {
                _learningProgress[k] = (v as num).toInt();
              }
            });
          }

          final growth = d['growthMilestone'] as Map<String, dynamic>?;
          if (growth != null) {
            growth.forEach((k, v) {
              if (_growthMilestone.containsKey(k)) {
                _growthMilestone[k] = v == true;
              }
            });
          }

          _behaviorLogs
            ..clear()
            ..addAll(
              ((d['behaviorLogs'] as List?) ?? const []).whereType<Map>().map(
                (e) => _BehaviorLog.fromMap(Map<String, dynamic>.from(e)),
              ),
            );

          _playIdeas
            ..clear()
            ..addAll(
              ((d['playIdeas'] as List?) ?? const []).whereType<Map>().map(
                (e) => _PlayIdea.fromMap(Map<String, dynamic>.from(e)),
              ),
            );
        });
      }
    } catch (_) {
      // Ignore Firestore read failures to keep dashboard usable.
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _aiToddlerController.dispose();
    super.dispose();
  }

  String get _behaviorInsight {
    if (_behaviorLogs.isEmpty) return 'Belum ada log perilaku hari ini.';
    final byHour = <int, int>{};
    final byCause = <String, int>{};
    for (final log in _behaviorLogs) {
      byHour[log.hour] = (byHour[log.hour] ?? 0) + 1;
      byCause[log.cause] = (byCause[log.cause] ?? 0) + 1;
    }
    final topHour = byHour.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final topCause = byCause.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return 'Sering tantrum sekitar jam ${topHour.toString().padLeft(2, '0')}:00, kemungkinan dipicu "$topCause".';
  }

  String get _smartAiInsight {
    if (_behaviorLogs.where((e) => e.mood == '😤').length >= 2) {
      return 'Pola perilaku menunjukkan emosi tinggi berulang. Rekomendasi: jeda transisi aktivitas + snack sehat sebelum jam rawan tantrum.';
    }
    return 'Perkembangan toddler cukup stabil. Pertahankan rutinitas tidur, permainan aktif, dan stimulasi sensorik dengan MPASI yang tepat.';
  }

  Future<void> _addTantrumLog() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    String cause = 'Lapar';
    String mood = '😤';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catat Tantrum'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: cause,
              items: const [
                DropdownMenuItem(value: 'Lapar', child: Text('Lapar')),
                DropdownMenuItem(value: 'Capek', child: Text('Capek')),
                DropdownMenuItem(value: 'Frustrasi', child: Text('Frustrasi')),
                DropdownMenuItem(value: 'Ngantuk', child: Text('Ngantuk')),
              ],
              onChanged: (v) => cause = v ?? cause,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: mood,
              items: const [
                DropdownMenuItem(value: '😄', child: Text('😄 Senang')),
                DropdownMenuItem(value: '🙂', child: Text('🙂 Netral')),
                DropdownMenuItem(value: '😤', child: Text('😤 Kesal')),
              ],
              onChanged: (v) => mood = v ?? mood,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _behaviorLogs.add(
                  _BehaviorLog(
                    hour: time.hour,
                    minute: time.minute,
                    cause: cause,
                    mood: mood,
                  ),
                );
                _tantrum++;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBehaviorSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Behavior & Tantrum Log',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addTantrumLog,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Log Tantrum'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _behaviorInsight,
                style: const TextStyle(color: Color(0xFF7A5A41)),
              ),
            ),
            const SizedBox(height: 10),
            ..._behaviorLogs.map(
              (e) => ListTile(
                dense: true,
                leading: Text(e.mood, style: const TextStyle(fontSize: 20)),
                title: Text('${e.timeLabel} - ${e.cause}'),
                subtitle: const Text('Tantrum event'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLearningSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Early Learning',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ..._learningProgress.entries.map(
                (e) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(e.key), Text('${e.value}%')],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: e.value / 100),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _learningProgress.updateAll(
                      (k, v) => (v + 5).clamp(0, 100),
                    );
                    _bicara++;
                  });
                  setModal(() {});
                },
                icon: const Icon(Icons.videogame_asset_outlined),
                label: const Text('Mini Game Interaktif (+5%)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPottySheet() async {
    DateTime selectedDate = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Kalender Potty Reward',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE1E8F6)),
                ),
                child: CalendarDatePicker(
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  onDateChanged: (date) {
                    selectedDate = date;
                    setModal(() {});
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tanggal dipilih: ${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF5A667A)),
              ),
              const SizedBox(height: 10),
              Text(
                'Progress: ${_pottySuccess.clamp(0, 24)}/24 poin   |   Accident: $_pottyAccident',
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FEFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB7ECF1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text(
                          'Start ➜',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Spacer(),
                        Text(
                          '⭐ Success!',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(
                        24,
                        (i) => _rewardDot(i, _pottySuccess.clamp(0, 24)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _pottySuccess++;
                          _stars += 1;
                        });
                        setModal(() {});
                      },
                      child: const Text('Tambah Reward'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _pottyAccident++);
                        setModal(() {});
                      },
                      child: const Text('Accident'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _pottySuccess >= 24
                    ? 'Well done! Reward chart selesai hari ini.'
                    : 'Kumpulkan 24 poin untuk menyelesaikan reward chart.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPlayIdeasSheet() async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = 'indoor';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Activity & Play Ideas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama aktivitas',
                  hintText: 'Contoh: Bermain puzzle hewan',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan manfaat',
                  hintText: 'Contoh: Melatih fokus dan koordinasi tangan',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: const [
                  DropdownMenuItem(value: 'indoor', child: Text('Indoor')),
                  DropdownMenuItem(value: 'outdoor', child: Text('Outdoor')),
                ],
                onChanged: (v) {
                  category = v ?? 'indoor';
                  setModal(() {});
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty ||
                      noteCtrl.text.trim().isEmpty) {
                    return;
                  }
                  setState(() {
                    _playIdeas.add(
                      _PlayIdea(
                        titleCtrl.text.trim(),
                        noteCtrl.text.trim(),
                        category,
                      ),
                    );
                    _aktivitas++;
                  });
                  titleCtrl.clear();
                  noteCtrl.clear();
                  category = 'indoor';
                  setModal(() {});
                },
                icon: const Icon(Icons.add),
                label: const Text('Tambah Aktivitas'),
              ),
              const SizedBox(height: 10),
              ..._playIdeas.asMap().entries.map(
                (entry) => ListTile(
                  leading: Icon(
                    entry.value.category == 'indoor'
                        ? Icons.home_outlined
                        : Icons.park_outlined,
                  ),
                  title: Text(entry.value.title),
                  subtitle: Text(entry.value.note),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.value.category.toUpperCase(),
                        style: const TextStyle(fontSize: 11),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () {
                          setState(() => _playIdeas.removeAt(entry.key));
                          setModal(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    titleCtrl.dispose();
    noteCtrl.dispose();
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

    // Calculate happy score based on activities
    final totalActivities = _tantrum + _bicara + _aktivitas;
    final happyScore = totalActivities > 0
        ? (((_bicara + _aktivitas) / (totalActivities * 2)) * 100)
              .toStringAsFixed(0)
        : '100';

    return Theme(
      data: themedContext,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FF),
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
            'Dashboard Toddler (1-2 th)',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Week Day Selector
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final date = DateTime.now().add(Duration(days: index - 3));
                    final isToday =
                        date.year == DateTime.now().year &&
                        date.month == DateTime.now().month &&
                        date.day == DateTime.now().day;
                    final dayName = [
                      'Sen',
                      'Sel',
                      'Rab',
                      'Kam',
                      'Jum',
                      'Sab',
                      'Min',
                    ];

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: isToday
                              ? LinearGradient(
                                  colors: [
                                    _theme.primaryColor,
                                    _theme.accentColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isToday ? null : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isToday
                              ? null
                              : Border.all(color: Colors.grey[300]!, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isToday ? 0.15 : 0.05,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayName[date.weekday - 1],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isToday
                                    ? Colors.white
                                    : _theme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Character & Score Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _theme.primaryColor.withOpacity(0.9),
                      _theme.accentColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _theme.primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('🧒', style: TextStyle(fontSize: 60)),
                    const SizedBox(height: 12),
                    const Text(
                      'Happy Score',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: happyScore,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: '%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '✨ Luar Biasa! 💪',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Education Activities Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Training',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[850],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _eduPlanCard(
                    title: 'Reading training',
                    subtitle: 'Baca cerita pendek setiap hari',
                    buttonText: 'Continue',
                    colorA: const Color(0xFFF3B9D0),
                    colorB: const Color(0xFFF7D2E2),
                    icon: Icons.menu_book_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ToddlerReadingModuleScreen(),
                        ),
                      );
                    },
                    height: 128,
                  ),
                  const SizedBox(height: 24),

                  ActivityHighlights(
                    activityName: 'Aktivitas Toddler',
                    percentage: (_tantrum + _bicara + _aktivitas) ~/ 3,
                    duration:
                        '${_bicara}x berbicara + ${_aktivitas}x aktivitas',
                    caloriesBurned: '${(_bicara + _aktivitas) * 10} kkal',
                    date: DateTime.now().toString().split(' ')[0],
                    emoji: '🧒',
                    accentColor: _theme.primaryColor,
                    onViewCalendar: () {
                      _openPottySheet();
                    },
                  ),

                  const SizedBox(height: 20),

                  _combinedMetricsPanel(),

                  const SizedBox(height: 20),
                  _buildToddlerQuickActions(),
                  const SizedBox(height: 24),
                ],
              ),

              // Save Button
              SizedBox(
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: Text(
                    _saving ? 'Menyimpan...' : 'Simpan Progress',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _combinedMetricsPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECE7F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _metricRowItem(
            title: 'Berbicara',
            subtitle: 'Interaksi berbicara',
            value: '${_bicara}x',
            emoji: '💬',
            color: const Color(0xFF4CAF50),
            onTap: _openLearningSheet,
          ),
          const Divider(height: 16, color: Color(0xFFEDE4EC)),
          _metricRowItem(
            title: 'Aktivitas',
            subtitle: 'Sesi bermain aktif',
            value: '${_aktivitas}x',
            emoji: '🏃',
            color: const Color(0xFFF06292),
            onTap: _openPlayIdeasSheet,
          ),
          const Divider(height: 16, color: Color(0xFFEDE4EC)),
          _metricRowItem(
            title: 'Tantrum',
            subtitle: 'Kali menangis/rewel',
            value: '${_tantrum}x',
            emoji: '😤',
            color: const Color(0xFF00BCD4),
            onTap: _openBehaviorSheet,
          ),
          const Divider(height: 16, color: Color(0xFFEDE4EC)),
          _metricRowItem(
            title: 'Mood',
            subtitle: 'Status mood hari ini',
            value: _tantrum < (_bicara + _aktivitas) ? 'Baik' : 'Biasa',
            emoji: '😊',
            color: const Color(0xFF9C27B0),
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(_smartAiInsight)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToddlerQuickActions() {
    return Row(
      children: [
        _buildToddlerQuickActionCard(
          'MPASI',
          Icons.restaurant_menu,
          Colors.orange,
          'Buka rekomendasi MPASI untuk toddler.',
        ),
        const SizedBox(width: 10),
        _buildToddlerQuickActionCard(
          'Sensorik',
          Icons.touch_app,
          Colors.purple,
          'Coba aktivitas sensorik untuk perkembangan motorik.',
        ),
        const SizedBox(width: 10),
        _buildToddlerQuickActionCard(
          'Play',
          Icons.toys,
          Colors.cyan,
          'Lihat ide bermain untuk energi dan keterampilan sosial.',
        ),
      ],
    );
  }

  Widget _buildToddlerQuickActionCard(
    String title,
    IconData icon,
    Color color,
    String message,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
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

  Widget _metricRowItem({
    required String title,
    required String subtitle,
    required String value,
    required String emoji,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 25 / 2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7A8393),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 30 / 2,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 16, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _eduPlanCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required Color colorA,
    required Color colorB,
    required IconData icon,
    required VoidCallback onTap,
    required double height,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorA, colorB],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorA.withOpacity(0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: -10,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.14),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: colorA,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rewardDot(int index, int progress) {
    final completed = index < progress;
    final tone = 60 + ((index % 5) * 35);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: completed
            ? Color.fromARGB(255, 30, 120, tone.clamp(120, 230))
            : const Color(0xFFA7E8EC),
        shape: BoxShape.circle,
        boxShadow: completed
            ? [
                BoxShadow(
                  color: const Color(0xFF3BBFD0).withOpacity(0.38),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: completed
          ? const Icon(Icons.star, color: Colors.white, size: 18)
          : null,
    );
  }
}

class _BehaviorLog {
  final int hour;
  final int minute;
  final String cause;
  final String mood;

  _BehaviorLog({
    required this.hour,
    required this.minute,
    required this.cause,
    required this.mood,
  });

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
    'hour': hour,
    'minute': minute,
    'cause': cause,
    'mood': mood,
  };

  factory _BehaviorLog.fromMap(Map<String, dynamic> map) {
    return _BehaviorLog(
      hour: (map['hour'] as num?)?.toInt() ?? 0,
      minute: (map['minute'] as num?)?.toInt() ?? 0,
      cause: map['cause']?.toString() ?? 'Lapar',
      mood: map['mood']?.toString() ?? '😤',
    );
  }
}

class _PlayIdea {
  final String title;
  final String note;
  final String category;

  _PlayIdea(this.title, this.note, this.category);

  Map<String, dynamic> toMap() => {
    'title': title,
    'note': note,
    'category': category,
  };

  factory _PlayIdea.fromMap(Map<String, dynamic> map) {
    return _PlayIdea(
      map['title']?.toString() ?? 'Aktivitas',
      map['note']?.toString() ?? '-',
      map['category']?.toString() ?? 'indoor',
    );
  }
}
