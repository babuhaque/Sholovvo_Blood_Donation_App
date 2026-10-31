import 'package:cloud_firestore/cloud_firestore.dart';

class RequestResponse {
  final String id;
  final String requestId;
  final String donorId;
  final String donorName;
  final String donorPhone;
  final String bloodGroup;
  final String status; // 'accepted' or 'declined'
  final DateTime? createdAt;

  RequestResponse({
    required this.id,
    required this.requestId,
    required this.donorId,
    required this.donorName,
    required this.donorPhone,
    required this.bloodGroup,
    required this.status,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'donorId': donorId,
      'donorName': donorName,
      'donorPhone': donorPhone,
      'bloodGroup': bloodGroup,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory RequestResponse.fromMap(Map<String, dynamic> map, String docId) {
    return RequestResponse(
      id: docId,
      requestId: map['requestId'] ?? '',
      donorId: map['donorId'] ?? '',
      donorName: map['donorName'] ?? 'Donor',
      donorPhone: map['donorPhone'] ?? '',
      bloodGroup: map['bloodGroup'] ?? 'A+',
      status: map['status'] ?? 'accepted',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
