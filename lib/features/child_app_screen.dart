import 'package:flutter/material.dart';

import '../services/backend_api_service.dart';

class ChildAppScreen extends StatelessWidget {
  const ChildAppScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await BackendApiService.clearSession(
      clearEmail: false,
      clearPassword: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anak - Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.child_friendly,
              size: 80,
              color: Color(0xFFAB47BC),
            ),
            const SizedBox(height: 24),
            const Text(
              'Selamat datang di Ruang Anak!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Fitur untuk anak sedang dikembangkan...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
