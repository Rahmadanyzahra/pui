import 'package:flutter/material.dart';

import '../patara/patara_ui.dart';
import '../services/backend_api_service.dart';
import 'app_entry_screen.dart';
import 'login_screen.dart';

/// Membuat password baru. Dipakai dua cara:
/// - [mustChange]: setelah masuk dengan password sementara dari email. Tidak bisa dilewati; pilihan
///   lainnya hanya keluar dari akun.
/// - dari menu Akun, untuk mengganti password seperti biasa.
class ChangePasswordScreen extends StatefulWidget {
  final bool mustChange;

  /// Password sementara yang baru saja dipakai masuk; bila ada, kolom password lama tidak ditampilkan.
  final String? temporaryPassword;

  const ChangePasswordScreen({super.key, this.mustChange = false, this.temporaryPassword});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;

  bool get _knowsCurrent => (widget.temporaryPassword ?? '').isNotEmpty;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; });
    try {
      await BackendApiService.changePassword(
        currentPassword: _knowsCurrent ? widget.temporaryPassword! : _current.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      showMessage(context, 'Password baru tersimpan.');
      if (widget.mustChange) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppEntryScreen()),
          (_) => false,
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          BackendApiService.isConnectionIssue(error)
              ? 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.'
              : errorText(error),
        );
      }
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _logout() async {
    try {
      await BackendApiService.send('POST', '/api/logout');
    } catch (_) {
      // Sesi lokal tetap dihapus walau server tidak terjangkau.
    }
    await BackendApiService.clearSession(clearPassword: true);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _passwordField(TextEditingController controller, String label, String? Function(String?) validator, {String? helper}) {
    return TextFormField(
      controller: controller,
      obscureText: !_showPassword,
      decoration: authDecoration(
        label,
        Icons.lock_outline,
        helper: helper,
        suffix: IconButton(
          tooltip: _showPassword ? 'Sembunyikan password' : 'Tampilkan password',
          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() { _showPassword = !_showPassword; }),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.mustChange,
      child: AuthScaffold(
        title: widget.mustChange ? 'Buat password baru' : 'Ganti password',
        subtitle: widget.mustChange
            ? 'Anda masuk dengan password sementara. Buat password baru agar akun tetap aman.'
            : 'Masukkan password lama, lalu buat password baru.',
        showBack: !widget.mustChange,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_knowsCurrent) ...[
                _passwordField(
                  _current,
                  widget.mustChange ? 'Password sementara dari email' : 'Password lama',
                  (value) => (value ?? '').isEmpty ? 'Isi password lama Anda' : null,
                ),
                const SizedBox(height: 14),
              ],
              _passwordField(
                _password,
                'Password baru',
                (value) => (value ?? '').length >= 8 ? null : 'Password minimal 8 karakter',
                helper: 'Minimal 8 karakter',
              ),
              const SizedBox(height: 14),
              _passwordField(
                _confirm,
                'Ulangi password baru',
                (value) => value == _password.text ? null : 'Password belum sama',
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Menyimpan...' : 'Simpan password baru', style: const TextStyle(fontSize: 16)),
                ),
              ),
              if (widget.mustChange)
                TextButton(
                  onPressed: _busy ? null : _logout,
                  child: const Text('Keluar dari akun'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
