import '../models/daily_activity.dart';
import '../models/child_analysis.dart';
import 'backend_api_service.dart';

class AnalysisService {
  static Future<String> saveAnalysis(ChildAnalysis analysis) async {
    try {
      final childId = int.tryParse(analysis.childId);
      if (childId == null) {
        throw Exception('Invalid childId');
      }
      await BackendApiService.logActivity(
        childId: childId,
        activityType: 'analysis_generated',
        value: analysis.toBackendJson(),
      );
      return DateTime.now().millisecondsSinceEpoch.toString();
    } catch (e) {
      print('Error saving analysis: $e');
      rethrow;
    }
  }

  static Future<ChildAnalysis?> getLatestAnalysis(String childId) async {
    try {
      final activities = await BackendApiService.getActivities(
        childId: int.tryParse(childId),
      );
      final analyses = activities
          .where((activity) => activity.activityType == 'analysis_generated')
          .map((activity) => ChildAnalysis.fromBackendJson(activity.value))
          .toList();
      if (analyses.isEmpty) return null;
      analyses.sort((a, b) => b.analysisDate.compareTo(a.analysisDate));
      return analyses.first;
    } catch (e) {
      print('Error getting latest analysis: $e');
      return null;
    }
  }

  static Future<List<ChildAnalysis>> getAnalysesForChild(String childId) async {
    try {
      final activities = await BackendApiService.getActivities(
        childId: int.tryParse(childId),
      );
      final analyses = activities
          .where((activity) => activity.activityType == 'analysis_generated')
          .map((activity) => ChildAnalysis.fromBackendJson(activity.value))
          .toList();
      analyses.sort((a, b) => b.analysisDate.compareTo(a.analysisDate));
      return analyses;
    } catch (e) {
      print('Error getting analyses: $e');
      return [];
    }
  }

  static Future<ChildAnalysis> generateAnalysis(
    String childId,
    String userId,
    List<DailyActivity> activities,
  ) async {
    if (activities.isEmpty) {
      throw Exception('No activities to analyze');
    }

    activities.sort((a, b) => a.date.compareTo(b.date));

    final startDate = activities.first.date;
    final endDate = activities.last.date;
    final daysOfData = activities
        .map((a) => DateTime(a.date.year, a.date.month, a.date.day))
        .toSet()
        .length;

    final sleepAnalysis = _analyzeSleep(activities);
    final feedingAnalysis = _analyzeFeeding(activities);
    final mealsAnalysis = _analyzeMeals(activities);
    final activityAnalysis = _analyzeActivity(activities);
    final behaviorAnalysis = _analyzeBehavior(activities);

    final recommendations = _generateRecommendations(
      sleepAnalysis,
      feedingAnalysis,
      mealsAnalysis,
      activityAnalysis,
      behaviorAnalysis,
    );

    return ChildAnalysis(
      childId: childId,
      userId: userId,
      analysisDate: DateTime.now(),
      periodStartDate: startDate,
      periodEndDate: endDate,
      daysOfData: daysOfData,
      avgSleepDurationHours: sleepAnalysis['avgDuration'],
      totalSleepSessions: sleepAnalysis['totalSessions'],
      sleepPattern: sleepAnalysis['pattern'],
      sleepQualityAssessment: sleepAnalysis['assessment'],
      avgFeedingFrequencyPerDay: feedingAnalysis['avgFrequency'],
      avgBreastfeedingDurationMin: feedingAnalysis['avgDuration'],
      avgQuantityPerSession: feedingAnalysis['avgQuantity'],
      feedingPattern: feedingAnalysis['pattern'],
      feedingRecommendation: feedingAnalysis['recommendation'],
      mealsPerDay: mealsAnalysis['mealsPerDay'],
      foodPreferences: mealsAnalysis['preferences'],
      nutritionAssessment: mealsAnalysis['assessment'],
      avgActivityDurationMin: activityAnalysis['avgDuration'],
      favoriteActivities: activityAnalysis['favorites'],
      activityLevel: activityAnalysis['level'],
      developmentMilestones: activityAnalysis['milestones'],
      moodPattern: behaviorAnalysis['moodPattern'],
      fussyEpisodesPerDay: behaviorAnalysis['fussyPerDay'],
      behaviorAssessment: behaviorAnalysis['assessment'],
      behaviorTrends: behaviorAnalysis['trends'],
      recommendations: recommendations['list'],
      overallAssessment: recommendations['overall'],
      areasOfConcern: recommendations['concerns'],
      positiveObservations: recommendations['positive'],
      aiInsights: recommendations['insights'],
      confidenceScore: 85,
    );
  }

  static Map<String, dynamic> _analyzeSleep(List<DailyActivity> activities) {
    final sleepActivities = activities
        .where((a) => a.activityType == 'sleep')
        .toList();

    if (sleepActivities.isEmpty) {
      return {
        'avgDuration': 0.0,
        'totalSessions': 0,
        'pattern': 'No sleep data recorded',
        'assessment': 'Insufficient data',
      };
    }

    double totalDuration = 0;
    for (final activity in sleepActivities) {
      if (activity.durationMinutes != null) {
        totalDuration += activity.durationMinutes!;
      }
    }

    final avgDurationHours = totalDuration / sleepActivities.length / 60;
    final numberOfDays = activities
        .map((a) => DateTime(a.date.year, a.date.month, a.date.day))
        .toSet()
        .length;
    final avgPerDay = sleepActivities.length / numberOfDays;

    String pattern;
    if (avgPerDay < 2) {
      pattern = 'Consolidated sleep - 1-2 long sessions per day';
    } else if (avgPerDay < 4) {
      pattern = 'Multiple short naps with longer night sleep';
    } else {
      pattern = 'Frequent short naps throughout day';
    }

    String assessment;
    if (avgDurationHours < 10) {
      assessment = 'Sleep duration appears low - monitor carefully';
    } else if (avgDurationHours > 18) {
      assessment = 'Sleep duration is high - may indicate growth spurt';
    } else {
      assessment = 'Sleep duration is within healthy range';
    }

    return {
      'avgDuration': double.parse(avgDurationHours.toStringAsFixed(1)),
      'totalSessions': sleepActivities.length,
      'pattern': pattern,
      'assessment': assessment,
    };
  }

  static Map<String, dynamic> _analyzeFeeding(List<DailyActivity> activities) {
    final feedingActivities = activities
        .where((a) => a.activityType == 'feeding')
        .toList();

    if (feedingActivities.isEmpty) {
      return {
        'avgFrequency': 0.0,
        'avgDuration': 0.0,
        'avgQuantity': 0.0,
        'pattern': 'No feeding data recorded',
        'recommendation': 'Start tracking feeding to get insights',
      };
    }

    final numberOfDays = activities
        .map((a) => DateTime(a.date.year, a.date.month, a.date.day))
        .toSet()
        .length;
    final avgFrequency = feedingActivities.length / numberOfDays;

    double totalDuration = 0;
    int breastfedCount = 0;
    double totalQuantity = 0;
    int quantityCount = 0;

    for (final activity in feedingActivities) {
      if (activity.durationMinutes != null) {
        totalDuration += activity.durationMinutes!;
      }
      if (activity.isBreastfeeding == true) {
        breastfedCount++;
      }
      if (activity.quantity != null) {
        totalQuantity += activity.quantity!;
        quantityCount++;
      }
    }

    final avgDuration = totalDuration / feedingActivities.length;
    final avgQuantity = quantityCount > 0 ? totalQuantity / quantityCount : 0.0;

    String pattern;
    if (avgFrequency < 4) {
      pattern = 'Frequent, on-demand feeding';
    } else if (avgFrequency < 8) {
      pattern = 'Regular scheduled feeding';
    } else {
      pattern = 'Very frequent feeding pattern';
    }

    final breastfeedPercentage = feedingActivities.isEmpty
        ? 0
        : (breastfedCount / feedingActivities.length * 100).toInt();

    String recommendation;
    if (breastfeedPercentage > 80) {
      recommendation =
          'Primarily breastfeeding - ensure adequate nutrition and hydration';
    } else if (breastfeedPercentage > 50) {
      recommendation = 'Mixed feeding pattern - monitor intake balance';
    } else {
      recommendation =
          'Formula or solid food dominant - track variety and nutrients';
    }

    return {
      'avgFrequency': double.parse(avgFrequency.toStringAsFixed(1)),
      'avgDuration': double.parse(avgDuration.toStringAsFixed(1)),
      'avgQuantity': double.parse(avgQuantity.toStringAsFixed(1)),
      'pattern': pattern,
      'recommendation': recommendation,
    };
  }

  static Map<String, dynamic> _analyzeMeals(List<DailyActivity> activities) {
    final mealActivities = activities
        .where((a) => a.activityType == 'meal')
        .toList();
    final mealCount = mealActivities.length;
    final dayCount = activities
        .map((a) => DateTime(a.date.year, a.date.month, a.date.day))
        .toSet()
        .length;
    final mealsPerDay = dayCount > 0 ? (mealCount / dayCount).round() : 0;
    final preferences = mealActivities
        .map((activity) => activity.description ?? activity.notes ?? 'meal')
        .toSet()
        .toList();
    return {
      'mealsPerDay': mealsPerDay,
      'preferences': preferences,
      'assessment': mealCount == 0
          ? 'No meal data recorded'
          : 'Meal data available',
    };
  }

  static Map<String, dynamic> _analyzeActivity(List<DailyActivity> activities) {
    final activityActivities = activities
        .where((a) => a.activityType == 'activity')
        .toList();
    final dayCount = activities
        .map((a) => DateTime(a.date.year, a.date.month, a.date.day))
        .toSet()
        .length;
    final avgDuration = activityActivities.isEmpty
        ? 0
        : (activityActivities.fold<int>(
                    0,
                    (sum, a) => sum + (a.durationMinutes ?? 0),
                  ) /
                  activityActivities.length)
              .round();
    return {
      'avgDuration': avgDuration,
      'favorites': activityActivities
          .map((a) => a.description ?? 'activity')
          .toSet()
          .toList(),
      'level': activityActivities.length < dayCount ? 'low' : 'moderate',
      'milestones': 'Tracked via backend activities',
    };
  }

  static Map<String, dynamic> _analyzeBehavior(List<DailyActivity> activities) {
    final moodCounts = <String, int>{};
    for (final activity in activities) {
      final mood = activity.moodAfter ?? activity.moodBefore;
      if (mood != null && mood.isNotEmpty) {
        moodCounts.update(mood, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final topMood = moodCounts.entries.isEmpty
        ? 'neutral'
        : moodCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return {
      'moodPattern': topMood,
      'fussyPerDay': activities
          .where((a) => a.moodAfter == 'fussy' || a.moodBefore == 'fussy')
          .length,
      'assessment': moodCounts.isEmpty
          ? 'No behavior data recorded'
          : 'Behavior data available',
      'trends': 'Derived from backend activity logs',
    };
  }

  static Map<String, dynamic> _generateRecommendations(
    Map<String, dynamic> sleepAnalysis,
    Map<String, dynamic> feedingAnalysis,
    Map<String, dynamic> mealsAnalysis,
    Map<String, dynamic> activityAnalysis,
    Map<String, dynamic> behaviorAnalysis,
  ) {
    return {
      'list': <String>[
        'Pertahankan rutinitas harian yang konsisten.',
        'Pantau pola tidur dan makan dari backend Laragon.',
      ],
      'overall': 'Data sudah tersimpan di backend Laragon.',
      'concerns': 'None',
      'positive': 'Activity log available',
      'insights': 'Analytics generated from backend data',
    };
  }
}
