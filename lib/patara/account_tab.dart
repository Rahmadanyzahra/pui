import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../features/change_password_screen.dart';
import '../features/family_delegation_parent_profile_edit_screen.dart';
import '../features/login_screen.dart';
import '../services/backend_api_service.dart';
import '../services/local_notification_service.dart';
import 'delegation_screen.dart';
import 'patara_ui.dart';
import 'research_screens.dart';

/// Akun: profil, kelola Delegasi (khusus Orang Tua), dan logout.
class AccountTab extends StatefulWidget {
  final bool isDelegate;
  final String? delegateInfo;

  const AccountTab({super.key, this.isDelegate = false, this.delegateInfo});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  late Future<Map<String, dynamic>> _profile;
  int _pending = 0;
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _profile = BackendApiService.getProfile();
    // Foto profil diambil terpisah; tanpa foto, kartu profil menampilkan huruf awal nama.
    _profile
        .then((profile) async {
          final bytes = profile['photo_path'] == null ? null : Uint8List.fromList(await BackendApiService.getProfilePhotoBytes());
          if (mounted) setState(() { _photo = bytes; });
        })
        .catchError((_) {});
    if (!widget.isDelegate) {
      BackendApiService.getPendingDelegationRequestCount()
          .then((count) {
            if (mounted) setState(() { _pending = count; });
          })
          .catchError((_) {});
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(_load);
  }

  Future<void> _testNotification() async {
    try {
      if (!await LocalNotificationService.ensurePermission()) {
        if (mounted) {
          showMessage(context, 'Notifikasi belum diizinkan. Aktifkan izin notifikasi TARA di pengaturan perangkat.');
        }
        return;
      }
      await LocalNotificationService.showNotification(
        title: 'TARA',
        body: 'Notifikasi aktif. Pengingat jadwal dan pemberitahuan Delegasi akan muncul di sini.',
      );
      if (mounted) showMessage(context, 'Notifikasi percobaan dikirim.');
    } catch (_) {
      if (mounted) showMessage(context, 'Perangkat ini tidak mendukung notifikasi.');
    }
  }

  /// Menghapus akun dan seluruh data terkait setelah pengguna memasukkan ulang password.
  Future<void> _deleteAccount() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus akun?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isDelegate
                  ? 'Akun Anda dihapus permanen dan akses ke data anak dicabut. Laporan yang sudah Anda kirim tetap tersimpan di akun Orang Tua.'
                  : 'Akun Anda beserta data anak, catatan aktivitas, pertumbuhan, kesehatan, dan laporan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password Anda', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Hapus akun'),
          ),
        ],
      ),
    );
    if (password == null) return;
    if (password.isEmpty) {
      if (mounted) showMessage(context, 'Masukkan password untuk menghapus akun.');
      return;
    }
    try {
      await BackendApiService.send('DELETE', '/api/account', body: {'password': password});
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
      return;
    }
    await BackendApiService.clearSession(clearPassword: true, clearEmail: true);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Keluar dari akun?',
      message: 'Anda perlu login kembali untuk membuka data anak.',
      confirmLabel: 'Keluar',
    );
    if (!confirmed) return;
    try {
      await BackendApiService.send('POST', '/api/logout');
    } catch (_) {
      // Sesi lokal tetap dihapus walau server tidak terjangkau.
    }
    await BackendApiService.clearSession(clearPassword: true, clearEmail: true);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Ikon menu dalam kotak berwarna lembut, agar tiap menu mudah dibedakan.
  Widget _menuIcon(IconData icon, Color color) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(12)),
    child: Icon(icon, color: color, size: 22),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _profile,
          builder: (context, snapshot) {
            final profile = snapshot.data ?? const {};
            final name = (profile['full_name'] ?? '').toString();
            final email = (profile['email'] ?? BackendApiService.lastEmail ?? '').toString();
            final initial = name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();
            // Kartu profil berwarna sesuai peran: ungu-merah muda untuk Orang Tua, hijau-biru untuk Delegasi.
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isDelegate
                      ? const [Color(0xFF26A69A), Color(0xFF42A5F5)]
                      : const [Color(0xFFEC407A), Color(0xFF7E57C2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
                      image: _photo == null ? null : DecorationImage(image: MemoryImage(_photo!), fit: BoxFit.cover),
                    ),
                    child: _photo != null
                        ? null
                        : Text(
                            initial,
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Pengguna TARA' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.isDelegate ? 'Delegasi' : 'Orang Tua',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.delegateInfo != null) ...[
          const SizedBox(height: 12),
          PataraCard(child: Text(widget.delegateInfo!, style: const TextStyle(height: 1.4))),
        ],
        const SizedBox(height: 12),
        PataraCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: _menuIcon(Icons.edit_outlined, pataraBlue),
                title: const Text('Kelola profil'),
                subtitle: const Text('Nama, nomor HP, dan foto'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(const FamilyDelegationParentProfileEditScreen()),
              ),
              if (!widget.isDelegate) ...[
                const Divider(height: 1),
                ListTile(
                  leading: _menuIcon(Icons.group_outlined, pataraTeal),
                  title: const Text('Delegasi'),
                  subtitle: Text(
                    _pending > 0
                        ? '$_pending permintaan menunggu persetujuan'
                        : 'Undang, setujui, atau cabut akses pengasuh',
                  ),
                  trailing: _pending > 0
                      ? Badge(label: Text('$_pending'))
                      : const Icon(Icons.chevron_right),
                  onTap: () => _open(const DelegationScreen()),
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: _menuIcon(Icons.lock_reset_outlined, pataraPurple),
                title: const Text('Ganti password'),
                subtitle: const Text('Buat password baru untuk akun ini'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(const ChangePasswordScreen()),
              ),
              const Divider(height: 1),
              ListTile(
                leading: _menuIcon(Icons.notifications_outlined, pataraOrange),
                title: const Text('Notifikasi'),
                subtitle: const Text('Izinkan dan coba notifikasi di perangkat ini'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _testNotification,
              ),
              const Divider(height: 1),
              ListTile(
                leading: _menuIcon(Icons.verified_user_outlined, pataraTeal),
                title: const Text('Persetujuan penelitian'),
                subtitle: const Text('Baca kembali lembar persetujuan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ConsentScreen.open(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: _menuIcon(Icons.logout, pataraInk),
                title: const Text('Keluar'),
                onTap: _logout,
              ),
              const Divider(height: 1),
              ListTile(
                leading: _menuIcon(Icons.delete_forever_outlined, const Color(0xFFC62828)),
                title: const Text('Hapus akun', style: TextStyle(color: Color(0xFFC62828))),
                subtitle: const Text('Hapus akun dan data secara permanen'),
                onTap: _deleteAccount,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
