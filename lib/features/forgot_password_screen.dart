import 'package:flutter/material.dart';

import '../patara/patara_ui.dart';
import '../services/backend_api_service.dart';

/// Lupa password: server mengirim password sementara ke email akun. Pengguna masuk dengan password itu,
/// lalu aplikasi meminta password baru (lihat ChangePasswordScreen).
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sent = false;
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; });
    try {
      final data =
          await BackendApiService.requestJson('POST', '/auth/forgot-password', body: {'email': _email.text.trim()})
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _sent = true;
        _notice = '${data['message']}';
      });
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

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Lupa password',
      subtitle: 'Kami kirim password sementara ke email akun Anda.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _sent ? 'Periksa email Anda' : 'Email akun Anda',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              enabled: !_sent,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: authDecoration('Email', Icons.email_outlined),
              validator: (value) => (value ?? '').trim().contains('@') ? null : 'Masukkan alamat email Anda',
            ),
            if (_sent) ...[
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_notice!, style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4)),
                ),
              const SizedBox(height: 12),
              const Text(
                'Masuk dengan email ini dan password sementara dari email. '
                'Setelah itu aplikasi meminta Anda membuat password baru.',
                style: TextStyle(fontSize: 13.5, height: 1.4),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _busy
                    ? null
                    : _sent
                    ? () => Navigator.of(context).pop(_email.text.trim())
                    : _request,
                child: Text(
                  _busy
                      ? 'Mengirim...'
                      : _sent
                      ? 'Kembali ke halaman masuk'
                      : 'Kirim password sementara',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            if (_sent)
              TextButton(
                onPressed: _busy ? null : () => setState(() { _sent = false; }),
                child: const Text('Ganti email atau kirim lagi'),
              ),
          ],
        ),
      ),
    );
  }
}
