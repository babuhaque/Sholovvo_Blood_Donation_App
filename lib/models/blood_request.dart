import 'package:cloud_firestore/cloud_firestore.dart';

class BloodRequest {
  final String id;
  final String userId;
  final String patientName;
  final String phoneNumber;
  final String bloodGroup;
  final int bloodBags;
  final String hospitalName;
  final String hospitalAddress;
  final String requiredDateTime;
  final String requestType; // 'Normal' or 'Emergency'
  final String notes;
  final String status; // 'open', 'fulfilled', 'cancelled'
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;

  BloodRequest({
    required this.id,
    required this.userId,
    required this.patientName,
    required this.phoneNumber,
    required this.bloodGroup,
    required this.bloodBags,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.requiredDateTime,
    required this.requestType,
    required this.notes,
    required this.status,
    this.latitude,
    this.longitude,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'patientName': patientName,
      'phoneNumber': phoneNumber,
      'bloodGroup': bloodGroup,
      'bloodBags': bloodBags,
      'hospitalName': hospitalName,
      'hospitalAddress': hospitalAddress,
      'requiredDateTime': requiredDateTime,
      'requestType': requestType,
      'notes': notes,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory BloodRequest.fromMap(Map<String, dynamic> map, String docId) {
    return BloodRequest(
      id: docId,
      userId: map['userId'] ?? '',
      patientName: map['patientName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      bloodGroup: map['bloodGroup'] ?? 'A+',
      bloodBags: map['bloodBags'] ?? 1,
      hospitalName: map['hospitalName'] ?? '',
      hospitalAddress: map['hospitalAddress'] ?? '',
      requiredDateTime: map['requiredDateTime'] ?? '',
      requestType: map['requestType'] ?? 'Normal',
      notes: map['notes'] ?? '',
      status: map['status'] ?? 'open',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
