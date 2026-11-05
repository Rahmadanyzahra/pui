import 'package:flutter/material.dart';

import '../features/join_parent_token_screen.dart';
import '../features/login_screen.dart';
import '../models/backend_connection.dart';
import '../patara/delegate_shell.dart';
import '../patara/parent_shell.dart';
import '../patara/research_screens.dart';
import 'backend_api_service.dart';

class RoleValidationService {
  RoleValidationService._();

  static String normalizeRole(String role) {
    return switch (role.trim().toLowerCase()) {
      'parent' || 'orang_tua' => 'orang_tua',
      'delegated_parent' || 'delegate' || 'delegasi' => 'delegasi',
      _ => '',
    };
  }

  static bool isParentRole(String role) {
    return normalizeRole(role) == 'orang_tua';
  }

  static bool isDelegateRole(String role) {
    return normalizeRole(role) == 'delegasi';
  }

  static Future<bool> isDelegateConnected() async {
    try {
      final status = await BackendApiService.getConnectionStatus();
      return status.approved;
    } catch (_) {
      return false;
    }
  }

  /// Layar awal sesuai role: Orang Tua, Delegasi (aktif atau belum terhubung), atau login.
  static Widget buildHomeForUser(BackendUser? user) {
    if (user == null) return const LoginScreen();
    // Orang Tua dan Delegasi menyetujui lembar persetujuan penelitian sebelum memakai aplikasi.
    if (isParentRole(user.role)) return const ConsentGate(child: ParentShell());
    if (isDelegateRole(user.role)) return const ConsentGate(child: _DelegateRoleHome());
    return const LoginScreen();
  }

  static Future<void> pushRoleBasedDashboard(
    BuildContext context, {
    required String titlePrefix,
    required Color themeColor,
    String? childId,
    int initialIndex = 0,
    bool rootNavigator = false,
  }) async {
    final user = await BackendApiService.getCurrentUser();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: rootNavigator).push(
      MaterialPageRoute<void>(builder: (_) => buildHomeForUser(user)),
    );
  }
}

class _DelegateRoleHome extends StatelessWidget {
  const _DelegateRoleHome();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BackendConnectionStatus>(
      future: BackendApiService.getConnectionStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final status = snapshot.data;
        final assignedChildId = status?.childId;
        if (status != null &&
            status.approved &&
            assignedChildId != null &&
            assignedChildId.isNotEmpty) {
          return DelegateShell(status: status);
        }

        return const JoinParentTokenScreen(roleLabel: 'Login Delegasi');
      },
    );
  }
}
