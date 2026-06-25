import 'package:flutter/material.dart';

import 'parent_dashboard_screen.dart';

void navigateBackToParentDashboard(
  BuildContext context, {
  required bool openedFromParentDashboard,
}) {
  final navigator = Navigator.of(context);
  try {
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    if (openedFromParentDashboard) {
      // Ensure we land at ParentDashboardScreen and clear any stacked routes.
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ParentDashboardScreen()),
        (route) => false,
      );
      return;
    }
  } catch (_) {
    // Last resort: push replacement
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ParentDashboardScreen()),
    );
  }
}
