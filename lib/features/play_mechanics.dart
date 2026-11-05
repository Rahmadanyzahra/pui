import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../patara/patara_ui.dart';
import '../services/backend_api_service.dart';
import '../services/game_sound_service.dart';
import '../widgets/game_art.dart';
import '../widgets/mini_game_ui.dart';

/// Permainan dengan cara main selain pilihan ganda: kartu memori, seret dan cocokkan, dan mewarnai.
/// Dipakai oleh Zona Bermain 1-2 tahun dan 2-5 tahun dengan isi yang berbeda.

Future<void> _saveResult(String summaryKey, String? childId, {required int score, required int stars}) async {
  await MiniGameSummary.saveFinished(summaryKey, score: score, stars: stars, childId: childId);
  if (childId == null) return;
  try {
    await BackendApiService.logActivity(
      childId: childId,
      activityType: 'play_game_completed',
      value: jsonEncode({'game': summaryKey, 'score': score, 'stars': stars}),
    );
  } catch (_) {
    // Hasil tetap tersimpan di perangkat bila backend tidak terjangkau.
  }
}

/// Tiga permainan tambahan untuk satu kelompok usia; [toddler] memakai isi yang lebih sederhana.
List<MiniGameEntry> playMechanicEntries({required bool toddler, String? childId}) {
  final prefix = toddler ? 'toddler' : 'anak';
  return [
    MiniGameEntry(
      title: 'Kartu Memori',
      description: 'Buka dua kartu dan cari gambar yang sama.',
      icon: Icons.style,
      emoji: '🃏',
      summaryKey: '${prefix}_game_memory_summary',
      builder: (_) => MemoryGameScreen(
        pairs: toddler ? 3 : 6,
        summaryKey: '${prefix}_game_memory_summary',
        childId: childId,
      ),
    ),
    MiniGameEntry(
      title: 'Seret & Cocokkan',
      description: toddler ? 'Seret bola ke keranjang yang warnanya sama.' : 'Seret gambar ke kelompoknya.',
      icon: Icons.pan_tool_alt,
      emoji: '🧲',
      summaryKey: '${prefix}_game_drag_summary',
      builder: (_) => DragMatchScreen(
        toddler: toddler,
        summaryKey: '${prefix}_game_drag_summary',
        childId: childId,
      ),
    ),
    MiniGameEntry(
      title: 'Mewarnai',
      description: 'Pilih warna lalu ketuk bagian gambar.',
      icon: Icons.brush,
      emoji: '🖍️',
      summaryKey: '${prefix}_game_coloring_summary',
      builder: (_) => ColoringScreen(summaryKey: '${prefix}_game_coloring_summary', childId: childId),
    ),
  ];
}

// ---------- Kartu Memori ----------

class MemoryGameScreen extends StatefulWidget {
  final int pairs;
  final String summaryKey;
  final String? childId;

  /// Benih acakan; diisi pada tes agar susunan kartu tetap.
  final int? seed;

  const MemoryGameScreen({super.key, required this.pairs, required this.summaryKey, this.childId, this.seed});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  static const _faces = ['🐶', '🐱', '🐰', '🐸', '🦋', '🐟', '🍎', '🌼'];

  late List<String> _cards;
  final Set<int> _matched = {};
  final List<int> _open = [];
  int _mistakes = 0;
  bool _locked = false;
  String? _feedback;
  bool _feedbackPositive = true;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final random = Random(widget.seed);
    final faces = ([..._faces]..shuffle(random)).take(widget.pairs).toList();
    _cards = [...faces, ...faces]..shuffle(random);
    _matched.clear();
    _open.clear();
    _mistakes = 0;
    _locked = false;
    _feedback = null;
  }

  bool get _finished => _matched.length == _cards.length;

  int get _stars => _mistakes <= widget.pairs
      ? 3
      : _mistakes <= widget.pairs * 2
      ? 2
      : 1;

  int get _score => max(10, widget.pairs * 20 - _mistakes * 5);

  Future<void> _tap(int index) async {
    if (_locked || _open.contains(index) || _matched.contains(index)) return;
    setState(() => _open.add(index));
    if (_open.length < 2) return;
    final first = _open[0], second = _open[1];
    if (_cards[first] == _cards[second]) {
      setState(() {
        _matched.addAll(_open);
        _open.clear();
        _feedback = 'Cocok!';
        _feedbackPositive = true;
      });
      if (_finished) await _saveResult(widget.summaryKey, widget.childId, score: _score, stars: _stars);
      return;
    }
    setState(() {
      _locked = true;
      _mistakes++;
      _feedback = 'Belum sama, coba lagi.';
      _feedbackPositive = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _open.clear();
      _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameShell(
      title: 'Kartu Memori',
      color: pataraPurple,
      step: _matched.length ~/ 2,
      totalSteps: widget.pairs,
      score: _finished ? _score : _matched.length ~/ 2 * 10,
      mistakes: _mistakes,
      stars: _stars,
      prompt: 'Buka dua kartu yang sama!',
      finished: _finished,
      feedback: _feedback,
      feedbackPositive: _feedbackPositive,
      onRestart: () => setState(_deal),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _cards.length <= 6 ? 3 : 4;
          final size = ((constraints.maxWidth - 10 * (columns - 1)) / columns).floorToDouble();
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var index = 0; index < _cards.length; index++)
                _MemoryCard(
                  key: ValueKey('memory-$index-${_cards[index]}'),
                  size: size,
                  face: _cards[index],
                  open: _open.contains(index) || _matched.contains(index),
                  matched: _matched.contains(index),
                  onTap: () => _tap(index),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final double size;
  final String face;
  final bool open;
  final bool matched;
  final VoidCallback onTap;

  const _MemoryCard({
    super.key,
    required this.size,
    required this.face,
    required this.open,
    required this.matched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: open ? 'Kartu terbuka' : 'Kartu tertutup',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: open ? (matched ? const Color(0xFFE8F5E9) : Colors.white) : pataraPurple,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: matched ? const Color(0xFF43A047) : Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: open
              ? Padding(padding: EdgeInsets.all(size * 0.14), child: GameArt(face, size: size))
              : const Icon(Icons.star_rounded, color: Colors.white70, size: 30),
        ),
      ),
    );
  }
}

// ---------- Seret & Cocokkan ----------

class _DragTargetInfo {
  final String key;
  final String label;
  final String emoji;
  final Color color;

  const _DragTargetInfo(this.key, this.label, this.emoji, this.color);
}

class DragMatchScreen extends StatefulWidget {
  final bool toddler;
  final String summaryKey;
  final String? childId;
  final int? seed;

  const DragMatchScreen({super.key, required this.toddler, required this.summaryKey, this.childId, this.seed});

  @override
  State<DragMatchScreen> createState() => _DragMatchScreenState();
}

class _DragMatchScreenState extends State<DragMatchScreen> {
  static const _colorTargets = [
    _DragTargetInfo('merah', 'Merah', '🧺', Color(0xFFE53935)),
    _DragTargetInfo('biru', 'Biru', '🧺', Color(0xFF1E88E5)),
    _DragTargetInfo('kuning', 'Kuning', '🧺', Color(0xFFFDD835)),
  ];
  static const _colorItems = [('🔴', 'merah'), ('🔵', 'biru'), ('🟡', 'kuning'), ('🍎', 'merah'), ('🐳', 'biru'), ('🍌', 'kuning')];
  static const _groupTargets = [
    _DragTargetInfo('hewan', 'Hewan', '🏡', Color(0xFF66BB6A)),
    _DragTargetInfo('buah', 'Buah', '🧺', Color(0xFFFFA726)),
    _DragTargetInfo('kendaraan', 'Kendaraan', '🛣️', Color(0xFF42A5F5)),
  ];
  static const _groupItems = [('🐄', 'hewan'), ('🍇', 'buah'), ('🚌', 'kendaraan'), ('🐔', 'hewan'), ('🍉', 'buah'), ('🚲', 'kendaraan')];

  late List<(String, String)> _items;
  final Set<int> _placed = {};
  int _mistakes = 0;
  String? _feedback;
  bool _feedbackPositive = true;

  List<_DragTargetInfo> get _targets => widget.toddler ? _colorTargets : _groupTargets;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    _items = [...(widget.toddler ? _colorItems : _groupItems)]..shuffle(Random(widget.seed));
    _placed.clear();
    _mistakes = 0;
    _feedback = null;
  }

  bool get _finished => _placed.length == _items.length;

  Future<void> _drop(int index, _DragTargetInfo target) async {
    if (_items[index].$2 != target.key) {
      setState(() {
        _mistakes++;
        _feedback = 'Bukan di sini, coba tempat lain.';
        _feedbackPositive = false;
      });
      return;
    }
    setState(() {
      _placed.add(index);
      _feedback = 'Tepat! Masuk ke ${target.label}.';
      _feedbackPositive = true;
    });
    if (_finished) {
      await _saveResult(widget.summaryKey, widget.childId, score: _placed.length * 10, stars: miniGameStars(_mistakes));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MiniGameShell(
      title: 'Seret & Cocokkan',
      color: pataraTeal,
      step: _placed.length,
      totalSteps: _items.length,
      score: _placed.length * 10,
      mistakes: _mistakes,
      prompt: widget.toddler ? 'Seret ke keranjang yang warnanya sama!' : 'Seret gambar ke kelompoknya!',
      finished: _finished,
      feedback: _feedback,
      feedbackPositive: _feedbackPositive,
      onRestart: () => setState(_deal),
      child: Column(
        children: [
          Row(
            children: [
              for (final target in _targets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: DragTarget<int>(
                      key: ValueKey('drop-${target.key}'),
                      onAcceptWithDetails: (details) => _drop(details.data, target),
                      builder: (context, candidates, _) => AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 118,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: candidates.isEmpty ? Colors.white : target.color.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: target.color, width: candidates.isEmpty ? 3 : 5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GameArt(target.emoji, size: 36),
                            FittedBox(
                              child: Text(target.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            ),
                            // Benda yang sudah masuk terlihat di dalam keranjangnya.
                            SizedBox(
                              height: 24,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final index in _placed)
                                    if (_items[index].$2 == target.key) GameArt(_items[index].$1, size: 22),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (var index = 0; index < _items.length; index++)
                if (!_placed.contains(index))
                  Draggable<int>(
                    key: ValueKey('drag-$index-${_items[index].$2}'),
                    data: index,
                    feedback: Material(
                      color: Colors.transparent,
                      child: GameArt(_items[index].$1, size: 72),
                    ),
                    childWhenDragging: const SizedBox(width: 76, height: 76),
                    child: Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
                      ),
                      child: GameArt(_items[index].$1, size: 48),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Mewarnai ----------

/// Satu bagian gambar yang bisa diwarnai. Koordinat dalam pecahan lebar dan tinggi kanvas.
class ColoringRegion {
  final String name;
  final Path Function(Size size) path;

  /// Titik di dalam bagian ini (pecahan kanvas), dipakai tes untuk mengetuknya.
  final Offset anchor;

  const ColoringRegion(this.name, this.path, this.anchor);
}

Path _rect(Size s, double l, double t, double r, double b) => Path()..addRect(Rect.fromLTRB(s.width * l, s.height * t, s.width * r, s.height * b));

Path _oval(Size s, double cx, double cy, double rx, double ry) =>
    Path()..addOval(Rect.fromCenter(center: Offset(s.width * cx, s.height * cy), width: s.width * rx * 2, height: s.height * ry * 2));

/// Gambar rumah: bagian belakang digambar lebih dulu, bagian depan menimpanya.
final List<ColoringRegion> coloringRegions = [
  ColoringRegion('Langit', (s) => _rect(s, 0, 0, 1, 0.72), const Offset(0.5, 0.08)),
  ColoringRegion('Rumput', (s) => _rect(s, 0, 0.72, 1, 1), const Offset(0.5, 0.92)),
  ColoringRegion('Matahari', (s) => _oval(s, 0.84, 0.16, 0.1, 0.1), const Offset(0.84, 0.16)),
  ColoringRegion('Daun pohon', (s) => _oval(s, 0.16, 0.42, 0.13, 0.17), const Offset(0.16, 0.36)),
  ColoringRegion('Batang pohon', (s) => _rect(s, 0.135, 0.56, 0.185, 0.78), const Offset(0.16, 0.7)),
  ColoringRegion('Dinding rumah', (s) => _rect(s, 0.36, 0.44, 0.78, 0.8), const Offset(0.44, 0.74)),
  ColoringRegion(
    'Atap',
    (s) => Path()
      ..moveTo(s.width * 0.31, s.height * 0.44)
      ..lineTo(s.width * 0.57, s.height * 0.22)
      ..lineTo(s.width * 0.83, s.height * 0.44)
      ..close(),
    const Offset(0.57, 0.36),
  ),
  ColoringRegion('Pintu', (s) => _rect(s, 0.52, 0.58, 0.62, 0.8), const Offset(0.57, 0.7)),
  ColoringRegion('Jendela', (s) => _rect(s, 0.66, 0.52, 0.74, 0.62), const Offset(0.7, 0.57)),
];

class ColoringScreen extends StatefulWidget {
  final String summaryKey;
  final String? childId;

  const ColoringScreen({super.key, required this.summaryKey, this.childId});

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen> {
  static const palette = [
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF29B6F6),
    Color(0xFF8E24AA),
    Color(0xFF8D6E63),
    Color(0xFFF48FB1),
  ];

  final Map<int, Color> _fills = {};
  Color _color = palette.first;
  bool _saved = false;

  void _paintAt(Offset position, Size size) {
    // Bagian yang digambar paling akhir berada paling depan, jadi diperiksa lebih dulu.
    for (var index = coloringRegions.length - 1; index >= 0; index--) {
      if (coloringRegions[index].path(size).contains(position)) {
        setState(() { _fills[index] = _color; });
        GameSoundService.play(GameSound.pop);
        return;
      }
    }
  }

  Future<void> _finish() async {
    GameSoundService.play(GameSound.selesai);
    await _saveResult(widget.summaryKey, widget.childId, score: _fills.length * 10, stars: 3);
    if (mounted) setState(() { _saved = true; });
  }

  @override
  Widget build(BuildContext context) {
    final complete = _fills.length == coloringRegions.length;
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6DF),
      appBar: sectionAppBar('Mewarnai', pataraOrange, icon: Icons.brush, actions: const [GameSoundToggle()]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _saved
                    ? 'Gambarmu selesai. Bagus sekali!'
                    : complete
                    ? 'Semua sudah berwarna. Ketuk Selesai, atau ganti warnanya lagi.'
                    : 'Pilih warna, lalu ketuk bagian gambar (${_fills.length} dari ${coloringRegions.length}).',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      key: const ValueKey('coloring-canvas'),
                      onTapDown: (details) => _paintAt(details.localPosition, constraints.biggest),
                      child: CustomPaint(size: constraints.biggest, painter: _ColoringPainter(Map.of(_fills))),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var index = 0; index < palette.length; index++)
                    Semantics(
                      button: true,
                      label: 'Warna ${index + 1}',
                      child: GestureDetector(
                        key: ValueKey('coloring-color-$index'),
                        onTap: () => setState(() { _color = palette[index]; }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _color == palette[index] ? 46 : 38,
                          height: _color == palette[index] ? 46 : 38,
                          decoration: BoxDecoration(
                            color: palette[index],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _fills.isEmpty
                          ? null
                          : () => setState(() {
                              _fills.clear();
                              _saved = false;
                            }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Ulangi'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: complete && !_saved ? _finish : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Selesai'),
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
}

class _ColoringPainter extends CustomPainter {
  final Map<int, Color> fills;

  _ColoringPainter(this.fills);

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFF455A64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    for (var index = 0; index < coloringRegions.length; index++) {
      final path = coloringRegions[index].path(size);
      canvas.drawPath(path, Paint()..color = fills[index] ?? Colors.white);
      canvas.drawPath(path, outline);
    }
  }

  @override
  bool shouldRepaint(_ColoringPainter oldDelegate) => true;
}
