import 'package:flutter/material.dart';

import '../ai_chat_screen.dart';
import '../../services/backend_api_service.dart';
import '../add_child_screen.dart';
import '../dashboard_anak.dart';
import '../dashboard_baby.dart';
import '../dashboard_toddler.dart';
import '../child_dashboard_screen.dart';
import '../join_parent_token_screen.dart';
import '../role_selection_screen.dart';
import '../theme_settings_screen.dart';
import 'five_menu_shell.dart';

class MenuAkunTab extends StatefulWidget {
  final int? childId;
  final Color? themeColor;

  const MenuAkunTab({super.key, this.childId, this.themeColor});

  @override
  State<MenuAkunTab> createState() => _MenuAkunTabState();
}

class _MenuAkunTabState extends State<MenuAkunTab> {
  late Future<BackendUser?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = BackendApiService.getCurrentUser();
  }

  Future<void> _refresh() async {
    setState(() {
      _userFuture = BackendApiService.getCurrentUser();
    });
    await _userFuture;
  }

  Future<void> _switchAccount() async {
    await BackendApiService.clearSession(clearPassword: true, clearEmail: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session backend dibersihkan.')),
    );
  }

  Future<void> _clearAllLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua data lokal?'),
        content: const Text(
          'Semua session, cache login, email tersimpan, dan data lokal aplikasi akan dihapus. Aksi ini tidak menghapus data di server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await BackendApiService.clearAllLocalData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua data lokal berhasil dihapus.')),
    );
  }

  Future<void> _openJoinTokenPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const JoinParentTokenScreen(roleLabel: 'Menu Akun'),
      ),
    );
    await _refresh();
  }

  Future<void> _openAiProfilePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiChatScreen(
          childId: widget.childId,
          themeColor: widget.themeColor,
        ),
      ),
    );
  }

  void _openThemePicker(bool includeParentTheme) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final types = <String>[
          if (includeParentTheme) 'parent',
          'delegated_parent',
          'baby',
          'toddler',
          'balita',
          'anak',
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: types
                .map(
                  (type) => ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text(switch (type) {
                      'parent' => 'Tema PARENT',
                      'delegated_parent' => 'Tema DELEGASI',
                      'balita' => 'Tema BALITA',
                      _ => 'Tema ${type.toUpperCase()}',
                    }),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ThemeSettingsScreen(dashboardType: type),
                        ),
                      );
                    },
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Future<void> _openRoleSelector() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const RoleSelectionScreen(openedFromParentProfile: true),
      ),
    );
    await _refresh();
  }

  Future<void> _openDashboardByRole(String role) async {
    final route = switch (role) {
      'delegated_parent' => MaterialPageRoute<void>(
        builder: (_) => const FiveMenuShell(
          childId: null,
          titlePrefix: 'Delegasi',
          dashboardType: 'delegated_parent',
          initialIndex: 0,
        ),
      ),
      'baby' => MaterialPageRoute<void>(
        builder: (_) => const BabyDashboard(umur: 1),
      ),
      'toddler' => MaterialPageRoute<void>(
        builder: (_) => const ToddlerDashboard(umur: 2),
      ),
      'balita' => MaterialPageRoute<void>(
        builder: (_) => const ChildDashboardScreen(category: 'balita', umur: 4),
      ),
      'anak' => MaterialPageRoute<void>(
        builder: (_) => const AnakDashboard(umur: 7),
      ),
      _ => null,
    };
    if (route == null) return;
    await Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.themeColor ?? const Color(0xFFF06292);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<BackendUser?>(
          future: _userFuture,
          builder: (context, snapshot) {
            final user = snapshot.data;
            final role = user?.role ?? '-';
            final email = user?.email ?? (BackendApiService.lastEmail ?? '-');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Akun Saya',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(email, style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        'Role: $role',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('AI Chat Profil'),
                  onTap: _openAiProfilePage,
                ),
                ListTile(
                  leading: const Icon(Icons.token_outlined),
                  title: const Text('Join Parent Dengan Token'),
                  onTap: _openJoinTokenPage,
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Pengaturan Tema'),
                  onTap: () => _openThemePicker(role == 'parent'),
                ),
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Pilih / Ubah Role'),
                  onTap: _openRoleSelector,
                ),
                if (role == 'parent')
                  ListTile(
                    leading: const Icon(Icons.child_care_outlined),
                    title: const Text('Tambah Anak'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AddChildScreen(),
                        ),
                      );
                    },
                  ),
                if (role != 'parent' && role != '-')
                  ListTile(
                    leading: const Icon(Icons.open_in_new_outlined),
                    title: const Text('Buka Dashboard Sesuai Role'),
                    onTap: () => _openDashboardByRole(role),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _switchAccount,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout / Ganti Akun'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _clearAllLocalData,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Clear All Data'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
