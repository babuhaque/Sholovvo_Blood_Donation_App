import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorUid;
  final String authorName;
  final String authorEmail;
  final String text;
  final String? imageUrl;
  final int likeCount;
  final DateTime? createdAt;
  final String? donationRecordId;

  Post({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorEmail,
    required this.text,
    this.imageUrl,
    required this.likeCount,
    this.createdAt,
    this.donationRecordId,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'authorEmail': authorEmail,
      'text': text,
      'imageUrl': imageUrl,
      'likeCount': likeCount,
      'createdAt': FieldValue.serverTimestamp(),
      if (donationRecordId != null) 'donationRecordId': donationRecordId,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map, String docId) {
    return Post(
      id: docId,
      authorUid: map['authorUid'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      authorEmail: map['authorEmail'] ?? '',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'],
      likeCount: map['likeCount'] ?? 0,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      donationRecordId: map['donationRecordId'],
    );
  }
}
