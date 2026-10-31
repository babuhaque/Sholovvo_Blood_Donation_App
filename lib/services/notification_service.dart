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

  // Create a notification using an atomic transaction to ensure idempotency and prevent duplicate writes
  Future<void> createNotification({
    required String recipientUid,
    required String requestId,
    String? responseId,
    required String type,
    required String title,
    required String body,
  }) async {
    if (responseId == null || responseId.isEmpty) {
      // Fallback for legacy new_request notifications using random IDs
      try {
        final existing = await _firestore
            .collection('notifications')
            .where('recipientUid', isEqualTo: recipientUid)
            .where('requestId', isEqualTo: requestId)
            .where('type', isEqualTo: type)
            .get();

        if (existing.docs.isEmpty) {
          AppNotification notification = AppNotification(
            id: '',
            recipientUid: recipientUid,
            requestId: requestId,
            type: type,
            title: title,
            body: body,
            isRead: false,
          );
          await _firestore.collection('notifications').add(notification.toMap());
        }
      } catch (e) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'notification-error',
          message: 'Failed to create legacy notification: $e',
        );
      }
      return;
    }

    String docId = 'notif_resp_$responseId';
    DocumentReference notifRef = _firestore.collection('notifications').doc(docId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot notifSnap = await transaction.get(notifRef);

      if (notifSnap.exists) {
        final data = notifSnap.data() as Map<String, dynamic>;
        if (data['responseId'] == responseId &&
            data['requestId'] == requestId &&
            data['recipientUid'] == recipientUid &&
            data['type'] == type) {
          return; // Valid duplicate; idempotent return without overwriting isRead
        } else {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'data-loss',
            message: 'Integrity Error: Existing notification relationship mismatch for $docId.',
          );
        }
      }

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

      transaction.set(notifRef, notification.toMap());
    });
  }
}
