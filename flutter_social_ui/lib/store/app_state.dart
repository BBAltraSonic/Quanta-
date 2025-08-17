import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../models/post_model.dart';
import '../models/comment.dart'; // Use the unified comment model

/// Profile view mode for avatar-centric profiles
enum ProfileViewMode {
  owner, // Creator viewing their own avatar
  public, // Other users viewing the avatar
  guest, // Unauthenticated users viewing the avatar
}

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
  final Map<String, List<String>> _userAvatars = {}; // userId -> List<avatarId>
  AvatarModel? _activeAvatar;

  // ========== AVATAR VIEW MODE STATE ==========
  final Map<String, ProfileViewMode> _avatarViewModes =
      {}; // avatarId -> ProfileViewMode
  final Map<String, List<String>> _avatarPosts = {}; // avatarId -> List<postId>
  final Map<String, int> _avatarFollowerCounts =
      {}; // avatarId -> followerCount
  final Map<String, DateTime> _avatarLastViewedAt =
      {}; // avatarId -> lastViewedAt

  Map<String, AvatarModel> get avatars => Map.unmodifiable(_avatars);
  AvatarModel? get activeAvatar => _activeAvatar;

  AvatarModel? getAvatar(String avatarId) => _avatars[avatarId];
  List<AvatarModel> getUserAvatars(String userId) =>
      (_userAvatars[userId] ?? [])
          .map((id) => _avatars[id])
          .where((a) => a != null)
          .cast<AvatarModel>()
          .toList();

  // ========== POST DATA (Authoritative) ==========
  final Map<String, PostModel> _posts = {};
  final List<String> _feedPostIds = []; // Ordered list for feed display
  final Map<String, List<String>> _userPostIds = {}; // userId -> List<postId>

  Map<String, PostModel> get posts => Map.unmodifiable(_posts);
  List<PostModel> get feedPosts => _feedPostIds
      .map((id) => _posts[id])
      .where((p) => p != null)
      .cast<PostModel>()
      .toList();
  List<PostModel> getUserPosts(String userId) => (_userPostIds[userId] ?? [])
      .map((id) => _posts[id])
      .where((p) => p != null)
      .cast<PostModel>()
      .toList();

  PostModel? getPost(String postId) => _posts[postId];

  // ========== COMMENT DATA (Authoritative) ==========
  final Map<String, Comment> _comments = {};
  final Map<String, List<String>> _postComments =
      {}; // postId -> List<commentId>

  Map<String, Comment> get comments => Map.unmodifiable(_comments);
  List<Comment> getPostComments(String postId) => (_postComments[postId] ?? [])
      .map((id) => _comments[id])
      .where((c) => c != null)
      .cast<Comment>()
      .toList();

  Comment? getComment(String commentId) => _comments[commentId];

  // ========== INTERACTION STATE (Authoritative) ==========
  final Map<String, bool> _likedPosts = {}; // postId -> bool
  final Map<String, bool> _likedComments = {}; // commentId -> bool
  final Map<String, bool> _followingAvatars = {}; // avatarId -> bool
  final Map<String, bool> _bookmarkedPosts = {}; // postId -> bool

  bool isPostLiked(String postId) => _likedPosts[postId] ?? false;
  bool isCommentLiked(String commentId) => _likedComments[commentId] ?? false;
  bool isFollowingAvatar(String avatarId) =>
      _followingAvatars[avatarId] ?? false;
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
    final existingIndex = userAvatarsList.indexWhere(
      (a) => _avatars[a]?.id == avatar.id,
    );
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

      // Clean up avatar-specific state
      _avatarViewModes.remove(avatarId);
      _avatarPosts.remove(avatarId);
      _avatarFollowerCounts.remove(avatarId);
      _avatarLastViewedAt.remove(avatarId);

      notifyListeners();
    }
  }

  // ========== AVATAR-CENTRIC STATE MANAGEMENT ==========

  /// Set active avatar for a specific user
  void setActiveAvatarForUser(String userId, AvatarModel avatar) {
    // Verify the avatar belongs to the user
    if (avatar.ownerUserId != userId) {
      throw ArgumentError('Avatar does not belong to the specified user');
    }

    _activeAvatar = avatar;

    // Update the avatar in the avatars map if not already there
    if (!_avatars.containsKey(avatar.id)) {
      setAvatar(avatar);
    }

    notifyListeners();
  }

  /// Get active avatar for a specific user
  AvatarModel? getActiveAvatarForUser(String userId) {
    if (_activeAvatar?.ownerUserId == userId) {
      return _activeAvatar;
    }

    // If no active avatar set, return the first avatar for the user
    final userAvatars = getUserAvatars(userId);
    return userAvatars.isNotEmpty ? userAvatars.first : null;
  }

  /// Determine view mode for an avatar profile
  ProfileViewMode determineAvatarViewMode(
    String avatarId,
    String? currentUserId,
  ) {
    // Check if we have a cached view mode
    if (_avatarViewModes.containsKey(avatarId)) {
      return _avatarViewModes[avatarId]!;
    }

    // Determine view mode based on ownership
    ProfileViewMode viewMode;
    if (currentUserId == null) {
      viewMode = ProfileViewMode.guest;
    } else {
      final avatar = _avatars[avatarId];
      if (avatar != null && avatar.ownerUserId == currentUserId) {
        viewMode = ProfileViewMode.owner;
      } else {
        viewMode = ProfileViewMode.public;
      }
    }

    // Cache the view mode
    _avatarViewModes[avatarId] = viewMode;
    return viewMode;
  }

  /// Set view mode for an avatar (for caching)
  void setAvatarViewMode(String avatarId, ProfileViewMode viewMode) {
    _avatarViewModes[avatarId] = viewMode;
    notifyListeners();
  }

  /// Get avatar-specific posts
  List<PostModel> getAvatarPosts(String avatarId) {
    final postIds = _avatarPosts[avatarId] ?? [];
    return postIds
        .map((id) => _posts[id])
        .where((p) => p != null)
        .cast<PostModel>()
        .toList();
  }

  /// Associate content with an avatar
  void associateContentWithAvatar(String avatarId, String postId) {
    if (!_avatarPosts.containsKey(avatarId)) {
      _avatarPosts[avatarId] = [];
    }

    if (!_avatarPosts[avatarId]!.contains(postId)) {
      _avatarPosts[avatarId]!.insert(
        0,
        postId,
      ); // Add to beginning for newest first
      notifyListeners();
    }
  }

  /// Remove content association from avatar
  void removeContentFromAvatar(String avatarId, String postId) {
    _avatarPosts[avatarId]?.remove(postId);
    notifyListeners();
  }

  /// Update avatar follower count
  void updateAvatarFollowerCount(String avatarId, int count) {
    _avatarFollowerCounts[avatarId] = count;

    // Also update the avatar model if it exists
    final avatar = _avatars[avatarId];
    if (avatar != null) {
      _avatars[avatarId] = avatar.copyWith(followersCount: count);
    }

    notifyListeners();
  }

  /// Get avatar follower count
  int getAvatarFollowerCount(String avatarId) {
    return _avatarFollowerCounts[avatarId] ??
        _avatars[avatarId]?.followersCount ??
        0;
  }

  /// Track avatar profile view
  void trackAvatarProfileView(String avatarId) {
    _avatarLastViewedAt[avatarId] = DateTime.now();
    notifyListeners();
  }

  /// Get last viewed time for avatar
  DateTime? getAvatarLastViewedAt(String avatarId) {
    return _avatarLastViewedAt[avatarId];
  }

  /// Switch active avatar (for avatar owners)
  Future<void> switchActiveAvatar(String newAvatarId) async {
    final avatar = _avatars[newAvatarId];
    if (avatar == null) {
      throw ArgumentError('Avatar not found: $newAvatarId');
    }

    // Verify ownership if current user is set
    if (_currentUserId != null && avatar.ownerUserId != _currentUserId) {
      throw ArgumentError('Cannot switch to avatar not owned by current user');
    }

    _activeAvatar = avatar;
    notifyListeners();
  }

  /// Get avatar stats for display
  Map<String, dynamic> getAvatarStats(String avatarId) {
    final avatar = _avatars[avatarId];
    final posts = getAvatarPosts(avatarId);
    final followerCount = getAvatarFollowerCount(avatarId);

    return {
      'followersCount': followerCount,
      'postsCount': posts.length,
      'likesCount': avatar?.likesCount ?? 0,
      'engagementRate': avatar?.engagementRate ?? 0.0,
      'lastViewedAt': getAvatarLastViewedAt(avatarId),
    };
  }

  /// Check if user owns avatar
  bool doesUserOwnAvatar(String userId, String avatarId) {
    final avatar = _avatars[avatarId];
    return avatar?.ownerUserId == userId;
  }

  /// Get all avatars owned by current user
  List<AvatarModel> getCurrentUserAvatars() {
    if (_currentUserId == null) return [];
    return getUserAvatars(_currentUserId!);
  }

  /// Check if current user has any avatars
  bool get currentUserHasAvatars {
    return getCurrentUserAvatars().isNotEmpty;
  }

  /// Get avatar view mode (cached or computed)
  ProfileViewMode getAvatarViewMode(String avatarId) {
    return _avatarViewModes[avatarId] ??
        determineAvatarViewMode(avatarId, _currentUserId);
  }

  /// Add or update post
  void setPost(PostModel post) {
    _posts[post.id] = post;

    // Add to feed if not already there
    if (!_feedPostIds.contains(post.id)) {
      _feedPostIds.insert(0, post.id); // Add to beginning for newest first
    }

    // Add to user's posts and avatar's posts
    if (_posts[post.id]?.avatarId != null) {
      final avatarId = _posts[post.id]!.avatarId;
      final avatar = _avatars[avatarId];

      if (avatar != null) {
        final userId = avatar.ownerUserId;

        // Add to user's posts
        if (!_userPostIds.containsKey(userId)) {
          _userPostIds[userId] = [];
        }
        if (!_userPostIds[userId]!.contains(post.id)) {
          _userPostIds[userId]!.insert(0, post.id);
        }

        // Associate with avatar
        associateContentWithAvatar(avatarId, post.id);
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

      // Remove from user posts and avatar posts
      final avatar = _avatars[post.avatarId];
      if (avatar != null) {
        _userPostIds[avatar.ownerUserId]?.remove(postId);
        removeContentFromAvatar(post.avatarId, postId);
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
  void updatePostEngagement(
    String postId, {
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
  void setCommentLikeStatus(
    String commentId,
    bool isLiked, {
    int? newLikesCount,
  }) {
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
    _avatarViewModes.clear();
    _avatarPosts.clear();
    _avatarFollowerCounts.clear();
    _avatarLastViewedAt.clear();
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
