import 'package:cloud_firestore/cloud_firestore.dart';

/// Invite code untuk remaja agar parent bisa connect
/// Child generate kode unik, parent input kode untuk connect
class InviteCode {
  final String id;
  final String childId; // Child yang generate kode
  final String code; // Kode unik 6-8 karakter
  final String status; // 'unused', 'used', 'expired'
  final String? connectedParentId; // Null jika belum dipakai
  final DateTime createdAt;
  final DateTime? usedAt;
  final DateTime expiresAt; // Kode expired setelah X hari

  InviteCode({
    required this.id,
    required this.childId,
    required this.code,
    this.status = 'unused',
    this.connectedParentId,
    DateTime? createdAt,
    this.usedAt,
    DateTime? expiresAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       expiresAt = expiresAt ?? DateTime.now().add(const Duration(days: 30));

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => status == 'unused' && !isExpired;

  factory InviteCode.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return InviteCode(
      id: doc.id,
      childId: data['childId'] ?? '',
      code: data['code'] ?? '',
      status: data['status'] ?? 'unused',
      connectedParentId: data['connectedParentId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 30)),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'childId': childId,
      'code': code,
      'status': status,
      'connectedParentId': connectedParentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  InviteCode copyWith({
    String? id,
    String? childId,
    String? code,
    String? status,
    String? connectedParentId,
    DateTime? createdAt,
    DateTime? usedAt,
    DateTime? expiresAt,
  }) {
    return InviteCode(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      code: code ?? this.code,
      status: status ?? this.status,
      connectedParentId: connectedParentId ?? this.connectedParentId,
      createdAt: createdAt ?? this.createdAt,
      usedAt: usedAt ?? this.usedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
