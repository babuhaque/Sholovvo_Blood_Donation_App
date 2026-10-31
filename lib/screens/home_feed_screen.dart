import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/post_service.dart';
import 'create_post_screen.dart';

class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  void _showCommentsBottomSheet(BuildContext context, Post post) {
    final TextEditingController commentController = TextEditingController();
    final PostService postService = PostService();
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
                    stream: postService.getComments(post.id),
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
                            await postService.addComment(
                              postId: post.id,
                              authorUid: currentUser.uid,
                              authorName: currentUser.displayName ?? currentUser.email?.split('@').first ?? 'Donor',
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

  @override
  Widget build(BuildContext context) {
    final PostService postService = PostService();
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solovvo Community Feed'),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Create Post',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreatePostScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Post>>(
        stream: postService.getPosts(limit: 20),
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
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                            future: currentUser != null ? postService.hasUserLiked(post.id, currentUser.uid) : Future.value(false),
                            builder: (context, snapshot) {
                              final hasLiked = snapshot.data ?? false;
                              return TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: hasLiked ? Colors.redAccent : Colors.grey.shade700,
                                ),
                                icon: Icon(hasLiked ? Icons.favorite : Icons.favorite_border),
                                label: Text('${post.likeCount} Likes'),
                                onPressed: currentUser == null
                                    ? null
                                    : () async {
                                        try {
                                          await postService.toggleLike(post.id, currentUser.uid);
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
                          StreamBuilder<List<Comment>>(
                            stream: postService.getComments(post.id),
                            builder: (context, commentSnapshot) {
                              final commentCount = (commentSnapshot.data ?? []).length;
                              return TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                                icon: const Icon(Icons.comment_outlined),
                                label: Text('Comments ($commentCount)'),
                                onPressed: () => _showCommentsBottomSheet(context, post),
                              );
                            },
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
        label: const Text('Create Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
