import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save or update profile with separation of public discovery data and private sensitive PII
  Future<void> saveProfile(UserProfile profile) async {
    try {
      // 1. Save public discovery profile at /users/{uid}
      await _firestore.collection('users').doc(profile.uid).set(
            profile.toPublicMap(),
            SetOptions(merge: true),
          );

      // 2. Save private sensitive PII at /users/{uid}/private/sensitive
      await _firestore
          .collection('users')
          .doc(profile.uid)
          .collection('private')
          .doc('sensitive')
          .set(profile.toPrivateMap(), SetOptions(merge: true));
    } catch (e) {
      throw 'Failed to save profile: $e';
    }
  }

  // Get profile by UID with robust, independent, non-destructive legacy fallback & safe auto-migration
  Future<UserProfile?> getProfile(String uid) async {
    try {
      DocumentSnapshot publicDoc = await _firestore.collection('users').doc(uid).get();
      if (!publicDoc.exists || publicDoc.data() == null) {
        return null;
      }

      final publicData = publicDoc.data() as Map<String, dynamic>;

      DocumentSnapshot? privateDoc;
      try {
        privateDoc = await _firestore
            .collection('users')
            .doc(uid)
            .collection('private')
            .doc('sensitive')
            .get();
      } catch (_) {
        // Fallback if private subcollection read fails due to rules or network
      }

      Map<String, dynamic>? privateData;
      if (privateDoc != null && privateDoc.exists && privateDoc.data() != null) {
        privateData = Map<String, dynamic>.from(privateDoc.data() as Map<String, dynamic>);
      }

      // Check legacy fields independently (phoneNumber, email, dateOfBirth)
      bool hasLegacyPhone = publicData.containsKey('phoneNumber') && (publicData['phoneNumber']?.toString().isNotEmpty ?? false);
      bool hasLegacyEmail = publicData.containsKey('email') && (publicData['email']?.toString().isNotEmpty ?? false);
      bool hasLegacyDob = publicData.containsKey('dateOfBirth') && (publicData['dateOfBirth']?.toString().isNotEmpty ?? false);

      if (hasLegacyPhone || hasLegacyEmail || hasLegacyDob) {
        privateData ??= {};
        bool needsSave = false;

        // Never overwrite an existing non-empty private field with legacy public data
        if (hasLegacyPhone && (privateData['phoneNumber'] == null || (privateData['phoneNumber'] as String).isEmpty)) {
          privateData['phoneNumber'] = publicData['phoneNumber'];
          needsSave = true;
        }
        if (hasLegacyEmail && (privateData['email'] == null || (privateData['email'] as String).isEmpty)) {
          privateData['email'] = publicData['email'];
          needsSave = true;
        }
        if (hasLegacyDob && (privateData['dateOfBirth'] == null || (privateData['dateOfBirth'] as String).isEmpty)) {
          privateData['dateOfBirth'] = publicData['dateOfBirth'];
          needsSave = true;
        }

        if (needsSave || (privateDoc == null || !privateDoc.exists)) {
          // 1. Ensure private copy is successfully written first
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('private')
              .doc('sensitive')
              .set(privateData, SetOptions(merge: true));
        }

        // 2. Only after private write succeeds, safely clean up legacy fields from public doc non-destructively
        Map<String, dynamic> updates = {};
        if (hasLegacyPhone) updates['phoneNumber'] = FieldValue.delete();
        if (hasLegacyEmail) updates['email'] = FieldValue.delete();
        if (hasLegacyDob) updates['dateOfBirth'] = FieldValue.delete();

        if (updates.isNotEmpty) {
          try {
            await _firestore.collection('users').doc(uid).update(updates);
          } catch (_) {}
        }
      }

      return UserProfile.fromMaps(publicData, privateData);
    } catch (e) {
      throw 'Failed to load profile: $e';
    }
  }

  // Reconcile donor availability with the 90-day recovery interval.
  // This runs when the donor opens their profile; true background scheduling
  // requires a trusted server-side scheduled function.
  Future<bool?> refreshDonationAvailability(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      if ((data['role'] ?? 'donor') != 'donor') return false;

      final rawDate = (data['lastDonationDate'] ?? '').toString().trim();
      if (rawDate.isEmpty) return data['isAvailable'] == true;

      final lastDonation = DateTime.tryParse(rawDate);
      if (lastDonation == null) return data['isAvailable'] == true;

      final eligible = !lastDonation.isAfter(DateTime.now()) &&
          DateTime.now().difference(lastDonation).inDays >= 90;
      final current = data['isAvailable'] == true;

      if (eligible && !current) {
        await doc.reference.update({'isAvailable': true});
        return true;
      }
      if (!eligible && current) {
        await doc.reference.update({'isAvailable': false});
        return false;
      }
      return current;
    } catch (e) {
      throw 'Failed to refresh donation availability: $e';
    }
  }

  // Update only availability status immediately
  Future<void> updateAvailability(String uid, bool isAvailable) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isAvailable': isAvailable,
      });
    } catch (e) {
      throw 'Failed to update availability: $e';
    }
  }

  // Update GPS location and timestamp
  Future<void> updateLocation(String uid, double latitude, double longitude) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'latitude': latitude,
        'longitude': longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update location: $e';
    }
  }
}
