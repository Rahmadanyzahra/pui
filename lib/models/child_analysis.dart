import 'dart:convert';

class ChildAnalysis {
  final String? id;
  final String childId;
  final String userId;
  final DateTime analysisDate;
  final DateTime periodStartDate;
  final DateTime periodEndDate;
  final int daysOfData;

  final double? avgSleepDurationHours;
  final int? totalSleepSessions;
  final String? sleepPattern;
  final String? sleepQualityAssessment;

  final double? avgFeedingFrequencyPerDay;
  final double? avgBreastfeedingDurationMin;
  final double? avgQuantityPerSession;
  final String? feedingPattern;
  final String? feedingRecommendation;

  final int? mealsPerDay;
  final List<String>? foodPreferences;
  final String? nutritionAssessment;

  final int? avgActivityDurationMin;
  final List<String>? favoriteActivities;
  final String? activityLevel;
  final String? developmentMilestones;

  final String? moodPattern;
  final int? fussyEpisodesPerDay;
  final String? behaviorAssessment;
  final String? behaviorTrends;

  final List<String>? recommendations;
  final String? overallAssessment;
  final String? areasOfConcern;
  final String? positiveObservations;

  final String? aiInsights;
  final int? confidenceScore;

  final DateTime createdAt;
  final DateTime? updatedAt;

  ChildAnalysis({
    this.id,
    required this.childId,
    required this.userId,
    required this.analysisDate,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.daysOfData,
    this.avgSleepDurationHours,
    this.totalSleepSessions,
    this.sleepPattern,
    this.sleepQualityAssessment,
    this.avgFeedingFrequencyPerDay,
    this.avgBreastfeedingDurationMin,
    this.avgQuantityPerSession,
    this.feedingPattern,
    this.feedingRecommendation,
    this.mealsPerDay,
    this.foodPreferences,
    this.nutritionAssessment,
    this.avgActivityDurationMin,
    this.favoriteActivities,
    this.activityLevel,
    this.developmentMilestones,
    this.moodPattern,
    this.fussyEpisodesPerDay,
    this.behaviorAssessment,
    this.behaviorTrends,
    this.recommendations,
    this.overallAssessment,
    this.areasOfConcern,
    this.positiveObservations,
    this.aiInsights,
    this.confidenceScore,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChildAnalysis.fromBackendJson(String jsonText) {
    final data = Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
    return ChildAnalysis(
      id: data['id']?.toString(),
      childId: data['childId']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      analysisDate:
          DateTime.tryParse(data['analysisDate']?.toString() ?? '') ??
          DateTime.now(),
      periodStartDate:
          DateTime.tryParse(data['periodStartDate']?.toString() ?? '') ??
          DateTime.now(),
      periodEndDate:
          DateTime.tryParse(data['periodEndDate']?.toString() ?? '') ??
          DateTime.now(),
      daysOfData: _asInt(data['daysOfData']),
      avgSleepDurationHours: _asDouble(data['avgSleepDurationHours']),
      totalSleepSessions: data['totalSleepSessions'] != null
          ? _asInt(data['totalSleepSessions'])
          : null,
      sleepPattern: data['sleepPattern']?.toString(),
      sleepQualityAssessment: data['sleepQualityAssessment']?.toString(),
      avgFeedingFrequencyPerDay: _asDouble(data['avgFeedingFrequencyPerDay']),
      avgBreastfeedingDurationMin: _asDouble(
        data['avgBreastfeedingDurationMin'],
      ),
      avgQuantityPerSession: _asDouble(data['avgQuantityPerSession']),
      feedingPattern: data['feedingPattern']?.toString(),
      feedingRecommendation: data['feedingRecommendation']?.toString(),
      mealsPerDay: data['mealsPerDay'] != null
          ? _asInt(data['mealsPerDay'])
          : null,
      foodPreferences: List<String>.from(data['foodPreferences'] ?? const []),
      nutritionAssessment: data['nutritionAssessment']?.toString(),
      avgActivityDurationMin: data['avgActivityDurationMin'] != null
          ? _asInt(data['avgActivityDurationMin'])
          : null,
      favoriteActivities: List<String>.from(
        data['favoriteActivities'] ?? const [],
      ),
      activityLevel: data['activityLevel']?.toString(),
      developmentMilestones: data['developmentMilestones']?.toString(),
      moodPattern: data['moodPattern']?.toString(),
      fussyEpisodesPerDay: data['fussyEpisodesPerDay'] != null
          ? _asInt(data['fussyEpisodesPerDay'])
          : null,
      behaviorAssessment: data['behaviorAssessment']?.toString(),
      behaviorTrends: data['behaviorTrends']?.toString(),
      recommendations: List<String>.from(data['recommendations'] ?? const []),
      overallAssessment: data['overallAssessment']?.toString(),
      areasOfConcern: data['areasOfConcern']?.toString(),
      positiveObservations: data['positiveObservations']?.toString(),
      aiInsights: data['aiInsights']?.toString(),
      confidenceScore: data['confidenceScore'] != null
          ? _asInt(data['confidenceScore'])
          : null,
      createdAt:
          DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'].toString())
          : null,
    );
  }

  String toBackendJson() {
    return jsonEncode({
      'childId': childId,
      'userId': userId,
      'analysisDate': analysisDate.toIso8601String(),
      'periodStartDate': periodStartDate.toIso8601String(),
      'periodEndDate': periodEndDate.toIso8601String(),
      'daysOfData': daysOfData,
      'avgSleepDurationHours': avgSleepDurationHours,
      'totalSleepSessions': totalSleepSessions,
      'sleepPattern': sleepPattern,
      'sleepQualityAssessment': sleepQualityAssessment,
      'avgFeedingFrequencyPerDay': avgFeedingFrequencyPerDay,
      'avgBreastfeedingDurationMin': avgBreastfeedingDurationMin,
      'avgQuantityPerSession': avgQuantityPerSession,
      'feedingPattern': feedingPattern,
      'feedingRecommendation': feedingRecommendation,
      'mealsPerDay': mealsPerDay,
      'foodPreferences': foodPreferences ?? const [],
      'nutritionAssessment': nutritionAssessment,
      'avgActivityDurationMin': avgActivityDurationMin,
      'favoriteActivities': favoriteActivities ?? const [],
      'activityLevel': activityLevel,
      'developmentMilestones': developmentMilestones,
      'moodPattern': moodPattern,
      'fussyEpisodesPerDay': fussyEpisodesPerDay,
      'behaviorAssessment': behaviorAssessment,
      'behaviorTrends': behaviorTrends,
      'recommendations': recommendations ?? const [],
      'overallAssessment': overallAssessment,
      'areasOfConcern': areasOfConcern,
      'positiveObservations': positiveObservations,
      'aiInsights': aiInsights,
      'confidenceScore': confidenceScore,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    });
  }
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
