import 'package:flutter/material.dart';

import '../patara/patara_ui.dart';
import '../services/backend_api_service.dart';
import '../services/input_validation_service.dart';
import 'app_entry_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _role = 'orang_tua';
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _isDelegate => _role == 'delegasi';

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; });
    try {
      await BackendApiService.registerUser(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        role: _role,
      );
      if (!mounted) return;
      // Layar awal menyesuaikan role: Orang Tua ke Beranda, Delegasi ke pengisian token.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppEntryScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      showMessage(
        context,
        BackendApiService.isConnectionIssue(error)
            ? 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.'
            : errorText(error).replaceFirst('Registrasi gagal: ', ''),
      );
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  InputDecoration _decoration(String label, IconData icon, {String? helper}) =>
      authDecoration(label, icon, helper: helper);

  /// Kekuatan password 0-3 untuk petunjuk visual; syarat wajibnya tetap minimal 8 karakter.
  int get _strength {
    final value = _password.text;
    if (value.length < 8) return 0;
    var score = 1;
    if (RegExp(r'[A-Za-z]').hasMatch(value) && RegExp(r'\d').hasMatch(value)) score++;
    if (value.length >= 12 || RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

  Widget _roleCard(String role, IconData icon, String label, String hint) {
    final selected = _role == role;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() { _role = role; }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? pataraPink.withOpacity(0.08) : const Color(0xFFF8F4F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? pataraPink : const Color(0xFFE9E1EC), width: selected ? 1.6 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: selected ? pataraPink : Colors.black45),
                    const Spacer(),
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 18,
                      color: selected ? pataraPink : Colors.black26,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(hint, style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;
    final (strengthLabel, strengthColor) = switch (strength) {
      0 => ('Belum 8 karakter', Colors.black38),
      1 => ('Cukup', pataraOrange),
      2 => ('Baik', pataraTeal),
      _ => ('Kuat', const Color(0xFF2E7D32)),
    };
    return AuthScaffold(
      showBack: true,
      title: 'Buat akun baru',
      subtitle: 'Gratis, dan hanya butuh satu menit.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Saya mendaftar sebagai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _roleCard('orang_tua', Icons.family_restroom, 'Orang Tua', 'Mengelola data anak dan laporan'),
                const SizedBox(width: 10),
                _roleCard('delegasi', Icons.volunteer_activism, 'Delegasi', 'Pengasuh yang membantu mencatat'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _isDelegate
                  ? 'Setelah mendaftar, Anda memasukkan token undangan dari Orang Tua.'
                  : 'Anda dapat mengundang Delegasi (pengasuh atau keluarga) setelah menambahkan data anak.',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Nama lengkap', Icons.person_outline),
              validator: (value) => InputValidationService.isValidName((value ?? '').trim())
                  ? null
                  : 'Nama hanya berisi huruf, minimal 2 karakter',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                'Email',
                Icons.email_outlined,
                helper: _isDelegate ? null : 'Laporan bulanan dikirim ke alamat ini.',
              ),
              validator: (value) {
                final email = (value ?? '').trim();
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                    ? null
                    : 'Masukkan alamat email yang benar';
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                _isDelegate ? 'Nomor HP' : 'Nomor HP (opsional)',
                Icons.phone_outlined,
              ),
              validator: (value) {
                final phone = (value ?? '').trim();
                if (phone.isEmpty) return _isDelegate ? 'Nomor HP wajib diisi untuk Delegasi' : null;
                return InputValidationService.isValidPhone(phone) ? null : 'Nomor HP tidak valid';
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: _decoration('Password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Sembunyikan password' : 'Tampilkan password',
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() { _showPassword = !_showPassword; }),
                ),
              ),
              validator: (value) => (value ?? '').length >= 8 ? null : 'Password minimal 8 karakter',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var level = 1; level <= 3; level++)
                  Expanded(
                    child: Container(
                      height: 5,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: strength >= level ? strengthColor : const Color(0xFFE9E1EC),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 112,
                  child: Text(
                    strengthLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: strengthColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Minimal 8 karakter. Lebih kuat bila memakai huruf, angka, dan simbol.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: !_showPassword,
              decoration: _decoration('Ulangi password', Icons.lock_outline),
              validator: (value) => value == _password.text ? null : 'Password tidak sama',
              onFieldSubmitted: (_) => _signUp(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _signUp,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Daftar', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Setelah masuk, Anda akan diminta membaca lembar persetujuan penelitian sebelum memakai aplikasi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Sudah punya akun? Masuk'),
            ),
          ],
        ),
      ),
    );
  }
}
