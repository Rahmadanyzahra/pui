import 'package:flutter/material.dart';
import 'app_entry_screen.dart';
import '../services/backend_api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const double _inputHeight = 54;
  static const double _buttonHeight = 48;
  static const double _headerToSubtitleGap = 8;
  static const double _subtitleToFormGap = 20;
  static const double _fieldGap = 14;
  static const double _actionGap = 16;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF4F4F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
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

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email, password, dan konfirmasi password harus diisi.',
          ),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password dan konfirmasi password tidak cocok.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await BackendApiService.register(
        email: email,
        password: password,
        role: 'parent',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registrasi berhasil!')));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppEntryScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Login'),
                          ),
                        ],
                      ),
                      const SizedBox(height: _headerToSubtitleGap),
                      const Text(
                        'Create your account to get started.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: _subtitleToFormGap),
                      SizedBox(
                        height: _inputHeight,
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration('Email'),
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
                      SizedBox(
                        height: _inputHeight,
                        child: TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: _inputDecoration('Confirm Password'),
                        ),
                      ),
                      const SizedBox(height: _actionGap),
                      SizedBox(
                        width: double.infinity,
                        height: _buttonHeight,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signUp,
                          style: _primaryButtonStyle,
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Sign Up',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
