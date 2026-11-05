import 'package:flutter/material.dart';

import '../patara/patara_ui.dart';
import '../services/backend_api_service.dart';
import 'app_entry_screen.dart';
import 'change_password_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _captchaAnswer = TextEditingController();
  BackendCaptchaChallenge? _captcha;
  bool _captchaLoading = true;
  bool _serverUnreachable = false;
  bool _loading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _email.text = BackendApiService.lastEmail ?? '';
    _loadCaptcha();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _captchaAnswer.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    setState(() { _captchaLoading = true; });
    try {
      final captcha = await BackendApiService.getLoginCaptcha();
      if (!mounted) return;
      setState(() {
        _captcha = captcha;
        _serverUnreachable = false;
        _captchaAnswer.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captcha = null;
        _serverUnreachable = true;
      });
    } finally {
      if (mounted) setState(() { _captchaLoading = false; });
    }
  }

  bool get _needsCaptcha => _captcha != null && !_captcha!.disabled;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (_captcha == null) {
      showMessage(context, 'Server belum terhubung. Ketuk "Coba lagi" terlebih dahulu.');
      return;
    }
    setState(() { _loading = true; });
    try {
      final mustChange = await BackendApiService.login(
        email: _email.text.trim(),
        password: _password.text,
        captchaSessionId: _needsCaptcha ? _captcha!.sessionId : null,
        captchaAnswer: _needsCaptcha ? _captchaAnswer.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => mustChange
              ? ChangePasswordScreen(mustChange: true, temporaryPassword: _password.text)
              : const AppEntryScreen(),
        ),
        (_) => false,
      );
    } catch (error) {
      final text = errorText(error).replaceFirst('Login gagal: ', '');
      await _loadCaptcha();
      if (!mounted) return;
      showMessage(
        context,
        BackendApiService.isConnectionIssue(error)
            ? 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.'
            : text.contains('Nama, email')
            ? 'Email atau password salah.'
            : text,
      );
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  /// Alamat server hanya perlu diubah saat pengujian, jadi disembunyikan dari layar utama.
  Future<void> _openServerSettings() async {
    final controller = TextEditingController(text: BackendApiService.baseUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alamat server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Text(
              BackendApiService.backendUrlHint(),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    await BackendApiService.setBaseUrl(url);
    await _loadCaptcha();
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) =>
      authDecoration(label, icon, suffix: suffix);

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Selamat datang kembali',
      subtitle: 'Catat aktivitas dan pantau perkembangan si kecil.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Masuk ke akun Anda', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (_serverUnreachable) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Color(0xFFC62828)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.'),
                    ),
                    TextButton(onPressed: _loadCaptcha, child: const Text('Coba lagi')),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: _decoration('Email', Icons.email_outlined),
              validator: (value) =>
                  (value ?? '').trim().contains('@') ? null : 'Masukkan alamat email Anda',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.password],
              decoration: _decoration(
                'Password',
                Icons.lock_outline,
                suffix: IconButton(
                  tooltip: _showPassword ? 'Sembunyikan password' : 'Tampilkan password',
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() { _showPassword = !_showPassword; }),
                ),
              ),
              validator: (value) => (value ?? '').isEmpty ? 'Masukkan password Anda' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final email = await Navigator.of(context).push<String>(
                    MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim())),
                  );
                  // Setelah password diganti, emailnya langsung terisi dan soal verifikasi diperbarui.
                  if (email == null || !mounted) return;
                  _email.text = email;
                  _password.clear();
                  await _loadCaptcha();
                },
                child: const Text('Lupa password?'),
              ),
            ),
            if (_needsCaptcha) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _captchaAnswer,
                keyboardType: TextInputType.number,
                decoration: _decoration(
                  'Verifikasi: berapa ${_captcha!.question.replaceAll('= ?', '').trim()}?',
                  Icons.verified_user_outlined,
                  suffix: IconButton(
                    tooltip: 'Ganti soal',
                    icon: const Icon(Icons.refresh),
                    onPressed: _captchaLoading ? null : _loadCaptcha,
                  ),
                ),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Isi jawaban verifikasi' : null,
                onFieldSubmitted: (_) => _signIn(),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Masuk', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: pataraTeal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data anak hanya dapat dibuka oleh Anda dan Delegasi yang Anda setujui.',
                    style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Belum punya akun?'),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text('Daftar'),
                ),
              ],
            ),
            TextButton(
              onPressed: _openServerSettings,
              child: const Text(
                'Pengaturan server',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
