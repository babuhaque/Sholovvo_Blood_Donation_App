import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/location_service.dart';
import '../services/post_service.dart';
import '../models/app_notification.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/user_profile.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'create_blood_request_screen.dart';
import 'my_blood_requests_screen.dart';
import 'nearby_blood_requests_screen.dart';
import 'notifications_screen.dart';
import 'create_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final PostService _postService = PostService();
  
  String _displayName = 'User';
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _updateLocationOnStartup();
    _loadUserProfile();
  }

  Future<void> _updateLocationOnStartup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      Position? pos = await LocationService.getCurrentPositionSafely();
      if (pos != null) {
        await _profileService.updateLocation(user.uid, pos.latitude, pos.longitude);
      }
    } catch (_) {}
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        UserProfile? profile = await _profileService.getProfile(user.uid);
        if (profile != null && profile.fullName.isNotEmpty) {
          setState(() {
            _displayName = profile.fullName;
            _isLoadingProfile = false;
          });
          return;
        }
      } catch (_) {}
    }
    setState(() {
      _displayName = user?.displayName ?? user?.email?.split('@').first ?? 'User';
      _isLoadingProfile = false;
    });
  }

  void _showCommentsBottomSheet(BuildContext context, Post post) {
    final TextEditingController commentController = TextEditingController();
    final User? currentUser = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<List<Comment>>(
                    stream: _postService.getComments(post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                      }
                      final comments = snapshot.data ?? [];
                      if (comments.isEmpty) {
                        return const Center(
                          child: Text('No comments yet. Be the first to comment!', style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade100,
                              child: Text(comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : 'A'),
                            ),
                            title: Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(comment.text),
                            dense: true,
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.redAccent),
                      onPressed: () async {
                        if (commentController.text.trim().isNotEmpty && currentUser != null) {
                          try {
                            await _postService.addComment(
                              postId: post.id,
                              authorUid: currentUser.uid,
                              authorName: _displayName,
                              text: commentController.text.trim(),
                            );
                            commentController.clear();
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
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      selectedItemColor: Colors.redAccent,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        switch (index) {
          case 0:
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyBloodRequestsScreen()),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_none), activeIcon: Icon(Icons.notifications), label: 'Notification'),
        BottomNavigationBarItem(icon: Icon(Icons.local_activity_outlined), activeIcon: Icon(Icons.local_activity), label: 'Activity'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'My Account'),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Sholovvo', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        backgroundColor: Colors.redAccent,
        actions: [
          StreamBuilder<List<AppNotification>>(
            stream: NotificationService().getUserNotifications(user?.uid ?? ''),
            builder: (context, snapshot) {
              final unreadCount = (snapshot.data ?? []).where((n) => !n.isRead).length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await _authService.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Facebook-style Top-Left Corner Brand Header with logo.jpeg
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'Images/logo.jpeg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.bloodtype, color: Colors.redAccent, size: 36),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isLoadingProfile ? 'Welcome to Sholovvo' : 'Welcome to $_displayName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Community Feed Stream
          Expanded(
            child: StreamBuilder<List<Post>>(
              stream: _postService.getPosts(limit: 20),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No community posts yet.\nBe the first to share an appeal or update!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreatePostScreen()),
                            );
                          },
                          child: const Text('Create Post'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: posts.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final post = posts[index];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author Row
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.redAccent,
                                  child: Text(
                                    post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'D',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.authorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      post.createdAt != null ? '${post.createdAt!.toLocal()}'.substring(0, 16) : 'Just now',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Post Text
                            Text(
                              post.text,
                              style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            // Post Image (if any)
                            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  post.imageUrl!,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 220,
                                      color: Colors.grey.shade100,
                                      child: const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 150,
                                    color: Colors.grey.shade200,
                                    child: const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.grey))),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            const Divider(height: 1),
                            const SizedBox(height: 4),
                            // Like & Comment Actions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                FutureBuilder<bool>(
                                  future: user != null ? _postService.hasUserLiked(post.id, user.uid) : Future.value(false),
                                  builder: (context, snapshot) {
                                    final hasLiked = snapshot.data ?? false;
                                    return TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: hasLiked ? Colors.redAccent : Colors.grey.shade700,
                                      ),
                                      icon: Icon(hasLiked ? Icons.favorite : Icons.favorite_border),
                                      label: Text('${post.likeCount} Likes'),
                                      onPressed: user == null
                                          ? null
                                          : () async {
                                              try {
                                                await _postService.toggleLike(post.id, user.uid);
                                              } catch (e) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                                );
                                              }
                                            },
                                    );
                                  },
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                                  icon: const Icon(Icons.comment_outlined),
                                  label: const Text('Comments'),
                                  onPressed: () => _showCommentsBottomSheet(context, post),
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
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(context),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        tooltip: 'Create Post',
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
      ),
    );
  }
}
