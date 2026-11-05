import 'package:flutter/material.dart';

import '../widgets/game_art.dart';

const pataraPink = Color(0xFFF06292);
const pataraInk = Color(0xFF37474F);
const pataraPurple = Color(0xFF7E57C2);
const pataraTeal = Color(0xFF26A69A);
const pataraOrange = Color(0xFFFB8C00);
const pataraBlue = Color(0xFF42A5F5);

const pataraGradient = LinearGradient(
  colors: [Color(0xFFF06292), Color(0xFFBA68C8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Logo TARA (maskot robot merah muda) dalam bingkai putih membulat.
class PataraLogo extends StatelessWidget {
  final double size;

  const PataraLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset('asset/image/tara_logo.png', fit: BoxFit.contain),
      ),
    );
  }
}

/// Kolom isian bergaya sama untuk layar masuk dan daftar.
InputDecoration authDecoration(String label, IconData icon, {Widget? suffix, String? helper}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 2,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: const Color(0xFFF8F4F9),
    border: border(Colors.transparent, 0),
    enabledBorder: border(const Color(0xFFE9E1EC), 1),
    focusedBorder: border(pataraPink, 1.6),
  );
}

/// Kerangka layar masuk dan daftar: kepala bergradasi dengan logo, lalu kartu formulir di atasnya.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBack;
  final Widget child;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget bubble(double size, double opacity) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white.withOpacity(opacity), shape: BoxShape.circle),
    );
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEC407A), Color(0xFFAB47BC), Color(0xFF5C6BC0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(right: -50, top: -30, child: bubble(190, 0.10)),
                    Positioned(left: -40, bottom: -60, child: bubble(160, 0.08)),
                    Positioned(right: 60, bottom: 30, child: bubble(54, 0.10)),
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, top + (showBack ? 4 : 28), 24, 72),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showBack)
                            Transform.translate(
                              offset: const Offset(-12, 0),
                              child: const BackButton(color: Colors.white),
                            ),
                          Row(
                            children: [
                              const PataraLogo(size: 62),
                              const SizedBox(width: 12),
                              const Text(
                                'TARA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800, height: 1.2),
                          ),
                          const SizedBox(height: 6),
                          Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF7B1FA2).withOpacity(0.12), blurRadius: 28, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kepala halaman dengan warna dan ikon sesuai bagian aplikasi, agar tiap bagian mudah dibedakan.
PreferredSizeWidget sectionAppBar(
  String title,
  Color color, {
  IconData? icon,
  List<Widget>? actions,
  bool automaticallyImplyLeading = true,
}) {
  final hsl = HSLColor.fromColor(color);
  final start = hsl.withLightness((hsl.lightness - 0.07).clamp(0.0, 1.0)).toColor();
  final end = hsl.withHue((hsl.hue + 28) % 360).toColor();
  const radius = BorderRadius.vertical(bottom: Radius.circular(22));
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: radius),
    actions: actions,
    flexibleSpace: ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [start, end], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          Positioned(
            right: -30,
            top: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), shape: BoxShape.circle),
            ),
          ),
          Positioned(
            right: 90,
            bottom: -60,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    ),
    title: Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

/// Warna kepala halaman anak menurut kelompok usia, supaya tiap kelompok mudah dikenali.
List<Color> ageThemeColors(String category) => switch (category) {
  'baby' => const [Color(0xFF0288D1), Color(0xFF26A69A)],
  'toddler' => const [Color(0xFFF57C00), Color(0xFFEC407A)],
  _ => const [Color(0xFF5E35B1), Color(0xFF1E88E5)],
};

/// Latar kepala halaman anak: gradasi sesuai kelompok usia dengan hiasan gelembung, awan, dan bintang.
class ChildHeaderBackground extends StatelessWidget {
  final String category;
  final Widget child;

  const ChildHeaderBackground({super.key, required this.category, required this.child});

  @override
  Widget build(BuildContext context) {
    Widget bubble(double size, double opacity) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white.withOpacity(opacity), shape: BoxShape.circle),
    );
    Widget sticker(IconData icon, double size, double opacity) =>
        Icon(icon, size: size, color: Colors.white.withOpacity(opacity));
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ageThemeColors(category),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(right: -50, top: -40, child: bubble(190, 0.10)),
          Positioned(right: 70, bottom: -70, child: bubble(150, 0.08)),
          Positioned(left: -40, bottom: -50, child: bubble(140, 0.10)),
          Positioned(right: 24, bottom: 26, child: sticker(Icons.cloud, 54, 0.22)),
          Positioned(right: 92, bottom: 78, child: sticker(Icons.star_rounded, 26, 0.35)),
          Positioned(right: 36, bottom: 104, child: sticker(Icons.star_rounded, 16, 0.30)),
          Positioned(right: 150, bottom: 34, child: sticker(Icons.favorite, 18, 0.22)),
          child,
        ],
      ),
    );
  }
}

const _mascots = ['🦁', '🐰', '🐱', '🐘', '🐼', '🐻', '🦊', '🐥', '🐠', '🍓', '🍎', '🍉'];
const _mascotColors = [
  Color(0xFFFFE0B2),
  Color(0xFFF8BBD0),
  Color(0xFFD1C4E9),
  Color(0xFFB3E5FC),
  Color(0xFFC8E6C9),
  Color(0xFFFFF9C4),
];

/// Karakter hewan atau buah yang tetap sama untuk satu anak.
// Dihitung sendiri (FNV-1a) karena String.hashCode berbeda antara aplikasi HP dan browser,
// sehingga anak yang sama bisa mendapat karakter yang berbeda.
int _stableHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String mascotFor(String seed) => _mascots[_stableHash(seed) % _mascots.length];
Color mascotColorFor(String seed) => _mascotColors[_stableHash(seed) % _mascotColors.length];

/// Karakter kartun beranimasi (melompat pelan dan bergoyang) untuk tampilan anak.
class KidMascot extends StatefulWidget {
  final String emoji;
  final double size;
  final Color? background;

  const KidMascot({super.key, required this.emoji, this.size = 64, this.background});

  @override
  State<KidMascot> createState() => _KidMascotState();
}

class _KidMascotState extends State<KidMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Karakter diam bila pengguna mematikan animasi di pengaturan aksesibilitas.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.background ?? Colors.white.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Transform.translate(
            offset: Offset(0, -widget.size * 0.07 * t),
            child: Transform.rotate(angle: (t - 0.5) * 0.16, child: child),
          );
        },
        child: GameArt(widget.emoji, size: widget.size * 0.68),
      ),
    );
  }
}

/// Ubin menu berwarna: ikon dalam kotak lembut, judul, dan keterangan singkat.
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PataraCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color.withOpacity(0.7)),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

String errorText(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

const _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String two(int value) => value.toString().padLeft(2, '0');
String formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';
String formatTime(DateTime date) => '${two(date.hour)}.${two(date.minute)}';
String formatMonth(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.year}';
String monthKey(DateTime date) => '${date.year}-${two(date.month)}';
String formatDuration(int minutes) => [
  if (minutes >= 60) '${minutes ~/ 60} jam',
  if (minutes % 60 > 0 || minutes == 0) '${minutes % 60} mnt',
].join(' ');

/// Durasi beserta asal buktinya: dihitung timer server atau hanya diisi manual.
/// String kosong bila durasi tidak dicatat.
String durationEvidence(int? minutes, String? source, {DateTime? startedAt, DateTime? endedAt}) {
  if (minutes == null) return '';
  if (source != 'timer') return 'Durasi ${formatDuration(minutes)} (diisi manual, tidak terverifikasi)';
  final span = startedAt != null && endedAt != null ? ', ${formatTime(startedAt)}–${formatTime(endedAt)}' : '';
  return 'Durasi ${formatDuration(minutes)} (timer server$span)';
}

/// Animasi masuk yang halus: isi memudar muncul sambil naik sedikit. Berjalan sekali saat pertama tampil.
class SoftEntrance extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double offset;

  const SoftEntrance({super.key, required this.child, this.duration = const Duration(milliseconds: 320), this.offset = 14});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: child),
      ),
    );
  }
}

/// Memudarkan isi tab setiap kali tab berganti, tanpa membuat ulang isinya (keadaan tiap tab tetap tersimpan).
class TabFade extends StatefulWidget {
  final int index;
  final Widget child;

  const TabFade({super.key, required this.index, required this.child});

  @override
  State<TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 240), value: 1);
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(_fade);

  @override
  void didUpdateWidget(TabFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
  }
}

class PataraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const PataraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftEntrance(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF06292).withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(gradient: pataraGradient, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: pataraInk,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: pataraPink.withOpacity(0.7)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.4),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Menampilkan hasil sebuah Future dengan keadaan memuat dan gagal yang seragam.
class AsyncView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;

  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyView(
            icon: Icons.cloud_off,
            title: 'Data belum dapat dimuat',
            message: errorText(snapshot.error!),
            actionLabel: 'Coba lagi',
            onAction: onRetry,
          );
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;

  const StatTile({super.key, required this.label, required this.value});

  static final _number = RegExp(r'^(\d+)(.*)$', dotAll: true);

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: pataraPink);
    // Angka di awal nilai (mis. "44" atau "6×") dihitung naik dari 0; nilai lain cukup memudar masuk.
    final match = _number.firstMatch(value);
    final shown = match == null
        ? SoftEntrance(offset: 6, child: Text(value, style: style))
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: double.parse(match.group(1)!)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, n, _) => Text('${n.round()}${match.group(2)}', style: style),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shown,
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

class DisclaimerNote extends StatelessWidget {
  final String text;

  const DisclaimerNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
