import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyAcceptedRequestsScreen extends StatelessWidget {
  const MyAcceptedRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Accepted Requests'),
        backgroundColor: Colors.redAccent,
      ),
      body: user == null
          ? const Center(child: Text('Please log in to continue.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('blood_requests')
                  .where('assignedDonorId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'accepted')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Could not load accepted requests: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volunteer_activism_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'You have no accepted blood requests yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final patientName = (data['patientName'] ?? 'Patient').toString();
                    final bloodGroup = (data['bloodGroup'] ?? '').toString();
                    final hospitalName = (data['hospitalName'] ?? '').toString();
                    final hospitalAddress = (data['hospitalAddress'] ?? '').toString();
                    final bags = data['bloodBags'] ?? 1;
                    final phone = (data['phoneNumber'] ?? '').toString();
                    final requiredAt = (data['requiredDateTime'] ?? '').toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    patientName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Chip(
                                  label: Text(bloodGroup),
                                  backgroundColor: Colors.red.shade50,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Hospital: $hospitalName'),
                            if (hospitalAddress.isNotEmpty) Text('Address: $hospitalAddress'),
                            Text('Blood bags: $bags'),
                            if (requiredAt.isNotEmpty) Text('Required: $requiredAt'),
                            if (phone.isNotEmpty) Text('Recipient phone: $phone'),
                            const SizedBox(height: 10),
                            const Text(
                              'You are the donor assigned to this request.',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
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
