class ScreenTimeTracker {
  static Future<void> startTracking(String dashboardType) async {
    // Screen time tracking is disabled in this version.
  }

  static Future<int> stopTracking() async {
    return 0;
  }

  static Future<int> getTodayScreenTime() async {
    return 0;
  }

  static Future<Map<String, int>> getTodayByDashboard() async {
    return {};
  }
}
