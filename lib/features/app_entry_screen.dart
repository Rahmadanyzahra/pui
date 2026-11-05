import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import '../services/role_validation_service.dart';
import 'change_password_screen.dart';
import 'onboarding_screen.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  late Future<BackendUser?> _userFuture;
  bool _mustChangePassword = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser();
  }

  Future<BackendUser?> _loadUser() async {
    await BackendApiService.initialize();
    // Selama pemeliharaan, layar pemeliharaan tampil di atas (main.dart) dan sesi tidak disentuh;
    // pemuatan akun dilanjutkan setelah admin mematikannya.
    while (await BackendApiService.checkMaintenance()) {
      await Future<void>.delayed(const Duration(seconds: 15));
    }
    await BackendApiService.tryAutoRelogin();
    _mustChangePassword = await BackendApiService.needsPasswordChange();
    final user = await BackendApiService.getCurrentUser();
    // Perkenalan hanya untuk yang belum masuk dan belum pernah melihatnya di perangkat ini.
    _showOnboarding = user == null && !await onboardingSeen();
    return user;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BackendUser?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_showOnboarding) {
          return OnboardingScreen(onDone: () => setState(() { _showOnboarding = false; }));
        }

        // Masuk dengan password sementara lalu aplikasi ditutup sebelum password baru dibuat.
        if (snapshot.data != null && _mustChangePassword) {
          return const ChangePasswordScreen(mustChange: true);
        }
        return RoleValidationService.buildHomeForUser(snapshot.data);
      },
    );
  }
}
