import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('family_notifications');

  static Future<String> sendNotification({
    required String parentId,
    required String childProfileId,
    required String recipientUid,
    required String childName,
    required String title,
    required String body,
    required String kind,
  }) async {
    final doc = _collection.doc();
    await doc.set({
      'parentId': parentId,
      'childProfileId': childProfileId,
      'recipientUid': recipientUid,
      'childName': childName,
      'title': title.trim(),
      'body': body.trim(),
      'kind': kind,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
    return doc.id;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamReceived(
    String recipientUid,
  ) {
    return _collection
        .where('recipientUid', isEqualTo: recipientUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamSent(
    String parentId,
  ) {
    return _collection
        .where('parentId', isEqualTo: parentId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> markAsRead(String notificationId) async {
    await _collection.doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }
}
