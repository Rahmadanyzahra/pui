import 'package:cloud_firestore/cloud_firestore.dart';

/// Permission system untuk kontrol akses data berdasarkan role
/// Rules: Parent bisa lihat semua data anak, Remaja bisa lihat sendiri
class PermissionSettings {
  final String id;
  final String parentId;
  final String? childId; // Null untuk parent-level settings
  final bool canViewActivities;
  final bool canViewLocation;
  final bool canViewScreenTime;
  final bool canViewMood;
  final bool canEditChild; // Parent only
  final bool canSetLimits; // Parent only
  final bool canViewReports;
  final bool locationTrackingEnabled;
  final bool screenTimeTrackingEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PermissionSettings({
    required this.id,
    required this.parentId,
    this.childId,
    this.canViewActivities = true,
    this.canViewLocation = true,
    this.canViewScreenTime = true,
    this.canViewMood = true,
    this.canEditChild = true,
    this.canSetLimits = true,
    this.canViewReports = true,
    this.locationTrackingEnabled = false,
    this.screenTimeTrackingEnabled = false,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PermissionSettings.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PermissionSettings(
      id: doc.id,
      parentId: data['parentId'] ?? '',
      childId: data['childId'],
      canViewActivities: data['canViewActivities'] ?? true,
      canViewLocation: data['canViewLocation'] ?? true,
      canViewScreenTime: data['canViewScreenTime'] ?? true,
      canViewMood: data['canViewMood'] ?? true,
      canEditChild: data['canEditChild'] ?? true,
      canSetLimits: data['canSetLimits'] ?? true,
      canViewReports: data['canViewReports'] ?? true,
      locationTrackingEnabled: data['locationTrackingEnabled'] ?? false,
      screenTimeTrackingEnabled: data['screenTimeTrackingEnabled'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'parentId': parentId,
      'childId': childId,
      'canViewActivities': canViewActivities,
      'canViewLocation': canViewLocation,
      'canViewScreenTime': canViewScreenTime,
      'canViewMood': canViewMood,
      'canEditChild': canEditChild,
      'canSetLimits': canSetLimits,
      'canViewReports': canViewReports,
      'locationTrackingEnabled': locationTrackingEnabled,
      'screenTimeTrackingEnabled': screenTimeTrackingEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
