/// Report system untuk laporan harian dan mingguan
/// Berisi summary dari aktivitas, screen time, lokasi, mood, dst
class Report {
  final String id;
  final String parentId;
  final String childId;
  final String reportType; // 'daily', 'weekly', 'monthly'
  final DateTime periodStartDate;
  final DateTime periodEndDate;
  final int daysIncluded;

  // Activity Summary
  final int totalActivities;
  final Map<String, int>? activitiesByType; // {'feeding': 10, 'sleep': 8, ...}
  final String? mostActiveTime; // 'morning', 'afternoon', 'evening'

  // Sleep Summary (Bayi/Toddler)
  final double? avgSleepHours;
  final int? totalSleepSessions;
  final String? sleepQuality; // 'good', 'fair', 'poor'

  // Screen Time Summary (Remaja)
  final double? totalScreenTimeHours;
  final Map<String, double>? appUsageByApp; // {'youtube': 2.5, 'tiktok': 1.2}
  final String? screenTimeStatus; // 'normal', 'warning', 'critical'

  // Mood Summary
  final Map<String, int>? moodDistribution; // {'happy': 10, 'sad': 2, ...}
  final String? overallMood;

  // Location Summary
  final int? locationCheckinsCount;
  final int? outOfSafeZoneCount;
  final List<String>? frequentLocations;

  // AI Generated Summary
  final String? aiSummary;
  final List<String>? recommendations;
  final String? areasOfConcern;
  final List<String>? positiveObservations;

  final DateTime generatedAt;
  final DateTime? createdAt;

  Report({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.reportType,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.daysIncluded,
    this.totalActivities = 0,
    this.activitiesByType,
    this.mostActiveTime,
    this.avgSleepHours,
    this.totalSleepSessions,
    this.sleepQuality,
    this.totalScreenTimeHours,
    this.appUsageByApp,
    this.screenTimeStatus,
    this.moodDistribution,
    this.overallMood,
    this.locationCheckinsCount,
    this.outOfSafeZoneCount,
    this.frequentLocations,
    this.aiSummary,
    this.recommendations,
    this.areasOfConcern,
    this.positiveObservations,
    DateTime? generatedAt,
    this.createdAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  factory Report.fromBackendJson(Map<String, dynamic> data) {
    return Report(
      id: data['id']?.toString() ?? '',
      parentId: data['parentId'] ?? '',
      childId: data['childId'] ?? '',
      reportType: data['reportType'] ?? 'daily',
      periodStartDate:
          DateTime.tryParse(data['periodStartDate'] ?? '') ?? DateTime.now(),
      periodEndDate:
          DateTime.tryParse(data['periodEndDate'] ?? '') ?? DateTime.now(),
      daysIncluded: data['daysIncluded'] ?? 1,
      totalActivities: data['totalActivities'] ?? 0,
      activitiesByType: Map<String, int>.from(data['activitiesByType'] ?? {}),
      mostActiveTime: data['mostActiveTime'],
      avgSleepHours: (data['avgSleepHours'] as num?)?.toDouble(),
      totalSleepSessions: data['totalSleepSessions'],
      sleepQuality: data['sleepQuality'],
      totalScreenTimeHours: (data['totalScreenTimeHours'] as num?)?.toDouble(),
      appUsageByApp: data['appUsageByApp'] != null
          ? Map<String, double>.from(data['appUsageByApp'])
          : null,
      screenTimeStatus: data['screenTimeStatus'],
      moodDistribution: Map<String, int>.from(data['moodDistribution'] ?? {}),
      overallMood: data['overallMood'],
      locationCheckinsCount: data['locationCheckinsCount'],
      outOfSafeZoneCount: data['outOfSafeZoneCount'],
      frequentLocations: List<String>.from(data['frequentLocations'] ?? []),
      aiSummary: data['aiSummary'],
      recommendations: List<String>.from(data['recommendations'] ?? []),
      areasOfConcern: data['areasOfConcern'],
      positiveObservations: List<String>.from(
        data['positiveObservations'] ?? [],
      ),
      generatedAt:
          DateTime.tryParse(data['generatedAt'] ?? '') ?? DateTime.now(),
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toBackendJson() {
    return {
      'id': id,
      'parentId': parentId,
      'childId': childId,
      'reportType': reportType,
      'periodStartDate': periodStartDate.toIso8601String(),
      'periodEndDate': periodEndDate.toIso8601String(),
      'daysIncluded': daysIncluded,
      'totalActivities': totalActivities,
      'activitiesByType': activitiesByType,
      'mostActiveTime': mostActiveTime,
      'avgSleepHours': avgSleepHours,
      'totalSleepSessions': totalSleepSessions,
      'sleepQuality': sleepQuality,
      'totalScreenTimeHours': totalScreenTimeHours,
      'appUsageByApp': appUsageByApp,
      'screenTimeStatus': screenTimeStatus,
      'moodDistribution': moodDistribution,
      'overallMood': overallMood,
      'locationCheckinsCount': locationCheckinsCount,
      'outOfSafeZoneCount': outOfSafeZoneCount,
      'frequentLocations': frequentLocations,
      'aiSummary': aiSummary,
      'recommendations': recommendations,
      'areasOfConcern': areasOfConcern,
      'positiveObservations': positiveObservations,
      'generatedAt': generatedAt.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
