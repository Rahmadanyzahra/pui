import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dashboard_back_navigation.dart';
import '../services/backend_api_service.dart';
import '../services/dashboard_theme_service.dart';
// import '../services/realtime_service.dart';
import '../services/child_food_service.dart';
import 'child_food_list_screen.dart';

class BabyDashboard extends StatefulWidget {
  final int? umur;
  final int? childId;
  final bool openedFromParentDashboard;

  const BabyDashboard({
    super.key,
    required this.umur,
    this.childId,
    this.openedFromParentDashboard = false,
  });

  @override
  State<BabyDashboard> createState() => _BabyDashboardState();
}

class _BabyDashboardState extends State<BabyDashboard> {
  int _tidur = 0;
  int _menyusu = 0;
  int _popok = 0;
  final TextEditingController _aiController = TextEditingController();
  final List<_FeedingLog> _feedingLogs = [];
  final List<_SleepLog> _sleepLogs = [];
  final List<_DiaperLog> _diaperLogs = [];
  int _ageProfileIndex = 1;
  final Map<String, String> _reminderConfig = {
    'Susu/Makan': 'Setiap 3 jam',
    'Vitamin/Obat': '08:00',
    'Tidur': '20:00',
    'Mandi': '07:00',
  };
  final Map<String, bool> _immunizationDone = {
    'Hepatitis B': false,
    'BCG': false,
    'Polio': false,
    'DPT-HB-Hib': false,
  };
  final Map<String, bool> _milestones = {
    'Mengangkat kepala': false,
    'Duduk dengan bantuan': false,
    'Merangkak': false,
    'Berdiri dengan pegangan': false,
  };
  bool _saving = false;
  String? _aiResponse;
  final DashboardThemeProfile _theme = DashboardThemeProfile.defaultTheme(
    'baby',
  );

  final String _todayKey = DateTime.now().toIso8601String().substring(0, 10);

  // Edukasi cards: stimulasi untuk bayi
  final List<Map<String, dynamic>> _eduCards = [
    {
      'label': 'Sensori',
      'icon': Icons.touch_app,
      'color': Color(0xFFFF69B4),
      'note': 'Sentuh berbagai tekstur lembut',
    },
    {
      'label': 'Warna',
      'icon': Icons.palette,
      'color': Color(0xFFE91E63),
      'note': 'Tunjukkan warna cerah yang menarik',
    },
    {
      'label': 'Suara',
      'icon': Icons.music_note,
      'color': Color(0xFFF06292),
      'note': 'Mainkan musik lembut atau bernyanyi',
    },
  ];

  Future<void> _save() async {
    final user = await BackendApiService.getCurrentUser();
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'dateKey': _todayKey,
        'tidur': _tidur,
        'menyusu': _menyusu,
        'popok': _popok,
        'milestones': _milestones,
        'ageProfileIndex': _ageProfileIndex,
        'feedingLogs': _feedingLogs.map((e) => e.toMap()).toList(),
        'sleepLogs': _sleepLogs.map((e) => e.toMap()).toList(),
        'diaperLogs': _diaperLogs.map((e) => e.toMap()).toList(),
        'reminderConfig': _reminderConfig,
        'immunizationDone': _immunizationDone,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await BackendApiService.logActivity(
        childId: widget.childId ?? user.id,
        activityType: 'baby_dashboard_state',
        value: jsonEncode(payload),
      );
      if (widget.childId != null) {
        try {
          await BackendApiService.logActivity(
            childId: widget.childId!,
            activityType: 'baby_daily_summary',
            value: 'tidur=$_tidur,menyusu=$_menyusu,popok=$_popok',
          );
        } catch (e) {
          // ignore error
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data tersimpan!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan data: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    // If this dashboard is showing for a specific child id, get today's food count
    if (widget.childId != null) {
      _refreshFoodCount();
    }
  }

  @override
  void dispose() {
    _aiController.dispose();
    super.dispose();
  }

  void _askAI(String question) {
    final adaptive = _buildAdaptiveInsight();
    final Map<String, String> responses = {
      'Bayi rewel kenapa?':
          'Bayi rewel bisa karena lapar, ngantuk, popok basah, kolik, atau butuh pelukan. Coba cek satu per satu kebutuhannya.',
      'Jadwal tidur ideal bayi':
          'Bayi 0-3 bulan: 14-17 jam/hari. Bayi 4-11 bulan: 12-15 jam/hari, termasuk 2-3 sesi tidur siang. Buat rutinitas: mandi → makan → tidur.',
      'smart insight': adaptive,
    };
    final q = question.toLowerCase();
    if (q.contains('growth') ||
        q.contains('insight') ||
        q.contains('prediksi')) {
      setState(() => _aiResponse = adaptive);
      return;
    }
    setState(() => _aiResponse = responses[question] ?? adaptive);
  }

  String get _ageCategoryLabel {
    switch (_ageProfileIndex) {
      case 0:
        return 'Newborn';
      case 1:
        return '3 Bulan';
      default:
        return '6 Bulan';
    }
  }

  double get _sleepTotalHours {
    return _sleepLogs.fold<double>(0, (sum, log) => sum + log.totalHours);
  }

  String _buildAdaptiveInsight() {
    final targetSleep = _ageProfileIndex == 0
        ? 15.0
        : _ageProfileIndex == 1
        ? 14.0
        : 13.0;
    final deficit = targetSleep - _sleepTotalHours;
    final nightWake = _sleepLogs
        .where((e) => e.startHour >= 22 || e.startHour <= 5)
        .length;
    final avgFeedGap = _feedingLogs.length < 2
        ? 0.0
        : (_feedingLogs.last.minuteOfDay - _feedingLogs.first.minuteOfDay) /
              (_feedingLogs.length - 1) /
              60;

    if (deficit > 1.5) {
      return 'Insight: bayi kurang tidur hari ini (kurang ${deficit.toStringAsFixed(1)} jam). Rekomendasi: percepat rutinitas tidur malam 30-45 menit dan kurangi stimulasi layar/suara sebelum tidur.';
    }
    if (nightWake >= 2) {
      return 'Insight: bayi sering bangun malam (${nightWake}x) - kemungkinan growth spurt. Rekomendasi: tambah sesi menyusu singkat sebelum jam tidur utama dan pastikan popok kering.';
    }
    if (avgFeedGap > 3.5 && avgFeedGap > 0) {
      return 'Insight: jeda menyusu cenderung panjang (${avgFeedGap.toStringAsFixed(1)} jam). Prediksi pola lapar: berikutnya sekitar 2.5-3 jam setelah sesi terakhir.';
    }
    return 'Insight: pola bayi cukup stabil hari ini. Prediksi jam tidur optimal: 19:30-20:30 dengan total tidur target ${targetSleep.toStringAsFixed(0)} jam.';
  }

  List<_TimelineItem> _buildTimeline() {
    final items = <_TimelineItem>[];
    for (final f in _feedingLogs) {
      items.add(
        _TimelineItem(
          minuteOfDay: f.minuteOfDay,
          title: 'Minum ${f.type}',
          subtitle: '${f.timeLabel} • ${f.durationMin} menit',
          color: const Color(0xFF5DAEF3),
          icon: Icons.water_drop_outlined,
        ),
      );
    }
    for (final s in _sleepLogs) {
      items.add(
        _TimelineItem(
          minuteOfDay: s.startHour * 60 + s.startMinute,
          title: 'Tidur',
          subtitle:
              '${s.startLabel} - ${s.wakeLabel} • ${s.totalHours.toStringAsFixed(1)} jam',
          color: const Color(0xFF8B6FD8),
          icon: Icons.bedtime,
        ),
      );
    }
    for (final d in _diaperLogs) {
      items.add(
        _TimelineItem(
          minuteOfDay: d.minuteOfDay,
          title: 'Popok ${d.type.toUpperCase()}',
          subtitle: d.timeLabel,
          color: const Color(0xFFE58F5D),
          icon: Icons.baby_changing_station,
        ),
      );
    }
    items.sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
    return items;
  }

  Future<void> _addFeedingLog() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;

    String type = 'ASI';
    final durationController = TextEditingController(text: '15');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catat minum ASI/susu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: 'ASI', child: Text('ASI')),
                DropdownMenuItem(value: 'Susu', child: Text('Susu Formula')),
              ],
              onChanged: (v) => type = v ?? 'ASI',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Durasi (menit)'),
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
              final duration = int.tryParse(durationController.text) ?? 15;
              setState(() {
                _feedingLogs.add(
                  _FeedingLog(
                    minuteOfDay: time.hour * 60 + time.minute,
                    durationMin: duration,
                    type: type,
                  ),
                );
                _menyusu++;
                if (widget.childId != null) {
                  ChildFoodService.createFood({
                    'childId': widget.childId.toString(),
                    'name': type,
                    'at': DateTime.now().toIso8601String(),
                  }).catchError((e) {
                    // ignore
                    return false;
                  });
                  _refreshFoodCount();
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    durationController.dispose();
  }

  int _foodCountToday = 0;

  Future<void> _refreshFoodCount() async {
    if (widget.childId == null) return;
    try {
      final foods = await ChildFoodService.fetchFoods();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final cnt = foods
          .where(
            (f) =>
                f['childId'].toString() == widget.childId.toString() &&
                (f['at'] ?? '').toString().startsWith(today),
          )
          .length;
      if (mounted) setState(() => _foodCountToday = cnt);
    } catch (_) {}
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
              .where((entry) => entry.activityType == 'baby_dashboard_state')
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (candidates.isNotEmpty && mounted) {
        final decoded = jsonDecode(candidates.first.value);
        if (decoded is! Map<String, dynamic>) return;
        final d = decoded;
        setState(() {
          _tidur = (d['tidur'] as num?)?.toInt() ?? 0;
          _menyusu = (d['menyusu'] as num?)?.toInt() ?? 0;
          _popok = (d['popok'] as num?)?.toInt() ?? 0;
          _ageProfileIndex = (d['ageProfileIndex'] as num?)?.toInt() ?? 1;
          final ms = d['milestones'] as Map<String, dynamic>?;
          if (ms != null) {
            ms.forEach((k, v) {
              if (_milestones.containsKey(k)) _milestones[k] = v as bool;
            });
          }
          if (d['feedingLogs'] is List) {
            _feedingLogs
              ..clear()
              ..addAll(
                (d['feedingLogs'] as List).whereType<Map>().map(
                  (e) => _FeedingLog.fromMap(Map<String, dynamic>.from(e)),
                ),
              );
          }
          if (d['sleepLogs'] is List) {
            _sleepLogs
              ..clear()
              ..addAll(
                (d['sleepLogs'] as List).whereType<Map>().map(
                  (e) => _SleepLog.fromMap(Map<String, dynamic>.from(e)),
                ),
              );
          }
          if (d['diaperLogs'] is List) {
            _diaperLogs
              ..clear()
              ..addAll(
                (d['diaperLogs'] as List).whereType<Map>().map(
                  (e) => _DiaperLog.fromMap(Map<String, dynamic>.from(e)),
                ),
              );
          }
          final reminder = d['reminderConfig'] as Map<String, dynamic>?;
          if (reminder != null) {
            reminder.forEach((k, v) {
              if (_reminderConfig.containsKey(k)) {
                _reminderConfig[k] = '$v';
              }
            });
          }
          final imm = d['immunizationDone'] as Map<String, dynamic>?;
          if (imm != null) {
            imm.forEach((k, v) {
              if (_immunizationDone.containsKey(k)) {
                _immunizationDone[k] = v == true;
              }
            });
          }
        });
      }
    } catch (_) {
      // Ignore Firestore read failures to keep dashboard usable.
    }
  }

  Future<void> _addSleepLog() async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (start == null || !mounted) return;
    final wake = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 2) % 24, minute: start.minute),
    );
    if (wake == null || !mounted) return;

    setState(() {
      _sleepLogs.add(
        _SleepLog(
          startHour: start.hour,
          startMinute: start.minute,
          wakeHour: wake.hour,
          wakeMinute: wake.minute,
        ),
      );
      _tidur++;
    });
  }

  Future<void> _addDiaperLog() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    String type = 'pipis';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catat popok'),
        content: DropdownButtonFormField<String>(
          value: type,
          items: const [
            DropdownMenuItem(value: 'pipis', child: Text('Pipis')),
            DropdownMenuItem(value: 'pup', child: Text('Pup')),
          ],
          onChanged: (v) => type = v ?? 'pipis',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _diaperLogs.add(
                  _DiaperLog(
                    minuteOfDay: time.hour * 60 + time.minute,
                    type: type,
                  ),
                );
                _popok++;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _editReminder(String key, String currentValue) async {
    final ctrl = TextEditingController(text: currentValue);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Atur reminder $key'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Contoh: 08:00 / Setiap 3 jam',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(
                () => _reminderConfig[key] = ctrl.text.trim().isEmpty
                    ? currentValue
                    : ctrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Widget _counterCard(
    String label,
    IconData icon,
    Color color,
    int value,
    VoidCallback onAdd,
    VoidCallback onMinus,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$value kali',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 82,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: IconButton(
                        onPressed: value > 0 ? onMinus : null,
                        icon: Icon(Icons.remove, color: color),
                        iconSize: 18,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: onAdd,
                        icon: Icon(Icons.add, color: color),
                        iconSize: 18,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eduCard(Map<String, dynamic> card) {
    final color = card['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: ElevatedButton(
        onPressed: () {
          _askAI(card['label'] as String);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(card['icon'] as IconData, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              card['label'] as String,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _foodSummaryCard() {
    return _counterCard(
      'Makanan hari ini',
      Icons.restaurant_menu,
      Colors.deepOrange,
      _foodCountToday,
      () async {
        // quick add: open prompt for food name
        final ctrl = TextEditingController(text: 'MPASI');
        final res = await showDialog<String?>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Catat Makanan Anak'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Nama makanan'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Simpan'),
              ),
            ],
          ),
        );
        if (res == null || res.isEmpty) return;
        try {
          await ChildFoodService.createFood({
            'childId': widget.childId,
            'name': res,
            'at': DateTime.now().toIso8601String(),
          });
          await _refreshFoodCount();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Catatan makanan tersimpan')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Gagal simpan makanan: $e')));
          }
        }
      },
      () async {
        // remove last – this is a convenience local decrement; real removal requires selecting entry
        if (_foodCountToday > 0) {
          setState(() => _foodCountToday--);
        }
      },
    );
  }

  Widget _quickCard({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.28), width: 1.2),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
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

  void _openAktivitasSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.76,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Aktivitas Detail',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.water_drop_outlined, size: 16),
                      label: const Text('Catat ASI/Susu'),
                      onPressed: () async {
                        await _addFeedingLog();
                        if (mounted) setModalState(() {});
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.restaurant_menu, size: 16),
                      label: const Text('Daftar Makanan'),
                      onPressed: () async {
                        if (widget.childId == null) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChildFoodListScreen(
                              childId: widget.childId.toString(),
                            ),
                          ),
                        );
                        if (mounted) setModalState(() {});
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.bedtime, size: 16),
                      label: const Text('Catat Tidur'),
                      onPressed: () async {
                        await _addSleepLog();
                        if (mounted) setModalState(() {});
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.baby_changing_station, size: 16),
                      label: const Text('Catat Popok'),
                      onPressed: () async {
                        await _addDiaperLog();
                        if (mounted) setModalState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _counterCard(
                  'Tidur',
                  Icons.bedtime,
                  Colors.indigo,
                  _tidur,
                  () {
                    setState(() => _tidur++);
                    setModalState(() {});
                  },
                  () {
                    setState(() => _tidur--);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 10),
                _counterCard(
                  'Menyusu',
                  Icons.water_drop,
                  Colors.blueAccent,
                  _menyusu,
                  () {
                    setState(() => _menyusu++);
                    setModalState(() {});
                  },
                  () {
                    setState(() => _menyusu--);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 10),
                // Food summary card (counts food entries for specific child)
                if (widget.childId != null) _foodSummaryCard(),
                const SizedBox(height: 10),
                _counterCard(
                  'Popok',
                  Icons.baby_changing_station,
                  Colors.amber,
                  _popok,
                  () {
                    setState(() => _popok++);
                    setModalState(() {});
                  },
                  () {
                    setState(() => _popok--);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Grafik Ringkas Hari Ini',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2EEF9)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _barMetric(
                        'Susu',
                        _feedingLogs.length.toDouble(),
                        const Color(0xFF5DAEF3),
                        8,
                      ),
                      _barMetric(
                        'Tidur',
                        _sleepTotalHours,
                        const Color(0xFF8B6FD8),
                        14,
                      ),
                      _barMetric(
                        'Popok',
                        _diaperLogs.length.toDouble(),
                        const Color(0xFFE58F5D),
                        8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE1BE)),
                  ),
                  child: Text(
                    _buildAdaptiveInsight(),
                    style: const TextStyle(
                      color: Color(0xFF8A6647),
                      height: 1.35,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Timeline Aktivitas Harian',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ..._buildTimeline().map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: item.color.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: item.color.withOpacity(0.18),
                          child: Icon(item.icon, size: 15, color: item.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                item.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_buildTimeline().isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Belum ada timeline. Tambahkan catatan ASI, tidur, atau popok.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
                    ),
                  ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            await _save();
                            if (mounted) setModalState(() {});
                          },
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt_rounded),
                    label: Text(_saving ? 'Menyimpan...' : 'Simpan Aktivitas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF39A74),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMilestoneSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Milestone Perkembangan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2EEF9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kategori Umur',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: List.generate(3, (index) {
                          final labels = ['Newborn', '3 Bulan', '6 Bulan'];
                          return ChoiceChip(
                            label: Text(labels[index]),
                            selected: _ageProfileIndex == index,
                            onSelected: (_) {
                              setState(() => _ageProfileIndex = index);
                              setModalState(() {});
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ..._milestones.keys.map((milestone) {
                  final isAchieved = _milestones[milestone]!;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isAchieved ? Colors.green[50] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAchieved
                            ? Colors.green[200]!
                            : Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: isAchieved,
                      activeColor: Colors.green,
                      title: Text(
                        milestone,
                        style: TextStyle(
                          decoration: isAchieved
                              ? TextDecoration.lineThrough
                              : null,
                          color: isAchieved
                              ? Colors.green[700]
                              : Colors.black87,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _milestones[milestone] = value ?? false;
                        });
                        setModalState(() {});
                      },
                    ),
                  );
                }),
                const SizedBox(height: 10),
                const Text(
                  'Jadwal Imunisasi',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ..._immunizationDone.entries.map(
                  (e) => SwitchListTile(
                    value: e.value,
                    title: Text(e.key),
                    subtitle: Text(
                      e.value ? 'Sudah dilakukan' : 'Belum dilakukan',
                    ),
                    onChanged: (v) {
                      setState(() => _immunizationDone[e.key] = v);
                      setModalState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Reminder & Alarm Rutinitas',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ..._reminderConfig.entries.map(
                  (e) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alarm_outlined),
                    title: Text(e.key),
                    subtitle: Text(e.value),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () async {
                      await _editReminder(e.key, e.value);
                      if (mounted) setModalState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFoodListScreen() {
    if (widget.childId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildFoodListScreen(childId: widget.childId.toString()),
      ),
    );
  }

  Widget _barMetric(String label, double value, Color color, double divisor) {
    final barHeight = (value / divisor).clamp(0.05, 1.0) * 72;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: barHeight,
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
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

    final completedMilestones = _milestones.values.where((v) => v).length;
    final totalActivity = _tidur + _menyusu + _popok;
    final expNow = (_tidur * 120) + (_menyusu * 80) + (_popok * 60);
    const expTarget = 3600;
    final expProgress = (expNow / expTarget).clamp(0.0, 1.0);
    final happyScore = totalActivity > 0
        ? (((_tidur + _menyusu + _popok + completedMilestones) /
                      (totalActivity + 3)) *
                  100)
              .clamp(0.0, 100.0)
              .toStringAsFixed(0)
        : '100';

    return Theme(
      data: themedContext,
      child: Scaffold(
        backgroundColor: const Color(0xFFEAF5FF),
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
            'Baby Dashboard',
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
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final date = DateTime.now().add(
                        Duration(days: index - 3),
                      );
                      final now = DateTime.now();
                      final isToday =
                          date.year == now.year &&
                          date.month == now.month &&
                          date.day == now.day;
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
                                : Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
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
                      const Text('👶', style: TextStyle(fontSize: 60)),
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
                        child: Text(
                          '✨ Aktivitas: $totalActivity • Milestone: $completedMilestones',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _quickCard(
                      label: 'MPASI',
                      icon: Icons.restaurant_menu,
                      color: const Color(0xFFFFA726),
                      onTap: _openFoodListScreen,
                    ),
                    const SizedBox(width: 8),
                    _quickCard(
                      label: 'Sensorik',
                      icon: Icons.touch_app,
                      color: const Color(0xFFE91E63),
                      onTap: _openMilestoneSheet,
                    ),
                    const SizedBox(width: 8),
                    _quickCard(
                      label: 'Play',
                      icon: Icons.toys,
                      color: const Color(0xFF42A5F5),
                      onTap: _openAktivitasSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFDFEFF), Color(0xFFFFEEF3)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF3C7D6),
                      width: 1.4,
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BABY PREMIUM',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Color(0xFF5682A3),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Because your baby deserves the best care.',
                        style: TextStyle(
                          color: Color(0xFF6E8DA7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Talk to BabyAI',
                            style: TextStyle(
                              fontSize: 30 / 1.6,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4B7DA7),
                            ),
                          ),
                          Text(
                            '+200',
                            style: TextStyle(
                              color: Color(0xFF73A5CC),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Butuh bantuan cepat? AI memberi jawaban dalam hitungan detik.',
                        style: TextStyle(color: Color(0xFF7891A6)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _aiController,
                              decoration: InputDecoration(
                                hintText: 'Tulis pertanyaan tentang bayi...',
                                filled: true,
                                fillColor: const Color(0xFFF2F8FD),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              final q = _aiController.text.trim();
                              _askAI(q.isEmpty ? 'Bayi rewel kenapa?' : q);
                              _aiController.clear();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF5DAEF3),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_aiResponse != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F8FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCCE4F8)),
                          ),
                          child: Text(
                            _aiResponse!,
                            style: const TextStyle(
                              color: Color(0xFF486C8A),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aktivitas Harian',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4A657A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '⏱ ${_tidur}x tidur',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFFE8885F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$expNow/$expTarget',
                            style: const TextStyle(
                              fontSize: 28 / 1.4,
                              color: Color(0xFF4B95D8),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: expProgress,
                          backgroundColor: const Color(0xFFE5EEF7),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF67AEE8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_alt_rounded),
                          label: Text(
                            _saving ? 'Menyimpan...' : 'Simpan Aktivitas',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF39A74),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
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
}

class _FeedingLog {
  final int minuteOfDay;
  final int durationMin;
  final String type;

  _FeedingLog({
    required this.minuteOfDay,
    required this.durationMin,
    required this.type,
  });

  String get timeLabel {
    final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final m = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toMap() => {
    'minuteOfDay': minuteOfDay,
    'durationMin': durationMin,
    'type': type,
  };

  factory _FeedingLog.fromMap(Map<String, dynamic> map) {
    return _FeedingLog(
      minuteOfDay: (map['minuteOfDay'] as num?)?.toInt() ?? 0,
      durationMin: (map['durationMin'] as num?)?.toInt() ?? 0,
      type: map['type']?.toString() ?? 'ASI',
    );
  }
}

class _SleepLog {
  final int startHour;
  final int startMinute;
  final int wakeHour;
  final int wakeMinute;

  _SleepLog({
    required this.startHour,
    required this.startMinute,
    required this.wakeHour,
    required this.wakeMinute,
  });

  String get startLabel =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  String get wakeLabel =>
      '${wakeHour.toString().padLeft(2, '0')}:${wakeMinute.toString().padLeft(2, '0')}';

  double get totalHours {
    final start = startHour * 60 + startMinute;
    var end = wakeHour * 60 + wakeMinute;
    if (end < start) end += 24 * 60;
    return (end - start) / 60;
  }

  Map<String, dynamic> toMap() => {
    'startHour': startHour,
    'startMinute': startMinute,
    'wakeHour': wakeHour,
    'wakeMinute': wakeMinute,
  };

  factory _SleepLog.fromMap(Map<String, dynamic> map) {
    return _SleepLog(
      startHour: (map['startHour'] as num?)?.toInt() ?? 0,
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      wakeHour: (map['wakeHour'] as num?)?.toInt() ?? 0,
      wakeMinute: (map['wakeMinute'] as num?)?.toInt() ?? 0,
    );
  }
}

class _DiaperLog {
  final int minuteOfDay;
  final String type;

  _DiaperLog({required this.minuteOfDay, required this.type});

  String get timeLabel {
    final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final m = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toMap() => {'minuteOfDay': minuteOfDay, 'type': type};

  factory _DiaperLog.fromMap(Map<String, dynamic> map) {
    return _DiaperLog(
      minuteOfDay: (map['minuteOfDay'] as num?)?.toInt() ?? 0,
      type: map['type']?.toString() ?? 'pipis',
    );
  }
}

class _TimelineItem {
  final int minuteOfDay;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  _TimelineItem({
    required this.minuteOfDay,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });
}
