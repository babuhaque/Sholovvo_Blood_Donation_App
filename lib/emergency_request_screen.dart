import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyRequestScreen extends StatefulWidget {
  const EmergencyRequestScreen({super.key});

  @override
  State<EmergencyRequestScreen> createState() => _EmergencyRequestScreenState();
}

class _EmergencyRequestScreenState extends State<EmergencyRequestScreen> {
  String? donorBloodGroup;
  GeoPoint? donorLocation;
  String donorName = '';
  String donorPhone = '';
  bool _isLoadingDonor = true;

  @override
  void initState() {
    super.initState();
    _loadDonorProfile();
  }

  Future<void> _loadDonorProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('donors').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          donorBloodGroup = data['bloodGroup'];
          donorLocation = data['location'];
          donorName = data['name'] ?? 'Donor';
          donorPhone = data['phone'] ?? '';
          _isLoadingDonor = false;
        });
        return;
      }
    }
    setState(() => _isLoadingDonor = false);
  }

  Future<void> _acceptRequest(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedBy': user.uid,
        'donorName': donorName,
        'donorPhone': donorPhone,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted successfully! Requester can now view your contact.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request rejected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Matching Requests (5 km)'),
        backgroundColor: Colors.redAccent,
      ),
      body: _isLoadingDonor
          ? const Center(child: CircularProgressIndicator())
          : donorBloodGroup == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Please complete your donor registration to view and accept matching requests within 5 km.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('requests')
                      .where('status', isEqualTo: 'active')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final docs = snapshot.data?.docs ?? [];

                    // Filter matching blood group and within 5 km (5000 meters)
                    List<QueryDocumentSnapshot> matchingDocs = [];
                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final reqBloodGroup = data['bloodGroup'];
                      final GeoPoint? reqLocation = data['location'];
                      final String reqUid = data['uid'] ?? '';

                      // Don't show user's own requests to themselves
                      if (reqUid == currentUserId) continue;

                      // 1. Blood group match check
                      if (reqBloodGroup != donorBloodGroup) continue;

                      // 2. 5 km distance check
                      if (reqLocation != null && donorLocation != null) {
                        double distanceInMeters = Geolocator.distanceBetween(
                          donorLocation!.latitude,
                          donorLocation!.longitude,
                          reqLocation.latitude,
                          reqLocation.longitude,
                        );
                        if (distanceInMeters <= 5000) {
                          matchingDocs.add(doc);
                        }
                      }
                    }

                    if (matchingDocs.isEmpty) {
                      return Center(
                        child: Text(
                          'No matching $donorBloodGroup requests found within 5 km.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: matchingDocs.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        final doc = matchingDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final requestId = doc.id;
                        final patientName = data['patientName'] ?? 'Unknown Patient';
                        final hospital = data['hospital'] ?? 'Unknown Hospital';
                        final bloodGroup = data['bloodGroup'] ?? 'A+';
                        final bags = data['bags'] ?? 1;
                        final reason = data['reason'] ?? '';

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      patientName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Text(
                                        bloodGroup,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.local_hospital, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        hospital,
                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.water_drop, size: 16, color: Colors.redAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Required Bags: $bags (Within 5 km)',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                if (reason.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Note: $reason',
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Reject'),
                                        onPressed: () => _rejectRequest(requestId),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Accept'),
                                        onPressed: () => _acceptRequest(requestId),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
