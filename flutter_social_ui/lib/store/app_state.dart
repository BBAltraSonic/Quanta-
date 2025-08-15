import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../models/post_model.dart';
import '../models/comment.dart'; // Use the unified comment model
import '../utils/ownership_manager.dart';

/// Central application state store - SINGLE SOURCE OF TRUTH
/// All data modifications must go through this store to ensure consistency
class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // ========== USER DATA (Authoritative) ==========
  UserModel? _currentUser;
  String? _currentUserId;
  
  UserModel? get currentUser => _currentUser;
  String? get currentUserId => _currentUserId;
  bool get isAuthenticated => _currentUser != null && _currentUserId != null;

  // ========== AVATAR DATA (Authoritative) ==========
  final Map<String, AvatarModel> _avatars = {};
  final Map<String, List<AvatarModel>> _userAvatars = {}; // userId -> List<AvatarModel>
  AvatarModel? _activeAvatar;
  
  Map<String, AvatarModel> get avatars => Map.unmodifiable(_avatars);
  AvatarModel? get activeAvatar => _activeAvatar;
  
  AvatarModel? getAvatar(String avatarId) => _avatars[avatarId];
  List<AvatarModel> getUserAvatars(String userId) => _userAvatars[userId] ?? [];

  // ========== POST DATA (Authoritative) ==========
  final Map<String, PostModel> _posts = {};
  final List<String> _feedPostIds = []; // Ordered list for feed display
  final Map<String, List<String>> _userPostIds = {}; // userId -> List<postId>
  
  Map<String, PostModel> get posts => Map.unmodifiable(_posts);
  List<PostModel> get feedPosts => _feedPostIds.map((id) => _posts[id]).where((p) => p != null).cast<PostModel>().toList();
  List<PostModel> getUserPosts(String userId) => (_userPostIds[userId] ?? []).map((id) => _posts[id]).where((p) => p != null).cast<PostModel>().toList();
  
  PostModel? getPost(String postId) => _posts[postId];

  // ========== COMMENT DATA (Authoritative) ==========
  final Map<String, Comment> _comments = {};
  final Map<String, List<String>> _postComments = {}; // postId -> List<commentId>
  
  Map<String, Comment> get comments => Map.unmodifiable(_comments);
  List<Comment> getPostComments(String postId) => (_postComments[postId] ?? []).map((id) => _comments[id]).where((c) => c != null).cast<Comment>().toList();
  
  Comment? getComment(String commentId) => _comments[commentId];

  // ========== INTERACTION STATE (Authoritative) ==========
  final Map<String, bool> _likedPosts = {}; // postId -> bool
  final Map<String, bool> _likedComments = {}; // commentId -> bool
  final Map<String, bool> _followingAvatars = {}; // avatarId -> bool
  final Map<String, bool> _bookmarkedPosts = {}; // postId -> bool
  
  bool isPostLiked(String postId) => _likedPosts[postId] ?? false;
  bool isCommentLiked(String commentId) => _likedComments[commentId] ?? false;
  bool isFollowingAvatar(String avatarId) => _followingAvatars[avatarId] ?? false;
  bool isPostBookmarked(String postId) => _bookmarkedPosts[postId] ?? false;

  // ========== UI STATE (Authoritative) ==========
  bool _isLoading = false;
  String? _error;
  final Map<String, bool> _loadingStates = {}; // For specific loading states
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool getLoadingState(String key) => _loadingStates[key] ?? false;

  // ========== PAGINATION STATE (Authoritative) ==========
  final Map<String, int> _currentPages = {}; // For different contexts
  final Map<String, bool> _hasMoreData = {}; // For pagination
  
  int getCurrentPage(String context) => _currentPages[context] ?? 0;
  bool hasMoreData(String context) => _hasMoreData[context] ?? true;

  // ========== STATE MODIFICATION METHODS ==========
  
  /// Set current user (authentication)
  void setCurrentUser(UserModel? user, String? userId) {
    _currentUser = user;
    _currentUserId = userId;
    notifyListeners();
  }

  /// Update user data
  void updateUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Set active avatar
  void setActiveAvatar(AvatarModel? avatar) {
    _activeAvatar = avatar;
    notifyListeners();
  }

  /// Add or update avatar
  void setAvatar(AvatarModel avatar) {
    _avatars[avatar.id] = avatar;
    
    // Update user's avatar list
    final userId = avatar.ownerUserId;
    if (!_userAvatars.containsKey(userId)) {
      _userAvatars[userId] = [];
    }
    final userAvatarsList = _userAvatars[userId]!;
    final existingIndex = userAvatarsList.indexWhere((a) => _avatars[a]?.id == avatar.id);
    if (existingIndex >= 0) {
      // Update existing
      userAvatarsList[existingIndex] = avatar.id;
    } else {
      // Add new
      userAvatarsList.add(avatar.id);
    }
    
    notifyListeners();
  }

  /// Remove avatar
  void removeAvatar(String avatarId) {
    final avatar = _avatars[avatarId];
    if (avatar != null) {
      _avatars.remove(avatarId);
      _userAvatars[avatar.ownerUserId]?.remove(avatarId);
      if (_activeAvatar?.id == avatarId) {
        _activeAvatar = null;
      }
      notifyListeners();
    }
  }

  /// Add or update post
  void setPost(PostModel post) {
    _posts[post.id] = post;
    
    // Add to feed if not already there
    if (!_feedPostIds.contains(post.id)) {
      _feedPostIds.insert(0, post.id); // Add to beginning for newest first
    }
    
    // Add to user's posts
    if (_posts[post.id]?.avatarId != null) {
      final avatar = _avatars[_posts[post.id]!.avatarId];
      if (avatar != null) {
        final userId = avatar.ownerUserId;
        if (!_userPostIds.containsKey(userId)) {
          _userPostIds[userId] = [];
        }
        if (!_userPostIds[userId]!.contains(post.id)) {
          _userPostIds[userId]!.insert(0, post.id);
        }
      }
    }
    
    notifyListeners();
  }

  /// Remove post
  void removePost(String postId) {
    final post = _posts[postId];
    if (post != null) {
      _posts.remove(postId);
      _feedPostIds.remove(postId);
      
      // Remove from user posts
      final avatar = _avatars[post.avatarId];
      if (avatar != null) {
        _userPostIds[avatar.ownerUserId]?.remove(postId);
      }
      
      // Remove associated comments
      _postComments[postId]?.forEach((commentId) {
        _comments.remove(commentId);
      });
      _postComments.remove(postId);
      
      notifyListeners();
    }
  }

  /// Update post engagement counts
  void updatePostEngagement(String postId, {
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? viewsCount,
  }) {
    final post = _posts[postId];
    if (post != null) {
      _posts[postId] = post.copyWith(
        likesCount: likesCount,
        commentsCount: commentsCount,
        sharesCount: sharesCount,
        viewsCount: viewsCount,
      );
      notifyListeners();
    }
  }

  /// Add or update comment
  void setComment(Comment comment) {
    _comments[comment.id] = comment;
    
    // Add to post's comments
    if (!_postComments.containsKey(comment.postId)) {
      _postComments[comment.postId] = [];
    }
    if (!_postComments[comment.postId]!.contains(comment.id)) {
      _postComments[comment.postId]!.add(comment.id);
    }
    
    notifyListeners();
  }

  /// Remove comment
  void removeComment(String commentId) {
    final comment = _comments[commentId];
    if (comment != null) {
      _comments.remove(commentId);
      _postComments[comment.postId]?.remove(commentId);
      notifyListeners();
    }
  }

  /// Set post like status
  void setPostLikeStatus(String postId, bool isLiked, {int? newLikesCount}) {
    _likedPosts[postId] = isLiked;
    
    if (newLikesCount != null) {
      updatePostEngagement(postId, likesCount: newLikesCount);
    }
    
    notifyListeners();
  }

  /// Set comment like status
  void setCommentLikeStatus(String commentId, bool isLiked, {int? newLikesCount}) {
    _likedComments[commentId] = isLiked;
    
    if (newLikesCount != null) {
      final comment = _comments[commentId];
      if (comment != null) {
        _comments[commentId] = comment.copyWith(likesCount: newLikesCount);
      }
    }
    
    notifyListeners();
  }

  /// Set avatar follow status
  void setFollowStatus(String avatarId, bool isFollowing) {
    _followingAvatars[avatarId] = isFollowing;
    notifyListeners();
  }

  /// Set post bookmark status
  void setBookmarkStatus(String postId, bool isBookmarked) {
    _bookmarkedPosts[postId] = isBookmarked;
    notifyListeners();
  }

  /// Set global loading state
  void setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }

  /// Set specific loading state
  void setLoadingState(String key, bool isLoading) {
    _loadingStates[key] = isLoading;
    notifyListeners();
  }

  /// Set error state
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Set pagination state
  void setPaginationState(String context, int currentPage, bool hasMore) {
    _currentPages[context] = currentPage;
    _hasMoreData[context] = hasMore;
    notifyListeners();
  }

  /// Bulk update posts (for feed refresh)
  void setPosts(List<PostModel> posts, {String context = 'feed'}) {
    for (final post in posts) {
      _posts[post.id] = post;
    }
    
    if (context == 'feed') {
      _feedPostIds.clear();
      _feedPostIds.addAll(posts.map((p) => p.id));
    }
    
    notifyListeners();
  }

  /// Bulk update comments for a post
  void setPostComments(String postId, List<Comment> comments) {
    for (final comment in comments) {
      _comments[comment.id] = comment;
    }
    
    _postComments[postId] = comments.map((c) => c.id).toList();
    notifyListeners();
  }

  /// Clear all data (logout)
  void clearAll() {
    _currentUser = null;
    _currentUserId = null;
    _avatars.clear();
    _userAvatars.clear();
    _activeAvatar = null;
    _posts.clear();
    _feedPostIds.clear();
    _userPostIds.clear();
    _comments.clear();
    _postComments.clear();
    _likedPosts.clear();
    _likedComments.clear();
    _followingAvatars.clear();
    _bookmarkedPosts.clear();
    _isLoading = false;
    _error = null;
    _loadingStates.clear();
    _currentPages.clear();
    _hasMoreData.clear();
    notifyListeners();
  }
}
