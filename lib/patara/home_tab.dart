import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'activity_form_screen.dart';
import 'child_dashboard_screen.dart';
import 'child_form_screen.dart';
import 'delegate_recap_screen.dart';
import 'parent_shell.dart';
import 'patara_api.dart';
import 'announcement_banner.dart';
import 'child_avatar.dart';
import 'patara_ui.dart';
import 'validation_screen.dart';

/// Beranda Orang Tua: sapaan, laporan Delegasi yang perlu divalidasi, dan daftar anak.
/// Mengetuk kartu anak membuka dashboard anak tersebut.
class HomeTab extends StatefulWidget {
  final ChildrenController controller;
  final ValueChanged<int> onOpenTab;

  const HomeTab({super.key, required this.controller, required this.onOpenTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _name = '';
  int _pending = 0;
  // Kategori aktif dari server (diatur admin); null selama belum dimuat.
  Map<String, ActivityCategory>? _activeCategories;

  ChildrenController get _children => widget.controller;

  @override
  void initState() {
    super.initState();
    _children.addListener(_onChanged);
    _loadExtras();
  }

  @override
  void dispose() {
    _children.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadExtras() async {
    try {
      final profile = await BackendApiService.getProfile();
      if (mounted) setState(() { _name = (profile['full_name'] ?? '').toString(); });
    } catch (_) {
      // Sapaan tanpa nama tetap ditampilkan.
    }
    try {
      final pending = await PataraApi.pendingValidations();
      if (mounted) setState(() { _pending = pending.length; });
    } catch (_) {
      // Banner validasi hanya muncul bila datanya berhasil dimuat.
    }
    try {
      final options = await PataraApi.formOptions(refresh: true);
      if (mounted) setState(() { _activeCategories = {for (final item in options.categories) item.key: item}; });
    } catch (_) {
      // Tanpa daftar kategori, catat cepat memakai daftar bawaan; server tetap menolak kategori nonaktif.
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_children.reload(), _loadExtras()]);
  }

  Future<void> _addChild() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ChildFormScreen()),
    );
    if (saved == true) await _children.reload();
  }

  Future<void> _openChild(BackendChild child) async {
    _children.select(child.id);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChildDashboardScreen(child: child)),
    );
    if (changed == true) await _children.reload();
    await _loadExtras();
  }

  Future<void> _openValidation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ValidationScreen()),
    );
    await _loadExtras();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _name.trim().isEmpty ? '' : ', ${_name.trim()}';
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: pataraGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo$firstName 👋',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Catat keseharian si kecil dan lihat perkembangannya.',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_pending > 0) ...[
                  _buildValidationBanner(),
                  const SizedBox(height: 4),
                ],
                ..._buildChildren(),
                if (_children.children.isNotEmpty) ...[
                  // Hanya layar yang tidak punya tab sendiri; AI Chat dan Jadwal sudah ada di tab bawah.
                  const SectionTitle('Laporan Delegasi'),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.fact_check_outlined,
                          label: 'Validasi',
                          color: pataraOrange,
                          badge: _pending,
                          onTap: _openValidation,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.leaderboard_outlined,
                          label: 'Rekap Delegasi',
                          color: pataraPurple,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DelegateRecapScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationBanner() {
    return PataraCard(
      onTap: _openValidation,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: pataraOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.fact_check_outlined, color: pataraOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_pending laporan Delegasi perlu divalidasi',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Periksa lalu tandai sesuai atau tidak sesuai',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: pataraOrange),
        ],
      ),
    );
  }

  List<Widget> _buildChildren() {
    if (_children.loading && _children.children.isEmpty) {
      return const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))];
    }
    if (_children.error != null && _children.children.isEmpty) {
      return [
        SizedBox(
          height: 320,
          child: EmptyView(
            icon: Icons.cloud_off,
            title: 'Data belum dapat dimuat',
            message: _children.error!,
            actionLabel: 'Coba lagi',
            onAction: _children.reload,
          ),
        ),
      ];
    }
    if (_children.children.isEmpty) {
      return [
        SizedBox(
          height: 340,
          child: EmptyView(
            icon: Icons.child_care,
            title: 'Selamat datang di TARA',
            message: 'Tambahkan data anak terlebih dahulu untuk mulai mencatat aktivitas dan memantau perkembangannya.',
            actionLabel: 'Tambah Anak',
            onAction: _addChild,
          ),
        ),
      ];
    }
    return [
      const AnnouncementBanner(),
      const SectionTitle('Anak saya'),
      for (final child in _children.children) ...[
        _buildChildCard(child),
        const SizedBox(height: 12),
      ],
      OutlinedButton.icon(
        onPressed: _addChild,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Tambah anak'),
      ),
    ];
  }

  // Catat cepat: satu ketukan menyimpan aktivitas dengan waktu sekarang, tanpa membuka formulir.
  static const _quickLogs = {
    'baby': [
      ('menyusu', 'Menyusu', Icons.water_drop_outlined, pataraPink),
      ('popok', 'Popok', Icons.baby_changing_station, pataraTeal),
      ('tidur', 'Tidur', Icons.bedtime_outlined, pataraPurple),
      ('mandi', 'Mandi', Icons.bathtub_outlined, pataraBlue),
    ],
    'other': [
      ('makan', 'Makan', Icons.restaurant, pataraPink),
      ('tidur', 'Tidur', Icons.bedtime_outlined, pataraPurple),
      ('mandi', 'Mandi', Icons.bathtub_outlined, pataraBlue),
      ('bermain', 'Bermain', Icons.toys_outlined, pataraOrange),
    ],
  };
  final Set<String> _savingQuick = {};

  Future<void> _quickLog(BackendChild child, String category, String label) async {
    final key = '${child.id}:$category';
    if (_savingQuick.contains(key)) return;
    setState(() => _savingQuick.add(key));
    final now = DateTime.now();
    try {
      await PataraApi.saveActivity(
        childId: child.id,
        category: category,
        data: {'event_at': now.toUtc().toIso8601String(), 'description': '', 'status': 'selesai'},
      );
      if (mounted) {
        showMessage(context, '$label ${child.nama} dicatat pukul ${two(now.hour)}.${two(now.minute)}. Untuk mood atau keterangan, pakai "Lengkap".');
      }
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _savingQuick.remove(key));
    }
  }

  Future<void> _fullLog(BackendChild child) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActivityFormScreen(child: child)));
    _loadExtras();
  }

  Widget _buildQuickLog(BackendChild child) {
    // Hanya kategori yang masih aktif di panel admin, dengan nama yang diberikan admin.
    final active = _activeCategories;
    final items = [
      for (final (key, label, icon, color) in _quickLogs[child.category == 'baby' ? 'baby' : 'other']!)
        if (active == null || active.containsKey(key)) (key, active?[key]?.label ?? label, icon, color),
    ];
    Widget chip(String label, IconData icon, Color color, VoidCallback? onTap, {Key? key}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          key: key,
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 3),
                  FittedBox(child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Catat cepat (waktu sekarang)', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (key, label, icon, color) in items)
              chip(
                label,
                icon,
                color,
                _savingQuick.contains('${child.id}:$key') ? null : () => _quickLog(child, key, label),
                key: ValueKey('quick-${child.id}-$key'),
              ),
            chip('Lengkap', Icons.edit_note, pataraInk, () => _fullLog(child)),
          ],
        ),
      ],
    );
  }

  Widget _buildChildCard(BackendChild child) {
    return PataraCard(
      onTap: () => _openChild(child),
      child: Column(
        children: [
          _buildChildHeader(child),
          const Divider(height: 22),
          _buildQuickLog(child),
        ],
      ),
    );
  }

  Widget _buildChildHeader(BackendChild child) {
    return Row(
        children: [
          ChildAvatar(childId: child.id, size: 60, background: mascotColorFor(child.id)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(child.ageLabel, style: const TextStyle(color: pataraInk)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: pataraPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    child.categoryLabel,
                    style: const TextStyle(fontSize: 12, color: pataraPink, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward_ios, size: 18, color: pataraPink),
              SizedBox(height: 4),
              Text('Buka', style: TextStyle(fontSize: 11, color: pataraPink, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return PataraCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
