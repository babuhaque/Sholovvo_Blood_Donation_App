import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  void _showPostRequestDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final TextEditingController patientNameController = TextEditingController();
    final TextEditingController hospitalController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController bagsController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    String selectedBloodGroup = 'A+';
    final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Broadcast SOS Request'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Form(
                  key: formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      TextFormField(
                        controller: patientNameController,
                        decoration: const InputDecoration(labelText: 'Patient Name'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedBloodGroup,
                        decoration: const InputDecoration(labelText: 'Blood Group'),
                        items: bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setDialogState(() => selectedBloodGroup = v!),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: hospitalController,
                        decoration: const InputDecoration(labelText: 'Hospital Name & Address'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: bagsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Bags Required'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Contact Phone'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: reasonController,
                        decoration: const InputDecoration(labelText: 'Reason / Note'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final user = FirebaseAuth.instance.currentUser;
                      GeoPoint geoPoint = const GeoPoint(23.8103, 90.4125);
                      try {
                        Position pos = await Geolocator.getCurrentPosition(
                          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                        );
                        geoPoint = GeoPoint(pos.latitude, pos.longitude);
                      } catch (_) {}

                      await FirebaseFirestore.instance.collection('requests').add({
                        'uid': user?.uid ?? '',
                        'patientName': patientNameController.text.trim(),
                        'hospital': hospitalController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'bloodGroup': selectedBloodGroup,
                        'bags': int.tryParse(bagsController.text.trim()) ?? 1,
                        'reason': reasonController.text.trim(),
                        'location': geoPoint,
                        'status': 'active',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('SOS Request broadcasted successfully!')),
                        );
                      }
                    }
                  },
                  child: const Text('Broadcast', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Request Activity'),
        backgroundColor: Colors.redAccent,
      ),
      body: user == null
          ? const Center(child: Text('Please login to view your activity.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .where('uid', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'You have not posted any requests yet.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final patientName = data['patientName'] ?? 'Unknown Patient';
                    final hospital = data['hospital'] ?? 'Unknown Hospital';
                    final bloodGroup = data['bloodGroup'] ?? 'A+';
                    final bags = data['bags'] ?? 1;
                    final reason = data['reason'] ?? '';
                    final status = data['status'] ?? 'active';
                    final donorName = data['donorName'];
                    final donorPhone = data['donorPhone'];

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
                                  patientName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'accepted' ? Colors.green : Colors.red,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    status == 'accepted' ? 'Accepted' : bloodGroup,
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
                                  'Required Bags: $bags | Blood: $bloodGroup',
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
                            const SizedBox(height: 12),
                            if (status == 'accepted' && donorName != null && donorPhone != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Donor Accepted: $donorName',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Phone: $donorPhone', style: const TextStyle(fontSize: 14)),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 36,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.call, size: 16),
                                        label: Text('Call Donor: $donorPhone'),
                                        onPressed: () async {
                                          final Uri launchUri = Uri(scheme: 'tel', path: donorPhone);
                                          if (await canLaunchUrl(launchUri)) {
                                            await launchUrl(launchUri);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'Status: Searching for matching donors within 5 km...',
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add_alert, color: Colors.white),
        label: const Text('Post Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showPostRequestDialog(context),
      ),
    );
  }
}
