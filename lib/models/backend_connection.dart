class BackendConnectionToken {
  final String token;
  final String childRole;
  final String? parentId;
  final String? parentUid;
  final String? connectedUserId;
  final String? connectedUserUid;
  final String status;
  final String? childId;
  final String? childName;
  final String? inviteeName;
  final String? inviteeContact;
  final String? delegateName;
  final String? createdAt;
  final String? expiresAt;
  final bool isUsed;

  const BackendConnectionToken({
    required this.token,
    required this.childRole,
    required this.isUsed,
    this.status = 'PENDING',
    this.childId,
    this.childName,
    this.inviteeName,
    this.inviteeContact,
    this.delegateName,
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
      childRole: (json['child_role'] as String?) ?? 'delegasi',
      parentId: json['parent_id']?.toString(),
      parentUid: json['parent_uid']?.toString(),
      status:
          (json['status'] as String?) ??
          (connectedUserId == null ? 'PENDING' : 'ACTIVE'),
      childId: json['child_id']?.toString(),
      childName: json['child_name']?.toString(),
      inviteeName: json['invitee_name']?.toString(),
      inviteeContact: json['invitee_contact']?.toString(),
      delegateName: json['delegate_name']?.toString(),
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
  final String status;
  final bool approved;
  final String? token;
  final String? parentId;
  final String? parentUid;
  final String? childRole;
  final String? childId;
  final String? childName;
  final String? connectedUserId;
  final String? connectedUserUid;
  final String? createdAt;
  final String? expiresAt;

  const BackendConnectionStatus({
    required this.connected,
    required this.message,
    this.status = 'PENDING',
    this.approved = false,
    this.token,
    this.parentId,
    this.parentUid,
    this.childRole,
    this.childId,
    this.childName,
    this.connectedUserId,
    this.connectedUserUid,
    this.createdAt,
    this.expiresAt,
  });

  factory BackendConnectionStatus.fromJson(Map<String, dynamic> json) {
    return BackendConnectionStatus(
      connected: json['connected'] == true,
      message: (json['message'] as String?) ?? '',
      status:
          (json['status'] as String?) ??
          (json['connected'] == true ? 'ACTIVE' : 'PENDING'),
      approved: json['approved'] == true,
      token: json['token']?.toString(),
      parentId: json['parent_id']?.toString(),
      childId: json['child_id']?.toString(),
      childName: json['child_name']?.toString(),
      parentUid: json['parent_uid']?.toString(),
      childRole: json['child_role']?.toString(),
      connectedUserId: json['connected_user_id']?.toString(),
      connectedUserUid: json['connected_user_uid']?.toString(),
      createdAt: json['created_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
    );
  }
}

class BackendDelegationInvitation {
  final String token;
  final String parentName;
  final String childName;
  final String childId;
  final String? inviteeName;

  const BackendDelegationInvitation({
    required this.token,
    required this.parentName,
    required this.childName,
    required this.childId,
    this.inviteeName,
  });

  factory BackendDelegationInvitation.fromJson(Map<String, dynamic> json) {
    return BackendDelegationInvitation(
      token: (json['token'] as String?) ?? '',
      parentName: (json['parent_name'] as String?) ?? 'Orang Tua',
      childName: (json['child_name'] as String?) ?? 'Anak',
      childId: json['child_id']?.toString() ?? '',
      inviteeName: json['invitee_name']?.toString(),
    );
  }
}
