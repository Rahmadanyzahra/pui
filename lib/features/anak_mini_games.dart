import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/dashboard_theme_service.dart';
import '../widgets/game_art.dart';
import '../widgets/mini_game_ui.dart';
import 'play_mechanics.dart';

enum AnakGameType { alphabetQuiz, numberCount, wordMatch, connectDots, animalName, colorName, nextNumber, oppositeWord }

extension AnakGameTypeX on AnakGameType {
  String get title {
    switch (this) {
      case AnakGameType.alphabetQuiz:
        return 'Kuis Huruf';
      case AnakGameType.numberCount:
        return 'Berhitung';
      case AnakGameType.wordMatch:
        return 'Kelompok Kata';
      case AnakGameType.connectDots:
        return 'Urutkan Angka';
      case AnakGameType.animalName:
        return 'Tebak Hewan';
      case AnakGameType.colorName:
        return 'Tebak Warna';
      case AnakGameType.nextNumber:
        return 'Angka Berikutnya';
      case AnakGameType.oppositeWord:
        return 'Lawan Kata';
    }
  }

  String get description {
    switch (this) {
      case AnakGameType.alphabetQuiz:
        return 'Pilih kata yang diawali huruf yang ditunjukkan.';
      case AnakGameType.numberCount:
        return 'Hitung gambar lalu pilih angkanya.';
      case AnakGameType.wordMatch:
        return 'Pilih kata yang termasuk dalam kelompoknya.';
      case AnakGameType.connectDots:
        return 'Ketuk angka 1 sampai 6 secara berurutan.';
      case AnakGameType.animalName:
        return 'Lihat gambarnya lalu pilih nama hewannya.';
      case AnakGameType.colorName:
        return 'Lihat warnanya lalu pilih namanya.';
      case AnakGameType.nextNumber:
        return 'Lanjutkan urutan angkanya.';
      case AnakGameType.oppositeWord:
        return 'Pilih kata yang berlawanan arti.';
    }
  }

  IconData get icon {
    switch (this) {
      case AnakGameType.alphabetQuiz:
        return Icons.text_fields;
      case AnakGameType.numberCount:
        return Icons.format_list_numbered;
      case AnakGameType.wordMatch:
        return Icons.quiz;
      case AnakGameType.connectDots:
        return Icons.linear_scale;
      case AnakGameType.animalName:
        return Icons.pets;
      case AnakGameType.colorName:
        return Icons.palette;
      case AnakGameType.nextNumber:
        return Icons.onetwothree;
      case AnakGameType.oppositeWord:
        return Icons.compare_arrows;
    }
  }

  String get emoji => switch (this) {
    AnakGameType.alphabetQuiz => '🔤',
    AnakGameType.numberCount => '🧮',
    AnakGameType.wordMatch => '🧺',
    AnakGameType.connectDots => '🔢',
    AnakGameType.animalName => '🦊',
    AnakGameType.colorName => '🎨',
    AnakGameType.nextNumber => '🚂',
    AnakGameType.oppositeWord => '🌗',
  };

  String get summaryKey => 'anak_game_${name}_summary';
}

class AnakMiniGameHubScreen extends StatelessWidget {
  final String? childId;

  const AnakMiniGameHubScreen({super.key, this.childId});

  @override
  Widget build(BuildContext context) {
    return MiniGameHub(
      title: 'Mini Game Anak',
      color: DashboardThemeProfile.defaultTheme('anak').primaryColor,
      childId: childId,
      games: [
        for (final type in AnakGameType.values)
          MiniGameEntry(
            title: type.title,
            description: type.description,
            icon: type.icon,
            emoji: type.emoji,
            summaryKey: type.summaryKey,
            builder: (_) =>
                AnakMiniGameScreen(gameType: type, childId: childId),
          ),
        ...playMechanicEntries(toddler: false, childId: childId),
      ],
    );
  }
}

class AnakMiniGameScreen extends StatefulWidget {
  final AnakGameType gameType;
  final String? childId;

  const AnakMiniGameScreen({super.key, required this.gameType, this.childId});

  @override
  State<AnakMiniGameScreen> createState() => _AnakMiniGameScreenState();
}

class _AnakMiniGameScreenState extends State<AnakMiniGameScreen> {
  static const _totalSteps = 6;
  final Color _color = DashboardThemeProfile.defaultTheme('anak').primaryColor;
  late List<_AnakQuestion> _questions;
  late List<int> _dots;
  int _stepIndex = 0;
  int _score = 0;
  int _mistakes = 0;
  String? _picked;
  int? _wrongDot;
  bool _done = false;
  // Naik setiap kali game diulang agar jeda dari sesi lama diabaikan.
  int _session = 0;

  bool get _isDots => widget.gameType == AnakGameType.connectDots;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    _questions = _isDots ? const [] : _buildQuestions(widget.gameType);
    _dots = List.generate(_totalSteps, (index) => index + 1)..shuffle();
  }

  void _answer(String value) {
    if (_done || _picked != null) return;
    final isRight = value == _questions[_stepIndex].correctValue;
    final session = _session;
    setState(() {
      _picked = value;
      if (isRight) {
        _score += 10;
      } else {
        _mistakes += 1;
      }
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted || session != _session) return;
      if (_stepIndex < _totalSteps - 1) {
        setState(() {
          _stepIndex++;
          _picked = null;
        });
      } else {
        _finish();
      }
    });
  }

  void _dotTapped(int value) {
    if (_done || value <= _stepIndex) return;
    if (value == _stepIndex + 1) {
      setState(() {
        _score += 10;
        _stepIndex++;
        _wrongDot = null;
      });
      if (_stepIndex >= _totalSteps) _finish();
      return;
    }
    final session = _session;
    setState(() {
      _mistakes += 1;
      _wrongDot = value;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || session != _session || _wrongDot != value) return;
      setState(() { _wrongDot = null; });
    });
  }

  void _finish() {
    setState(() { _done = true; });
    _saveResult();
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
        activityType: 'anak_game_completed',
        value: jsonEncode(result),
      );
    } catch (_) {
      // Hasil tetap tersimpan di perangkat bila backend tidak terjangkau.
    }
  }

  void _restart() {
    setState(() {
      _session++;
      _stepIndex = 0;
      _score = 0;
      _mistakes = 0;
      _picked = null;
      _wrongDot = null;
      _done = false;
      _prepare();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? feedback;
    final bool positive;
    if (_isDots) {
      positive = _wrongDot == null;
      feedback = _wrongDot != null
          ? 'Belum, cari angka ${_stepIndex + 1}'
          : 'Ketuk angka ${min(_stepIndex + 1, _totalSteps)}';
    } else {
      positive = _picked == _questions[_stepIndex].correctValue;
      feedback = _picked == null
          ? null
          : (positive ? 'Benar! 🎉' : 'Belum tepat');
    }
    return MiniGameShell(
      title: widget.gameType.title,
      color: _color,
      step: _isDots ? _stepIndex : _stepIndex + (_picked != null ? 1 : 0),
      totalSteps: _totalSteps,
      score: _score,
      mistakes: _mistakes,
      finished: _done,
      onRestart: _restart,
      feedback: feedback,
      feedbackPositive: positive,
      child: _isDots ? _buildDots() : _buildQuestion(_questions[_stepIndex]),
    );
  }

  Widget _buildPrompt(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildDots() {
    return Column(
      children: [
        _buildPrompt('Ketuk angka dari 1 sampai $_totalSteps secara berurutan'),
        MiniGameOptionGrid(
          columns: 3,
          childAspectRatio: 1,
          children: [
            for (final value in _dots)
              MiniGameOption(
                state: value <= _stepIndex
                    ? MiniGameOptionState.correct
                    : value == _wrongDot
                    ? MiniGameOptionState.wrong
                    : MiniGameOptionState.idle,
                onTap: () => _dotTapped(value),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestion(_AnakQuestion question) {
    return Column(
      children: [
        _buildPrompt(question.prompt),
        if (question.visual != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            // Soal bergambar (hewan, buah, warna) memakai gambar; huruf dan angka tetap berupa teks.
            child: question.visual!.runes.first > 0x2000
                ? GameArtRow(question.visual!, size: question.visual!.contains(' ') ? 44 : 96)
                : Text(
                    question.visual!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: question.visual!.length == 1 ? 72 : 36,
                      fontWeight: FontWeight.w800,
                      color: _color,
                    ),
                  ),
          ),
        MiniGameOptionGrid(
          childAspectRatio: 2.2,
          children: [
            for (final option in question.options)
              MiniGameOption(
                state: _picked == null
                    ? MiniGameOptionState.idle
                    : option == question.correctValue
                    ? MiniGameOptionState.correct
                    : option == _picked
                    ? MiniGameOptionState.wrong
                    : MiniGameOptionState.idle,
                onTap: () => _answer(option),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    option,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AnakQuestion {
  final String prompt;
  final String? visual;
  final List<String> options;
  final String correctValue;

  const _AnakQuestion({
    required this.prompt,
    required this.options,
    required this.correctValue,
    this.visual,
  });
}

const _alphabetWords = [
  'Apel',
  'Buku',
  'Cicak',
  'Donat',
  'Elang',
  'Foto',
  'Gajah',
  'Hutan',
];

const _wordGroups = {
  'Alat tulis': ['Pensil', 'Pulpen', 'Penghapus', 'Penggaris'],
  'Buah': ['Jeruk', 'Apel', 'Pisang', 'Mangga'],
  'Binatang': ['Kucing', 'Anjing', 'Gajah', 'Sapi'],
  'Makanan': ['Nasi', 'Roti', 'Soto', 'Sate'],
};

const _animalNames = {
  '🐱': 'Kucing',
  '🐶': 'Anjing',
  '🐘': 'Gajah',
  '🐒': 'Monyet',
  '🐢': 'Kura-kura',
  '🦋': 'Kupu-kupu',
  '🐟': 'Ikan',
  '🐔': 'Ayam',
};

const _colorNames = {
  '🟥': 'Merah',
  '🟦': 'Biru',
  '🟩': 'Hijau',
  '🟨': 'Kuning',
  '🟧': 'Oranye',
  '🟪': 'Ungu',
  '🟫': 'Cokelat',
  '⬛': 'Hitam',
};

const _opposites = {
  'Besar': 'Kecil',
  'Panas': 'Dingin',
  'Tinggi': 'Pendek',
  'Siang': 'Malam',
  'Naik': 'Turun',
  'Buka': 'Tutup',
  'Banyak': 'Sedikit',
  'Cepat': 'Lambat',
};

/// Soal "gambar atau kata -> pilih pasangannya" dari sebuah tabel pasangan.
List<_AnakQuestion> _pairQuestions(Map<String, String> pairs, int total, String Function(String key) prompt, {bool showKey = true}) {
  final keys = pairs.keys.toList()..shuffle();
  return keys.take(total).map((key) {
    final answer = pairs[key]!;
    final others = pairs.values.where((value) => value != answer).toList()..shuffle();
    return _AnakQuestion(
      prompt: prompt(key),
      visual: showKey ? key : null,
      options: [answer, ...others.take(3)]..shuffle(),
      correctValue: answer,
    );
  }).toList();
}

/// Enam soal dengan jawaban yang tidak berulang dalam satu sesi.
List<_AnakQuestion> _buildQuestions(AnakGameType type) {
  const total = 6;
  switch (type) {
    case AnakGameType.alphabetQuiz:
      final answers = List<String>.of(_alphabetWords)..shuffle();
      return answers.take(total).map((answer) {
        final others = _alphabetWords.where((word) => word != answer).toList()
          ..shuffle();
        return _AnakQuestion(
          prompt: 'Kata mana yang diawali huruf ini?',
          visual: answer[0],
          options: [answer, ...others.take(3)]..shuffle(),
          correctValue: answer,
        );
      }).toList();
    case AnakGameType.numberCount:
      const values = [3, 4, 5, 6, 7, 8];
      final targets = List<int>.of(values)..shuffle();
      return targets.take(total).map((target) {
        final others = values.where((value) => value != target).toList()
          ..shuffle();
        return _AnakQuestion(
          prompt: 'Ada berapa semangka?',
          visual: List.filled(target, '🍉').join(' '),
          options: ([target, ...others.take(3)]..shuffle())
              .map((value) => '$value')
              .toList(),
          correctValue: '$target',
        );
      }).toList();
    case AnakGameType.wordMatch:
      final random = Random();
      final groups = _wordGroups.keys.toList();
      final used = <String>{};
      return List.generate(total, (index) {
        final group = groups[index % groups.length];
        final candidates = _wordGroups[group]!
            .where((word) => !used.contains(word))
            .toList();
        final answer = candidates[random.nextInt(candidates.length)];
        used.add(answer);
        final others = _wordGroups.entries
            .where((entry) => entry.key != group)
            .expand((entry) => entry.value)
            .toList()
          ..shuffle();
        return _AnakQuestion(
          prompt: 'Mana yang termasuk "$group"?',
          options: [answer, ...others.take(3)]..shuffle(),
          correctValue: answer,
        );
      })..shuffle();
    case AnakGameType.connectDots:
      return const [];
    case AnakGameType.animalName:
      return _pairQuestions(_animalNames, total, (_) => 'Hewan apa ini?');
    case AnakGameType.colorName:
      return _pairQuestions(_colorNames, total, (_) => 'Warna apa ini?');
    case AnakGameType.oppositeWord:
      return _pairQuestions(_opposites, total, (word) => 'Apa lawan kata "$word"?', showKey: false);
    case AnakGameType.nextNumber:
      final starts = [1, 2, 3, 4, 5, 6]..shuffle();
      return starts.take(total).map((start) {
        final answer = start + 3;
        final others = [answer - 2, answer + 1, answer + 2]..shuffle();
        return _AnakQuestion(
          prompt: 'Angka berapa selanjutnya?',
          visual: '$start  ${start + 1}  ${start + 2}  ?',
          options: ([answer, ...others]..shuffle()).map((value) => '$value').toList(),
          correctValue: '$answer',
        );
      }).toList();
  }
}
