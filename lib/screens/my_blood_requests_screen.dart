import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blood_request.dart';
import '../services/blood_request_service.dart';
import '../services/notification_service.dart';
import 'create_blood_request_screen.dart';
import 'donor_discovery_screen.dart';

class MyBloodRequestsScreen extends StatelessWidget {
  const MyBloodRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BloodRequestService requestService = BloodRequestService();
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Blood Requests'), backgroundColor: Colors.redAccent),
        body: const Center(child: Text('Please log in to view your requests.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Blood Requests'),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Request',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateBloodRequestScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<BloodRequest>>(
        stream: requestService.getUserRequests(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.water_drop_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'You have not created any blood requests yet.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateBloodRequestScreen()),
                      );
                    },
                    child: const Text('Create Blood Request'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: requests.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final request = requests[index];
              bool isOpen = request.status == 'open';

              Color statusColor = Colors.green;
              if (request.status == 'cancelled') statusColor = Colors.grey;
              if (request.status == 'fulfilled') statusColor = Colors.blue;
              if (request.status == 'accepted') statusColor = Colors.orange;
              if (request.status == 'donation_completed') statusColor = Colors.deepOrange;

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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              request.bloodGroup,
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
                            'Bags: ${request.bloodBags} | Type: ${request.requestType}',
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
                      if (['accepted', 'donation_completed', 'fulfilled'].contains(request.status)) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.volunteer_activism, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  request.status == 'fulfilled'
                                      ? 'Donation confirmed. Thank you for helping!'
                                      : request.status == 'donation_completed'
                                          ? 'The donor marked this donation completed. Please confirm if the blood was received.'
                                          : request.assignedDonorId == null
                                              ? 'A donor has accepted this request.'
                                              : 'A donor has accepted this request. Donor ID: ${request.assignedDonorId}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (request.status == 'fulfilled') ...[
                        const SizedBox(height: 10),
                        _DonationRatingButton(request: request, recipientUid: currentUser.uid),
                      ],
                      if (request.status == 'donation_completed') ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.verified),
                            label: const Text('Confirm Donation Received'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Confirm Blood Donation'),
                                  content: const Text('Did you receive the blood donation from the assigned donor? Only confirm if the donation actually happened.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not yet')),
                                    ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Yes, confirm')),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              try {
                                final batch = FirebaseFirestore.instance.batch();
                                final requestRef = FirebaseFirestore.instance.collection('blood_requests').doc(request.id);
                                final donationRef = FirebaseFirestore.instance.collection('donation_history').doc(request.id);
                                batch.set(donationRef, {
                                  'donorUid': request.assignedDonorId,
                                  'bloodGroup': request.bloodGroup,
                                  'requestId': request.id,
                                  'hospitalName': request.hospitalName,
                                  'status': 'confirmed',
                                  'donationDate': FieldValue.serverTimestamp(),
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'confirmedBy': currentUser.uid,
                                });
                                batch.update(requestRef, {'status': 'fulfilled', 'fulfilledAt': FieldValue.serverTimestamp()});
                                await batch.commit();
                                // Notify the assigned donor after recipient confirmation.
                                if (request.assignedDonorId != null) {
                                  await NotificationService().createNotification(
                                    recipientUid: request.assignedDonorId!,
                                    requestId: request.id,
                                    type: 'donation_confirmed',
                                    title: 'Donation confirmed',
                                    body: 'The recipient confirmed your ${request.bloodGroup} blood donation. Thank you!',
                                  );
                                }
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donation confirmed successfully.')));
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not confirm donation: $e')));
                              }
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Chip(
                            label: Text(
                              request.status.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: statusColor,
                            padding: EdgeInsets.zero,
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                ),
                                icon: const Icon(Icons.people_outline, size: 16),
                                label: const Text('View Donors'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DonorDiscoveryScreen(request: request),
                                    ),
                                  );
                                },
                              ),
                              if (isOpen) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  icon: const Icon(Icons.cancel_outlined, size: 16),
                                  label: const Text('Cancel'),
                                  onPressed: () async {
                                    bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Cancel Request'),
                                        content: const Text('Are you sure you want to cancel this blood request?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('No'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        await requestService.cancelRequest(request.id);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Request cancelled successfully.')),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ],
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateBloodRequestScreen()),
          );
        },
      ),
    );
  }
}

class _DonationRatingButton extends StatefulWidget {
  final BloodRequest request; final String recipientUid;
  const _DonationRatingButton({required this.request, required this.recipientUid});
  @override State<_DonationRatingButton> createState() => _DonationRatingButtonState();
}
class _DonationRatingButtonState extends State<_DonationRatingButton> {
  bool _loading = false;
  Future<void> _rateDonation() async {
    int stars = 5; final controller = TextEditingController();
    final rating = await showDialog<int>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Rate Blood Donor'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('How was your donation experience?'),
          DropdownButtonFormField<int>(value: stars, decoration: const InputDecoration(labelText: 'Star rating'),
            items: List.generate(5, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('$v Stars'))).toList(),
            onChanged: (v) => setDialogState(() => stars = v ?? 5)),
          const SizedBox(height: 12),
          TextField(controller: controller, maxLength: 300, maxLines: 3, decoration: const InputDecoration(labelText: 'Review (optional)', border: OutlineInputBorder())),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, stars), child: const Text('Submit'))],
      )));
    if (rating == null) { controller.dispose(); return; }
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('donation_ratings').doc(widget.request.id).set({
        'requestId': widget.request.id, 'donorUid': widget.request.assignedDonorId,
        'recipientUid': widget.recipientUid, 'stars': rating, 'review': controller.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you! Your rating has been submitted.')));
    } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit rating: $e'))); }
    finally { controller.dispose(); if (mounted) setState(() => _loading = false); }
  }
  @override Widget build(BuildContext context) {
    if (widget.request.assignedDonorId == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('donation_ratings').doc(widget.request.id).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.data?.exists ?? false) {
          final stars = snapshot.data?.data()?['stars'];
          return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.star, color: Colors.amber),
            title: Text(stars is int ? 'You rated this donor: $stars/5' : 'You rated this donor'));
        }
        return SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _loading ? null : _rateDonation,
          icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.star_outline),
          label: const Text('Rate Donor')));
      });
  }
}
