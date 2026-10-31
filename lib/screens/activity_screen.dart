import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import 'create_post_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final postService = PostService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Activity'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view your activity.'))
          : StreamBuilder<List<Post>>(
              stream: postService.getUserPosts(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Unable to load activity: ${snapshot.error}'));
                }

                final posts = snapshot.data ?? [];
                if (posts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'You have not shared any posts yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Post'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _ActivityPostCard(post: posts[index]),
                );
              },
            ),
    );
  }
}

class _ActivityPostCard extends StatelessWidget {
  const _ActivityPostCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final date = post.createdAt == null
        ? 'Just now'
        : post.createdAt!.toLocal().toString().substring(0, 16);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const Chip(label: Text('My post')),
              ],
            ),
            if (post.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(post.text),
            ],
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  height: 210,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 100,
                    child: Center(child: Text('Image could not be loaded')),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.favorite_border, color: Colors.redAccent, size: 18),
                const SizedBox(width: 5),
                Text('${post.likeCount} likes'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
