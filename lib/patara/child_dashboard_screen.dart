import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../features/anak_mini_games.dart';
import '../features/toddler_mini_games.dart';
import '../services/backend_api_service.dart';
import 'activity_form_screen.dart';
import 'activity_tab.dart';
import 'baby_care_card.dart';
import 'discovery_card.dart';
import 'experiment_card.dart';
import 'behavior_screen.dart';
import 'child_avatar.dart';
import 'child_form_screen.dart';
import 'development_screen.dart';
import 'growth_screen.dart';
import 'guidance_screen.dart';
import 'mission_card.dart';
import 'health_screen.dart';
import 'monthly_report_screen.dart';
import 'patara_api.dart';
import 'patara_ui.dart';
import 'spk_screen.dart';

class _DashboardData {
  final Map<String, dynamic> behavior;
  final Map<String, dynamic> growth;
  final Map<String, dynamic> health;
  final FormOptions options;
  final List<ActivityLog> logs;

  const _DashboardData(this.behavior, this.growth, this.health, this.options, this.logs);
}

/// Dashboard satu anak: karakter, catatan aktivitas terbaru, kesehatan dan
/// pertumbuhan, mini game sesuai usia, serta pintu masuk ke semua fitur.
/// Mengembalikan true bila data anak berubah atau dihapus.
class ChildDashboardScreen extends StatefulWidget {
  final BackendChild child;

  const ChildDashboardScreen({super.key, required this.child});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  late BackendChild _child = widget.child;
  late Future<_DashboardData> _data;
  bool _changed = false;
  // 0 = Hari ini, 1 = Tumbuh kembang, 2 = Laporan.
  int _section = 0;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_DashboardData> _load() async {
    final id = _child.id;
    final results = await Future.wait([
      PataraApi.behavior(id, 7),
      PataraApi.growth(id),
      PataraApi.health(id),
    ]);
    return _DashboardData(results[0], results[1], results[2], await PataraApi.formOptions(), await PataraApi.activityLogs(id));
  }

  void _reload() => setState(() { _data = _load(); });

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  void _openHistory() => _open(
    Scaffold(
      appBar: sectionAppBar('Aktivitas ${_child.nama}', pataraPink, icon: Icons.history),
      body: ActivityHistory(child: _child),
    ),
  );

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChildFormScreen(child: _child)),
    );
    if (saved != true) return;
    _changed = true;
    try {
      final fresh = await BackendApiService.getChild(_child.id);
      if (mounted) setState(() { _child = fresh; });
    } catch (_) {
      // Data lama tetap ditampilkan; Beranda akan memuat ulang saat kembali.
    }
  }

  /// Mengganti foto profil anak dari kamera atau galeri.
  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto dengan kamera'),
              onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (picked == null) return;
      await BackendApiService.send('PUT', '/children/${_child.id}/photo', filePath: picked.path);
      ChildAvatar.refresh(_child.id);
      _changed = true;
      if (mounted) showMessage(context, 'Foto ${_child.nama} diperbarui.');
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus data ${_child.nama}?',
      message:
          'Semua catatan aktivitas, kesehatan, pertumbuhan, perkembangan, dan akses Delegasi untuk anak ini ikut dihapus dan tidak dapat dikembalikan.',
    );
    if (!confirmed) return;
    try {
      await BackendApiService.deleteChild(_child.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    }
  }

  bool get _hasGames => _child.category == 'toddler' || _child.category == 'balita';

  @override
  Widget build(BuildContext context) {
    final gender = switch (_child.gender?.toUpperCase()) {
      'L' => 'Laki-laki',
      'P' => 'Perempuan',
      _ => 'Jenis kelamin belum diisi',
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _open(ActivityFormScreen(child: _child)),
          icon: const Icon(Icons.add),
          label: const Text('Catat aktivitas'),
        ),
        body: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: ageThemeColors(_child.category).first,
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) => switch (value) {
                      'photo' => _changePhoto(),
                      'edit' => _edit(),
                      _ => _delete(),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'photo', child: Text('Ganti foto anak')),
                      PopupMenuItem(value: 'edit', child: Text('Ubah data anak')),
                      PopupMenuItem(value: 'delete', child: Text('Hapus anak')),
                    ],
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: ChildHeaderBackground(
                    category: _child.category,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      alignment: Alignment.bottomLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Ketuk foto untuk menggantinya.
                          GestureDetector(
                            onTap: _changePhoto,
                            child: ChildAvatar(childId: _child.id, size: 84),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _child.nama,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${_child.ageLabel} • ${_child.categoryLabel}',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                Text(gender, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(pinned: true, delegate: _SectionBar(_section, (value) => setState(() { _section = value; }))),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                sliver: SliverList.list(
                  children: switch (_section) {
                    0 => _buildToday(),
                    1 => _buildGrowthSection(),
                    _ => _buildReports(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withData(Widget Function(_DashboardData data) builder) {
    return FutureBuilder<_DashboardData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PataraCard(child: LinearProgressIndicator());
        }
        if (snapshot.hasError) {
          return PataraCard(child: Text(errorText(snapshot.error!)));
        }
        return builder(snapshot.data!);
      },
    );
  }

  /// Hari ini: yang dipakai setiap hari, yaitu mencatat, melihat catatan terakhir, dan bermain.
  List<Widget> _buildToday() => [
    if (_child.category == 'baby') ...[
      BabyCareCard(child: _child),
      const SizedBox(height: 12),
    ],
    MissionCard(child: _child),
    _withData(
      (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummary(data.behavior),
          SectionTitle(
            'Aktivitas terbaru',
            trailing: TextButton(onPressed: _openHistory, child: const Text('Lihat semua')),
          ),
          _buildRecent(data.options, data.logs),
        ],
      ),
    ),
    if (_hasGames) ...[
      const SectionTitle('Zona bermain'),
      _buildPlayZone(),
    ],
  ];

  /// Tumbuh kembang: pertumbuhan, kesehatan, perkembangan, dan ide stimulasi sesuai usia.
  List<Widget> _buildGrowthSection() => [
    _withData(
      (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGrowth(data.growth),
          const SizedBox(height: 12),
          _buildHealth(data.health),
        ],
      ),
    ),
    const SizedBox(height: 12),
    MenuTile(
      icon: Icons.trending_up,
      title: 'Perkembangan',
      subtitle: 'Motorik, bahasa, sosial, kognitif',
      color: pataraOrange,
      onTap: () => _open(DevelopmentScreen(child: _child)),
    ),
    const SizedBox(height: 10),
    MenuTile(
      icon: Icons.lightbulb_outline,
      title: 'Ide Aktivitas & Gizi',
      subtitle: 'Sensori, stimulasi, dan makan sesuai usia',
      color: pataraTeal,
      onTap: () => _open(GuidanceScreen(child: _child)),
    ),
  ];

  /// Laporan: pola dari catatan, percobaan kebiasaan, dan laporan bulanan.
  List<Widget> _buildReports() => [
    DiscoveryCard(child: _child),
    const SizedBox(height: 12),
    MenuTile(
      icon: Icons.insights,
      title: 'Pola Perilaku',
      subtitle: 'Behavior tracking: mood, rewel, dan tantrum',
      color: pataraPurple,
      onTap: () => _open(BehaviorScreen(child: _child)),
    ),
    const SizedBox(height: 10),
    MenuTile(
      icon: Icons.leaderboard_outlined,
      title: 'Rekomendasi (AHP–SAW)',
      subtitle: 'Ide aktivitas paling cocok dan waktu terbaik kegiatan',
      color: pataraTeal,
      onTap: () => _open(SpkScreen(child: _child)),
    ),
    const SizedBox(height: 10),
    MenuTile(
      icon: Icons.picture_as_pdf,
      title: 'Laporan Bulanan',
      subtitle: 'Bisa diunduh kapan saja: 7 hari, 30 hari, atau per bulan',
      color: const Color(0xFFE53935),
      onTap: () => _open(MonthlyReportScreen(child: _child)),
    ),
    const SizedBox(height: 12),
    ExperimentCard(child: _child),
  ];

  Widget _cardHeader(IconData icon, Color color, String title, String action) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        Text(action, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        Icon(Icons.chevron_right, color: color, size: 20),
      ],
    );
  }

  Widget _buildGrowth(Map<String, dynamic> growth) {
    final latest = growth['latest'] as Map<String, dynamic>?;
    return PataraCard(
      onTap: () => _open(GrowthScreen(child: _child)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.monitor_weight_outlined, pataraTeal, 'Pertumbuhan', latest == null ? 'Catat' : 'Grafik'),
          const SizedBox(height: 10),
          if (latest == null)
            const Text(
              'Belum ada data berat dan tinggi badan. Catat hasil pengukuran terakhir si kecil.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            )
          else ...[
            Row(
              children: [
                Expanded(child: StatTile(label: 'Berat', value: '${formatNumber(latest['weight_kg'] as num)} kg')),
                Expanded(child: StatTile(label: 'Tinggi', value: '${formatNumber(latest['height_cm'] as num)} cm')),
                Expanded(
                  child: StatTile(
                    label: 'Lingkar kepala',
                    value: latest['head_circumference_cm'] == null
                        ? '–'
                        : '${formatNumber(latest['head_circumference_cm'] as num)} cm',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Diukur ${formatDate(DateTime.parse('${latest['measured_at']}').toLocal())}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealth(Map<String, dynamic> health) {
    final given = health['immunizations_given'] as int;
    final total = health['immunizations_total'] as int;
    final records = (health['records'] as List)
        .cast<Map<String, dynamic>>()
        .where((record) => record['record_type'] != 'imunisasi')
        .toList();
    return PataraCard(
      onTap: () => _open(HealthScreen(child: _child)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.vaccines, pataraOrange, 'Kesehatan dan imunisasi', 'Buka'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : given / total,
                    minHeight: 10,
                    color: pataraOrange,
                    backgroundColor: pataraOrange.withOpacity(0.15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$given/$total imunisasi', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            records.isEmpty
                ? 'Belum ada catatan sakit atau kunjungan dokter.'
                : 'Catatan terakhir: ${records.first['title']} (${formatDate(DateTime.parse('${records.first['record_date']}'))})',
            style: const TextStyle(fontSize: 13, color: pataraInk),
          ),
        ],
      ),
    );
  }

  Widget _buildRecent(FormOptions options, List<ActivityLog> logs) {
    if (logs.isEmpty) {
      return const PataraCard(
        child: Text(
          'Belum ada catatan aktivitas. Ketuk "Catat aktivitas" untuk memulai.',
          style: TextStyle(color: Colors.black54, height: 1.4),
        ),
      );
    }
    return PataraCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final log in logs.take(4))
            ListTile(
              dense: true,
              onTap: _openHistory,
              leading: CircleAvatar(
                backgroundColor: pataraPink.withOpacity(0.12),
                child: Icon(options.categoryIcon(log.category), color: pataraPink, size: 20),
              ),
              title: Text(
                options.categoryLabel(log.category),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                [
                  '${formatDate(log.at)} ${formatTime(log.at)}',
                  if (log.description.isNotEmpty) log.description,
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                '${moodEmoji[log.moodAfter] ?? ''}${log.fromDelegate && log.validationStatus == 'pending' ? ' ⏳' : ''}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
        ],
      ),
    );
  }

  /// Ajakan bermain bergaya ceria dengan karakter hewan; isinya menyesuaikan kelompok usia.
  Widget _buildPlayZone() {
    final toddler = _child.category == 'toddler';
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _open(
        toddler ? ToddlerMiniGameHubScreen(childId: _child.id) : AnakMiniGameHubScreen(childId: _child.id),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFF176), Color(0xFFFFB74D)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            KidMascot(emoji: toddler ? '🐥' : '🦁', size: 60, background: Colors.white.withOpacity(0.55)),
            const SizedBox(width: 8),
            KidMascot(emoji: toddler ? '🍓' : '🐘', size: 46, background: Colors.white.withOpacity(0.55)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ayo main, ${_child.nama}!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF5D4037)),
                  ),
                  Text(
                    toddler ? 'Warna, bentuk, dan buah untuk usia 1–2 tahun' : 'Huruf, angka, dan kata untuk usia 2–5 tahun',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF5D4037)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill, color: Color(0xFFE65100), size: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(Map<String, dynamic> behavior) {
    final mood = behavior['mood'] as Map<String, dynamic>;
    final tantrum = behavior['tantrum'] as Map<String, dynamic>;
    final pending = (behavior['pending_validation'] as num?)?.toInt() ?? 0;
    return PataraCard(
      onTap: () => _open(BehaviorScreen(child: _child)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.insights, pataraPurple, '7 hari terakhir', 'Pola'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: StatTile(label: 'Aktivitas', value: '${behavior['total_activities']}')),
              Expanded(child: StatTile(label: 'Tantrum', value: '${tantrum['total']}×')),
              Expanded(child: StatTile(label: 'Mood setelah', value: '${mood['after_label']}')),
            ],
          ),
          if (pending > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$pending laporan Delegasi menunggu validasi dan belum dihitung.',
              style: const TextStyle(color: pataraOrange, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pemilih bagian dashboard yang tetap terlihat saat halaman digulir.
class _SectionBar extends SliverPersistentHeaderDelegate {
  final int selected;
  final ValueChanged<int> onSelected;

  _SectionBar(this.selected, this.onSelected);

  // Tanpa ikon, supaya ketiga tulisan muat dengan ukuran huruf yang sama di layar kecil.
  static const _labels = ['Hari ini', 'Tumbuh kembang', 'Laporan'];

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: pataraPink.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            for (var index = 0; index < _labels.length; index++)
              Expanded(
                child: Material(
                  color: selected == index ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelected(index),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _labels[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected == index ? FontWeight.w800 : FontWeight.w600,
                              color: selected == index ? pataraPink : pataraInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionBar oldDelegate) => oldDelegate.selected != selected;
}
