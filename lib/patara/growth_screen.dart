import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'patara_api.dart';
import 'patara_ui.dart';

String formatNumber(num value) =>
    value.toStringAsFixed(1).replaceAll('.', ',').replaceAll(RegExp(r',0$'), '');

/// Catat dan lihat pertumbuhan: berat badan, tinggi badan, dan lingkar kepala.
class GrowthScreen extends StatefulWidget {
  final BackendChild child;

  const GrowthScreen({super.key, required this.child});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  late Future<Map<String, dynamic>> _data;
  String _metric = 'weight_kg';

  static const _metrics = {
    'weight_kg': ('Berat', 'kg', pataraPink),
    'height_cm': ('Tinggi', 'cm', pataraTeal),
    'head_circumference_cm': ('Lingkar kepala', 'cm', pataraPurple),
  };

  @override
  void initState() {
    super.initState();
    _data = PataraApi.growth(widget.child.id);
  }

  void _reload() => setState(() { _data = PataraApi.growth(widget.child.id); });

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GrowthForm(child: widget.child),
    );
    if (saved == true && mounted) {
      showMessage(context, 'Data pertumbuhan tersimpan.');
      _reload();
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus catatan ini?',
      message: 'Catatan pengukuran yang dihapus tidak dapat dikembalikan.',
    );
    if (!confirmed) return;
    try {
      await PataraApi.deleteGrowth(widget.child.id, record['id'] as Object);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar('Pertumbuhan ${widget.child.nama}', pataraTeal, icon: Icons.monitor_weight_outlined),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      body: AsyncView<Map<String, dynamic>>(
        future: _data,
        onRetry: _reload,
        builder: (context, data) {
          final records = (data['records'] as List).cast<Map<String, dynamic>>();
          if (records.isEmpty) {
            return EmptyView(
              icon: Icons.monitor_weight_outlined,
              title: 'Belum ada data pertumbuhan',
              message:
                  'Catat berat badan, tinggi badan, dan lingkar kepala ${widget.child.nama} secara berkala, misalnya sebulan sekali.',
              actionLabel: 'Catat Pertumbuhan',
              onAction: _add,
            );
          }
          final latest = data['latest'] as Map<String, dynamic>;
          final change = data['change'] as Map<String, dynamic>;
          final latestDate = DateTime.parse('${latest['measured_at']}').toLocal();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                'Pengukuran terakhir: ${formatDate(latestDate)}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final entry in _metrics.entries) ...[
                    Expanded(
                      child: _MetricCard(
                        label: entry.value.$1,
                        unit: entry.value.$2,
                        color: entry.value.$3,
                        value: latest[entry.key] as num?,
                        change: change[entry.key] as num?,
                      ),
                    ),
                    if (entry.key != _metrics.keys.last) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SectionTitle('Posisi pada kurva WHO'),
              WhoPositionCard(who: data['who'] as Map<String, dynamic>?),
              const SectionTitle('Grafik'),
              SegmentedButton<String>(
                segments: [
                  for (final entry in _metrics.entries)
                    ButtonSegment(value: entry.key, label: Text(entry.value.$1.split(' ').first)),
                ],
                selected: {_metric},
                onSelectionChanged: (value) => setState(() { _metric = value.first; }),
              ),
              const SizedBox(height: 12),
              PataraCard(
                child: SizedBox(
                  height: 210,
                  child: _GrowthChart(
                    points: [
                      for (final record in records)
                        if (record[_metric] != null)
                          (DateTime.parse('${record['measured_at']}').toLocal(), (record[_metric] as num).toDouble()),
                    ],
                    color: _metrics[_metric]!.$3,
                    unit: _metrics[_metric]!.$2,
                  ),
                ),
              ),
              const SectionTitle('Riwayat pengukuran'),
              for (final record in records.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PataraCard(
                    padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatDate(DateTime.parse('${record['measured_at']}').toLocal()),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                [
                                  '${formatNumber(record['weight_kg'] as num)} kg',
                                  '${formatNumber(record['height_cm'] as num)} cm',
                                  if (record['head_circumference_cm'] != null)
                                    'LK ${formatNumber(record['head_circumference_cm'] as num)} cm',
                                ].join('  •  '),
                                style: const TextStyle(color: pataraInk),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus pengukuran',
                          onPressed: () => _delete(record),
                          icon: const Icon(Icons.delete_outline, color: Colors.black38),
                        ),
                      ],
                    ),
                  ),
                ),
              const DisclaimerNote(
                'Halaman ini mencatat hasil pengukuran, perubahannya, dan posisinya pada kurva WHO. Angka z-score bukan diagnosis; penilaian status gizi atau pertumbuhan dilakukan oleh tenaga kesehatan, misalnya di posyandu atau dokter anak.',
              ),
            ],
          );
        },
      ),
    );
  }
}

String _signed(num value) =>
    '${value > 0 ? '+' : ''}${value.toStringAsFixed(2).replaceAll('.', ',')}';

/// Posisi pengukuran terakhir pada kurva standar WHO (z-score), tanpa kategori status gizi.
class WhoPositionCard extends StatelessWidget {
  final Map<String, dynamic>? who;

  const WhoPositionCard({super.key, required this.who});

  @override
  Widget build(BuildContext context) {
    final data = who;
    if (data == null || data['available'] != true) {
      return PataraCard(
        child: Text(
          '${data?['reason'] ?? 'Posisi pada kurva WHO belum dapat dihitung.'}',
          style: const TextStyle(color: Colors.black54, height: 1.4),
        ),
      );
    }
    final indicators = (data['indicators'] as List).cast<Map<String, dynamic>>();
    return PataraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in indicators) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['label']}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
                Text(
                  'z ${_signed(item['z_score'] as num)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: item['outside'] == true ? pataraOrange : pataraTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _ZScale(z: (item['z_score'] as num).toDouble(), outside: item['outside'] == true),
            const SizedBox(height: 4),
            Text('${item['text']}', style: const TextStyle(fontSize: 12.5)),
            Text(
              'Median WHO ${formatNumber(item['median'] as num)} ${'${item['unit']}'.replaceAll('m2', 'm²')}; '
              '-2 SD ${formatNumber(item['minus_2sd'] as num)}; +2 SD ${formatNumber(item['plus_2sd'] as num)}.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
          ],
          if (data['consult'] == true)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: pataraOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Ada angka di luar rentang -2 SD sampai +2 SD. Bawa catatan ini ke Posyandu, Puskesmas, atau dokter anak untuk diperiksa. Ini bukan diagnosis.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ),
          Text(
            'Dihitung untuk usia ${data['age_days']} hari memakai ${data['measure']}. Sumber: ${data['source']}',
            style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Garis -3 SD sampai +3 SD dengan penanda posisi; bagian -2 sampai +2 diberi warna.
class _ZScale extends StatelessWidget {
  final double z;
  final bool outside;

  const _ZScale({required this.z, required this.outside});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double at(double value) => (value.clamp(-3, 3) + 3) / 6 * width;
        return SizedBox(
          height: 30,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 5,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Positioned(
                left: at(-2),
                width: at(2) - at(-2),
                top: 5,
                child: Container(height: 8, color: pataraTeal.withOpacity(0.35)),
              ),
              Positioned(
                left: (at(z) - 7).clamp(0, width - 14),
                top: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: outside ? pataraOrange : pataraTeal,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              for (final (value, label) in const [(-2.0, '-2'), (0.0, '0'), (2.0, '+2')])
                Positioned(
                  left: at(value) - 10,
                  width: 20,
                  top: 17,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String unit;
  final Color color;
  final num? value;
  final num? change;

  const _MetricCard({
    required this.label,
    required this.unit,
    required this.color,
    required this.value,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    final delta = change;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value == null ? '–' : '${formatNumber(value!)} $unit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          Text(
            delta == null
                ? ' '
                : delta == 0
                ? 'tetap'
                : '${delta > 0 ? '+' : ''}${formatNumber(delta)} $unit',
            style: const TextStyle(fontSize: 11.5, color: pataraInk),
          ),
        ],
      ),
    );
  }
}

/// Grafik garis untuk satu ukuran pertumbuhan. Ketuk titik untuk melihat tanggal dan nilainya.
class _GrowthChart extends StatefulWidget {
  final List<(DateTime, double)> points;
  final Color color;
  final String unit;

  const _GrowthChart({required this.points, required this.color, required this.unit});

  @override
  State<_GrowthChart> createState() => _GrowthChartState();
}

class _GrowthChartState extends State<_GrowthChart> {
  int? _selected;

  @override
  void didUpdateWidget(_GrowthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Titik terpilih tidak dibawa saat berganti ukuran (berat, tinggi, lingkar kepala).
    if (oldWidget.unit != widget.unit || oldWidget.color != widget.color || oldWidget.points.length != widget.points.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.length < 2) {
      return const Center(
        child: Text(
          'Grafik muncul setelah ada dua pengukuran.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    final shown = points[_selected ?? points.length - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatDate(shown.$1)}: ${formatNumber(shown.$2)} ${widget.unit}',
          style: TextStyle(fontWeight: FontWeight.w800, color: widget.color),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = _ChartLayout(points, constraints.biggest);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => setState(() { _selected = layout.nearest(details.localPosition.dx); }),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _ChartPainter(layout, widget.color, _selected ?? points.length - 1),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: _ChartLayout.gutter),
            Expanded(
              child: Text(formatDate(points.first.$1), style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ),
            Text(formatDate(points.last.$1), style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ],
    );
  }
}

/// Letak titik grafik: sumbu waktu mendatar, nilai tegak, dengan ruang di kiri untuk angka sumbu.
class _ChartLayout {
  static const gutter = 38.0;

  final List<(DateTime, double)> points;
  final Size size;
  late final double low;
  late final double high;

  _ChartLayout(this.points, this.size) {
    final values = points.map((point) => point.$2);
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    // Ruang 10% di atas dan bawah agar garis tidak menempel tepi; nilai yang sama tetap terlihat.
    final margin = max == min ? 1.0 : (max - min) * 0.1;
    low = min - margin;
    high = max + margin;
  }

  double y(double value) => 8 + (1 - (value - low) / (high - low)) * (size.height - 16);

  Offset position(int index) {
    final start = points.first.$1.millisecondsSinceEpoch;
    final span = points.last.$1.millisecondsSinceEpoch - start;
    final x = span == 0 ? index / (points.length - 1) : (points[index].$1.millisecondsSinceEpoch - start) / span;
    return Offset(gutter + 6 + x * (size.width - gutter - 14), y(points[index].$2));
  }

  int nearest(double dx) {
    var best = 0;
    for (var i = 1; i < points.length; i++) {
      if ((position(i).dx - dx).abs() < (position(best).dx - dx).abs()) best = i;
    }
    return best;
  }
}

class _ChartPainter extends CustomPainter {
  final _ChartLayout layout;
  final Color color;
  final int selected;

  _ChartPainter(this.layout, this.color, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final points = layout.points;
    final grid = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final value = layout.high - i * (layout.high - layout.low) / 3;
      final y = layout.y(value);
      canvas.drawLine(Offset(_ChartLayout.gutter, y), Offset(size.width, y), grid);
      final label = TextPainter(
        text: TextSpan(text: formatNumber(value), style: const TextStyle(fontSize: 10, color: Colors.black54)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _ChartLayout.gutter - 4);
      label.paint(canvas, Offset(_ChartLayout.gutter - 6 - label.width, y - label.height / 2));
    }
    final line = Path()..moveTo(layout.position(0).dx, layout.position(0).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(layout.position(i).dx, layout.position(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(layout.position(points.length - 1).dx, size.height)
      ..lineTo(layout.position(0).dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withOpacity(0.12));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < points.length; i++) {
      final picked = i == selected;
      canvas.drawCircle(layout.position(i), picked ? 8 : 5, Paint()..color = Colors.white);
      canvas.drawCircle(layout.position(i), picked ? 6 : 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.layout.points != layout.points ||
      oldDelegate.layout.size != layout.size ||
      oldDelegate.color != color ||
      oldDelegate.selected != selected;
}

class _GrowthForm extends StatefulWidget {
  final BackendChild child;

  const _GrowthForm({required this.child});

  @override
  State<_GrowthForm> createState() => _GrowthFormState();
}

class _GrowthFormState extends State<_GrowthForm> {
  final _formKey = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _head = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    _head.dispose();
    super.dispose();
  }

  double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validate(String? text, double min, double max, {bool required = true}) {
    if ((text ?? '').trim().isEmpty) return required ? 'Wajib diisi' : null;
    final value = _parse(text!);
    if (value == null) return 'Isi dengan angka';
    return value < min || value > max ? 'Antara ${formatNumber(min)} dan ${formatNumber(max)}' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; });
    try {
      final now = DateTime.now();
      await PataraApi.addGrowth(
        widget.child.id,
        weightKg: _parse(_weight.text)!,
        heightCm: _parse(_height.text)!,
        headCm: _head.text.trim().isEmpty ? null : _parse(_head.text),
        measuredAt: DateUtils.isSameDay(_date, now) ? now : DateTime(_date.year, _date.month, _date.day, 12),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  InputDecoration _decoration(String label, String suffix) => InputDecoration(
    labelText: label,
    suffixText: suffix,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    const number = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Catat pertumbuhan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: widget.child.birthDate ?? DateTime(DateTime.now().year - 6),
                    lastDate: DateTime.now(),
                    helpText: 'Tanggal pengukuran',
                  );
                  if (picked != null) setState(() { _date = picked; });
                },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text('Diukur ${formatDate(_date)}'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weight,
                keyboardType: number,
                decoration: _decoration('Berat badan', 'kg'),
                validator: (text) => _validate(text, 0.5, 50),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _height,
                keyboardType: number,
                decoration: _decoration('Tinggi / panjang badan', 'cm'),
                validator: (text) => _validate(text, 20, 140),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _head,
                keyboardType: number,
                decoration: _decoration('Lingkar kepala (opsional)', 'cm'),
                validator: (text) => _validate(text, 20, 70, required: false),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
