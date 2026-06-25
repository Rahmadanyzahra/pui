import 'package:flutter/material.dart';

import '../models/daily_activity.dart';
import 'backend_api_service.dart';

class ActivityTrackingService {
  static Future<String> addActivity(
    DailyActivity activity, {
    String? childName,
    int? childAge,
  }) async {
    try {
      final backendChildId = await _resolveBackendChildId(
        activity.childId,
        childName: childName,
        childAge: childAge,
      );
      if (backendChildId != null) {
        await BackendApiService.logActivity(
          childId: backendChildId,
          activityType: activity.activityType,
          value: activity.toBackendJson(),
        );
      }
      return DateTime.now().millisecondsSinceEpoch.toString();
    } catch (e) {
      debugPrint('Error adding activity: $e');
      rethrow;
    }
  }

  static Future<int?> _resolveBackendChildId(
    String childId, {
    String? childName,
    int? childAge,
  }) async {
    final parsedId = int.tryParse(childId);
    if (parsedId != null) return parsedId;

    if (childName == null || childName.trim().isEmpty) return null;

    try {
      final backendChildren = await BackendApiService.getChildren();
      final normalizedName = childName.trim().toLowerCase();
      for (final child in backendChildren) {
        if (child.nama.trim().toLowerCase() != normalizedName) continue;
        if (childAge != null && child.umur != childAge) continue;
        return child.id;
      }
    } catch (e) {
      debugPrint('Warning: could not resolve backend child id: $e');
    }

    return null;
  }

  static Future<void> updateActivity(DailyActivity activity) async {
    debugPrint(
      'updateActivity is handled as append-only on backend: ${activity.id}',
    );
  }

  static Future<void> deleteActivity(String activityId) async {
    debugPrint(
      'deleteActivity is handled in backend activity log only: $activityId',
    );
  }

  static Future<List<DailyActivity>> getActivitiesByDate(
    String childId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      final all = await BackendApiService.getActivities(
        childId: int.tryParse(childId),
      );
      return all
          .map(
            (item) => DailyActivity.fromBackendActivity({
              'id': item.id,
              'child_id': item.childId,
              'activity_type': item.activityType,
              'value': item.value,
              'created_at': item.createdAt,
            }),
          )
          .where(
            (activity) =>
                !activity.date.isBefore(startOfDay) &&
                !activity.date.isAfter(endOfDay),
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting activities by date: $e');
      return [];
    }
  }

  static Future<List<DailyActivity>> getActivitiesInPeriod(
    String childId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final all = await BackendApiService.getActivities(
        childId: int.tryParse(childId),
      );
      return all
          .map(
            (item) => DailyActivity.fromBackendActivity({
              'id': item.id,
              'child_id': item.childId,
              'activity_type': item.activityType,
              'value': item.value,
              'created_at': item.createdAt,
            }),
          )
          .where(
            (activity) =>
                !activity.date.isBefore(startDate) &&
                !activity.date.isAfter(endDate),
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting activities in period: $e');
      return [];
    }
  }

  static Future<List<DailyActivity>> getActivitiesByType(
    String childId,
    String activityType,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final activities = await getActivitiesInPeriod(
        childId,
        startDate,
        endDate,
      );
      return activities
          .where((activity) => activity.activityType == activityType)
          .toList();
    } catch (e) {
      debugPrint('Error getting activities by type: $e');
      return [];
    }
  }

  static Stream<List<DailyActivity>> streamActivitiesByDate(
    String childId,
    DateTime date,
  ) {
    return Stream<List<DailyActivity>>.periodic(
      const Duration(seconds: 3),
    ).asyncMap((_) => getActivitiesByDate(childId, date));
  }

  static Stream<List<DailyActivity>> streamActivitiesInPeriod(
    String childId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return Stream<List<DailyActivity>>.periodic(
      const Duration(seconds: 3),
    ).asyncMap((_) => getActivitiesInPeriod(childId, startDate, endDate));
  }

  static Future<Map<String, dynamic>> getActivityStatistics(
    String childId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final activities = await getActivitiesInPeriod(
        childId,
        startDate,
        endDate,
      );
      if (activities.isEmpty) {
        return {'total': 0, 'byType': {}, 'avgPerDay': 0};
      }

      final byType = <String, int>{};
      for (final activity in activities) {
        byType.update(
          activity.activityType,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      final daysCount = endDate.difference(startDate).inDays + 1;
      return {
        'total': activities.length,
        'daysWithData': activities
            .map(
              (activity) => DateTime(
                activity.date.year,
                activity.date.month,
                activity.date.day,
              ),
            )
            .toSet()
            .length,
        'byType': byType,
        'avgPerDay': (activities.length / daysCount).toStringAsFixed(1),
      };
    } catch (e) {
      debugPrint('Error getting activity statistics: $e');
      return {};
    }
  }

  static Future<bool> has30DaysOfData(String childId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final activities = await getActivitiesInPeriod(
        childId,
        thirtyDaysAgo,
        DateTime.now(),
      );
      final uniqueDates = activities
          .map(
            (activity) => DateTime(
              activity.date.year,
              activity.date.month,
              activity.date.day,
            ),
          )
          .toSet();
      return uniqueDates.length >= 30;
    } catch (e) {
      debugPrint('Error checking 30 days of data: $e');
      return false;
    }
  }
}
