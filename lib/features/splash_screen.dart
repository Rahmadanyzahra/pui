import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../patara/patara_ui.dart';

/// Warna badan maskot di tara_logo.png; layar peluncur Android dan iOS memakai warna yang sama
/// supaya perpindahan dari layar sistem ke splash ini tidak berkedip.
const _mascotPink = Color(0xFFFFA4C3);
const _faceInk = Color(0xFF34163A);
const _lightBackground = Color(0xFFFFF6FA);

/// Letak kepala maskot di dalam gambar tara_mascot.png (tara_logo.png tanpa latar putih), dalam satuan lebar gambar.
const _headCenterInImage = Offset(0.5, 0.512);
const _headRadiusInImage = 0.255;

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Urutan animasi: layar penuh merah muda berwajah maskot -> warna itu mengecil menjadi kepala
/// maskot -> maskot naik, lalu nama dan tagline muncul bergantian.
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _started = false;

  static const _total = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Bila pengguna mematikan animasi di pengaturan HP, langsung tampilkan keadaan akhir.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = 1;
      _timer = Timer(const Duration(milliseconds: 900), _goNext);
    } else {
      // Mulai setelah frame pertama benar-benar tampil; kalau tidak, bagian wajah sudah lewat
      // selagi Android masih menampilkan layar pembukanya sendiri.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _timer = Timer(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          _controller.forward().whenComplete(() {
            _timer = Timer(const Duration(milliseconds: 350), _goNext);
          });
        });
      });
    }
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => widget.nextScreen,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Nilai 0..1 untuk satu potongan waktu animasi, dengan kurva.
  double _phase(double begin, double end, [Curve curve = Curves.linear]) {
    final t = ((_controller.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBackground,
      body: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _buildFrame(constraints.biggest),
        ),
      ),
    );
  }

  Widget _buildFrame(Size screen) {
    final shrink = _phase(0.22, 0.48, Curves.easeInOutCubic);
    final reveal = _phase(0.44, 0.52, Curves.easeOut);
    // Lingkaran tetap utuh di belakang gambar sampai gambar terlihat penuh, baru menghilang.
    final circleFade = _phase(0.52, 0.56);
    final wobble = _phase(0.50, 0.72);
    final rise = _phase(0.58, 0.80, Curves.easeInOutCubic);
    final wash = _phase(0.60, 0.85, Curves.easeOut);

    final imageSize = math.min(screen.width * 0.52, 220.0);
    final headRadius = imageSize * _headRadiusInImage;
    final center = Offset(screen.width / 2, screen.height / 2);
    final imageCenter = center.translate(0, -screen.height * 0.12 * rise);
    final imageTopLeft = imageCenter - Offset(imageSize / 2, imageSize / 2);
    final headCenter = imageTopLeft + Offset(_headCenterInImage.dx * imageSize, _headCenterInImage.dy * imageSize);

    // Lingkaran merah muda: mulai menutupi seluruh layar, berakhir tepat sebesar kepala maskot.
    final coverRadius = math.sqrt(screen.width * screen.width + screen.height * screen.height) / 2 + 2;
    final circleRadius = _lerp(coverRadius, headRadius, shrink);
    final circleCenter = Offset.lerp(center, headCenter, shrink)!;
    final faceScale = _lerp(screen.width * 0.30, headRadius, shrink);
    // Memantul kecil lalu diam, berawal dan berakhir di ukuran yang sama dengan lingkaran.
    final popScale = 1 + 0.10 * math.sin(wobble * 2 * math.pi) * (1 - wobble);

    // Kedip sekali sebelum mengecil.
    final blinkT = _phase(0.10, 0.18);
    final blink = 1 - math.sin(blinkT * math.pi) * 0.9;

    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: wash,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFE0EC), Color(0xFFF3E5F5), Color(0xFFE3F2FD)],
                ),
              ),
            ),
          ),
        ),
        if (circleFade < 1)
          Positioned.fill(
            child: Opacity(
              opacity: 1 - circleFade,
              child: CustomPaint(
                painter: _MascotFacePainter(
                  circleCenter: circleCenter,
                  circleRadius: circleRadius,
                  faceScale: faceScale,
                  blink: blink,
                ),
              ),
            ),
          ),
        if (reveal > 0)
          Positioned(
            left: imageTopLeft.dx,
            top: imageTopLeft.dy,
            width: imageSize,
            height: imageSize,
            child: Opacity(
              opacity: reveal,
              child: Transform.scale(
                scale: popScale,
                alignment: Alignment(0, (_headCenterInImage.dy - 0.5) * 2),
                child: Image.asset('asset/image/tara_mascot.png', fit: BoxFit.contain),
              ),
            ),
          ),
        Positioned(
          left: 32,
          right: 32,
          top: imageCenter.dy + imageSize / 2 + 12,
          child: Column(
            children: [
              _staggered(
                _phase(0.70, 0.86, Curves.easeOutCubic),
                const Text(
                  'TARA',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: pataraPink, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 6),
              _staggered(
                _phase(0.76, 0.92, Curves.easeOutCubic),
                const Text(
                  'Tracking & Recording',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pataraPurple),
                ),
              ),
              const SizedBox(height: 10),
              _staggered(
                _phase(0.82, 1.0, Curves.easeOutCubic),
                const Text(
                  'Teman pintar untuk mencatat dan memantau tumbuh kembang si kecil',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: pataraInk, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _staggered(double t, Widget child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      );

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Lingkaran badan maskot dengan wajahnya: mata besar berkilau, mulut tersenyum, dan pipi merona,
/// meniru wajah di tara_mascot.png supaya pergantian ke gambar asli tidak terasa.
class _MascotFacePainter extends CustomPainter {
  final Offset circleCenter;
  final double circleRadius;
  final double faceScale;
  final double blink;

  _MascotFacePainter({
    required this.circleCenter,
    required this.circleRadius,
    required this.faceScale,
    required this.blink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(circleCenter, circleRadius, Paint()..color = _mascotPink);

    final r = faceScale;
    Offset at(double x, double y) => circleCenter + Offset(x * r, y * r);

    final blush = Paint()..color = const Color(0xFFFF7FA8).withOpacity(0.45);
    canvas.drawOval(Rect.fromCenter(center: at(-0.62, 0.10), width: r * 0.32, height: r * 0.16), blush);
    canvas.drawOval(Rect.fromCenter(center: at(0.56, 0.10), width: r * 0.32, height: r * 0.16), blush);

    final ink = Paint()..color = _faceInk;
    final shine = Paint()..color = Colors.white;
    for (final eye in [at(-0.50, -0.13), at(0.36, -0.13)]) {
      final eyeRect = Rect.fromCenter(center: eye, width: r * 0.34, height: r * 0.38 * blink);
      canvas.drawOval(eyeRect, ink);
      if (blink > 0.5) {
        canvas.drawCircle(eye + Offset(-r * 0.05, -r * 0.07 * blink), r * 0.065, shine);
        canvas.drawCircle(eye + Offset(r * 0.06, r * 0.06 * blink), r * 0.03, shine);
      }
    }

    // Mulut terbuka: setengah lingkaran gelap dengan lidah merah muda.
    final mouthRect = Rect.fromCenter(center: at(-0.07, 0.10), width: r * 0.36, height: r * 0.30);
    final mouth = Path()
      ..moveTo(mouthRect.left, mouthRect.top)
      ..lineTo(mouthRect.right, mouthRect.top)
      ..arcTo(mouthRect, 0, math.pi, false)
      ..close();
    canvas.drawPath(mouth, ink);
    canvas.save();
    canvas.clipPath(mouth);
    canvas.drawCircle(at(-0.07, 0.30), r * 0.13, Paint()..color = const Color(0xFFFF6F91));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotFacePainter old) =>
      old.circleCenter != circleCenter ||
      old.circleRadius != circleRadius ||
      old.faceScale != faceScale ||
      old.blink != blink;
}
