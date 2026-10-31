import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donation_record.dart';

class DonationHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream donation records for a specific donor
  Stream<List<DonationRecord>> getDonorDonations(String donorUid) {
    return _firestore
        .collection('donation_history')
        .where('donorUid', isEqualTo: donorUid)
        .snapshots()
        .map((snapshot) {
      List<DonationRecord> records = snapshot.docs.map((doc) {
        return DonationRecord.fromMap(doc.data(), doc.id);
      }).toList();

      records.sort((a, b) {
        if (a.donationDate == null || b.donationDate == null) return 0;
        return b.donationDate!.compareTo(a.donationDate!);
      });

      return records;
    });
  }

  // Add a donation record with validation (forces status to 'pending' for security)
  Future<void> addDonationRecord(DonationRecord record) async {
    try {
      if (record.hospitalName.trim().isEmpty) {
        throw 'Hospital name cannot be empty.';
      }
      if (record.donorUid.trim().isEmpty) {
        throw 'Invalid donor UID.';
      }
      if (record.donationDate != null && record.donationDate!.isAfter(DateTime.now())) {
        throw 'Donation date cannot be in the future.';
      }

      final secureRecord = DonationRecord(
        id: '',
        donorUid: record.donorUid,
        bloodGroup: record.bloodGroup,
        requestId: record.requestId,
        hospitalName: record.hospitalName.trim(),
        status: 'pending', // Client submissions are always pending until verified by backend/admin
        donationDate: record.donationDate,
      );

      await _firestore.collection('donation_history').add(secureRecord.toMap());
    } catch (e) {
      throw 'Failed to add donation record: $e';
    }
  }
}
