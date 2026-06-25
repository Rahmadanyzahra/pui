import 'dart:convert';

import '../models/daily_activity.dart';
import '../models/report.dart';
import 'backend_api_service.dart';

/// Service untuk generate daily dan weekly reports
class ReportService {
  static Future<Report> generateDailyReport({
    required String parentId,
    required String childId,
    required DateTime forDate,
  }) async {
    final activities = await _loadActivitiesForPeriod(
      childId,
      DateTime(forDate.year, forDate.month, forDate.day),
      DateTime(forDate.year, forDate.month, forDate.day, 23, 59, 59),
    );
    final report = _buildReport(
      reportId: _makeReportId(parentId, childId, 'daily', forDate),
      parentId: parentId,
      childId: childId,
      reportType: 'daily',
      activities: activities,
      periodStartDate: DateTime(forDate.year, forDate.month, forDate.day),
      periodEndDate: DateTime(
        forDate.year,
        forDate.month,
        forDate.day,
        23,
        59,
        59,
      ),
      daysIncluded: 1,
    );
    await BackendApiService.logActivity(
      childId: int.parse(childId),
      activityType: 'report_generated',
      value: jsonEncode(report.toBackendJson()),
    );
    return report;
  }

  static Future<Report> generateWeeklyReport({
    required String parentId,
    required String childId,
    required DateTime forDate,
  }) async {
    final dayOfWeek = forDate.weekday;
    final startOfWeek = DateTime(
      forDate.year,
      forDate.month,
      forDate.day,
    ).subtract(Duration(days: dayOfWeek - 1));
    final endOfWeek = startOfWeek.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );
    final activities = await _loadActivitiesForPeriod(
      childId,
      startOfWeek,
      endOfWeek,
    );
    final report = _buildReport(
      reportId: _makeReportId(parentId, childId, 'weekly', forDate),
      parentId: parentId,
      childId: childId,
      reportType: 'weekly',
      activities: activities,
      periodStartDate: startOfWeek,
      periodEndDate: endOfWeek,
      daysIncluded: 7,
    );
    await BackendApiService.logActivity(
      childId: int.parse(childId),
      activityType: 'report_generated',
      value: jsonEncode(report.toBackendJson()),
    );
    return report;
  }

  static Future<Report?> getReport(String reportId) async {
    final activities = await BackendApiService.getActivities();
    final matches = activities
        .where((activity) => activity.activityType == 'report_generated')
        .map(
          (activity) => Report.fromBackendJson(
            jsonDecode(activity.value) as Map<String, dynamic>,
          ),
        )
        .where((report) => report.id == reportId)
        .toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return matches.first;
  }

  static Future<List<Report>> getChildReports(String childId) async {
    final activities = await BackendApiService.getActivities(
      childId: int.tryParse(childId),
    );
    final reports = activities
        .where((activity) => activity.activityType == 'report_generated')
        .map(
          (activity) => Report.fromBackendJson(
            jsonDecode(activity.value) as Map<String, dynamic>,
          ),
        )
        .where((report) => report.childId == childId)
        .toList();
    reports.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return reports;
  }

  static Future<List<DailyActivity>> _loadActivitiesForPeriod(
    String childId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final activities = await BackendApiService.getActivities(
      childId: int.tryParse(childId),
    );
    return activities
        .map(
          (activity) => DailyActivity.fromBackendActivity({
            'id': activity.id,
            'child_id': activity.childId,
            'activity_type': activity.activityType,
            'value': activity.value,
            'created_at': activity.createdAt,
          }),
        )
        .where(
          (activity) =>
              !activity.date.isBefore(startDate) &&
              !activity.date.isAfter(endDate),
        )
        .toList();
  }

  static Report _buildReport({
    required String reportId,
    required String parentId,
    required String childId,
    required String reportType,
    required List<DailyActivity> activities,
    required DateTime periodStartDate,
    required DateTime periodEndDate,
    required int daysIncluded,
  }) {
    final summary = _analyzeActivities(activities);
    return Report(
      id: reportId,
      parentId: parentId,
      childId: childId,
      reportType: reportType,
      periodStartDate: periodStartDate,
      periodEndDate: periodEndDate,
      daysIncluded: daysIncluded,
      totalActivities: activities.length,
      activitiesByType: summary['activitiesByType'],
      avgSleepHours: summary['avgSleepHours'],
      aiSummary: summary['aiSummary'],
      recommendations: summary['recommendations'],
    );
  }

  static String _makeReportId(
    String parentId,
    String childId,
    String reportType,
    DateTime forDate,
  ) {
    final stamp = DateTime(
      forDate.year,
      forDate.month,
      forDate.day,
    ).millisecondsSinceEpoch;
    return '$parentId-$childId-$reportType-$stamp';
  }

  static Map<String, dynamic> _analyzeActivities(
    List<DailyActivity> activities,
  ) {
    final activitiesByType = <String, int>{};
    double totalSleepHours = 0;
    int sleepCount = 0;

    for (final activity in activities) {
      activitiesByType[activity.activityType] =
          (activitiesByType[activity.activityType] ?? 0) + 1;

      if (activity.activityType == 'sleep' &&
          activity.durationMinutes != null) {
        totalSleepHours += activity.durationMinutes! / 60;
        sleepCount++;
      }
    }

    final avgSleep = sleepCount > 0 ? totalSleepHours / sleepCount : null;

    return {
      'activitiesByType': activitiesByType,
      'avgSleepHours': avgSleep,
      'aiSummary': _generateAISummary(activities, avgSleep),
      'recommendations': _generateRecommendations(activities, avgSleep),
    };
  }

  static String _generateAISummary(
    List<DailyActivity> activities,
    double? avgSleep,
  ) {
    if (activities.isEmpty) {
      return 'Tidak ada aktivitas yang tercatat pada periode ini.';
    }

    var summary =
        'Ringkasan aktivitas: ${activities.length} aktivitas tercatat.';
    if (avgSleep != null) {
      summary += ' Rata-rata tidur: ${avgSleep.toStringAsFixed(1)} jam.';
    }
    return summary;
  }

  static List<String> _generateRecommendations(
    List<DailyActivity> activities,
    double? avgSleep,
  ) {
    final recs = <String>[];

    if (avgSleep != null && avgSleep < 8) {
      recs.add(
        'Tingkatkan durasi tidur anak. Saat ini rata-rata ${avgSleep.toStringAsFixed(1)} jam/malam.',
      );
    }

    if (activities.isEmpty) {
      recs.add(
        'Mulai mencatat aktivitas anak untuk mendapatkan insights yang lebih baik.',
      );
    }

    if (recs.isEmpty) {
      recs.add('Pola aktivitas anak terlihat sehat. Lanjutkan monitoring.');
    }

    return recs;
  }
}
