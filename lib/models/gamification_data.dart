import 'package:cloud_firestore/cloud_firestore.dart';

/// Gamification system dengan reward poin dan badge
class GamificationData {
  final String id;
  final String childId;
  final String userId;
  final int totalPoints;
  final List<Badge> badges;
  final int level; // Level berdasarkan poin
  final DateTime createdAt;
  final DateTime? updatedAt;

  GamificationData({
    required this.id,
    required this.childId,
    required this.userId,
    this.totalPoints = 0,
    this.badges = const [],
    this.level = 1,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Calculate level berdasarkan total points
  /// Level 1: 0-100, Level 2: 100-250, Level 3: 250-500, dst
  static int calculateLevel(int points) {
    if (points < 100) return 1;
    if (points < 250) return 2;
    if (points < 500) return 3;
    if (points < 1000) return 4;
    return 5;
  }

  factory GamificationData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    List<Badge> badges = [];
    if (data['badges'] != null) {
      badges = (data['badges'] as List)
          .map((b) => Badge.fromMap(b as Map<String, dynamic>))
          .toList();
    }

    return GamificationData(
      id: doc.id,
      childId: data['childId'] ?? '',
      userId: data['userId'] ?? '',
      totalPoints: data['totalPoints'] ?? 0,
      badges: badges,
      level: data['level'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'childId': childId,
      'userId': userId,
      'totalPoints': totalPoints,
      'badges': badges.map((b) => b.toMap()).toList(),
      'level': level,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  GamificationData copyWith({
    String? id,
    int? totalPoints,
    List<Badge>? badges,
    int? level,
  }) {
    return GamificationData(
      id: id ?? this.id,
      childId: childId,
      userId: userId,
      totalPoints: totalPoints ?? this.totalPoints,
      badges: badges ?? this.badges,
      level: level ?? this.level,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Badge/Achievement untuk child
class Badge {
  final String id;
  final String name;
  final String description;
  final String badgeType; // 'activity', 'consistency', 'milestone'
  final String? iconUrl;
  final int requiredPoints;
  final DateTime unlockedAt;
  final bool isVisible;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.badgeType,
    this.iconUrl,
    this.requiredPoints = 0,
    required this.unlockedAt,
    this.isVisible = true,
  });

  factory Badge.fromMap(Map<String, dynamic> map) {
    return Badge(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      badgeType: map['badgeType'] ?? 'activity',
      iconUrl: map['iconUrl'],
      requiredPoints: map['requiredPoints'] ?? 0,
      unlockedAt: (map['unlockedAt'] is Timestamp)
          ? (map['unlockedAt'] as Timestamp).toDate()
          : DateTime.now(),
      isVisible: map['isVisible'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'badgeType': badgeType,
      'iconUrl': iconUrl,
      'requiredPoints': requiredPoints,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
      'isVisible': isVisible,
    };
  }
}

/// Point transaction untuk track point history
class PointTransaction {
  final String id;
  final String childId;
  final String userId;
  final int points; // Positive untuk gain, negative untuk loss
  final String reason; // 'activity_completed', 'streak', 'badge_unlocked'
  final String? activityId; // Reference ke activity jika applicable
  final DateTime transactionDate;
  final DateTime createdAt;

  PointTransaction({
    required this.id,
    required this.childId,
    required this.userId,
    required this.points,
    required this.reason,
    this.activityId,
    DateTime? transactionDate,
    DateTime? createdAt,
  }) : transactionDate = transactionDate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  factory PointTransaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PointTransaction(
      id: doc.id,
      childId: data['childId'] ?? '',
      userId: data['userId'] ?? '',
      points: data['points'] ?? 0,
      reason: data['reason'] ?? '',
      activityId: data['activityId'],
      transactionDate:
          (data['transactionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'childId': childId,
      'userId': userId,
      'points': points,
      'reason': reason,
      'activityId': activityId,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
