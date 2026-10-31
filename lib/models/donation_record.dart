import 'package:cloud_firestore/cloud_firestore.dart';

class DonationRecord {
  final String id;
  final String donorUid;
  final String bloodGroup;
  final String? requestId;
  final String hospitalName;
  final String status; // 'confirmed' (verified) or 'pending' (unverified)
  final DateTime? donationDate;
  final DateTime? createdAt;

  DonationRecord({
    required this.id,
    required this.donorUid,
    required this.bloodGroup,
    this.requestId,
    required this.hospitalName,
    required this.status,
    this.donationDate,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'donorUid': donorUid,
      'bloodGroup': bloodGroup,
      'requestId': requestId,
      'hospitalName': hospitalName,
      'status': status, // 'confirmed' or 'pending'
      'donationDate': donationDate != null ? Timestamp.fromDate(donationDate!) : FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory DonationRecord.fromMap(Map<String, dynamic> map, String docId) {
    return DonationRecord(
      id: docId,
      donorUid: map['donorUid'] ?? '',
      bloodGroup: map['bloodGroup'] ?? 'A+',
      requestId: map['requestId'],
      hospitalName: map['hospitalName'] ?? '',
      status: map['status'] ?? 'pending',
      donationDate: map['donationDate'] != null ? (map['donationDate'] as Timestamp).toDate() : null,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
