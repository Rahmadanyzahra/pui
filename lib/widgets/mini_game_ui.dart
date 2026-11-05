import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../patara/home_play_panel.dart';
import '../patara/patara_ui.dart';
import '../services/game_sound_service.dart';
import 'game_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hasil terbaik satu mini game, disimpan di SharedPreferences.
class MiniGameSummary {
  final int bestScore;
  final int stars;
  final bool completed;
  final int progress;

  const MiniGameSummary({
    this.bestScore = 0,
    this.stars = 0,
    this.completed = false,
    this.progress = 0,
  });

  /// Hasil disimpan per anak, sehingga anak lain atau akun baru di HP yang sama mulai dari nol.
  static String _scoped(String key, String? childId) => childId == null ? key : '${key}_$childId';

  static Future<MiniGameSummary> load(String key, {String? childId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scoped(key, childId));
    if (raw == null) return const MiniGameSummary();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return MiniGameSummary(
        bestScore: (decoded['bestScore'] as num?)?.toInt() ?? 0,
        stars: (decoded['stars'] as num?)?.toInt() ?? 0,
        completed: decoded['completed'] as bool? ?? false,
        progress: (decoded['progress'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const MiniGameSummary();
    }
  }

  /// Menyimpan sesi yang selesai tanpa menimpa skor dan bintang terbaik.
  static Future<void> saveFinished(
    String key, {
    required int score,
    required int stars,
    String? childId,
  }) async {
    final previous = await load(key, childId: childId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scoped(key, childId),
      jsonEncode({
        'bestScore': score > previous.bestScore ? score : previous.bestScore,
        'stars': stars > previous.stars ? stars : previous.stars,
        'completed': true,
        'progress': 100,
      }),
    );
  }
}

int miniGameStars(int mistakes) {
  if (mistakes <= 1) return 3;
  if (mistakes <= 3) return 2;
  return 1;
}

class MiniGameStars extends StatelessWidget {
  final int count;
  final double size;

  const MiniGameStars({super.key, required this.count, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Icon(
          index < count ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: Colors.amber,
        ),
      ),
    );
  }
}

class MiniGameEntry {
  final String title;
  final String description;
  final IconData icon;
  final String emoji;
  final String summaryKey;
  final WidgetBuilder builder;

  const MiniGameEntry({
    required this.title,
    required this.description,
    required this.icon,
    required this.summaryKey,
    required this.builder,
    this.emoji = '🎮',
  });
}

/// Latar padang rumput untuk Zona Bermain: langit, matahari, awan, bukit, pohon, dan bunga.
class MeadowPainter extends CustomPainter {
  /// Bagian tinggi (0-1) tempat rumput dimulai.
  final double horizon;

  const MeadowPainter({this.horizon = 0.6});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, ground = h * horizon;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF8FD3F4), Color(0xFFDDF5CE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );
    // Matahari dan awan tetap di bagian atas walaupun langitnya tinggi (layar bermain).
    final sky = math.min(ground, 170.0);
    final sun = Offset(w * 0.82, sky * 0.34);
    canvas.drawCircle(sun, 30, Paint()..color = const Color(0x55FFF59D));
    canvas.drawCircle(sun, 19, Paint()..color = const Color(0xFFFFE566));
    final cloud = Paint()..color = Colors.white.withOpacity(0.92);
    for (final (x, y, scale) in const [(0.2, 0.3, 1.0), (0.56, 0.16, 0.7)]) {
      final center = Offset(w * x, sky * y);
      canvas.drawCircle(center, 15 * scale, cloud);
      canvas.drawCircle(center + Offset(17 * scale, 4 * scale), 12 * scale, cloud);
      canvas.drawCircle(center - Offset(16 * scale, -4 * scale), 11 * scale, cloud);
    }
    final lift = (h - ground).clamp(40.0, 90.0);
    final far = Path()
      ..moveTo(0, ground)
      ..quadraticBezierTo(w * 0.22, ground - lift * 0.9, w * 0.52, ground - lift * 0.2)
      ..quadraticBezierTo(w * 0.8, ground - lift * 0.8, w, ground - lift * 0.3)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFF9FD98C));
    void tree(double x, double scale) {
      final base = Offset(w * x, ground + 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: base - Offset(0, 14 * scale), width: 7 * scale, height: 30 * scale),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF8D6E63),
      );
      canvas.drawCircle(base - Offset(0, 40 * scale), 21 * scale, Paint()..color = const Color(0xFF4CAF50));
      canvas.drawCircle(base - Offset(11 * scale, 31 * scale), 14 * scale, Paint()..color = const Color(0xFF66BB6A));
      canvas.drawCircle(base - Offset(-12 * scale, 30 * scale), 13 * scale, Paint()..color = const Color(0xFF43A047));
    }

    tree(0.08, 1.1);
    tree(0.93, 0.85);
    final near = Path()
      ..moveTo(0, ground + 6)
      ..quadraticBezierTo(w * 0.4, ground - 12, w, ground + 10)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF7CCB6B));
    for (final (x, tint) in const [(0.2, Color(0xFFFFF176)), (0.34, Color(0xFFF48FB1)), (0.7, Color(0xFFFFFFFF)), (0.8, Color(0xFFFFB74D))]) {
      final center = Offset(w * x, ground + 16 + (x * 40) % 12);
      for (var petal = 0; petal < 5; petal++) {
        final angle = petal * 1.2566;
        canvas.drawCircle(center + Offset(4 * math.cos(angle), 4 * math.sin(angle)), 3, Paint()..color = tint);
      }
      canvas.drawCircle(center, 2.2, Paint()..color = const Color(0xFFFF8F00));
    }
  }

  @override
  bool shouldRepaint(MeadowPainter oldDelegate) => oldDelegate.horizon != horizon;
}

/// Zona Bermain: padang rumput dengan karakter, tantangan hari ini, petak permainan,
/// dan ide bermain di rumah.
class MiniGameHub extends StatefulWidget {
  final String title;
  final Color color;
  final List<MiniGameEntry> games;

  /// Bila diisi, tab "Main di rumah" menampilkan ide sesuai usia anak ini.
  final String? childId;

  const MiniGameHub({
    super.key,
    required this.title,
    required this.color,
    required this.games,
    this.childId,
  });

  @override
  State<MiniGameHub> createState() => _MiniGameHubState();
}

class _MiniGameHubState extends State<MiniGameHub> {
  static const _leaf = Color(0xFF2E5E2B);
  static const _tileColors = [
    Color(0xFFFFF3C4),
    Color(0xFFD9F0FF),
    Color(0xFFFFE0EC),
    Color(0xFFE3F6D5),
    Color(0xFFEDE3FF),
    Color(0xFFFFE6CC),
  ];

  Map<String, MiniGameSummary> _summaries = const {};
  bool _homePlay = false;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final loaded = <String, MiniGameSummary>{};
    for (final game in widget.games) {
      loaded[game.summaryKey] = await MiniGameSummary.load(game.summaryKey, childId: widget.childId);
    }
    if (!mounted) return;
    setState(() { _summaries = loaded; });
  }

  Future<void> _open(MiniGameEntry game) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: game.builder));
    await _loadSummaries();
  }

  int get _stars => widget.games.fold<int>(0, (total, game) => total + (_summaries[game.summaryKey]?.stars ?? 0));

  bool _finished(MiniGameEntry game) => _summaries[game.summaryKey]?.completed ?? false;

  /// Permainan yang ditawarkan hari ini; berganti setiap hari.
  MiniGameEntry get _todayGame {
    final now = DateTime.now();
    return widget.games[now.difference(DateTime(now.year)).inDays % widget.games.length];
  }

  Widget _pill({required Widget child, VoidCallback? onTap, String? tooltip}) {
    final pill = Material(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: child),
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }

  Widget _buildScene(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final stars = _stars;
    return SizedBox(
      height: 232 + top,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: MeadowPainter())),
          Positioned(
            left: 12,
            right: 12,
            top: top + 8,
            child: Row(
              children: [
                _pill(
                  tooltip: 'Kembali',
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back_rounded, color: _leaf, size: 22),
                ),
                const Spacer(),
                _pill(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                      const SizedBox(width: 4),
                      Text('$stars', style: const TextStyle(fontWeight: FontWeight.w800, color: _leaf)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: top + 56,
            child: Column(
              children: [
                const Text('Ayo main!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _leaf)),
                Text(
                  stars == 0
                      ? 'Pilih permainan dan kumpulkan bintang.'
                      : 'Bintang terkumpul: $stars dari ${widget.games.length * 3}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: _leaf, height: 1.3),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                KidMascot(emoji: '🐢', size: 46, background: Colors.transparent),
                KidMascot(emoji: '🦁', size: 70, background: Colors.transparent),
                KidMascot(emoji: '🐥', size: 50, background: Colors.transparent),
                KidMascot(emoji: '🐰', size: 46, background: Colors.transparent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Jalur petualangan: satu titik per permainan, berubah menjadi bintang setelah selesai.
  Widget _buildAdventure() {
    final done = widget.games.where(_finished).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: const Color(0xFF6DB65B), borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Petualangan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Text(
                '$done dari ${widget.games.length} selesai',
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var index = 0; index < widget.games.length; index++) ...[
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 4,
                      color: _finished(widget.games[index]) ? const Color(0xFFFFE566) : Colors.white38,
                    ),
                  ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _finished(widget.games[index]) ? const Color(0xFFFFE566) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: _finished(widget.games[index])
                      ? const Icon(Icons.star_rounded, size: 17, color: Color(0xFFEF8F00))
                      : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChallenge() {
    final game = _todayGame;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _open(game),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFFFF3C4), borderRadius: BorderRadius.circular(16)),
                child: GameArt(game.emoji, size: 38),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TANTANGAN HARI INI',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFEF6C00), letterSpacing: 0.6),
                    ),
                    Text(game.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                    Text(
                      game.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF6DB65B), size: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    Widget tab(String label, IconData icon, bool homePlay) {
      final selected = _homePlay == homePlay;
      return Expanded(
        child: Material(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() { _homePlay = homePlay; }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: _leaf),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: _leaf),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFCFE8BF), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          tab('Permainan', Icons.grid_view_rounded, false),
          tab('Main di rumah', Icons.cottage_rounded, true),
        ],
      ),
    );
  }

  Widget _buildTile(MiniGameEntry game, int index, double width) {
    final summary = _summaries[game.summaryKey] ?? const MiniGameSummary();
    return SizedBox(
      key: ValueKey('game-${game.summaryKey}'),
      width: width,
      height: 146,
      child: Material(
        color: _tileColors[index % _tileColors.length],
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _open(game),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                child: Column(
                  children: [
                    GameArt(game.emoji, size: 54),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Center(
                        child: Text(
                          game.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25, color: pataraInk),
                        ),
                      ),
                    ),
                    MiniGameStars(count: summary.stars, size: 16),
                  ],
                ),
              ),
              if (summary.completed)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Color(0xFF43A047),
                    child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final childId = widget.childId;
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6DF),
      body: Stack(
        children: [
          ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildScene(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAdventure(),
                const SizedBox(height: 12),
                _buildChallenge(),
                if (childId != null) ...[
                  const SizedBox(height: 14),
                  _buildTabs(),
                ],
                const SizedBox(height: 14),
                if (_homePlay && childId != null)
                  HomePlayPanel(childId: childId)
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 340 ? 3 : 2;
                      final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (var index = 0; index < widget.games.length; index++)
                            _buildTile(widget.games[index], index, width.floorToDouble()),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
          // Bilah status tetap berwarna langit saat isi digulir di bawahnya.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: MediaQuery.paddingOf(context).top,
            child: const ColoredBox(color: Color(0xFF8FD3F4)),
          ),
        ],
      ),
    );
  }
}

/// Tombol nyala/mati efek suara di bilah atas game.
class GameSoundToggle extends StatefulWidget {
  const GameSoundToggle({super.key});

  @override
  State<GameSoundToggle> createState() => _GameSoundToggleState();
}

class _GameSoundToggleState extends State<GameSoundToggle> {
  @override
  void initState() {
    super.initState();
    GameSoundService.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: GameSoundService.enabled,
      builder: (context, on, _) => IconButton(
        tooltip: on ? 'Matikan suara' : 'Nyalakan suara',
        icon: Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded),
        onPressed: () => GameSoundService.setEnabled(!on),
      ),
    );
  }
}

/// Kerangka layar bermain: progres dan skor di atas, soal di tengah,
/// umpan balik di bawah, lalu layar hasil setelah selesai.
///
/// Efek suara diputar dari perubahan skor, kesalahan, dan status selesai, jadi setiap game
/// yang memakai kerangka ini otomatis bersuara.
class MiniGameShell extends StatefulWidget {
  final String title;
  final Color color;
  final int step;
  final int totalSteps;
  final int score;
  final int mistakes;
  final bool finished;
  final String? feedback;
  final bool feedbackPositive;
  final VoidCallback onRestart;
  final Widget child;

  /// Bintang di layar hasil; bila kosong dihitung dari jumlah kesalahan.
  final int? stars;

  /// Ajakan yang tampil sebelum ada umpan balik.
  final String prompt;

  const MiniGameShell({
    super.key,
    required this.title,
    required this.color,
    required this.step,
    required this.totalSteps,
    required this.score,
    required this.mistakes,
    required this.finished,
    required this.onRestart,
    required this.child,
    this.feedback,
    this.feedbackPositive = true,
    this.stars,
    this.prompt = 'Ayo pilih jawabannya!',
  });

  @override
  State<MiniGameShell> createState() => _MiniGameShellState();
}

class _MiniGameShellState extends State<MiniGameShell> {
  @override
  void didUpdateWidget(MiniGameShell old) {
    super.didUpdateWidget(old);
    if (widget.finished && !old.finished) {
      GameSoundService.play(GameSound.selesai);
    } else if (!widget.finished && widget.mistakes > old.mistakes) {
      GameSoundService.play(GameSound.salah);
    } else if (!widget.finished && widget.score > old.score) {
      GameSoundService.play(GameSound.benar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sectionAppBar(
        widget.title,
        widget.color,
        icon: Icons.sports_esports_outlined,
        actions: const [GameSoundToggle()],
      ),
      body: SizedBox.expand(
        // Latar padang rumput yang sama dengan Zona Bermain.
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: MeadowPainter(horizon: 0.84))),
            SafeArea(child: widget.finished ? _buildResult(context) : _buildPlaying()),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaying() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var index = 0; index < widget.totalSteps; index++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 12,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: index < widget.step ? widget.color : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: widget.color.withOpacity(0.35)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.step}/${widget.totalSteps}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                    Text(
                      '${widget.score}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: widget.child,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              // Karakter melompat sekali setiap umpan balik berganti.
              TweenAnimationBuilder<double>(
                key: ValueKey('${widget.step}-${widget.feedback}'),
                tween: Tween(begin: 0.8, end: 1),
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0xFFFFE082), shape: BoxShape.circle),
                  child: GameArt(widget.feedback == null ? '🦁' : (widget.feedbackPositive ? '🤩' : '🤔'), size: 30),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: widget.feedback == null
                          ? widget.color.withOpacity(0.3)
                          : (widget.feedbackPositive ? const Color(0xFF43A047) : const Color(0xFFE53935)),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    widget.feedback ?? widget.prompt,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.feedback == null
                          ? Colors.black54
                          : (widget.feedbackPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameArtRow('🎉 🏆 🎉', size: 48),
            const SizedBox(height: 4),
            Text(
              widget.mistakes == 0 ? 'Luar biasa!' : 'Kamu hebat!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: widget.color),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selesai!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            MiniGameStars(count: widget.stars ?? miniGameStars(widget.mistakes), size: 48),
            const SizedBox(height: 12),
            Text(
              'Skor ${widget.score}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.mistakes == 0 ? 'Tanpa kesalahan' : 'Salah ${widget.mistakes} kali',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: widget.onRestart,
                icon: const Icon(Icons.replay),
                label: const Text('Main Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Pilih Game Lain'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum MiniGameOptionState { idle, correct, wrong }

/// Kartu pilihan jawaban yang berubah warna setelah dijawab.
class MiniGameOption extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final MiniGameOptionState state;

  const MiniGameOption({
    super.key,
    required this.child,
    required this.onTap,
    this.state = MiniGameOptionState.idle,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color border;
    switch (state) {
      case MiniGameOptionState.correct:
        background = const Color(0xFFE8F5E9);
        border = const Color(0xFF43A047);
      case MiniGameOptionState.wrong:
        background = const Color(0xFFFFEBEE);
        border = const Color(0xFFE53935);
      case MiniGameOptionState.idle:
        background = Colors.white;
        border = const Color(0xFF90CAF9);
    }
    return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: border.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Stack(
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: border, width: 2.5),
                  ),
                  child: child,
                ),
                if (state != MiniGameOptionState.idle)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Icon(
                      state == MiniGameOptionState.correct ? Icons.check_circle : Icons.cancel,
                      color: border,
                      size: 22,
                    ),
                  ),
              ],
            ),
          ),
        ),
    );
  }
}

/// Grid dua kolom untuk pilihan jawaban.
class MiniGameOptionGrid extends StatelessWidget {
  final List<Widget> children;
  final double childAspectRatio;
  final int columns;

  const MiniGameOptionGrid({
    super.key,
    required this.children,
    this.childAspectRatio = 1.2,
    this.columns = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}
