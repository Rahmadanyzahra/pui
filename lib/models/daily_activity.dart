import 'dart:convert';

class DailyActivity {
  final String? id;
  final String childId;
  final String userId;
  final DateTime date;
  final String activityType;
  final String? description;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final double? quantity;
  final String? unit;
  final bool? isBreastfeeding;
  final String? moodBefore;
  final String? moodAfter;
  final int? rating;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DailyActivity({
    this.id,
    required this.childId,
    required this.userId,
    required this.date,
    required this.activityType,
    this.description,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.quantity,
    this.unit,
    this.isBreastfeeding,
    this.moodBefore,
    this.moodAfter,
    this.rating,
    this.notes,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int? calculateDuration() {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!).inMinutes;
    }
    return durationMinutes;
  }

  factory DailyActivity.fromBackendActivity(Map<String, dynamic> data) {
    final payload = _decodePayload(data['value']);
    final merged = <String, dynamic>{...data, ...payload};
    return DailyActivity(
      id: merged['id']?.toString(),
      childId: (merged['child_id'] ?? merged['childId'] ?? '').toString(),
      userId: (merged['userId'] ?? '').toString(),
      date:
          DateTime.tryParse(
            (merged['date'] ??
                    merged['created_at'] ??
                    merged['createdAt'] ??
                    '')
                .toString(),
          ) ??
          DateTime.now(),
      activityType:
          (merged['activityType'] ?? merged['activity_type'] ?? 'activity')
              .toString(),
      description: merged['description']?.toString(),
      startTime: _parseDateTime(merged['startTime']),
      endTime: _parseDateTime(merged['endTime']),
      durationMinutes: _asInt(merged['durationMinutes']),
      quantity: _asDouble(merged['quantity']),
      unit: merged['unit']?.toString(),
      isBreastfeeding: merged['isBreastfeeding'] as bool?,
      moodBefore: merged['moodBefore']?.toString(),
      moodAfter: merged['moodAfter']?.toString(),
      rating: _asIntNullable(merged['rating']),
      notes: merged['notes']?.toString(),
      createdAt:
          DateTime.tryParse(
            (merged['createdAt'] ?? merged['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      updatedAt: _parseDateTime(merged['updatedAt']),
    );
  }

  String toBackendJson() {
    return jsonEncode({
      'childId': childId,
      'userId': userId,
      'date': date.toIso8601String(),
      'activityType': activityType,
      'description': description,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationMinutes': durationMinutes ?? calculateDuration(),
      'quantity': quantity,
      'unit': unit,
      'isBreastfeeding': isBreastfeeding,
      'moodBefore': moodBefore,
      'moodAfter': moodAfter,
      'rating': rating,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    });
  }

  DailyActivity copyWith({
    String? id,
    String? childId,
    String? userId,
    DateTime? date,
    String? activityType,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    double? quantity,
    String? unit,
    bool? isBreastfeeding,
    String? moodBefore,
    String? moodAfter,
    int? rating,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyActivity(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      activityType: activityType ?? this.activityType,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isBreastfeeding: isBreastfeeding ?? this.isBreastfeeding,
      moodBefore: moodBefore ?? this.moodBefore,
      moodAfter: moodAfter ?? this.moodAfter,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String getActivityLabel(String type) {
    switch (type) {
      case 'feeding':
        return '🍼 Menyusui/Botol';
      case 'meal':
        return '🍽️ Makan';
      case 'sleep':
        return '😴 Tidur';
      case 'activity':
        return '🎮 Kegiatan';
      case 'parenting':
        return '👨‍👩‍👧 Parenting';
      default:
        return type;
    }
  }

  static String getMoodLabel(String mood) {
    switch (mood) {
      case 'happy':
        return '😊 Senang';
      case 'calm':
        return '😌 Tenang';
      case 'fussy':
        return '😤 Rewel';
      case 'sleepy':
        return '😴 Mengantuk';
      case 'crying':
        return '😢 Menangis';
      default:
        return mood;
    }
  }
}

dynamic _decodePayload(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(value);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
  }
  if (value is Map<String, dynamic>) return value;
  return <String, dynamic>{};
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asIntNullable(dynamic value) {
  if (value == null) return null;
  return _asInt(value);
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
