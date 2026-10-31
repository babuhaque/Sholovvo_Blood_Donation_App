import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/blood_request.dart';
import '../models/user_profile.dart';
import '../models/request_response.dart';
import '../services/request_response_service.dart';
import '../services/profile_service.dart';

class NearbyBloodRequestsScreen extends StatefulWidget {
  const NearbyBloodRequestsScreen({super.key});

  @override
  State<NearbyBloodRequestsScreen> createState() => _NearbyBloodRequestsScreenState();
}

class _NearbyBloodRequestsScreenState extends State<NearbyBloodRequestsScreen> {
  final RequestResponseService _responseService = RequestResponseService();
  final ProfileService _profileService = ProfileService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  UserProfile? _donorProfile;
  bool _isLoading = true;
  String _selectedDistanceFilter = 'All'; // 'All', '5 km', '10 km'

  @override
  void initState() {
    super.initState();
    _loadDonorProfile();
  }

  Future<void> _loadDonorProfile() async {
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      UserProfile? profile = await _profileService.getProfile(_currentUser.uid);
      setState(() {
        _donorProfile = profile;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  double? _calculateDistance(double? reqLat, double? reqLng) {
    if (reqLat == null || reqLng == null) return null;
    if (_donorProfile?.latitude == null || _donorProfile?.longitude == null) return null;

    double distanceInMeters = Geolocator.distanceBetween(
      _donorProfile!.latitude!,
      _donorProfile!.longitude!,
      reqLat,
      reqLng,
    );
    return distanceInMeters / 1000.0; // km
  }

  Future<void> _respondToRequest(BloodRequest request, String status) async {
    if (_donorProfile == null) return;

    try {
      RequestResponse response = RequestResponse(
        id: '',
        requestId: request.id,
        donorId: _donorProfile!.uid,
        donorName: _donorProfile!.fullName,
        donorPhone: _donorProfile!.phoneNumber,
        bloodGroup: _donorProfile!.bloodGroup,
        status: status,
      );

      await _responseService.submitResponse(response);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'accepted' ? 'You accepted this request.' : 'You declined this request.'),
          backgroundColor: status == 'accepted' ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nearby Blood Requests'), backgroundColor: Colors.redAccent),
        body: const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    if (_donorProfile == null || _donorProfile!.role != 'donor' || !_donorProfile!.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nearby Blood Requests'), backgroundColor: Colors.redAccent),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _donorProfile == null
                  ? 'Please complete your donor profile first.'
                  : _donorProfile!.role != 'donor'
                      ? 'Only users with role "donor" can view and respond to blood requests.'
                      : 'You are currently offline (Availability is turned off in your profile).',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Nearby Requests (${_donorProfile!.bloodGroup})'),
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
        children: [
          // Distance Filter Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filter Distance:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ToggleButtons(
                  isSelected: [
                    _selectedDistanceFilter == 'All',
                    _selectedDistanceFilter == '5 km',
                    _selectedDistanceFilter == '10 km',
                  ],
                  onPressed: (index) {
                    setState(() {
                      if (index == 0) _selectedDistanceFilter = 'All';
                      if (index == 1) _selectedDistanceFilter = '5 km';
                      if (index == 2) _selectedDistanceFilter = '10 km';
                    });
                  },
                  color: Colors.redAccent,
                  selectedColor: Colors.white,
                  fillColor: Colors.redAccent,
                  borderRadius: BorderRadius.circular(8),
                  constraints: const BoxConstraints(minHeight: 36, minWidth: 70),
                  children: const [
                    Text('All'),
                    Text('5 km'),
                    Text('10 km'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('blood_requests')
                  .where('status', isEqualTo: 'open')
                  .where('bloodGroup', isEqualTo: _donorProfile!.bloodGroup)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                List<Map<String, dynamic>> validRequests = [];

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final request = BloodRequest.fromMap(data, doc.id);

                  if (request.userId == _donorProfile!.uid) continue;

                  double? distanceKm = _calculateDistance(request.latitude, request.longitude);

                  if (_selectedDistanceFilter == '5 km') {
                    if (distanceKm == null || distanceKm > 5.0) continue;
                  } else if (_selectedDistanceFilter == '10 km') {
                    if (distanceKm == null || distanceKm > 10.0) continue;
                  }

                  validRequests.add({
                    'request': request,
                    'distance': distanceKm,
                  });
                }

                validRequests.sort((a, b) {
                  double? distA = a['distance'] as double?;
                  double? distB = b['distance'] as double?;
                  if (distA == null && distB == null) return 0;
                  if (distA == null) return 1;
                  if (distB == null) return -1;
                  return distA.compareTo(distB);
                });

                if (validRequests.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No open matching blood requests found within the selected distance filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: validRequests.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final item = validRequests[index];
                    final BloodRequest request = item['request'] as BloodRequest;
                    final double? distance = item['distance'] as double?;

                    return Card(
                      elevation: 3,
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
                                  request.patientName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: request.requestType == 'Emergency' ? Colors.red : Colors.redAccent,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    '${request.bloodGroup} • ${request.requestType}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                                    '${request.hospitalName} - ${request.hospitalAddress}',
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
                                  'Bags: ${request.bloodBags} | Distance: ${distance != null ? '${distance.toStringAsFixed(1)} km' : 'Unknown'}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Required: ${request.requiredDateTime}',
                                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                                ),
                              ],
                            ),
                            if (request.notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Notes: ${request.notes}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                            const SizedBox(height: 16),
                            StreamBuilder<List<RequestResponse>>(
                              stream: _responseService.getResponsesForRequest(request.id),
                              builder: (context, respSnapshot) {
                                final responses = respSnapshot.data ?? [];
                                final myResponse = responses.cast<RequestResponse?>().firstWhere(
                                      (r) => r?.donorId == _donorProfile?.uid,
                                      orElse: () => null,
                                    );

                                if (myResponse != null) {
                                  return Row(
                                    children: [
                                      Icon(
                                        myResponse.status == 'accepted' ? Icons.check_circle : Icons.cancel,
                                        color: myResponse.status == 'accepted' ? Colors.green : Colors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'You have ${myResponse.status.toUpperCase()} this request.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: myResponse.status == 'accepted' ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey.shade700,
                                          side: BorderSide(color: Colors.grey.shade400),
                                        ),
                                        icon: const Icon(Icons.close, size: 16),
                                        label: const Text('Decline'),
                                        onPressed: () => _respondToRequest(request, 'declined'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('Accept'),
                                        onPressed: () => _respondToRequest(request, 'accepted'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
