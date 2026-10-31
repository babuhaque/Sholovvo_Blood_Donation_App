import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String recipientUid;
  final String requestId;
  final String? responseId;
  final String type; // 'new_request', 'donor_response'
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.recipientUid,
    required this.requestId,
    this.responseId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipientUid': recipientUid,
      'requestId': requestId,
      'responseId': responseId,
      'type': type,
      'title': title,
      'body': body,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, String docId) {
    return AppNotification(
      id: docId,
      recipientUid: map['recipientUid'] ?? '',
      requestId: map['requestId'] ?? '',
      responseId: map['responseId'],
      type: map['type'] ?? 'general',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
