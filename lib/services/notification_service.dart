import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream notifications for a specific user
  Stream<List<AppNotification>> getUserNotifications(String uid) {
    return _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      List<AppNotification> notifications = snapshot.docs.map((doc) {
        return AppNotification.fromMap(doc.data(), doc.id);
      }).toList();

      // Sort by createdAt descending in memory
      notifications.sort((a, b) {
        if (a.createdAt == null || b.createdAt == null) return 0;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return notifications;
    });
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      throw 'Failed to mark notification as read: $e';
    }
  }

  // Create or idempotently re-raise a notification using a deterministic id.
  //
  // Idempotency is structural rather than read-then-write: the document id is
  // derived from the request/response pair, so a repeated submission targets the
  // same document and a merged write refreshes the content instead of creating a
  // duplicate. This is required because the security rules keep a notification
  // readable only by its recipient, so a sender must never need to get or query
  // the document before writing it.
  Future<void> createNotification({
    required String recipientUid,
    required String requestId,
    String? responseId,
    required String type,
    required String title,
    required String body,
  }) async {
    final String docId = (responseId == null || responseId.isEmpty)
        // One lifecycle notification per recipient, request and type.
        ? 'notif_req_${type}_${requestId}_$recipientUid'
        // A donor response raises exactly one notification for the recipient.
        : 'notif_resp_$responseId';

    AppNotification notification = AppNotification(
      id: docId,
      recipientUid: recipientUid,
      requestId: requestId,
      responseId: responseId,
      type: type,
      title: title,
      body: body,
      isRead: false,
    );

    try {
      await _firestore
          .collection('notifications')
          .doc(docId)
          .set(notification.toWriteMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: e.code,
        message: 'Failed to write $type notification $docId '
            'for recipient $recipientUid: ${e.message ?? e.code}',
      );
    }
  }
}
