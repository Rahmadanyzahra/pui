import 'dart:math' as mathdart;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Location tracking untuk real-time lokasi child
class LocationData {
  final String id;
  final String childId;
  final String userId; // User yang posisinya di-track
  final double latitude;
  final double longitude;
  final double? accuracy; // Akurasi GPS dalam meter
  final String? address; // Reverse geocoding
  final bool isInSafeZone;
  final DateTime timestamp;
  final DateTime? createdAt;

  LocationData({
    required this.id,
    required this.childId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.address,
    this.isInSafeZone = true,
    required this.timestamp,
    this.createdAt,
  });

  factory LocationData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LocationData(
      id: doc.id,
      childId: data['childId'] ?? '',
      userId: data['userId'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      address: data['address'],
      isInSafeZone: data['isInSafeZone'] ?? true,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'childId': childId,
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'address': address,
      'isInSafeZone': isInSafeZone,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}

/// Safe Zone untuk mencegah child keluar area tertentu
class SafeZone {
  final String id;
  final String parentId;
  final String childId;
  final String name; // 'Rumah', 'Sekolah', dsb
  final double latitude;
  final double longitude;
  final double radiusMeters; // Radius zona aman dalam meter
  final bool isActive;
  final DateTime createdAt;

  SafeZone({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 500, // Default 500 meter
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SafeZone.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SafeZone(
      id: doc.id,
      parentId: data['parentId'] ?? '',
      childId: data['childId'] ?? '',
      name: data['name'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (data['radiusMeters'] as num?)?.toDouble() ?? 500,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'parentId': parentId,
      'childId': childId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Check apakah lokasi berada dalam safe zone
  bool isLocationInZone(double lat, double lng) {
    const earthRadiusMeters = 6371000;

    double dLat = _toRadians(lat - latitude);
    double dLng = _toRadians(lng - longitude);

    double a =
        (Math.sin(dLat / 2) * Math.sin(dLat / 2)) +
        (Math.cos(_toRadians(latitude)) *
            Math.cos(_toRadians(lat)) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2));

    double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    double distance = earthRadiusMeters * c;

    return distance <= radiusMeters;
  }

  static double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }
}

// Helper class untuk math operations
class Math {
  static double sin(double x) => mathdart.sin(x);
  static double cos(double x) => mathdart.cos(x);
  static double sqrt(double x) => mathdart.sqrt(x);
  static double atan2(double y, double x) => mathdart.atan2(y, x);
}
