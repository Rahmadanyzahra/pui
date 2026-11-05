import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backend_api_service.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

/// Sistem pendukung keputusan untuk Orang Tua: bobot kriteria ditentukan dengan AHP (perbandingan
/// berpasangan), lalu alternatif diurutkan dengan SAW. Dua penggunaan: ide aktivitas paling cocok dan
/// waktu terbaik melakukan suatu kegiatan. Perhitungannya ada di server (services/spk.js).
class SpkScreen extends StatelessWidget {
  final BackendChild child;

  const SpkScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Rekomendasi ${child.nama}'),
          backgroundColor: pataraTeal,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Ide Aktivitas'), Tab(text: 'Waktu Terbaik')],
          ),
        ),
        body: TabBarView(
          children: [
            _SpkPanel(child: child, mode: _Mode.ideas),
            _SpkPanel(child: child, mode: _Mode.time),
          ],
        ),
      ),
    );
  }
}

enum _Mode { ideas, time }

// Skala Saaty dalam satu penggeser: -8..8. 0 = sama penting (1); n > 0 = kiri lebih penting (n+1);
// n < 0 = kanan lebih penting (1/(|n|+1)).
double _saaty(int step) => step >= 0 ? step + 1.0 : 1 / (1 - step);
int _step(double value) => value >= 1 ? (value.round() - 1) : -((1 / value).round() - 1);
const _scaleText = {
  1: 'sama penting',
  2: 'sedikit lebih penting (2)',
  3: 'sedikit lebih penting (3)',
  4: 'lebih penting (4)',
  5: 'lebih penting (5)',
  6: 'sangat lebih penting (6)',
  7: 'sangat lebih penting (7)',
  8: 'mutlak lebih penting (8)',
  9: 'mutlak lebih penting (9)',
};

class _SpkPanel extends StatefulWidget {
  final BackendChild child;
  final _Mode mode;

  const _SpkPanel({required this.child, required this.mode});

  @override
  State<_SpkPanel> createState() => _SpkPanelState();
}

class _SpkPanelState extends State<_SpkPanel> with AutomaticKeepAliveClientMixin {
  static const _ideaCriteria = ['Kesesuaian usia', 'Frekuensi stimulasi aspek', 'Respons anak', 'Dukungan pedoman'];
  static const _timeCriteria = ['Mood setelah kegiatan', 'Tingkat rewel', 'Jumlah tantrum', 'Persentase selesai'];
  static const _pairs = [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]];

  List<int> _steps = List.filled(6, 0);
  String? _category;
  List<ActivityCategory> _categories = const [];
  Future<Map<String, dynamic>>? _result;

  List<String> get _criteria => widget.mode == _Mode.ideas ? _ideaCriteria : _timeCriteria;
  String get _prefKey => 'spk_pairwise_${widget.mode.name}';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Perbandingan terakhir disimpan di perangkat supaya tidak perlu diisi ulang.
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString(_prefKey);
      if (saved != null && mounted) {
        final values = (jsonDecode(saved) as List).map((value) => (value as num).toDouble()).toList();
        if (values.length == 6) setState(() { _steps = values.map(_step).toList(); });
      }
      if (widget.mode == _Mode.ideas) _calculate();
    });
    if (widget.mode == _Mode.time) {
      PataraApi.formOptions().then((options) {
        if (!mounted) return;
        setState(() {
          _categories = options.categories.where((item) => item.ageGroup == null || item.ageGroup == (widget.child.category == 'baby' ? 'baby' : '')).toList();
          _category = _categories.any((item) => item.key == 'mandi') ? 'mandi' : _categories.firstOrNull?.key;
        });
      }).catchError((_) {});
    }
  }

  Future<void> _calculate() async {
    final pairwise = _steps.map(_saaty).toList();
    (await SharedPreferences.getInstance()).setString(_prefKey, jsonEncode(pairwise));
    setState(() {
      _result = widget.mode == _Mode.ideas
          ? PataraApi.spkActivityIdeas(widget.child.id, pairwise)
          : PataraApi.spkBestTime(widget.child.id, _category ?? 'mandi', pairwise);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PataraCard(
          child: Text(
            widget.mode == _Mode.ideas
                ? 'Aplikasi mengurutkan ide stimulasi sesuai usia ${widget.child.nama} dari pedoman resmi. '
                    'Tentukan dulu kriteria mana yang lebih penting bagi Anda (AHP), lalu ide diurutkan dengan SAW.'
                : 'Aplikasi membandingkan pagi, siang, sore, dan malam dari catatan tervalidasi 60 hari terakhir '
                    'untuk satu kegiatan. Tentukan kriteria yang lebih penting (AHP), lalu waktu diurutkan dengan SAW.',
            style: const TextStyle(height: 1.4),
          ),
        ),
        if (widget.mode == _Mode.time) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Kegiatan', border: OutlineInputBorder()),
            items: [for (final item in _categories) DropdownMenuItem(value: item.key, child: Text(item.label))],
            onChanged: (value) => setState(() { _category = value; }),
          ),
        ],
        const SectionTitle('Kriteria mana yang lebih penting?'),
        for (final (index, pair) in _pairs.indexed) _comparison(index, _criteria[pair[0]], _criteria[pair[1]]),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _calculate,
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Hitung rekomendasi'),
          style: FilledButton.styleFrom(backgroundColor: pataraTeal, minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 16),
        if (_result != null)
          AsyncView<Map<String, dynamic>>(
            future: _result!,
            onRetry: _calculate,
            builder: (context, data) => _buildResult(data),
          ),
      ],
    );
  }

  Widget _comparison(int index, String left, String right) {
    final step = _steps[index];
    final value = _saaty(step);
    final text = step == 0
        ? 'Keduanya sama penting'
        : step > 0
            ? '"$left" ${_scaleText[value.round()]} dari "$right"'
            : '"$right" ${_scaleText[(1 / value).round()]} dari "$left"';
    return PataraCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(left, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
              const Text('vs', style: TextStyle(color: Colors.black45)),
              Expanded(child: Text(right, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
            ],
          ),
          Slider(
            value: -step.toDouble(),
            min: -8,
            max: 8,
            divisions: 16,
            activeColor: pataraTeal,
            label: text,
            onChanged: (position) => setState(() { _steps[index] = -position.round(); }),
          ),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> data) {
    final ahp = data['ahp'] as Map<String, dynamic>;
    final criteria = (data['criteria'] as List).cast<Map<String, dynamic>>();
    final consistent = ahp['consistent'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PataraCard(
          child: Row(
            children: [
              Icon(consistent ? Icons.check_circle : Icons.warning_amber_rounded, color: consistent ? Colors.green : pataraOrange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  consistent
                      ? 'Penilaian konsisten (CR = ${_n(ahp['cr'])} ≤ 0,1).'
                      : 'Penilaian kurang konsisten (CR = ${_n(ahp['cr'])} > 0,1). Periksa lagi perbandingan di atas supaya hasilnya bisa dipercaya.',
                  style: const TextStyle(height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Bobot kriteria (AHP)'),
        PataraCard(
          child: Column(
            children: [
              for (final (index, item) in criteria.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('C${index + 1} ${item['label']} (${item['type'] == 'cost' ? 'cost' : 'benefit'})')),
                      Text('${((ahp['weights'][index] as num) * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (data['enough'] != true)
          PataraCard(child: Text('${data['reason']}', style: const TextStyle(height: 1.4)))
        else ...[
          SectionTitle(widget.mode == _Mode.ideas ? 'Ide paling cocok' : 'Urutan waktu terbaik untuk ${data['category']['label']}'),
          for (final item in ((data['saw'] as Map)['ranked'] as List).cast<Map<String, dynamic>>().take(widget.mode == _Mode.ideas ? 5 : 4))
            _rankCard(item),
          const SizedBox(height: 8),
          _calculation(data, criteria),
        ],
        const SizedBox(height: 8),
        const DisclaimerNote(
          'Rekomendasi ini hasil hitungan dari pedoman dan catatan Anda, bukan penilaian terhadap anak. '
          'Yang diurutkan adalah ide atau waktu kegiatan.',
        ),
      ],
    );
  }

  Widget _rankCard(Map<String, dynamic> item) {
    final first = item['rank'] == 1;
    return PataraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: first ? pataraTeal : pataraTeal.withOpacity(0.15),
            child: Text('${item['rank']}', style: TextStyle(color: first ? Colors.white : pataraTeal, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['label']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  widget.mode == _Mode.ideas
                      ? '${item['aspect_label']} • usia ${item['age_range']} • nilai V = ${_n(item['score'])}'
                      : '${item['logs']} catatan • nilai V = ${_n(item['score'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (widget.mode == _Mode.ideas) ...[
                  const SizedBox(height: 6),
                  Text('${item['how']}', style: const TextStyle(height: 1.35, fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calculation(Map<String, dynamic> data, List<Map<String, dynamic>> criteria) {
    final ahp = data['ahp'] as Map<String, dynamic>;
    final saw = data['saw'] as Map<String, dynamic>;
    final ranked = (saw['ranked'] as List).cast<Map<String, dynamic>>();
    final heads = [for (var i = 0; i < criteria.length; i++) 'C${i + 1}'];
    List<List<String>> rowsOf(List matrix) => [
      for (final (i, row) in matrix.indexed) ['C${i + 1}', ...(row as List).map(_n)],
    ];
    return PataraCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('Lihat perhitungan AHP dan SAW', style: TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _caption('1. Matriks perbandingan berpasangan'),
          _table(['', ...heads], [...rowsOf(ahp['matrix'] as List), ['Jumlah', ...(ahp['column_sums'] as List).map(_n)]]),
          _caption('2. Matriks ternormalisasi dan bobot (rata-rata baris)'),
          _table(['', ...heads, 'Bobot'], [
            for (final (i, row) in (ahp['normalized'] as List).indexed) ['C${i + 1}', ...(row as List).map(_n), _n(ahp['weights'][i])],
          ]),
          _caption('3. Uji konsistensi'),
          Text(
            'λmaks = ${_n(ahp['lambda_max'])}   CI = (λmaks − n)/(n − 1) = ${_n(ahp['ci'])}\n'
            'RI (n = ${criteria.length}) = ${_n(ahp['ri'])}   CR = CI/RI = ${_n(ahp['cr'])} → ${ahp['consistent'] == true ? 'konsisten' : 'tidak konsisten'}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5),
          ),
          _caption('4. Matriks keputusan (X)'),
          _table(['Alternatif', ...heads], [for (final item in ranked) [_short(item), ...(item['values'] as List).map(_n)]]),
          Text(
            [for (final (i, c) in criteria.indexed) 'C${i + 1}: ${c['label']} (${c['type']}) — ${c['note']}'].join('\n'),
            style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.4),
          ),
          _caption('5. Normalisasi (benefit = x/maks, cost = min/x) dan nilai preferensi V'),
          _table(['Alternatif', ...heads, 'V', 'Rank'], [
            for (final item in ranked) [_short(item), ...(item['normalized'] as List).map(_n), _n(item['score']), '${item['rank']}'],
          ]),
        ],
      ),
    );
  }

  String _short(Map<String, dynamic> item) =>
      widget.mode == _Mode.ideas ? '${item['key']} ${item['label']}' : '${item['label']}'.split(' ').first;

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
  );

  Widget _table(List<String> head, List<List<String>> rows) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowHeight: 34,
      dataRowMinHeight: 30,
      dataRowMaxHeight: 44,
      columnSpacing: 14,
      horizontalMargin: 8,
      border: TableBorder.all(color: Colors.black12),
      columns: [for (final text in head) DataColumn(label: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)))],
      rows: [
        for (final row in rows)
          DataRow(cells: [for (final text in row) DataCell(Text(text, style: const TextStyle(fontSize: 12)))]),
      ],
    ),
  );

  static String _n(Object? value) {
    if (value is! num) return '$value';
    final text = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(4);
    return text.contains('.') ? text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '').replaceAll('.', ',') : text;
  }
}
