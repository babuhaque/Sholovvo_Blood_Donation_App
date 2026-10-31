import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/blood_request.dart';
import '../models/user_profile.dart';
import '../models/request_response.dart';
import '../services/request_response_service.dart';
import '../services/location_service.dart';

class DonorDiscoveryScreen extends StatefulWidget {
  final BloodRequest request;

  const DonorDiscoveryScreen({super.key, required this.request});

  @override
  State<DonorDiscoveryScreen> createState() => _DonorDiscoveryScreenState();
}

class _DonorDiscoveryScreenState extends State<DonorDiscoveryScreen> {
  final RequestResponseService _responseService = RequestResponseService();
  String _selectedDistanceFilter = 'All'; // 'All', '5 km', '10 km'
  Position? _currentPosition;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    Position? pos = await LocationService.getCurrentPositionSafely();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _isLoadingLocation = false;
      });
    }
  }

  bool _isLocationFresh(DateTime? updatedAt) {
    if (updatedAt == null) return false;
    return DateTime.now().difference(updatedAt).inHours <= 24;
  }

  double? _calculateDistance(double? donorLat, double? donorLng, DateTime? updatedAt) {
    if (donorLat == null || donorLng == null || !_isLocationFresh(updatedAt)) return null;
    
    double refLat = _currentPosition?.latitude ?? widget.request.latitude ?? 0.0;
    double refLng = _currentPosition?.longitude ?? widget.request.longitude ?? 0.0;

    if (refLat == 0.0 && refLng == 0.0) return null;

    double distanceInMeters = Geolocator.distanceBetween(refLat, refLng, donorLat, donorLng);
    return distanceInMeters / 1000.0; // km
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Donors for ${widget.request.patientName} (${widget.request.bloodGroup})'),
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

          // Donor Responses Section (Accepted)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Donor Responses (Accepted)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<RequestResponse>>(
                    stream: _responseService.getResponsesForRequest(widget.request.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      final responses = snapshot.data ?? [];
                      final acceptedResponses = responses.where((r) => r.status == 'accepted').toList();

                      if (acceptedResponses.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('No donors have accepted this request yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        );
                      }

                      return ListView.builder(
                        itemCount: acceptedResponses.length,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemBuilder: (context, index) {
                          final resp = acceptedResponses[index];
                          return Card(
                            color: Colors.green.shade50,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                              title: Text(resp.donorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Blood: ${resp.bloodGroup} | Phone: ${resp.donorPhone}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.call, color: Colors.green),
                                onPressed: () async {
                                  final Uri uri = Uri(scheme: 'tel', path: resp.donorPhone);
                                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                                },
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
          ),
          const Divider(height: 1),

          // Matching Available Donors List
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Available ${widget.request.bloodGroup} Donors Nearby',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent),
                  ),
                ),
                Expanded(
                  child: _isLoadingLocation
                      ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .where('role', isEqualTo: 'donor')
                              .where('isAvailable', isEqualTo: true)
                              .where('bloodGroup', isEqualTo: widget.request.bloodGroup)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(child: Text('Error: ${snapshot.error}'));
                            }

                            final docs = snapshot.data?.docs ?? [];
                            List<Map<String, dynamic>> scoredDonors = [];

                            for (var doc in docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final donor = UserProfile.fromMap(data);

                              double? distanceKm = _calculateDistance(donor.latitude, donor.longitude, donor.locationUpdatedAt);

                              if (_selectedDistanceFilter == '5 km') {
                                if (distanceKm == null || distanceKm > 5.0) continue;
                              } else if (_selectedDistanceFilter == '10 km') {
                                if (distanceKm == null || distanceKm > 10.0) continue;
                              }

                              scoredDonors.add({
                                'donor': donor,
                                'distance': distanceKm,
                              });
                            }

                            scoredDonors.sort((a, b) {
                              double? distA = a['distance'] as double?;
                              double? distB = b['distance'] as double?;
                              if (distA == null && distB == null) return 0;
                              if (distA == null) return 1;
                              if (distB == null) return -1;
                              return distA.compareTo(distB);
                            });

                            if (scoredDonors.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.asset(
                                          'Images/download.png',
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.search_off, size: 64, color: Colors.grey),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No available donors found with fresh location within the selected distance filter.\n(Donors need to tap "Update GPS" in their profile)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: scoredDonors.length,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemBuilder: (context, index) {
                                final item = scoredDonors[index];
                                final UserProfile donor = item['donor'] as UserProfile;
                                final double? distance = item['distance'] as double?;

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red.shade100,
                                      child: Text(donor.bloodGroup, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(donor.fullName.isNotEmpty ? donor.fullName : 'Donor', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      distance != null
                                          ? 'Approx. ${distance.toStringAsFixed(1)} km away'
                                          : 'Location unavailable or stale (update required)',
                                      style: TextStyle(
                                        color: distance != null ? Colors.black87 : Colors.orange.shade800,
                                      ),
                                    ),
                                    trailing: const Chip(
                                      label: Text('Available', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      backgroundColor: Colors.green,
                                      padding: EdgeInsets.zero,
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
          ),
        ],
      ),
    );
  }
}
