import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'activity_form_screen.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// Tugas dari Orang Tua untuk Delegasi: jadwal anak yang ditugaskan. Delegasi melaporkan
/// pelaksanaannya lewat formulir catat (dengan foto bila wajib), lalu tugas ditandai sudah dilakukan.
class DelegateTasksTab extends StatefulWidget {
  final BackendChild child;

  const DelegateTasksTab({super.key, required this.child});

  @override
  State<DelegateTasksTab> createState() => _DelegateTasksTabState();
}

class _DelegateTasksTabState extends State<DelegateTasksTab> {
  late Future<(List<Map<String, dynamic>>, FormOptions)> _data = _load();

  static const _repeatLabels = {'none': 'Sekali', 'daily': 'Setiap hari', 'weekly': 'Setiap minggu'};

  Future<(List<Map<String, dynamic>>, FormOptions)> _load() async {
    final results = await Future.wait([PataraApi.schedules(widget.child.id), PataraApi.formOptions()]);
    return (results[0] as List<Map<String, dynamic>>, results[1] as FormOptions);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() { _data = next; });
    try {
      await next;
    } catch (_) {
      // Galatnya ditampilkan AsyncView beserta tombol coba lagi.
    }
  }

  static String _day(DateTime date) => '${date.year}-${two(date.month)}-${two(date.day)}';

  /// Tugas berlaku hari ini: harian selalu, mingguan pada hari yang sama, sekali pada tanggalnya.
  static bool _dueToday(Map<String, dynamic> item, DateTime now) {
    final time = DateTime.tryParse('${item['reminder_time']}')?.toLocal();
    if (time == null) return false;
    return switch ('${item['repeat_rule']}') {
      'daily' => true,
      'weekly' => time.weekday == now.weekday,
      _ => _day(time) == _day(now),
    };
  }

  static DateTime _timeToday(Map<String, dynamic> item, DateTime now) {
    final time = DateTime.tryParse('${item['reminder_time']}')?.toLocal() ?? now;
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  Future<void> _complete(Map<String, dynamic> item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityFormScreen(
          child: widget.child,
          isDelegate: true,
          initial: {
            'category': item['category'],
            'description': [item['title'], item['description']].where((text) => '${text ?? ''}'.trim().isNotEmpty).join('. '),
          },
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await PataraApi.setScheduleDone('${item['id']}', DateTime.now(), true);
      if (!mounted) return;
      showMessage(context, 'Tugas ditandai sudah dilakukan. Laporannya dikirim ke Orang Tua untuk divalidasi.');
    } catch (error) {
      if (mounted) showMessage(context, 'Laporan tersimpan, tetapi tanda tugas gagal: ${errorText(error)}');
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<(List<Map<String, dynamic>>, FormOptions)>(
      future: _data,
      onRetry: _reload,
      builder: (context, data) {
        final (items, options) = data;
        final now = DateTime.now();
        final today = _day(now);
        final due = items.where((item) => _dueToday(item, now)).toList()
          ..sort((a, b) => _timeToday(a, now).compareTo(_timeToday(b, now)));
        final done = due.where((item) => (item['done_dates'] as List).contains(today)).length;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Summary(total: due.length, done: done, childName: widget.child.nama),
              const SizedBox(height: 14),
              if (due.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyView(
                    icon: Icons.task_alt,
                    title: 'Belum ada tugas hari ini',
                    message: 'Tugas muncul di sini saat Orang Tua membuat jadwal untuk anak ini. Anda akan diberi tahu.',
                  ),
                )
              else
                for (final item in due)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TaskCard(
                      item: item,
                      time: _timeToday(item, now),
                      repeatLabel: _repeatLabels['${item['repeat_rule']}'] ?? '',
                      category: options.categories.where((c) => c.key == item['category']).firstOrNull,
                      done: (item['done_dates'] as List).contains(today),
                      doneBy: (item['done_by'] as Map?)?[today] as Map?,
                      late: _timeToday(item, now).isBefore(now),
                      onComplete: () => _complete(item),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  final int total;
  final int done;
  final String childName;

  const _Summary({required this.total, required this.done, required this.childName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF26A69A), Color(0xFF42A5F5)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: total == 0 ? 0 : done / total),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 5,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
                Text('$done/$total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 0 ? 'Tugas hari ini' : (done == total ? 'Semua tugas selesai!' : 'Tugas hari ini'),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Dari Orang Tua untuk $childName',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final DateTime time;
  final String repeatLabel;
  final ActivityCategory? category;
  final bool done;
  final Map? doneBy;
  final bool late;
  final VoidCallback onComplete;

  const _TaskCard({
    required this.item,
    required this.time,
    required this.repeatLabel,
    required this.category,
    required this.done,
    required this.doneBy,
    required this.late,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? pataraTeal : (late ? pataraOrange : pataraPurple);
    final description = '${item['description'] ?? ''}'.trim();
    final who = doneBy == null
        ? 'Sudah dilakukan'
        : 'Sudah dilakukan ${doneBy!['role'] == 'orang_tua' ? 'oleh Orang Tua' : 'oleh ${doneBy!['name'] ?? 'Anda'}'}';
    return PataraCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
                child: Icon(category?.icon ?? Icons.event_note, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Text(
                      'Pukul ${formatTime(time)} • $repeatLabel${category == null ? '' : ' • ${category!.label}'}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  done ? 'Selesai' : (late ? 'Lewat waktu' : 'Belum'),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description, style: const TextStyle(fontSize: 13.5, height: 1.35)),
          ],
          const SizedBox(height: 12),
          if (done)
            Row(
              children: [
                const Icon(Icons.check_circle, color: pataraTeal, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(who, style: const TextStyle(color: pataraTeal, fontWeight: FontWeight.w600))),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.task_alt),
                label: Text(
                  category?.requiresPhoto == true ? 'Sudah saya lakukan (lapor + foto)' : 'Sudah saya lakukan',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
