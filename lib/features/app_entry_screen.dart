import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';
import 'child_app_screen.dart';
import 'login_screen.dart';
import 'menu/five_menu_shell.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  late Future<BackendUser?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser();
  }

  Future<BackendUser?> _loadUser() async {
    await BackendApiService.initialize();
    await BackendApiService.tryAutoRelogin();
    return BackendApiService.getCurrentUser();
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

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        final role = user.role.toLowerCase();
        if (role == 'parent') {
          return const FiveMenuShell(
            childId: null,
            themeColor: Color(0xFFF06292),
            titlePrefix: 'Parent',
            dashboardType: 'parent',
            initialIndex: 0,
          );
        }

        if (role == 'admin' || role == 'super_admin') {
          return const Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'Akses Super Admin',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Role super admin dikelola di web backend. Gunakan akun parent atau delegasi di aplikasi mobile.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (role == 'delegated_parent') {
          return const FiveMenuShell(
            childId: null,
            themeColor: Color(0xFFFF7043),
            titlePrefix: 'Delegasi',
            dashboardType: 'delegated_parent',
            initialIndex: 0,
          );
        }

        return const ChildAppScreen();
      },
    );
  }
}
