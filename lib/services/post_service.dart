import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../models/comment.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream posts (limited to 20 for pagination/performance)
  Stream<List<Post>> getPosts({int limit = 20}) {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Post.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // Stream posts created by the signed-in user for the Activity tab.
  Stream<List<Post>> getUserPosts(String userId, {int limit = 50}) {
    return _firestore
        .collection('posts')
        .where('authorUid', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Temporary debug helper to safely inspect decoded JWT claims from Firebase ID token
  void _debugFirebaseIdTokenClaims(String? idToken) {
    if (idToken == null) {
      debugPrint('Debug Token: No active Firebase ID token found.');
      return;
    }
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) {
        debugPrint('Debug Token: Invalid JWT format.');
        return;
      }
      String payloadNormalized = base64Url.normalize(parts[1]);
      String payloadString = utf8.decode(base64Url.decode(payloadNormalized));
      Map<String, dynamic> payload = json.decode(payloadString);

      debugPrint('--- Firebase ID Token Debug Claims ---');
      debugPrint('sub (UID): ${payload['sub']}');
      debugPrint('aud (Audience): ${payload['aud']}');
      debugPrint('iss (Issuer): ${payload['iss']}');
      debugPrint('role (Claim): ${payload['role'] ?? 'Missing (Check Supabase Third-Party Auth configuration)'}');
      debugPrint('---------------------------------------');
    } catch (e) {
      debugPrint('Debug Token: Error parsing token payload: $e');
    }
  }

  // Upload image to Supabase Storage bucket 'community-posts' under USER_UID/uniqueFileName.jpg
  Future<String?> uploadPostImage(String uid, XFile imageFile) async {
    try {
      // 1. Verify signed-in user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'User must be signed in to upload images.';
      }

      // Ensure upload matches auth uid
      if (user.uid != uid) {
        throw 'Unauthorized: User UID mismatch.';
      }

      final bytes = await imageFile.readAsBytes();

      // 2. Validate size (max 5 MB)
      if (bytes.length > 5 * 1024 * 1024) {
        throw 'Image size exceeds 5MB limit.';
      }

      // 3. Validate file type (JPG, PNG, WebP)
      final nameLower = imageFile.name.toLowerCase();
      bool isValidType = nameLower.endsWith('.jpg') ||
          nameLower.endsWith('.jpeg') ||
          nameLower.endsWith('.png') ||
          nameLower.endsWith('.webp');

      if (!isValidType) {
        throw 'Only JPG, PNG, and WebP image formats are allowed.';
      }

      // 4. Get Firebase ID token and run safe debug helper
      final idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw 'Failed to retrieve Firebase authentication token.';
      }
      _debugFirebaseIdTokenClaims(idToken);

      final extension = nameLower.contains('.') ? nameLower.split('.').last : 'jpg';
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final storagePath = '$uid/$uniqueFileName';

      // 5. Upload binary to Supabase Storage bucket 'community-posts' with explicit Authorization header
      await Supabase.instance.client.storage
          .from('community-posts')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$extension',
              upsert: true,
              headers: {'Authorization': 'Bearer $idToken'},
            ),
          );

      // 6. Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('community-posts')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      throw 'Failed to upload image to Supabase Storage: $e';
    }
  }

  // Create Post
  Future<void> createPost({
    required String authorUid,
    required String authorName,
    required String authorEmail,
    required String text,
    XFile? imageFile,
    String? donationRecordId,
  }) async {
    try {
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadPostImage(authorUid, imageFile);
      }

      Post post = Post(
        id: '',
        authorUid: authorUid,
        authorName: authorName,
        authorEmail: authorEmail,
        text: text,
        imageUrl: imageUrl,
        likeCount: 0,
        donationRecordId: donationRecordId,
      );

      await _firestore.collection('posts').add(post.toMap());
    } catch (e) {
      throw 'Failed to create post: $e';
    }
  }

  // Like or Unlike Post (scalable structure: post_likes/{postId_userId})
  Future<void> toggleLike(String postId, String userId) async {
    final likeDocId = '${postId}_$userId';
    final likeRef = _firestore.collection('post_likes').doc(likeDocId);
    final postRef = _firestore.collection('posts').doc(postId);

    await _firestore.runTransaction((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);
      final postSnapshot = await transaction.get(postRef);

      if (!postSnapshot.exists) throw 'Post does not exist';

      int currentLikes = postSnapshot.data()?['likeCount'] ?? 0;

      if (likeSnapshot.exists) {
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': currentLikes > 0 ? currentLikes - 1 : 0});
      } else {
        transaction.set(likeRef, {
          'postId': postId,
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'likeCount': currentLikes + 1});
      }
    });
  }

  // Check if user liked post
  Future<bool> hasUserLiked(String postId, String userId) async {
    final likeDocId = '${postId}_$userId';
    final doc = await _firestore.collection('post_likes').doc(likeDocId).get();
    return doc.exists;
  }

  // Add Comment
  Future<void> addComment({
    required String postId,
    required String authorUid,
    required String authorName,
    required String text,
  }) async {
    try {
      Comment comment = Comment(
        id: '',
        postId: postId,
        authorUid: authorUid,
        authorName: authorName,
        text: text,
      );

      await _firestore.collection('posts').doc(postId).collection('comments').add(comment.toMap());
    } catch (e) {
      throw 'Failed to add comment: $e';
    }
  }

  // Stream Comments for a Post
  Stream<List<Comment>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Comment.fromMap(doc.data(), doc.id)).toList();
    });
  }
}
