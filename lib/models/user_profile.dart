import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String fullName;
  final String phoneNumber;
  final String email;
  final String dateOfBirth;
  final String bloodGroup;
  final String gender;
  final String lastDonationDate;
  final String role; // 'donor' or 'recipient'
  final bool isAvailable;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;

  UserProfile({
    required this.uid,
    required this.fullName,
    required this.phoneNumber,
    required this.email,
    required this.dateOfBirth,
    required this.bloodGroup,
    required this.gender,
    required this.lastDonationDate,
    required this.role,
    required this.isAvailable,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
  });

  Map<String, dynamic> toPublicMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'bloodGroup': bloodGroup,
      'gender': gender,
      'lastDonationDate': lastDonationDate,
      'role': role,
      'isAvailable': isAvailable,
      'latitude': latitude,
      'longitude': longitude,
      'locationUpdatedAt': locationUpdatedAt != null ? Timestamp.fromDate(locationUpdatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toPrivateMap() {
    return {
      'phoneNumber': phoneNumber,
      'email': email,
      'dateOfBirth': dateOfBirth,
    };
  }

  Map<String, dynamic> toMap() {
    final map = toPublicMap();
    map.addAll(toPrivateMap());
    return map;
  }

  factory UserProfile.fromMaps(Map<String, dynamic> publicMap, Map<String, dynamic>? privateMap) {
    return UserProfile(
      uid: publicMap['uid'] ?? '',
      fullName: publicMap['fullName'] ?? '',
      phoneNumber: privateMap?['phoneNumber'] ?? publicMap['phoneNumber'] ?? '',
      email: privateMap?['email'] ?? publicMap['email'] ?? '',
      dateOfBirth: privateMap?['dateOfBirth'] ?? publicMap['dateOfBirth'] ?? '',
      bloodGroup: publicMap['bloodGroup'] ?? 'A+',
      gender: publicMap['gender'] ?? 'Male',
      lastDonationDate: publicMap['lastDonationDate'] ?? '',
      role: publicMap['role'] ?? 'donor',
      isAvailable: publicMap['isAvailable'] ?? true,
      latitude: publicMap['latitude'] != null ? (publicMap['latitude'] as num).toDouble() : null,
      longitude: publicMap['longitude'] != null ? (publicMap['longitude'] as num).toDouble() : null,
      locationUpdatedAt: publicMap['locationUpdatedAt'] != null ? (publicMap['locationUpdatedAt'] as Timestamp).toDate() : null,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile.fromMaps(map, map);
  }
}
