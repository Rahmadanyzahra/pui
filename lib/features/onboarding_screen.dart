import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../patara/patara_ui.dart';

/// Kunci penanda bahwa layar perkenalan sudah pernah dilihat di perangkat ini.
const onboardingSeenKey = 'tara_onboarding_seen';

Future<bool> onboardingSeen() async => (await SharedPreferences.getInstance()).getBool(onboardingSeenKey) ?? false;

class _Slide {
  final String title;
  final String text;
  final Color color;
  final List<IconData> icons;

  const _Slide(this.title, this.text, this.color, this.icons);
}

const _slides = [
  _Slide(
    'Catat keseharian si kecil',
    'Makan, tidur, bermain, mood, dan tantrum tercatat rapi. TARA merangkumnya menjadi pola yang mudah dipahami.',
    pataraPink,
    [Icons.restaurant, Icons.bedtime, Icons.toys, Icons.sentiment_satisfied_alt],
  ),
  _Slide(
    'Libatkan pengasuh dengan tenang',
    'Nenek atau pengasuh ikut mencatat dengan foto bukti, lalu Anda yang memutuskan laporannya sesuai atau tidak.',
    pataraPurple,
    [Icons.family_restroom, Icons.photo_camera, Icons.verified, Icons.notifications_active],
  ),
  _Slide(
    'Tanya AI, selesaikan misi',
    'Ceritakan kegiatan anak ke AI Chat untuk dijadikan catatan, dan kumpulkan misi harian agar pencatatan tetap teratur.',
    pataraOrange,
    [Icons.smart_toy, Icons.local_fire_department, Icons.emoji_events, Icons.chat_bubble],
  ),
];

/// Perkenalan tiga halaman yang tampil sekali, sebelum layar masuk.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduceMotion && !_float.isAnimating) _float.repeat();
  }

  @override
  void dispose() {
    _float.dispose();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingSeenKey, true);
    widget.onDone();
  }

  bool _moving = false;

  // Ketukan kedua selama halaman masih bergeser diabaikan, supaya halaman terakhir tidak terlewat.
  Future<void> _next() async {
    if (_moving) return;
    if (_page == _slides.length - 1) {
      await _finish();
      return;
    }
    _moving = true;
    try {
      await _pages.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    } finally {
      _moving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    final color = _slides[_page].color;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6FA),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (page) => setState(() { _page = page; }),
                itemBuilder: (context, index) => _SlideView(slide: _slides[index], float: _float),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? color : color.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: last ? 0 : 1,
                      child: OutlinedButton(
                        onPressed: last ? null : _finish,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: pataraInk,
                          side: BorderSide(color: color.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Lewati'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(last ? 'Mulai' : 'Lanjut', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final Animation<double> float;

  const _SlideView({required this.slide, required this.float});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth * 0.78, constraints.maxHeight * 0.55);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SoftEntrance(offset: 24, child: _Illustration(slide: slide, float: float, size: size)),
              const SizedBox(height: 36),
              SoftEntrance(
                duration: const Duration(milliseconds: 450),
                child: Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xFF2D2140)),
                ),
              ),
              const SizedBox(height: 12),
              SoftEntrance(
                duration: const Duration(milliseconds: 600),
                child: Text(
                  slide.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14.5, height: 1.5, color: pataraInk),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Maskot TARA di tengah lingkaran lembut, dikelilingi ikon fitur yang melayang naik-turun.
class _Illustration extends StatelessWidget {
  final _Slide slide;
  final Animation<double> float;
  final double size;

  const _Illustration({required this.slide, required this.float, required this.size});

  // Posisi kiri-atas tiap ikon (satuan lebar ilustrasi); ikon selebar 0,2 sehingga tetap di dalam bingkai.
  static const _spots = [Offset(0.04, 0.16), Offset(0.76, 0.08), Offset(0.0, 0.66), Offset(0.78, 0.62)];

  @override
  Widget build(BuildContext context) {
    final chip = size * 0.2;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: float,
        builder: (context, _) {
          final t = float.value * 2 * math.pi;
          return Stack(
            children: [
              Center(
                child: Container(
                  width: size * 0.82,
                  height: size * 0.82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [slide.color.withOpacity(0.28), slide.color.withOpacity(0.06)]),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, math.sin(t) * 6),
                  child: Image.asset('asset/image/tara_mascot.png', width: size * 0.56, height: size * 0.56),
                ),
              ),
              for (var i = 0; i < slide.icons.length; i++)
                Positioned(
                  left: _spots[i].dx * size,
                  top: _spots[i].dy * size + math.sin(t + i * 1.6) * 7,
                  child: Container(
                    width: chip,
                    height: chip,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(chip * 0.32),
                      boxShadow: [BoxShadow(color: slide.color.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Icon(slide.icons[i], color: slide.color, size: chip * 0.52),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
