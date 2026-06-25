import 'package:flutter/material.dart';
import 'dashboard_anak.dart';
import 'dashboard_baby.dart';
import 'dashboard_toddler.dart';

class ChildDashboardScreen extends StatelessWidget {
  final String category;
  final int? umur;
  final int? childId;
  final bool openedFromParentDashboard;

  const ChildDashboardScreen({
    super.key,
    required this.category,
    required this.umur,
    this.childId,
    this.openedFromParentDashboard = false,
  });

  String _safeCategory() {
    if (umur == null) {
      // fallback to category from navigation
      return category;
    }
    // Mapping umur ke kategori baru
    if (umur! <= 1) {
      return 'baby';
    } else if (umur! <= 2) {
      return 'toddler';
    } else if (umur! <= 5) {
      return 'balita';
    } else if (umur! <= 12) {
      return 'anak';
    } else {
      return 'unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedCategory = _safeCategory();
    switch (resolvedCategory) {
      case 'baby':
        return BabyDashboard(
          umur: umur,
          childId: childId,
          openedFromParentDashboard: openedFromParentDashboard,
        );
      case 'toddler':
        return ToddlerDashboard(
          umur: umur,
          childId: childId,
          openedFromParentDashboard: openedFromParentDashboard,
        );
      case 'anak':
      case 'balita':
        return AnakDashboard(
          umur: umur,
          childId: childId,
          openedFromParentDashboard: openedFromParentDashboard,
        );
      default:
        return const Scaffold(
          body: Center(child: Text('Kategori dashboard tidak ditemukan.')),
        );
    }
  }
}
