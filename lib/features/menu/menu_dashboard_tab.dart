import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../add_child_screen.dart';
import '../dashboard_anak.dart';
import '../dashboard_baby.dart';
import '../health_tracking_screen.dart';
import '../dashboard_toddler.dart';
import '../child_dashboard_screen.dart';
import 'five_menu_shell.dart';
import '../../services/backend_api_service.dart';
import '../../services/child_profile_service.dart';
import '../../services/notification_badge_service.dart';
import '../../models/child_profile.dart';
import '../../widgets/backend_analytics_panel.dart';

class MenuDashboardTab extends StatefulWidget {
  final int? childId;
  final Color? themeColor;
  final List<String>? assignedChildren;
  final String? linkedParentUid;

  const MenuDashboardTab({
    super.key,
    this.childId,
    this.themeColor,
    this.assignedChildren,
    this.linkedParentUid,
  });

  @override
  State<MenuDashboardTab> createState() => _MenuDashboardTabState();
}

class _MenuDashboardTabState extends State<MenuDashboardTab> {
  late Future<List<ChildProfile>> _childrenFuture;
  int _selectedTabIndex = 0;

  static const List<String> _topTabLabels = [
    'Perkembangan',
    'Kesehatan',
    'Reminder',
    'AI Parenting',
    'Akun',
  ];

  static const List<IconData> _topTabIcons = [
    Icons.show_chart,
    Icons.monitor_heart_outlined,
    Icons.notifications_none,
    Icons.smart_toy_outlined,
    Icons.person_outline,
  ];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  void _loadChildren() {
    final parentRef = BackendApiService.lastEmail ?? 'backend-parent';
    _childrenFuture = ChildProfileService.getParentChildren(parentRef);
    setState(() {});
  }

  Future<void> _setPreferredLandingDashboard(String? dashboardCategory) async {
    final prefs = await SharedPreferences.getInstance();
    if (dashboardCategory == null || dashboardCategory.isEmpty) {
      await prefs.remove('preferredLandingDashboard');
    } else {
      await prefs.setString('preferredLandingDashboard', dashboardCategory);
    }
  }

  void _openFamilyDashboardPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard Keluarga',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Akses Bayi, Toddler, Balita, Anak, dan Parent dari satu tempat.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFE7F3),
                    child: Icon(
                      Icons.family_restroom,
                      color: Color(0xFFF06292),
                    ),
                  ),
                  title: const Text('Dashboard Parent'),
                  subtitle: const Text('Kelola semua anak'),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    Navigator.pop(sheetContext);
                    await _setPreferredLandingDashboard(null);
                    if (!mounted) return;
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FiveMenuShell(
                          titlePrefix: 'Parent',
                          dashboardType: 'parent',
                          initialIndex: 0,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.child_care, color: Color(0xFF4CAF50)),
                  ),
                  title: const Text('Dashboard Bayi'),
                  subtitle: const Text('Monitoring usia 0-1 tahun'),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    Navigator.pop(sheetContext);
                    await _setPreferredLandingDashboard('baby');
                    if (!mounted) return;
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => BabyDashboard(
                          umur: 1,
                          childId: widget.childId,
                          openedFromParentDashboard: true,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.child_care, color: Color(0xFF1E88E5)),
                  ),
                  title: const Text('Dashboard Anak'),
                  subtitle: const Text('Monitoring usia 6-12 tahun'),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    Navigator.pop(sheetContext);
                    await _setPreferredLandingDashboard('anak');
                    if (!mounted) return;
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChildDashboardScreen(
                          category: 'anak',
                          umur: 8,
                          childId: widget.childId,
                          openedFromParentDashboard: true,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2F1),
                    child: Icon(Icons.child_care, color: Color(0xFF00897B)),
                  ),
                  title: const Text('Dashboard Balita'),
                  subtitle: const Text('Monitoring usia 2-5 tahun'),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    Navigator.pop(sheetContext);
                    await _setPreferredLandingDashboard('balita');
                    if (!mounted) return;
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChildDashboardScreen(
                          category: 'balita',
                          umur: 4,
                          childId: widget.childId,
                          openedFromParentDashboard: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFeaturePage(BuildContext context, String title, int initialIndex) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => FiveMenuShell(
          childId: widget.childId,
          themeColor: widget.themeColor,
          titlePrefix: title,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _selectTopTab(BuildContext context, int index) {
    setState(() {
      _selectedTabIndex = index;
    });
    switch (index) {
      case 0:
        _openFeaturePage(context, 'Menu', 1);
        break;
      case 1:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => HealthTrackingScreen(
              title: 'Kesehatan Anak',
              childId: widget.childId,
              isParentContext: widget.childId == null,
            ),
          ),
        );
        break;
      case 2:
        _openFeaturePage(context, 'Menu', widget.childId == null ? 3 : 2);
        break;
      case 3:
        _openFeaturePage(context, 'Menu', 2);
        break;
      case 4:
      default:
        _openFeaturePage(context, 'Menu', widget.childId == null ? 4 : 3);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.themeColor ?? const Color(0xFFF06292);
    final hasSession = BackendApiService.lastEmail != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hi, Mom 👋',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF51375F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Parent Dashboard',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pusat monitoring aktivitas keluarga. Gunakan tab lain untuk fokus per menu.',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.notifications_none,
                            color: Color(0xFF51375F),
                          ),
                        ),
                      ),
                    ),
                    // Red badge with real-time count update
                    StreamBuilder<int>(
                      stream: NotificationBadgeService.countStream,
                      initialData: 0,
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        if (count == 0) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                count > 9 ? '9+' : count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF5F5F8),
                    hintText: 'Cari fitur atau informasi...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF9CA3AF),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF9B1B74),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _topTabLabels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final selected = index == _selectedTabIndex;
                  return GestureDetector(
                    onTap: () => _selectTopTab(context, index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? accent : const Color(0xFFF7F7FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? accent.withOpacity(0.22)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _topTabIcons[index],
                            size: 18,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _topTabLabels[index],
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF374151),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              _DashboardFeatureCard(
                icon: Icons.monitor_heart_outlined,
                title: 'Kesehatan Anak',
                subtitle: 'Pantau nutrisi, growth, dan riwayat kesehatan anak.',
                buttonLabel: 'Lihat Detail',
                color: const Color(0xFF8E24AA),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HealthTrackingScreen(
                      title: 'Kesehatan Anak',
                      childId: widget.childId,
                      isParentContext: widget.childId == null,
                    ),
                  ),
                ),
              ),
              _DashboardFeatureCard(
                icon: Icons.dashboard_customize,
                title: 'Dashboard Keluarga',
                subtitle:
                    'Lihat ringkasan aktivitas bayi, toddler, dan parent.',
                buttonLabel: 'Buka Dashboard',
                color: const Color(0xFFF06292),
                onTap: () => _openFamilyDashboardPicker(context),
              ),
              _DashboardFeatureCard(
                icon: Icons.person_add,
                title: 'Tambah Anak Manual',
                subtitle: 'Tambah bayi, toddler, balita, atau anak.',
                buttonLabel: 'Tambah Sekarang',
                color: const Color(0xFF00BCD4),
                onTap: () async {
                  final result = await Navigator.push<Object?>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddChildScreen()),
                  );
                  if (!mounted || result is! Map) return;
                  if (result['saved'] == true) {
                    setState(() {});
                    _openSavedChildDashboard(result);
                  }
                },
              ),
              _DashboardFeatureCard(
                icon: Icons.calendar_month_outlined,
                title: 'Jadwal & Reminder',
                subtitle:
                    'Atur jadwal imunisasi, kontrol, dan aktivitas penting.',
                buttonLabel: 'Lihat Jadwal',
                color: const Color(0xFFFB8C00),
                onTap: () => _openFeaturePage(
                  context,
                  'Menu',
                  widget.childId == null ? 3 : 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasSession) ...[
            _buildChildProfilesSection(
              BackendApiService.lastEmail ?? 'backend-parent',
              accent,
            ),
          ],
          _buildQuickMealsRow(),
          if (widget.childId == null) ...[
            const SizedBox(height: 14),
            _ParentGenerateTokenCard(themeColor: accent),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.16), accent.withOpacity(0.06)],
              ),
              border: Border.all(color: accent.withOpacity(0.28)),
            ),
            child: const Text(
              'Gunakan menu bawah untuk membuka fitur lengkap per kategori. '
              'Setiap tab sudah diisi dengan fitur inti yang terkait.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF37474F)),
            ),
          ),
          const SizedBox(height: 14),
          BackendAnalyticsPanel(
            title: widget.childId == null
                ? 'Dashboard Parent'
                : 'Dashboard Child',
            childId: widget.childId,
            themeColor: widget.themeColor,
            initialMenuKey: 'info',
            showMenuSelector: true,
          ),
        ],
      ),
    );
  }

  Widget _buildChildProfilesSection(String parentId, Color accent) {
    return FutureBuilder<List<ChildProfile>>(
      future: _childrenFuture,
      builder: (context, snapshot) {
        final children = snapshot.data ?? const <ChildProfile>[];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_2_outlined, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Anak Tersimpan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                  Text(
                    '${children.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _loadChildren,
                    child: Icon(Icons.refresh, color: accent, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(minHeight: 2),
              if (snapshot.hasError) ...[
                const SizedBox(height: 8),
                Text(
                  'Gagal memuat daftar anak: ${snapshot.error}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFC62828),
                  ),
                ),
              ] else if (children.isEmpty)
                const Text(
                  'Belum ada anak tersimpan. Tambah anak dulu lalu daftar ini akan muncul otomatis.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54),
                )
              else
                Column(
                  children: children.map((child) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openChildDashboard(child),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FCFF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFD7E2EE)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: _categoryColor(
                                  child.category,
                                ).withOpacity(0.18),
                                child: Icon(
                                  _categoryIcon(child.category),
                                  color: _categoryColor(child.category),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      child.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_categoryLabel(child.category)} • ${child.age} th',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Hapus anak',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Color(0xFFD32F2F),
                                    ),
                                    onPressed: () => _confirmDeleteChild(child),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.black38,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'baby':
        return Icons.child_care;
      case 'toddler':
        return Icons.toys;
      case 'balita':
        return Icons.child_care;
      case 'anak':
      default:
        return Icons.face;
    }
  }

  Future<void> _confirmDeleteChild(ChildProfile child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Anak'),
        content: Text(
          'Yakin ingin menghapus "${child.name}" dari daftar anak?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Color(0xFFD32F2F)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ChildProfileService.deleteChildProfile(child.id);
      _loadChildren();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anak "${child.name}" berhasil dihapus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus anak: $e')));
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'baby':
        return const Color(0xFF4CAF50);
      case 'toddler':
        return const Color(0xFF9C27B0);
      case 'balita':
        return const Color(0xFF26A69A);
      case 'anak':
      default:
        return const Color(0xFF1E88E5);
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'baby':
        return 'Bayi';
      case 'toddler':
        return 'Toddler';
      case 'balita':
        return 'Balita';
      case 'anak':
      default:
        return 'Anak';
    }
  }

  void _openChildDashboard(ChildProfile child) {
    final age = child.age;
    Widget dashboard;

    switch (child.category) {
      case 'baby':
        dashboard = BabyDashboard(
          umur: age,
          childId: null,
          openedFromParentDashboard: true,
        );
        break;
      case 'toddler':
        dashboard = ToddlerDashboard(
          umur: age,
          childId: null,
          openedFromParentDashboard: true,
        );
        break;
      case 'balita':
        dashboard = AnakDashboard(
          umur: age,
          childId: null,
          openedFromParentDashboard: true,
        );
        break;
      case 'anak':
      default:
        dashboard = AnakDashboard(
          umur: age,
          childId: null,
          openedFromParentDashboard: true,
        );
        break;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => dashboard));
  }

  void _openSavedChildDashboard(Map result) {
    final category = (result['category'] as String?) ?? 'anak';
    final age = (result['age'] as int?) ?? 0;

    Widget dashboard;
    switch (category) {
      case 'baby':
        dashboard = BabyDashboard(umur: age, openedFromParentDashboard: true);
        break;
      case 'toddler':
        dashboard = ToddlerDashboard(
          umur: age,
          openedFromParentDashboard: true,
        );
        break;
      case 'balita':
        dashboard = AnakDashboard(umur: age, openedFromParentDashboard: true);
        break;
      case 'anak':
      default:
        dashboard = AnakDashboard(umur: age, openedFromParentDashboard: true);
        break;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => dashboard));
  }

  Widget _buildQuickMealsRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _quickAddSchedule('Breakfast', hour: 8),
              child: const Text('Breakfast'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _quickAddSchedule('Lunch', hour: 12),
              child: const Text('Lunch'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _quickAddSchedule('Dinner', hour: 18),
              child: const Text('Dinner'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _quickAddSchedule(String title, {int hour = 8}) async {
    try {
      final scheduleDate = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        hour,
      );
      try {
        final payload = jsonEncode({
          'title': title,
          'scheduleDate': scheduleDate.toIso8601String(),
          'source': 'menu_dashboard',
        });
        if (widget.childId != null) {
          await BackendApiService.logActivity(
            childId: widget.childId,
            activityType: 'schedule',
            value: payload,
          );
        } else {
          await BackendApiService.logParentActivity(
            activityType: 'schedule',
            value: payload,
          );
        }
      } catch (e) {
        debugPrint('Warning: failed to log quick schedule to backend: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title ditambahkan')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menambah jadwal: $e')));
    }
  }
}

class _ParentGenerateTokenCard extends StatefulWidget {
  final Color themeColor;

  const _ParentGenerateTokenCard({required this.themeColor});

  @override
  State<_ParentGenerateTokenCard> createState() =>
      _ParentGenerateTokenCardState();
}

class _ParentGenerateTokenCardState extends State<_ParentGenerateTokenCard> {
  String _selectedRole = 'delegated_parent';
  bool _loading = false;
  String? _generatedToken;
  String? _error;

  Future<void> _generateToken() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await BackendApiService.generateConnectionToken(
        childRole: _selectedRole,
      );
      try {
        await BackendApiService.logParentActivity(
          activityType: 'token_generated',
          value: 'role=$_selectedRole, source=menu_dashboard_tab',
        );
      } catch (e) {
        debugPrint('Warning: failed to log token generation to backend: $e');
      }
      if (!mounted) return;
      setState(() {
        _generatedToken = token;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Token berhasil dibuat.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.themeColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Token Child',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Parent bisa membuat token untuk delegated parent.',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role akun yang akan terhubung',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: 'delegated_parent',
                child: Text('Delegasi Orang Tua'),
              ),
            ],
            onChanged: _loading
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectedRole = value);
                    }
                  },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generateToken,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.vpn_key_outlined),
              label: Text(_loading ? 'Membuat token...' : 'Generate Token'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
              ),
            ),
          ),
          if (_generatedToken != null) ...[
            const SizedBox(height: 10),
            SelectableText(
              'Token terbaru: $_generatedToken',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFC62828),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color color;
  final VoidCallback onTap;

  const _DashboardFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 320,
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2B2540),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: color.withOpacity(0.8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  backgroundColor: color.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
