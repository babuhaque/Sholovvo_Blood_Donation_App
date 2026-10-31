import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_response.dart';
import 'notification_service.dart';

class RequestResponseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Collision-safe length-prefixed claim ID generator
  static String getClaimId(String requestId, String donorId) {
    return 'req_${requestId.length}_${requestId}_donor_${donorId.length}_$donorId';
  }

  // Submit or update a donor response (accept/decline) for a request using Firestore Transaction
  Future<void> submitResponse(RequestResponse response) async {
    try {
      if (response.status != 'accepted' && response.status != 'declined') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'invalid-argument',
          message: 'Invalid response status: must be either "accepted" or "declined".',
        );
      }

      // Query legacy responses before transaction
      final legacyQuery = await _firestore
          .collection('request_responses')
          .where('requestId', isEqualTo: response.requestId)
          .where('donorId', isEqualTo: response.donorId)
          .get();

      if (legacyQuery.docs.length > 1) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'aborted',
          message: 'Conflict Error: Multiple legacy response documents exist for this request and donor pair.',
        );
      }

      String claimId = getClaimId(response.requestId, response.donorId);
      DocumentReference claimRef = _firestore.collection('response_claims').doc(claimId);
      DocumentReference bloodReqRef = _firestore.collection('blood_requests').doc(response.requestId);

      String responseId = '';
      String creatorUid = '';

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot reqSnap = await transaction.get(bloodReqRef);
        if (!reqSnap.exists || reqSnap.data() == null) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'Blood request does not exist.',
          );
        }

        final reqData = reqSnap.data() as Map<String, dynamic>;
        creatorUid = reqData['userId'] ?? '';
        String requestStatus = reqData['status'] ?? 'open';

        if (creatorUid == response.donorId) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'You cannot respond to your own blood request.',
          );
        }
        if (requestStatus != 'open') {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message: 'Cannot respond to a request that is not open (Status: $requestStatus).',
          );
        }

        DocumentSnapshot claimSnap = await transaction.get(claimRef);

        if (claimSnap.exists) {
          // --- CASE A: EXISTING CLAIM ---
          final claimData = claimSnap.data() as Map<String, dynamic>;
          responseId = claimData['responseId'] ?? '';
          String claimReqId = claimData['requestId'] ?? '';
          String claimDonorId = claimData['donorId'] ?? '';

          if (responseId.isEmpty || claimReqId != response.requestId || claimDonorId != response.donorId) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'data-loss',
              message: 'Integrity Error: Claim data mismatch.',
            );
          }

          DocumentReference respRef = _firestore.collection('request_responses').doc(responseId);
          DocumentSnapshot respSnap = await transaction.get(respRef);

          if (!respSnap.exists) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'data-loss',
              message: 'Integrity Error: Claim exists but referenced response document is missing.',
            );
          }

          final respData = respSnap.data() as Map<String, dynamic>;
          if (respData['requestId'] != response.requestId || respData['donorId'] != response.donorId) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'data-loss',
              message: 'Integrity Error: Referenced response document fields do not match claim.',
            );
          }

          transaction.set(respRef, {
            'status': response.status,
            'donorName': response.donorName,
            'donorPhone': response.donorPhone,
          }, SetOptions(merge: true));
        } else if (legacyQuery.docs.isNotEmpty) {
          // --- CASE B: LEGACY RESPONSE ADOPTION ---
          responseId = legacyQuery.docs.first.id;
          DocumentReference respRef = _firestore.collection('request_responses').doc(responseId);

          transaction.set(respRef, {
            'status': response.status,
            'donorName': response.donorName,
            'donorPhone': response.donorPhone,
          }, SetOptions(merge: true));

          transaction.set(claimRef, {
            'requestId': response.requestId,
            'donorId': response.donorId,
            'responseId': responseId,
          }, SetOptions(merge: true));
        } else {
          // --- CASE C: FIRST-TIME SUBMISSION ---
          DocumentReference respRef = _firestore.collection('request_responses').doc();
          responseId = respRef.id;

          transaction.set(respRef, response.toMap());
          transaction.set(claimRef, {
            'requestId': response.requestId,
            'donorId': response.donorId,
            'responseId': responseId,
          });
        }
      });

      // 4. Separate response submission success from notification delivery failure
      try {
        await _notifyRequestCreator(response, responseId, creatorUid);
      } catch (notifError) {
        // Non-fatal warning log; response transaction is already successfully committed
        debugPrint('Warning: Response submitted successfully, but notification delivery failed: $notifError');
      }
    } catch (e) {
      if (e is FirebaseException) {
        rethrow;
      }
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unknown',
        message: 'Failed to submit response: $e',
      );
    }
  }

  Future<void> _notifyRequestCreator(RequestResponse response, String responseId, String creatorUid) async {
    if (creatorUid.isNotEmpty) {
      DocumentSnapshot reqDoc = await _firestore.collection('blood_requests').doc(response.requestId).get();
      String patientName = 'Patient';
      if (reqDoc.exists && reqDoc.data() != null) {
        patientName = (reqDoc.data() as Map<String, dynamic>)['patientName'] ?? 'Patient';
      }

      String actionText = response.status == 'accepted' ? 'accepted' : 'declined';
      await _notificationService.createNotification(
        recipientUid: creatorUid,
        requestId: response.requestId,
        responseId: responseId,
        type: 'donor_response',
        title: 'Donor Response (${response.bloodGroup})',
        body: '${response.donorName} has $actionText your request for $patientName.',
      );
    }
  }

  // Get stream of responses for a specific request
  Stream<List<RequestResponse>> getResponsesForRequest(String requestId) {
    return _firestore
        .collection('request_responses')
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RequestResponse.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // Get responses given by a specific donor
  Stream<List<RequestResponse>> getDonorResponses(String donorId) {
    return _firestore
        .collection('request_responses')
        .where('donorId', isEqualTo: donorId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RequestResponse.fromMap(doc.data(), doc.id)).toList();
    });
  }
}
