import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'app_entry_screen.dart';
import '../services/backend_api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double _inputHeight = 54;
  static const double _buttonHeight = 48;
  static const double _headerToSubtitleGap = 8;
  static const double _subtitleToFormGap = 20;
  static const double _fieldGap = 14;
  static const double _auxGap = 10;
  static const double _actionGap = 16;
  static const double _socialGap = 12;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaAnswerController = TextEditingController();
  bool _loading = false;
  bool _captchaLoading = false;
  BackendCaptchaChallenge? _captchaChallenge;

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF4F4F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFF06292), width: 1.3),
      ),
    );
  }

  ButtonStyle get _primaryButtonStyle => ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, _buttonHeight),
    backgroundColor: const Color(0xFFF06292),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Future<void> _loadCaptcha() async {
    setState(() => _captchaLoading = true);
    try {
      final challenge = await BackendApiService.getLoginCaptcha();
      if (!mounted) return;
      setState(() {
        _captchaChallenge = challenge;
        _captchaAnswerController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captchaChallenge = null;
      });
    } finally {
      if (mounted) setState(() => _captchaLoading = false);
    }
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final captchaAnswer = _captchaAnswerController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan password harus diisi.')),
      );
      return;
    }

    if (_captchaChallenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captcha belum dimuat. Coba muat ulang.')),
      );
      return;
    }

    // If server disabled captcha, skip requiring answer
    if (!_captchaChallenge!.disabled && captchaAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jawab captcha untuk login.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (!_captchaChallenge!.disabled) {
        await BackendApiService.login(
          email: email,
          password: password,
          captchaSessionId: _captchaChallenge!.sessionId,
          captchaAnswer: captchaAnswer,
        );
      } else {
        // captcha disabled on server; proceed without captcha fields
        await BackendApiService.login(email: email, password: password);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login berhasil!')));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppEntryScreen()),
        (_) => false,
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('captcha')) {
        await _loadCaptcha();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan email Anda untuk mengirim instruksi reset password.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Email'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Jika email terdaftar, instruksi reset akan dikirim.',
                    ),
                  ),
                );
              },
              child: const Text('Kirim'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSocialSignIn(String provider) async {
    // Simple placeholder: show an animated feedback and snackbar.
    if (!mounted) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider Sign-In belum diimplementasikan.')),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _captchaAnswerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD1C4E9),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                alignment: Alignment.center,
                color: const Color(0xFFD1C4E9),
                child: Stack(
                  children: [
                    Positioned(
                      left: -80,
                      top: -30,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: const BoxDecoration(
                          color: Colors.white60,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -40,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.9, end: 1.0),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutBack,
                            builder: (context, v, child) {
                              return Transform.scale(scale: v, child: child);
                            },
                            child: Image.asset(
                              'asset/image/PARATA (2).png',
                              width: 140,
                              height: 140,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'deeps',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const Text(
                            'BEERCAFE',
                            style: TextStyle(
                              fontSize: 20,
                              letterSpacing: 2,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Register'),
                                ),
                              ],
                            ),
                            const SizedBox(height: _headerToSubtitleGap),
                            const Text(
                              'Welcome to Patara AI. Please sign in to continue.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: _subtitleToFormGap),
                            SizedBox(
                              height: _inputHeight,
                              child: TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDecoration(
                                  'Email / Username',
                                ),
                              ),
                            ),
                            const SizedBox(height: _fieldGap),
                            SizedBox(
                              height: _inputHeight,
                              child: TextField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: _inputDecoration('Password'),
                              ),
                            ),
                            const SizedBox(height: _fieldGap),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F1FA),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(
                                    0xFFF06292,
                                  ).withOpacity(0.18),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Captcha keamanan',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _captchaLoading
                                            ? null
                                            : _loadCaptcha,
                                        child: _captchaLoading
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text('Muat ulang'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (_captchaChallenge?.disabled == true)
                                        ? 'Captcha dinonaktifkan'
                                        : (_captchaChallenge?.question ??
                                              'Captcha belum tersedia'),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (!(_captchaChallenge?.disabled == true))
                                    SizedBox(
                                      height: _inputHeight,
                                      child: TextField(
                                        controller: _captchaAnswerController,
                                        keyboardType: TextInputType.number,
                                        decoration: _inputDecoration(
                                          'Jawaban captcha',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: _auxGap),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _captchaLoading
                                    ? null
                                    : _showForgotPasswordDialog,
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                            const SizedBox(height: _socialGap),
                            SizedBox(
                              width: double.infinity,
                              height: _buttonHeight,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _signIn,
                                style: _primaryButtonStyle,
                                child: _loading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            ),
                            const SizedBox(height: _actionGap),
                            SizedBox(
                              width: double.infinity,
                              height: _buttonHeight,
                              child: ElevatedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _handleSocialSignIn('Google'),
                                style: _primaryButtonStyle,
                                icon: const Icon(Icons.g_mobiledata, size: 24),
                                label: const Text('Continue with Google'),
                              ),
                            ),
                            const SizedBox(height: _socialGap),
                            SizedBox(
                              width: double.infinity,
                              height: _buttonHeight,
                              child: ElevatedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _handleSocialSignIn('Facebook'),
                                style: _primaryButtonStyle,
                                icon: const Icon(Icons.facebook, size: 20),
                                label: const Text('Continue with Facebook'),
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
          ],
        ),
      ),
    );
  }
}
