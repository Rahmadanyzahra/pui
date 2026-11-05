import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/dashboard_theme_service.dart';
import '../widgets/game_art.dart';
import '../widgets/mini_game_ui.dart';
import 'play_mechanics.dart';

enum ToddlerGameType { colorMatch, shapeMatch, fruitTap, bubblePop, animalTap, vehicleTap, faceTap }

extension ToddlerGameTypeX on ToddlerGameType {
  String get title {
    switch (this) {
      case ToddlerGameType.colorMatch:
        return 'Cocokkan Warna';
      case ToddlerGameType.shapeMatch:
        return 'Cocokkan Bentuk';
      case ToddlerGameType.fruitTap:
        return 'Ketuk Buah';
      case ToddlerGameType.bubblePop:
        return 'Pecahkan Gelembung';
      case ToddlerGameType.animalTap:
        return 'Cari Hewan';
      case ToddlerGameType.vehicleTap:
        return 'Cari Kendaraan';
      case ToddlerGameType.faceTap:
        return 'Wajah Apa Ini';
    }
  }

  String get description {
    switch (this) {
      case ToddlerGameType.colorMatch:
        return 'Pilih warna yang disebutkan.';
      case ToddlerGameType.shapeMatch:
        return 'Pilih bentuk yang disebutkan.';
      case ToddlerGameType.fruitTap:
        return 'Ketuk buah yang diminta.';
      case ToddlerGameType.bubblePop:
        return 'Pecahkan gelembung sesuai warnanya.';
      case ToddlerGameType.animalTap:
        return 'Ketuk hewan yang disebutkan.';
      case ToddlerGameType.vehicleTap:
        return 'Ketuk kendaraan yang disebutkan.';
      case ToddlerGameType.faceTap:
        return 'Ketuk wajah senang, sedih, atau mengantuk.';
    }
  }

  IconData get icon {
    switch (this) {
      case ToddlerGameType.colorMatch:
        return Icons.color_lens;
      case ToddlerGameType.shapeMatch:
        return Icons.category;
      case ToddlerGameType.fruitTap:
        return Icons.food_bank;
      case ToddlerGameType.bubblePop:
        return Icons.bubble_chart;
      case ToddlerGameType.animalTap:
        return Icons.pets;
      case ToddlerGameType.vehicleTap:
        return Icons.directions_bus;
      case ToddlerGameType.faceTap:
        return Icons.emoji_emotions;
    }
  }

  String get emoji => switch (this) {
    ToddlerGameType.colorMatch => '🌈',
    ToddlerGameType.shapeMatch => '🔷',
    ToddlerGameType.fruitTap => '🍓',
    ToddlerGameType.bubblePop => '🫧',
    ToddlerGameType.animalTap => '🐮',
    ToddlerGameType.vehicleTap => '🚗',
    ToddlerGameType.faceTap => '😄',
  };

  String get summaryKey => 'toddler_game_${name}_summary';
}

extension _ToddlerGameContent on ToddlerGameType {
  String promptFor(String label) {
    switch (this) {
      case ToddlerGameType.colorMatch:
        return 'Mana warna $label?';
      case ToddlerGameType.shapeMatch:
        return 'Mana bentuk $label?';
      case ToddlerGameType.fruitTap:
        return 'Mana buah $label?';
      case ToddlerGameType.bubblePop:
        return 'Pecahkan gelembung $label!';
      case ToddlerGameType.animalTap:
        return 'Mana $label?';
      case ToddlerGameType.vehicleTap:
        return 'Mana $label?';
      case ToddlerGameType.faceTap:
        return 'Mana wajah $label?';
    }
  }

  List<_Choice> get choices {
    switch (this) {
      case ToddlerGameType.colorMatch:
      case ToddlerGameType.bubblePop:
        return const [
          _Choice('Merah', color: Colors.red),
          _Choice('Kuning', color: Colors.yellow),
          _Choice('Biru', color: Colors.blue),
          _Choice('Hijau', color: Colors.green),
          _Choice('Ungu', color: Colors.purple),
          _Choice('Oranye', color: Colors.orange),
        ];
      case ToddlerGameType.shapeMatch:
        return const [
          _Choice('Lingkaran', icon: Icons.circle),
          _Choice('Persegi', icon: Icons.square),
          _Choice('Segitiga', icon: Icons.change_history),
          _Choice('Bintang', icon: Icons.star),
          _Choice('Hati', icon: Icons.favorite),
          _Choice('Segi Enam', icon: Icons.hexagon),
        ];
      case ToddlerGameType.fruitTap:
        return const [
          _Choice('Apel', emoji: '🍎'),
          _Choice('Pisang', emoji: '🍌'),
          _Choice('Stroberi', emoji: '🍓'),
          _Choice('Mangga', emoji: '🥭'),
          _Choice('Anggur', emoji: '🍇'),
          _Choice('Nanas', emoji: '🍍'),
        ];
      case ToddlerGameType.animalTap:
        return const [
          _Choice('Kucing', emoji: '🐱'),
          _Choice('Anjing', emoji: '🐶'),
          _Choice('Sapi', emoji: '🐮'),
          _Choice('Ayam', emoji: '🐔'),
          _Choice('Ikan', emoji: '🐟'),
          _Choice('Gajah', emoji: '🐘'),
        ];
      case ToddlerGameType.vehicleTap:
        return const [
          _Choice('Mobil', emoji: '🚗'),
          _Choice('Bus', emoji: '🚌'),
          _Choice('Kereta', emoji: '🚂'),
          _Choice('Pesawat', emoji: '✈️'),
          _Choice('Sepeda', emoji: '🚲'),
          _Choice('Kapal', emoji: '⛵'),
        ];
      case ToddlerGameType.faceTap:
        return const [
          _Choice('Senang', emoji: '😄'),
          _Choice('Sedih', emoji: '😢'),
          _Choice('Marah', emoji: '😠'),
          _Choice('Mengantuk', emoji: '😴'),
          _Choice('Terkejut', emoji: '😲'),
          _Choice('Sayang', emoji: '🥰'),
        ];
    }
  }
}

class ToddlerMiniGameHubScreen extends StatelessWidget {
  final String? childId;

  const ToddlerMiniGameHubScreen({super.key, this.childId});

  @override
  Widget build(BuildContext context) {
    return MiniGameHub(
      title: 'Mini Game Toddler',
      color: DashboardThemeProfile.defaultTheme('toddler').primaryColor,
      childId: childId,
      games: [
        for (final type in ToddlerGameType.values)
          MiniGameEntry(
            title: type.title,
            description: type.description,
            icon: type.icon,
            emoji: type.emoji,
            summaryKey: type.summaryKey,
            builder: (_) =>
                ToddlerMiniGameScreen(gameType: type, childId: childId),
          ),
        ...playMechanicEntries(toddler: true, childId: childId),
      ],
    );
  }
}

class ToddlerMiniGameScreen extends StatefulWidget {
  final ToddlerGameType gameType;
  final String? childId;

  const ToddlerMiniGameScreen({
    super.key,
    required this.gameType,
    this.childId,
  });

  @override
  State<ToddlerMiniGameScreen> createState() => _ToddlerMiniGameScreenState();
}

class _ToddlerMiniGameScreenState extends State<ToddlerMiniGameScreen> {
  static const _totalRounds = 6;
  final Color _color = DashboardThemeProfile.defaultTheme(
    'toddler',
  ).primaryColor;
  late List<_ToddlerQuestion> _rounds;
  int _roundIndex = 0;
  int _score = 0;
  int _mistakes = 0;
  int? _picked;
  bool _done = false;
  // Naik setiap kali game diulang agar jeda dari sesi lama diabaikan.
  int _session = 0;

  @override
  void initState() {
    super.initState();
    _rounds = _buildRounds();
  }

  List<_ToddlerQuestion> _buildRounds() {
    // Setiap ronde menanyakan jawaban yang berbeda.
    final answers = List<_Choice>.of(widget.gameType.choices)..shuffle();
    return answers.take(_totalRounds).map((answer) {
      final others = widget.gameType.choices
          .where((choice) => choice.label != answer.label)
          .toList()
        ..shuffle();
      final options = [answer, ...others.take(3)]..shuffle();
      return _ToddlerQuestion(
        prompt: widget.gameType.promptFor(answer.label),
        options: options,
        correctIndex: options.indexOf(answer),
      );
    }).toList();
  }

  void _answer(int index) {
    if (_done || _picked != null) return;
    final isRight = index == _rounds[_roundIndex].correctIndex;
    final session = _session;
    setState(() {
      _picked = index;
      if (isRight) {
        _score += 10;
      } else {
        _mistakes += 1;
      }
    });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted || session != _session) return;
      if (_roundIndex < _totalRounds - 1) {
        setState(() {
          _roundIndex++;
          _picked = null;
        });
      } else {
        setState(() { _done = true; });
        _saveResult();
      }
    });
  }

  Future<void> _saveResult() async {
    final stars = miniGameStars(_mistakes);
    final result = {
      'gameType': widget.gameType.name,
      'score': _score,
      'stars': stars,
      'progress': 100,
      'mistakes': _mistakes,
      'finishedAt': DateTime.now().toIso8601String(),
    };
    await MiniGameSummary.saveFinished(
      widget.gameType.summaryKey,
      score: _score,
      stars: stars,
      childId: widget.childId,
    );
    try {
      final user = widget.childId == null
          ? await BackendApiService.getCurrentUser()
          : null;
      await BackendApiService.logActivity(
        childId: widget.childId ?? user?.id,
        activityType: 'toddler_game_completed',
        value: jsonEncode(result),
      );
    } catch (_) {
      // Hasil tetap tersimpan di perangkat bila backend tidak terjangkau.
    }
  }

  void _restart() {
    setState(() {
      _session++;
      _roundIndex = 0;
      _score = 0;
      _mistakes = 0;
      _picked = null;
      _done = false;
      _rounds = _buildRounds();
    });
  }

  MiniGameOptionState _stateFor(_ToddlerQuestion question, int index) {
    if (_picked == null) return MiniGameOptionState.idle;
    if (index == question.correctIndex) return MiniGameOptionState.correct;
    if (index == _picked) return MiniGameOptionState.wrong;
    return MiniGameOptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final question = _rounds[_roundIndex];
    final answered = _picked != null;
    final isRight = _picked == question.correctIndex;
    return MiniGameShell(
      title: widget.gameType.title,
      color: _color,
      step: _roundIndex + (answered ? 1 : 0),
      totalSteps: _totalRounds,
      score: _score,
      mistakes: _mistakes,
      finished: _done,
      onRestart: _restart,
      feedback: answered ? (isRight ? 'Benar! 🎉' : 'Ini jawabannya 👆') : null,
      feedbackPositive: isRight,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              question.prompt,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          MiniGameOptionGrid(
            children: [
              for (var i = 0; i < question.options.length; i++)
                MiniGameOption(
                  state: _stateFor(question, i),
                  onTap: () => _answer(i),
                  child: _buildChoice(question.options[i], answered),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Nama pilihan baru muncul setelah dijawab supaya anak memilih dari gambarnya.
  Widget _buildChoice(_Choice choice, bool showLabel) {
    final Widget visual;
    // Semua jenis pilihan (gambar, bentuk, warna) memakai kotak 68 x 68 agar ukurannya seragam.
    if (choice.emoji != null) {
      visual = GameArt(choice.emoji!, size: 68);
    } else if (choice.icon != null) {
      visual = SizedBox(width: 68, height: 68, child: Icon(choice.icon, size: 64, color: _color));
    } else {
      final isBubble = widget.gameType == ToddlerGameType.bubblePop;
      visual = Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: choice.color,
          shape: isBubble ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isBubble ? null : BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          visual,
          const SizedBox(height: 6),
          Opacity(
            opacity: showLabel ? 1 : 0,
            child: Text(
              choice.label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice {
  final String label;
  final Color? color;
  final IconData? icon;
  final String? emoji;

  const _Choice(this.label, {this.color, this.icon, this.emoji});
}

class _ToddlerQuestion {
  final String prompt;
  final List<_Choice> options;
  final int correctIndex;

  const _ToddlerQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });
}
