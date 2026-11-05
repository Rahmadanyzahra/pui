import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// Behavior Tracking: pola dari mood, rewel, tantrum, frekuensi, dan konsistensi pencatatan.
class BehaviorScreen extends StatefulWidget {
  final BackendChild child;

  const BehaviorScreen({super.key, required this.child});

  @override
  State<BehaviorScreen> createState() => _BehaviorScreenState();
}

class _BehaviorScreenState extends State<BehaviorScreen> {
  int _days = 30;
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _data = PataraApi.behavior(widget.child.id, _days);
  }

  void _load(int days) => setState(() {
    _days = days;
    _data = PataraApi.behavior(widget.child.id, days);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar('Pola Perilaku ${widget.child.nama}', pataraPurple, icon: Icons.insights),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 hari')),
                ButtonSegment(value: 30, label: Text('30 hari')),
                ButtonSegment(value: 90, label: Text('90 hari')),
              ],
              selected: {_days},
              onSelectionChanged: (value) => _load(value.first),
            ),
          ),
          Expanded(
            child: AsyncView<Map<String, dynamic>>(
              future: _data,
              onRetry: () => _load(_days),
              builder: (context, data) => BehaviorSummaryView(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tampilan hasil analisis perilaku; dipakai juga di Laporan Bulanan.
class BehaviorSummaryView extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool embedded;

  const BehaviorSummaryView({super.key, required this.data, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final mood = data['mood'] as Map<String, dynamic>;
    final fussy = data['fussy'] as Map<String, dynamic>;
    final tantrum = data['tantrum'] as Map<String, dynamic>;
    final categories = (data['by_category'] as List).cast<Map<String, dynamic>>();
    final patterns = (data['patterns'] as List).cast<Map<String, dynamic>>();
    final byTime = (data['by_time'] as List).cast<Map<String, dynamic>>();
    final maxCount = categories.fold<int>(1, (max, item) => (item['count'] as int) > max ? item['count'] as int : max);

    final children = <Widget>[
      PataraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: StatTile(label: 'Aktivitas', value: '${data['total_activities']}')),
                Expanded(child: StatTile(label: 'Hari tercatat', value: '${data['active_days']}/${data['period_days']}')),
                Expanded(child: StatTile(label: 'Konsistensi', value: '${data['consistency_percent']}%')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Mood sebelum', value: '${mood['before_label']}')),
                Expanded(child: StatTile(label: 'Mood setelah', value: '${mood['after_label']}')),
                Expanded(child: StatTile(label: 'Tantrum', value: '${tantrum['total']}×')),
              ],
            ),
            const SizedBox(height: 12),
            Text('Tingkat rewel rata-rata: ${fussy['label']}', style: const TextStyle(color: pataraInk)),
          ],
        ),
      ),
      const SectionTitle('Pola yang terbaca'),
      if (patterns.isEmpty)
        PataraCard(child: Text('${data['summary']}', style: const TextStyle(height: 1.4)))
      else
        PataraCard(
          child: Column(
            children: [
              for (final pattern in patterns)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_patternIcon('${pattern['type']}'), size: 20, color: pataraPink),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${pattern['text']}', style: const TextStyle(height: 1.35))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      if (categories.isNotEmpty) ...[
        const SectionTitle('Frekuensi aktivitas'),
        PataraCard(
          child: Column(
            children: [
              for (final item in categories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('${item['label']}')),
                          Text(
                            '${item['count']}×${_moodChange(item['mood_change'])}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (item['count'] as int) / maxCount,
                          minHeight: 8,
                          color: pataraPink,
                          backgroundColor: pataraPink.withOpacity(0.14),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SectionTitle('Tantrum menurut waktu'),
        PataraCard(
          child: Row(
            children: [
              for (final bucket in byTime)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${bucket['tantrum_total']}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: pataraPink),
                      ),
                      Text(
                        '${bucket['key']}'.replaceFirstMapped(RegExp('^.'), (match) => match[0]!.toUpperCase()),
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      DisclaimerNote('Metode: ${data['method']}. ${data['disclaimer']}'),
    ];

    if (embedded) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }

  static String _moodChange(Object? value) {
    if (value is! num || value == 0) return '';
    return value > 0 ? '  mood ↑' : '  mood ↓';
  }

  static IconData _patternIcon(String type) => switch (type) {
    'mood_naik' => Icons.sentiment_very_satisfied,
    'mood_turun' => Icons.sentiment_dissatisfied,
    'tantrum' => Icons.warning_amber,
    'rewel' => Icons.mood_bad,
    'konsistensi' => Icons.event_available,
    _ => Icons.bar_chart,
  };
}
