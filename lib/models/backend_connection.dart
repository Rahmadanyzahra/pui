class BackendConnectionToken {
  final String token;
  final String childRole;
  final String? parentId;
  final String? parentUid;
  final String? connectedUserId;
  final String? connectedUserUid;
  final String? createdAt;
  final String? expiresAt;
  final bool isUsed;

  const BackendConnectionToken({
    required this.token,
    required this.childRole,
    required this.isUsed,
    this.parentId,
    this.parentUid,
    this.connectedUserId,
    this.connectedUserUid,
    this.createdAt,
    this.expiresAt,
  });

  factory BackendConnectionToken.fromJson(Map<String, dynamic> json) {
    final connectedUserId = json['connected_user_id']?.toString();
    final connectedUserUid = json['connected_user_uid']?.toString();

    return BackendConnectionToken(
      token: (json['token'] as String?) ?? '',
      childRole: (json['child_role'] as String?) ?? 'delegated_parent',
      parentId: json['parent_id']?.toString(),
      parentUid: json['parent_uid']?.toString(),
      connectedUserId: connectedUserId,
      connectedUserUid: connectedUserUid,
      createdAt: json['created_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      isUsed: connectedUserId != null || connectedUserUid != null,
    );
  }
}

class BackendConnectionStatus {
  final bool connected;
  final String message;
  final String? token;
  final String? parentId;
  final String? parentUid;
  final String? childRole;
  final String? connectedUserId;
  final String? connectedUserUid;
  final String? createdAt;
  final String? expiresAt;

  const BackendConnectionStatus({
    required this.connected,
    required this.message,
    this.token,
    this.parentId,
    this.parentUid,
    this.childRole,
    this.connectedUserId,
    this.connectedUserUid,
    this.createdAt,
    this.expiresAt,
  });

  factory BackendConnectionStatus.fromJson(Map<String, dynamic> json) {
    return BackendConnectionStatus(
      connected: json['connected'] == true,
      message: (json['message'] as String?) ?? '',
      token: json['token']?.toString(),
      parentId: json['parent_id']?.toString(),
      parentUid: json['parent_uid']?.toString(),
      childRole: json['child_role']?.toString(),
      connectedUserId: json['connected_user_id']?.toString(),
      connectedUserUid: json['connected_user_uid']?.toString(),
      createdAt: json['created_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
    );
  }
}
