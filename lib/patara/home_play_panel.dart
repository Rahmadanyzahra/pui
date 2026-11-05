import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'patara_api.dart';
import '../widgets/game_art.dart';
import 'patara_ui.dart';

/// "Main di rumah" di Zona Bermain: ide motorik, sensorik, dan eksperimen kecil sesuai usia anak.
/// Isinya diambil dari panduan stimulasi di server, jadi sumbernya sama dengan halaman Panduan.
class HomePlayPanel extends StatefulWidget {
  final String childId;

  const HomePlayPanel({super.key, required this.childId});

  @override
  State<HomePlayPanel> createState() => _HomePlayPanelState();
}

class _HomePlayPanelState extends State<HomePlayPanel> {
  static const _groups = [
    ('motorik', 'Motorik', '🤸', Color(0xFFFFB74D)),
    ('sensori', 'Sensorik', '🖐️', Color(0xFF4FC3F7)),
    ('eksperimen', 'Eksperimen kecil', '🧪', Color(0xFFBA68C8)),
  ];
  static const _shortSources = {
    'kia': 'Buku KIA 2024',
    'sdidtk': 'SDIDTK Kemenkes 2016',
    'ccd': 'WHO & UNICEF 2012',
    'who_move': 'WHO 2019',
    'pgs': 'Permenkes 41/2014',
  };

  late Future<Map<String, dynamic>> _data = PataraApi.guidance(widget.childId);
  String _group = 'motorik';
  Set<String> _done = {};

  // Centang "sudah dicoba" hanya berlaku untuk hari ini dan hanya tersimpan di perangkat.
  String get _doneKey {
    final now = DateTime.now();
    return 'home_play_done_${widget.childId}_${now.year}-${now.month}-${now.day}';
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() { _done = {...?prefs.getStringList(_doneKey)}; });
    });
  }

  Future<void> _toggle(String id) async {
    setState(() => _done.contains(id) ? _done.remove(id) : _done.add(id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_doneKey, _done.toList());
  }

  List<Map<String, dynamic>> _itemsFor(Map<String, dynamic> data, String group) {
    final activities = (data['activities'] as List).cast<Map<String, dynamic>>();
    if (group == 'eksperimen') return activities.where((item) => item['experiment'] == true).toList();
    return [
      ...activities.where((item) => item['type'] == group),
      if (group == 'motorik')
        // Dari anjuran gerak WHO hanya butir aktivitas fisik yang masuk; tidur dan layar ada di halaman Panduan.
        for (final item in ((data['movement'] as List?) ?? const []).cast<Map<String, dynamic>>())
          if (RegExp('aktivitas fisik|berintensitas|bergerak', caseSensitive: false).hasMatch('${item['text']}'))
            {'title': 'Aktif bergerak setiap hari', 'how': item['text'], 'sources': item['sources']},
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data;
        if (snapshot.hasError || data == null) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('Ide bermain belum dapat dimuat.', textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => setState(() { _data = PataraApi.guidance(widget.childId); }),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          );
        }
        final group = _groups.firstWhere((item) => item.$1 == _group);
        final items = _itemsFor(data, _group);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (key, label, emoji, color) in _groups)
                  ChoiceChip(
                    avatar: GameArt(emoji, size: 20),
                    label: Text(label),
                    selected: _group == key,
                    showCheckmark: false,
                    selectedColor: color.withOpacity(0.35),
                    backgroundColor: Colors.white,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: pataraInk),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (_) => setState(() { _group = key; }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Belum ada ide pada kelompok ini untuk usia anak.'),
              ),
            for (final item in items) _buildItem(item, group.$3, group.$4),
            const SizedBox(height: 6),
            Text(
              '${data['safety']}',
              style: const TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600, color: Color(0xFF33691E)),
            ),
            const SizedBox(height: 6),
            Text(
              'Sumber: ${[for (final source in (data['sources'] as List).cast<Map<String, dynamic>>()) if (_shortSources.containsKey(source['key'])) source['label']].join(' ')}',
              style: const TextStyle(fontSize: 11.5, height: 1.4, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kelompok "Eksperimen kecil" dibuat aplikasi dari kegiatan stimulasi pada pedoman di atas. '
              'Tanda centang hanya pengingat untuk hari ini di perangkat ini dan tidak masuk ke catatan atau analisis. '
              'Ini saran umum, bukan penilaian perkembangan.',
              style: TextStyle(fontSize: 11.5, height: 1.4, color: Colors.black54),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItem(Map<String, dynamic> item, String emoji, Color color) {
    final id = '$_group:${item['how']}';
    final done = _done.contains(id);
    final sources = [
      for (final key in (item['sources'] as List? ?? const [])) _shortSources[key] ?? '$key',
    ].join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x1A2E7D32), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.25), shape: BoxShape.circle),
            child: GameArt(emoji, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text('${item['how']}', style: const TextStyle(fontSize: 13, height: 1.4, color: pataraInk)),
                const SizedBox(height: 4),
                Text(sources, style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: done ? 'Sudah dicoba hari ini' : 'Tandai sudah dicoba',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _toggle(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: done ? const Color(0xFF66BB6A) : const Color(0xFFF1F5EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.check_rounded, color: done ? Colors.white : Colors.black26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
