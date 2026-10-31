import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/blood_request.dart';
import 'notification_service.dart';

class BloodRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Create blood request and trigger notifications to matching nearby donors
  Future<void> createRequest(BloodRequest request) async {
    try {
      DocumentReference docRef = await _firestore.collection('blood_requests').add(request.toMap());
      String requestId = docRef.id;

      // Trigger in-app notifications for matching available donors within 10 km with fresh location
      _notifyMatchingDonors(requestId, request);
    } catch (e) {
      throw 'Failed to create blood request: $e';
    }
  }

  Future<void> _notifyMatchingDonors(String requestId, BloodRequest request) async {
    try {
      QuerySnapshot donorSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'donor')
          .where('isAvailable', isEqualTo: true)
          .where('bloodGroup', isEqualTo: request.bloodGroup)
          .get();

      for (var doc in donorSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final donorUid = data['uid'] ?? doc.id;

        if (donorUid == request.userId) continue; // Skip creator

        double? lat = data['latitude'] != null ? (data['latitude'] as num).toDouble() : null;
        double? lng = data['longitude'] != null ? (data['longitude'] as num).toDouble() : null;
        Timestamp? updatedAt = data['locationUpdatedAt'] as Timestamp?;

        // Check location freshness (within 24 hours)
        bool isFresh = false;
        if (updatedAt != null) {
          DateTime updatedTime = updatedAt.toDate();
          if (DateTime.now().difference(updatedTime).inHours <= 24) {
            isFresh = true;
          }
        }

        // If location is fresh and valid, check 10km radius; otherwise notify if location missing or apply matching
        bool shouldNotify = false;
        if (lat != null && lng != null && isFresh && request.latitude != null && request.longitude != null) {
          double distMeters = Geolocator.distanceBetween(request.latitude!, request.longitude!, lat, lng);
          if (distMeters <= 10000) { // within 10 km
            shouldNotify = true;
          }
        } else {
          shouldNotify = true;
        }

        if (shouldNotify) {
          await _notificationService.createNotification(
            recipientUid: donorUid,
            requestId: requestId,
            type: 'new_request',
            title: 'New ${request.bloodGroup} Blood Request',
            body: '${request.patientName} needs ${request.bloodBags} bag(s) of blood.',
          );
        }
      }
    } catch (_) {
      // Suppress background notification dispatch errors
    }
  }

  // Get stream of requests created by a specific user
  Stream<List<BloodRequest>> getUserRequests(String userId) {
    return _firestore
        .collection('blood_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      List<BloodRequest> requests = snapshot.docs.map((doc) {
        return BloodRequest.fromMap(doc.data(), doc.id);
      }).toList();

      requests.sort((a, b) {
        if (a.createdAt == null || b.createdAt == null) return 0;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return requests;
    });
  }

  // Cancel request (update status to 'cancelled')
  Future<void> cancelRequest(String requestId) async {
    try {
      await _firestore.collection('blood_requests').doc(requestId).update({
        'status': 'cancelled',
      });
    } catch (e) {
      throw 'Failed to cancel request: $e';
    }
  }
}
