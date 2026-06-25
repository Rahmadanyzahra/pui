import 'dart:math';
import 'dart:ui';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ToddlerReadingModuleScreen extends StatefulWidget {
  final ValueChanged<int>? onStarsEarned;

  const ToddlerReadingModuleScreen({super.key, this.onStarsEarned});

  @override
  State<ToddlerReadingModuleScreen> createState() =>
      _ToddlerReadingModuleScreenState();
}

class _ToddlerReadingModuleScreenState
    extends State<ToddlerReadingModuleScreen> {
  int _points = 650;
  int _totalStars = 0;
  int _bestScore = 0;
  double _readingProgress = 0.0;
  bool _loading = true;
  List<_QuizQuestion> _dailyQuestions = const [];
  // final String _todayKey = DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _loadReadingStats();
  }

  Future<void> _loadReadingStats() async {
    // Gunakan ID user lokal atau dari backend jika perlu, atau random saja jika offline
    final String? uid =
        null; // TODO: Ganti dengan user id dari BackendApiService jika perlu
    final generatedIds = _generateDailyQuestionIds(uid);
    // List<String> todayQuestionIds = generatedIds;

    setState(() {
      _dailyQuestions = _resolveQuestionsByIds(generatedIds);
      _loading = false;
    });
  }

  List<String> _generateDailyQuestionIds(String? uid) {
    final now = DateTime.now();
    final accountSeed = uid?.hashCode.abs() ?? 0;
    final seed = (now.year * 10000) + (now.month * 100) + now.day + accountSeed;
    final shuffled = [..._questionBank]..shuffle(Random(seed));
    return shuffled.take(10).map((q) => q.id).toList();
  }

  List<_QuizQuestion> _resolveQuestionsByIds(List<String> ids) {
    final selected = ids
        .map((id) => _questionById[id])
        .whereType<_QuizQuestion>()
        .toList();
    if (selected.isNotEmpty) {
      return selected;
    }
    return [..._questionBank]..shuffle(Random(DateTime.now().millisecond));
  }

  // Future<void> _persistDailyQuestionIds(String uid, List<String> ids) async {
  //   // TODO: Simpan ke backend jika sudah ada endpoint, atau simpan lokal saja
  //   // Saat ini, tidak melakukan apa-apa
  // }

  @override
  Widget build(BuildContext context) {
    const pinkBg = Color(0xFFF8BBD0);
    const softWhite = Color(0xFFFFFBFD);
    const orange = Color(0xFFFFB74D);
    const deepBlue = Color(0xFF2D2A58);

    return Scaffold(
      backgroundColor: pinkBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: softWhite,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundImage: AssetImage(
                              'asset/image/logoai.png',
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Hi, Mysha',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                              color: deepBlue,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE3B4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '$_points Point',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF9A6A12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4ECFB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Menulis & Membaca',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                color: deepBlue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Terdapat ${_dailyQuestions.length} soal',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: _readingProgress,
                                minHeight: 8,
                                color: orange,
                                backgroundColor: const Color(0xFFD2D1EA),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Best: $_bestScore/${_dailyQuestions.length} | ⭐ $_totalStars',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 12,
                                    color: Color(0xFF5D5A78),
                                  ),
                                ),
                                SizedBox(
                                  height: 34,
                                  child: ElevatedButton(
                                    onPressed: _openQuiz,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE266B0),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text(
                                      'Main lagi',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Text(
                            'Kategori',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                              color: deepBlue,
                            ),
                          ),
                          Spacer(),
                          Text(
                            'Lihat semua',
                            style: TextStyle(
                              color: Color(0xFFE266B0),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.95,
                          children: [
                            _categoryCard(
                              icon: Icons.palette_rounded,
                              title: 'Mewarnai',
                              subtitle: 'Terdapat 15 soal',
                              onTap: () {},
                            ),
                            _categoryCard(
                              icon: Icons.extension_rounded,
                              title: 'Puzzle',
                              subtitle: 'Terdapat 5 soal',
                              onTap: () {},
                            ),
                            _categoryCard(
                              icon: Icons.calculate_rounded,
                              title: 'Berhitung',
                              subtitle: 'Terdapat 20 soal',
                              onTap: () {},
                            ),
                            _categoryCard(
                              icon: Icons.quiz_rounded,
                              title: 'Siapakah Aku?',
                              subtitle:
                                  'Terdapat ${_dailyQuestions.length} soal',
                              onTap: _openQuiz,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F6FA),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(Icons.home_rounded, color: Color(0xFFE266B0)),
                            Icon(
                              Icons.watch_later_outlined,
                              color: Color(0xFFC7C3D5),
                            ),
                            Icon(
                              Icons.settings_outlined,
                              color: Color(0xFFC7C3D5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _categoryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F1F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Icon(icon, color: const Color(0xFFE266B0), size: 20),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: Color(0xFF2D2A58),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFE266B0),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQuiz() async {
    if (_dailyQuestions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soal belum siap. Coba lagi sebentar.')),
      );
      return;
    }

    final result = await Navigator.of(context).push<_QuizResult>(
      MaterialPageRoute(
        builder: (_) => ToddlerQuizScreen(questions: _dailyQuestions),
      ),
    );
    if (result == null || !mounted) return;

    final int updatedStars = _totalStars + result.earnedStars;
    final int updatedPoints = _points + (result.earnedStars * 10);
    final int updatedBest = result.score > _bestScore
        ? result.score
        : _bestScore;
    final double updatedProgress = (result.score / result.total).clamp(
      0.0,
      1.0,
    );

    setState(() {
      _totalStars = updatedStars;
      _points = updatedPoints;
      _bestScore = updatedBest;
      _readingProgress = updatedProgress;
    });

    widget.onStarsEarned?.call(result.earnedStars);
    await _saveReadingStats(result);
  }

  Future<void> _saveReadingStats(_QuizResult result) async {
    // TODO: Simpan ke backend jika sudah ada endpoint, atau simpan lokal saja
    // Saat ini, tidak melakukan apa-apa
  }
}

class ToddlerQuizScreen extends StatefulWidget {
  final List<_QuizQuestion> questions;
  const ToddlerQuizScreen({super.key, required this.questions});

  @override
  State<ToddlerQuizScreen> createState() => _ToddlerQuizScreenState();
}

class _ToddlerQuizScreenState extends State<ToddlerQuizScreen> {
  int _index = 0;
  int _score = 0;
  int _earnedStars = 0;
  String? _selectedLetter;

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_index];

    return Scaffold(
      backgroundColor: const Color(0xFFF8BBD0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBFD),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _roundTopButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      Text(
                        '${_index + 1}/${widget.questions.length}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7E7A9A),
                        ),
                      ),
                      const Spacer(),
                      _roundTopButton(
                        icon: Icons.assignment_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Siapakah Aku?',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Poppins',
                      color: Color(0xFF212057),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 360),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0.10, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: Column(
                      key: ValueKey(_index),
                      children: [
                        Container(
                          width: 210,
                          height: 210,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFD08A),
                          ),
                          child: Center(
                            child: Image.asset(
                              question.imageAsset,
                              fit: BoxFit.contain,
                              width: 160,
                              height: 160,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.pets_rounded,
                                size: 90,
                                color: Color(0xFFEEA23A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _patternWord(question.answer, question.missingLetter),
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            fontFamily: 'Poppins',
                            color: Color(0xFF212057),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: question.options.map((choice) {
                            final isSelected = _selectedLetter == choice;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: SizedBox(
                                width: 78,
                                height: 72,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() => _selectedLetter = choice);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? const Color(0xFFFFB74D)
                                        : const Color(0xFFC6C2D9),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    choice,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 40,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedLetter == null
                          ? null
                          : () => _submitAnswer(question),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE266B0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Jawab',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundTopButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE266B0),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  String _patternWord(String word, String missingLetter) {
    final index = word.indexOf(missingLetter);
    if (index < 0) return word.split('').join(' ');
    final chars = word.split('');
    chars[index] = '_';
    return chars.join(' ');
  }

  Future<void> _submitAnswer(_QuizQuestion question) async {
    final isCorrect = _selectedLetter == question.missingLetter;
    if (isCorrect) {
      _score++;
      _earnedStars++;
    }

    await _showAnimatedPopup(
      barrierDismissible: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFFFBFD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFD08A),
              ),
              child: Icon(
                isCorrect
                    ? Icons.star_rounded
                    : Icons.sentiment_neutral_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCorrect ? 'Jawaban Kamu Benar!' : 'Belum Tepat, Coba Lagi!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Poppins',
                fontSize: 24,
                color: Color(0xFF1D1D55),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kamu sudah menjawab\n$_score soal dari ${widget.questions.length} soal',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Nunito',
                color: Color(0xFF5D5A78),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE266B0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Text(
                  _index < widget.questions.length - 1
                      ? 'Soal Selanjutnya'
                      : 'Lihat Hasil',
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (_index < widget.questions.length - 1) {
      setState(() {
        _index++;
        _selectedLetter = null;
      });
      return;
    }

    await _showFinalResult();
  }

  Future<void> _showFinalResult() async {
    await _showAnimatedPopup(
      barrierDismissible: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFFFBFD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              size: 54,
              color: Color(0xFFFFB74D),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quiz Selesai!',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                fontFamily: 'Poppins',
                color: Color(0xFF1D1D55),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_score dari ${widget.questions.length} soal\n⭐ +$_earnedStars bintang',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontFamily: 'Nunito'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(
                  _QuizResult(
                    score: _score,
                    total: widget.questions.length,
                    earnedStars: _earnedStars,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE266B0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: const Text('Kembali ke Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAnimatedPopup({
    required Widget child,
    bool barrierDismissible = true,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'quiz_popup',
      barrierColor: Colors.black.withOpacity(0.12),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) {
        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: child,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, dialogChild) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final bouncecurved = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeInCubic,
        );
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.20),
          end: Offset.zero,
        ).animate(curved);
        final scale = Tween<double>(
          begin: 0.92,
          end: 1.0,
        ).animate(bouncecurved);

        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 3.2 * animation.value,
            sigmaY: 3.2 * animation.value,
          ),
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: offset,
              child: ScaleTransition(scale: scale, child: dialogChild),
            ),
          ),
        );
      },
    );
  }
}

class _QuizResult {
  final int score;
  final int total;
  final int earnedStars;

  const _QuizResult({
    required this.score,
    required this.total,
    required this.earnedStars,
  });
}

class _QuizQuestion {
  final String id;
  final String imageAsset;
  final String answer;
  final String missingLetter;
  final List<String> options;

  const _QuizQuestion({
    required this.id,
    required this.imageAsset,
    required this.answer,
    required this.missingLetter,
    required this.options,
  });
}

const List<_QuizQuestion> _questionBank = [
  _QuizQuestion(
    id: 'lion_i',
    imageAsset: 'asset/image/animals/lion.png',
    answer: 'SINGA',
    missingLetter: 'I',
    options: ['A', 'I', 'E'],
  ),
  _QuizQuestion(
    id: 'cat_u',
    imageAsset: 'asset/image/animals/cat.png',
    answer: 'KUCING',
    missingLetter: 'U',
    options: ['U', 'A', 'I'],
  ),
  _QuizQuestion(
    id: 'bird_u',
    imageAsset: 'asset/image/animals/bird.png',
    answer: 'BURUNG',
    missingLetter: 'U',
    options: ['E', 'U', 'O'],
  ),
  _QuizQuestion(
    id: 'elephant_a',
    imageAsset: 'asset/image/animals/elephant.png',
    answer: 'GAJAH',
    missingLetter: 'A',
    options: ['A', 'U', 'I'],
  ),
  _QuizQuestion(
    id: 'fish_k',
    imageAsset: 'asset/image/animals/fish.png',
    answer: 'IKAN',
    missingLetter: 'K',
    options: ['K', 'T', 'R'],
  ),
  _QuizQuestion(
    id: 'rabbit_i',
    imageAsset: 'asset/image/animals/rabbit.png',
    answer: 'KELINCI',
    missingLetter: 'I',
    options: ['A', 'I', 'U'],
  ),
  _QuizQuestion(
    id: 'lion_n',
    imageAsset: 'asset/image/animals/lion.png',
    answer: 'SINGA',
    missingLetter: 'N',
    options: ['N', 'O', 'I'],
  ),
  _QuizQuestion(
    id: 'cat_g',
    imageAsset: 'asset/image/animals/cat.png',
    answer: 'KUCING',
    missingLetter: 'G',
    options: ['J', 'G', 'K'],
  ),
  _QuizQuestion(
    id: 'elephant_h',
    imageAsset: 'asset/image/animals/elephant.png',
    answer: 'GAJAH',
    missingLetter: 'H',
    options: ['M', 'H', 'T'],
  ),
  _QuizQuestion(
    id: 'bird_r',
    imageAsset: 'asset/image/animals/bird.png',
    answer: 'BURUNG',
    missingLetter: 'R',
    options: ['L', 'R', 'N'],
  ),
  _QuizQuestion(
    id: 'fish_i',
    imageAsset: 'asset/image/animals/fish.png',
    answer: 'IKAN',
    missingLetter: 'I',
    options: ['I', 'U', 'E'],
  ),
  _QuizQuestion(
    id: 'rabbit_l',
    imageAsset: 'asset/image/animals/rabbit.png',
    answer: 'KELINCI',
    missingLetter: 'L',
    options: ['L', 'N', 'M'],
  ),
  _QuizQuestion(
    id: 'lion_a',
    imageAsset: 'asset/image/animals/lion.png',
    answer: 'SINGA',
    missingLetter: 'A',
    options: ['A', 'U', 'O'],
  ),
  _QuizQuestion(
    id: 'bird_b',
    imageAsset: 'asset/image/animals/bird.png',
    answer: 'BURUNG',
    missingLetter: 'B',
    options: ['D', 'B', 'P'],
  ),
];

final Map<String, _QuizQuestion> _questionById = {
  for (final q in _questionBank) q.id: q,
};
