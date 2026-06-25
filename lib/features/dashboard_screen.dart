import 'package:flutter/material.dart';
import '../models/child.dart';
import 'dashboard_back_navigation.dart';

class DashboardScreen extends StatelessWidget {
  final Child child;
  final bool openedFromParentDashboard;

  const DashboardScreen({
    super.key,
    required this.child,
    this.openedFromParentDashboard = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${child.name} Dashboard'),
        leading: openedFromParentDashboard
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => navigateBackToParentDashboard(
                  context,
                  openedFromParentDashboard: true,
                ),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat datang di dashboard ${child.name}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Umur: ${child.age} tahun'),
            Text('Kategori: ${child.category}'),
            const SizedBox(height: 32),
            // TODO: Add age-specific widgets
            Expanded(
              child: Center(
                child: Text(
                  'Konten untuk kategori ${child.category} akan ditambahkan.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
