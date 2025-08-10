import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/comment.dart';
import '../config/app_config.dart';

class SimpleSupabaseService {
  static final SimpleSupabaseService _instance = SimpleSupabaseService._internal();
  factory SimpleSupabaseService() => _instance;
  SimpleSupabaseService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  // Initialize Supabase (only if not already initialized)
  static Future<void> initialize() async {
    try {
      // Check if Supabase is already initialized
      if (Supabase.instance.client != null) {
        debugPrint('✅ Supabase already initialized, skipping...');
        return;
      }
      
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      debugPrint('✅ Supabase initialized successfully');
    } catch (e) {
      // If already initialized, that's fine
      if (e.toString().contains('already been initialized')) {
        debugPrint('✅ Supabase already initialized, continuing...');
        return;
      }
      debugPrint('❌ Supabase initialization failed: $e');
      rethrow;
    }
  }

  // Authentication
  Future<AuthResponse> signUp(String email, String password, {String? fullName}) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      return response;
    } catch (e) {
      debugPrint('❌ Sign up failed: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('❌ Sign in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('❌ Sign out failed: $e');
      rethrow;
    }
  }

  User? get currentUser => _supabase.auth.currentUser;
  bool get isSignedIn => _supabase.auth.currentUser != null;

  // Posts
  Future<List<PostModel>> getFeedPosts({int page = 0, int limit = 20}) async {
    try {
      final response = await _supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);
      
      return response.map<PostModel>((json) => PostModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Failed to get feed posts: $e');
      return [];
    }
  }

  Future<PostModel?> createPost({
    required String caption,
    required PostType type,
    String? mediaUrl,
    String? thumbnailUrl,
  }) async {
    if (!isSignedIn) return null;

    try {
      final response = await _supabase.from('posts').insert({
        'user_id': currentUser!.id,
        'caption': caption,
        'type': type.name,
        'media_url': mediaUrl,
        'thumbnail_url': thumbnailUrl,
        'likes_count': 0,
        'comments_count': 0,
        'shares_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return PostModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to create post: $e');
      return null;
    }
  }

  // Likes
  Future<bool> likePost(String postId) async {
    if (!isSignedIn) return false;

    try {
      // Check if already liked
      final existingLike = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', currentUser!.id)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUser!.id);
        return false;
      } else {
        // Like
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': currentUser!.id,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ Failed to like post: $e');
      return false;
    }
  }

  Future<bool> isPostLiked(String postId) async {
    if (!isSignedIn) return false;

    try {
      final like = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', currentUser!.id)
          .maybeSingle();
      
      return like != null;
    } catch (e) {
      debugPrint('❌ Failed to check like status: $e');
      return false;
    }
  }

  // Comments
  Future<List<Comment>> getPostComments(String postId, {int page = 0, int limit = 20}) async {
    try {
      final response = await _supabase
          .from('comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true)
          .range(page * limit, (page + 1) * limit - 1);
      
      return response.map<Comment>((json) => Comment.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Failed to get comments: $e');
      return [];
    }
  }

  Future<Comment?> addComment(String postId, String text) async {
    if (!isSignedIn) return null;

    try {
      final response = await _supabase.from('comments').insert({
        'post_id': postId,
        'user_id': currentUser!.id,
        'text': text,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return Comment.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to add comment: $e');
      return null;
    }
  }

  // File Upload
  Future<String?> uploadFile(String bucket, String path, Uint8List bytes) async {
    try {
      await _supabase.storage.from(bucket).uploadBinary(path, bytes);
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('❌ Failed to upload file: $e');
      return null;
    }
  }
}
