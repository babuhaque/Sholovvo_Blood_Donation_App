import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime? createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.authorUid,
    required this.authorName,
    required this.text,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorUid': authorUid,
      'authorName': authorName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map, String docId) {
    return Comment(
      id: docId,
      postId: map['postId'] ?? '',
      authorUid: map['authorUid'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      text: map['text'] ?? '',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
