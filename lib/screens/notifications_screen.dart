import 'package:flutter/material.dart';
import '../locale_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';
import '../models/blood_request.dart';
import '../services/notification_service.dart';
import 'donor_discovery_screen.dart';
import 'nearby_blood_requests_screen.dart';
import 'my_accepted_requests_screen.dart';

Color _notificationColor(String type) {
  switch (type) {
    case 'new_request': return Colors.redAccent;
    case 'donor_response': return Colors.blue;
    case 'donation_completed': return Colors.orange;
    case 'donation_confirmed': return Colors.green;
    default: return Colors.grey;
  }
}

IconData _notificationIcon(String type) {
  switch (type) {
    case 'new_request': return Icons.water_drop;
    case 'donor_response': return Icons.volunteer_activism;
    case 'donation_completed': return Icons.hourglass_top;
    case 'donation_confirmed': return Icons.verified;
    default: return Icons.notifications;
  }
}
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _handleNotificationTap(BuildContext context, AppNotification notification) async {
    if (!notification.isRead) {
      await NotificationService().markAsRead(notification.id);
    }

    if (!context.mounted) return;

    try {
      if (notification.type == 'donation_confirmed') {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const MyAcceptedRequestsScreen()));
        return;
      }
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('blood_requests').doc(notification.requestId).get();
      if (doc.exists && doc.data() != null) {
        BloodRequest request = BloodRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        
        if (!context.mounted) return;
        final currentUser = FirebaseAuth.instance.currentUser;
        
        if (request.userId == currentUser?.uid) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DonorDiscoveryScreen(request: request)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NearbyBloodRequestsScreen()),
          );
        }
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The related blood request no longer exists.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final NotificationService notificationService = NotificationService();

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(appText(context, 'Notifications', 'নোটিফিকেশন')), backgroundColor: Colors.redAccent),
        body: Center(child: Text(appText(context, 'Please log in to view notifications.', 'নোটিফিকেশন দেখতে লগইন করুন।'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.redAccent,
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: notificationService.getUserNotifications(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    appText(context, 'No notifications yet.', 'এখনো কোনো নোটিফিকেশন নেই।'),
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return Card(
                elevation: notif.isRead ? 1 : 3,
                color: notif.isRead ? Colors.white : Colors.red.shade50,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _notificationColor(notif.type),
                    child: Icon(_notificationIcon(notif.type), color: Colors.white),
                  ),
                  title: Text(
                    notif.title,
                    style: TextStyle(
                      fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notif.body),
                      const SizedBox(height: 4),
                      Text(
                        notif.createdAt != null
                            ? '${notif.createdAt!.toLocal()}'.substring(0, 16)
                            : '',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: !notif.isRead
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                  onTap: () => _handleNotificationTap(context, notif),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
