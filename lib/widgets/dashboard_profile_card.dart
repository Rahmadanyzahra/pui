import 'package:flutter/material.dart';

class DashboardProfileCard extends StatelessWidget {
  final String dashboardType;
  final Color primaryColor;

  const DashboardProfileCard({
    super.key,
    required this.dashboardType,
    required this.primaryColor,
  });

  String get emoji {
    switch (dashboardType) {
      case 'baby':
        return '👶';
      case 'toddler':
        return '🧒';
      case 'anak':
      case 'balita':
        return '👧';
      case 'remaja':
        return '👨';
      default:
        return '👤';
    }
  }

  String get title {
    switch (dashboardType) {
      case 'baby':
        return 'Bayi (0–1 tahun)';
      case 'toddler':
        return 'Toddler (1–2 tahun)';
      case 'anak':
        return 'Anak (6–12 tahun)';
      case 'balita':
        return 'Balita (3–5 tahun)';
      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$emoji $title',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pantau perkembangan dan aktivitas sehari-hari',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
