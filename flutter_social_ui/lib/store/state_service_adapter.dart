import 'package:flutter/foundation.dart';
import 'app_state.dart';
import '../models/user_model.dart';
import '../models/avatar_model.dart';
import '../models/post_model.dart';
import '../models/comment.dart';
import '../utils/ownership_manager.dart';

/// Service adapter to bridge existing services with the central AppState
/// This helps gradually migrate services to use the central state store
class StateServiceAdapter {
  static final StateServiceAdapter _instance = StateServiceAdapter._internal();
  factory StateServiceAdapter() => _instance;
  StateServiceAdapter._internal();

  final AppState _appState = AppState();

  // ========== GETTERS FOR SERVICES ==========

  /// Get current user from central state
  UserModel? get currentUser => _appState.currentUser;
  String? get currentUserId => _appState.currentUserId;
  bool get isAuthenticated => _appState.isAuthenticated;

  /// Get avatars from central state
  Map<String, AvatarModel> get avatars => _appState.avatars;
  AvatarModel? get activeAvatar => _appState.activeAvatar;
  AvatarModel? getAvatar(String avatarId) => _appState.getAvatar(avatarId);
  List<AvatarModel> getUserAvatars(String userId) =>
      _appState.getUserAvatars(userId);

  /// Get posts from central state
  Map<String, PostModel> get posts => _appState.posts;
  List<PostModel> get feedPosts => _appState.feedPosts;
  PostModel? getPost(String postId) => _appState.getPost(postId);
  List<PostModel> getUserPosts(String userId) => _appState.getUserPosts(userId);

  /// Get comments from central state
  Map<String, Comment> get comments => _appState.comments;
  Comment? getComment(String commentId) => _appState.getComment(commentId);
  List<Comment> getPostComments(String postId) =>
      _appState.getPostComments(postId);

  /// Get interaction states from central state
  bool isPostLiked(String postId) => _appState.isPostLiked(postId);
  bool isCommentLiked(String commentId) => _appState.isCommentLiked(commentId);
  bool isFollowingAvatar(String avatarId) =>
      _appState.isFollowingAvatar(avatarId);
  bool isPostBookmarked(String postId) => _appState.isPostBookmarked(postId);

  /// Get UI state from central state
  bool get isLoading => _appState.isLoading;
  String? get error => _appState.error;
  bool getLoadingState(String key) => _appState.getLoadingState(key);

  /// Get pagination state from central state
  int getCurrentPage(String context) => _appState.getCurrentPage(context);
  bool hasMoreData(String context) => _appState.hasMoreData(context);

  // ========== METHODS FOR SERVICES TO UPDATE STATE ==========

  /// Update current user
  void setCurrentUser(UserModel? user, String? userId) {
    _appState.setCurrentUser(user, userId);
  }

  /// Update user data
  void updateUser(UserModel user) {
    _appState.updateUser(user);
  }

  /// Set active avatar
  void setActiveAvatar(AvatarModel? avatar) {
    _appState.setActiveAvatar(avatar);
  }

  /// Add or update avatar
  void setAvatar(AvatarModel avatar) {
    _appState.setAvatar(avatar);
  }

  /// Remove avatar
  void removeAvatar(String avatarId) {
    _appState.removeAvatar(avatarId);
  }

  /// Add or update post
  void setPost(PostModel post) {
    _appState.setPost(post);
  }

  /// Remove post
  void removePost(String postId) {
    _appState.removePost(postId);
  }

  /// Update post engagement
  void updatePostEngagement(
    String postId, {
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? viewsCount,
  }) {
    _appState.updatePostEngagement(
      postId,
      likesCount: likesCount,
      commentsCount: commentsCount,
      sharesCount: sharesCount,
      viewsCount: viewsCount,
    );
  }

  /// Add or update comment
  void setComment(Comment comment) {
    _appState.setComment(comment);
  }

  /// Remove comment
  void removeComment(String commentId) {
    _appState.removeComment(commentId);
  }

  /// Set post like status
  void setPostLikeStatus(String postId, bool isLiked, {int? newLikesCount}) {
    _appState.setPostLikeStatus(postId, isLiked, newLikesCount: newLikesCount);
  }

  /// Set comment like status
  void setCommentLikeStatus(
    String commentId,
    bool isLiked, {
    int? newLikesCount,
  }) {
    _appState.setCommentLikeStatus(
      commentId,
      isLiked,
      newLikesCount: newLikesCount,
    );
  }

  /// Set follow status
  void setFollowStatus(String avatarId, bool isFollowing) {
    _appState.setFollowStatus(avatarId, isFollowing);
  }

  /// Set bookmark status
  void setBookmarkStatus(String postId, bool isBookmarked) {
    _appState.setBookmarkStatus(postId, isBookmarked);
  }

  /// Set loading state
  void setLoading(bool isLoading) {
    _appState.setLoading(isLoading);
  }

  /// Set specific loading state
  void setLoadingState(String key, bool isLoading) {
    _appState.setLoadingState(key, isLoading);
  }

  /// Set error state
  void setError(String? error) {
    _appState.setError(error);
  }

  /// Clear error state
  void clearError() {
    _appState.clearError();
  }

  /// Set pagination state
  void setPaginationState(String context, int currentPage, bool hasMore) {
    _appState.setPaginationState(context, currentPage, hasMore);
  }

  /// Bulk set posts
  void setPosts(List<PostModel> posts, {String context = 'feed'}) {
    _appState.setPosts(posts, context: context);
  }

  /// Bulk set comments for a post
  void setPostComments(String postId, List<Comment> comments) {
    _appState.setPostComments(postId, comments);
  }

  /// Clear all data (logout)
  void clearAll() {
    _appState.clearAll();
  }

  // ========== CONVENIENCE METHODS FOR COMMON OPERATIONS ==========

  /// Update post like count optimistically
  void optimisticTogglePostLike(String postId) {
    final currentLiked = isPostLiked(postId);
    final post = getPost(postId);
    if (post != null) {
      final newCount = currentLiked ? post.likesCount - 1 : post.likesCount + 1;
      setPostLikeStatus(postId, !currentLiked, newLikesCount: newCount);
    }
  }

  /// Update comment like count optimistically
  void optimisticToggleCommentLike(String commentId) {
    final currentLiked = isCommentLiked(commentId);
    final comment = getComment(commentId);
    if (comment != null) {
      final newCount = currentLiked
          ? comment.likesCount - 1
          : comment.likesCount + 1;
      setCommentLikeStatus(commentId, !currentLiked, newLikesCount: newCount);
    }
  }

  // ========== MISSING METHODS FOR FEEDS SERVICE ==========

  /// Get cached posts for a specific feed
  List<PostModel>? getCachedPostsForFeed(String feedType) {
    // For now, return feed posts - can be expanded to support different feed types
    return _appState.feedPosts.isNotEmpty ? _appState.feedPosts : null;
  }

  /// Cache posts from service
  void cachePosts(List<PostModel> posts) {
    for (final post in posts) {
      setPost(post);
    }
  }

  /// Set feed posts for specific page
  void setFeedPostsForPage(List<PostModel> posts, int page) {
    // For now, just set posts - can be expanded to support page-specific caching
    setPosts(posts);
  }

  /// Set feed loading state
  void setFeedLoadingState(String feedType, bool isLoading) {
    setLoadingState(feedType, isLoading);
  }

  /// Set feed error
  void setFeedError(String feedType, String? error) {
    setError(error);
  }

  /// Set post liked status (alias for setPostLikeStatus)
  void setPostLikedStatus(String postId, bool isLiked) {
    setPostLikeStatus(postId, isLiked);
  }

  /// Check if avatar is followed (alias for isFollowingAvatar)
  bool isAvatarFollowed(String avatarId) {
    return isFollowingAvatar(avatarId);
  }

  /// Set avatar followed status (alias for setFollowStatus)
  void setAvatarFollowedStatus(String avatarId, bool isFollowing) {
    setFollowStatus(avatarId, isFollowing);
  }

  /// Set post bookmarked status (alias for setBookmarkStatus)
  void setPostBookmarkedStatus(String postId, bool isBookmarked) {
    setBookmarkStatus(postId, isBookmarked);
  }

  /// Get cached post by ID
  PostModel? getCachedPost(String postId) {
    return getPost(postId);
  }

  /// Get cached avatar by ID
  AvatarModel? getCachedAvatar(String avatarId) {
    return getAvatar(avatarId);
  }

  /// Get cached comment by ID
  Comment? getCachedComment(String commentId) {
    return getComment(commentId);
  }

  // Placeholder for notifyListeners - this would typically be handled by
  // the underlying ChangeNotifier, but for now just adding as no-op
  void notifyListeners() {
    // This will be handled by the underlying AppState ChangeNotifier
    // when proper integration is implemented
  }

  /// Update follow status optimistically
  void optimisticToggleFollow(String avatarId) {
    final currentFollowing = isFollowingAvatar(avatarId);
    setFollowStatus(avatarId, !currentFollowing);
  }

  /// Update bookmark status optimistically
  void optimisticToggleBookmark(String postId) {
    final currentBookmarked = isPostBookmarked(postId);
    setBookmarkStatus(postId, !currentBookmarked);
  }

  /// Add listener to state changes
  void addListener(VoidCallback listener) {
    _appState.addListener(listener);
  }

  /// Remove listener from state changes
  void removeListener(VoidCallback listener) {
    _appState.removeListener(listener);
  }

  /// Get the underlying AppState for direct access (advanced usage)
  AppState get appState => _appState;

  // ========== OWNERSHIP DETECTION METHODS ==========

  final OwnershipManager _ownershipManager = OwnershipManager();

  /// Check if the current user owns a profile
  bool isOwnProfile(String? userId) => _ownershipManager.isOwnProfile(userId);

  /// Check if the current user owns a post
  bool isOwnPost(PostModel? post) => _ownershipManager.isOwnPost(post);

  /// Check if the current user owns a post by ID
  bool isOwnPostById(String? postId) => _ownershipManager.isOwnPostById(
    postId,
    postId != null ? getPost(postId) : null,
  );

  /// Check if the current user owns an avatar
  bool isOwnAvatar(String? avatarId) => _ownershipManager.isOwnAvatar(
    avatarId,
    avatar: avatarId != null ? getAvatar(avatarId) : null,
  );

  /// Check if the current user owns a comment
  bool isOwnComment(Comment? comment) =>
      _ownershipManager.isOwnComment(comment);

  /// Check if the current user owns a comment by ID
  bool isOwnCommentById(String? commentId) =>
      _ownershipManager.isOwnCommentById(
        commentId,
        commentId != null ? getComment(commentId) : null,
      );

  /// Generic ownership check for any element
  bool isOwnElement(dynamic element) => _ownershipManager.isOwnElement(element);

  /// Check if element belongs to another user
  bool isOtherElement(dynamic element) =>
      _ownershipManager.isOtherElement(element);

  /// Check if user can edit an element
  bool canEdit(dynamic element) => _ownershipManager.canEdit(element);

  /// Check if user can delete an element
  bool canDelete(dynamic element) => _ownershipManager.canDelete(element);

  /// Check if user can view private details
  bool canViewPrivateDetails(dynamic element) =>
      _ownershipManager.canViewPrivateDetails(element);

  /// Check if user can modify settings
  bool canModifySettings(dynamic element) =>
      _ownershipManager.canModifySettings(element);

  /// Check if user can follow the element owner
  bool canFollowElement(dynamic element) =>
      _ownershipManager.canFollowElement(element);

  /// Check if user can report the element
  bool canReportElement(dynamic element) =>
      _ownershipManager.canReportElement(element);

  /// Get detailed ownership state
  OwnershipState getOwnershipState(dynamic element) =>
      _ownershipManager.getOwnershipState(element);

  /// Debug ownership information
  void debugOwnership(dynamic element, {String? context}) =>
      _ownershipManager.debugOwnership(element, context: context);

  // ========== CACHE WARMING METHODS ==========

  /// Warm cache with data from services
  void warmCacheFromService({
    List<PostModel>? posts,
    List<AvatarModel>? avatars,
    List<Comment>? comments,
    Map<String, bool>? likedPosts,
    Map<String, bool>? followingAvatars,
    Map<String, bool>? bookmarkedPosts,
  }) {
    if (posts != null) {
      for (final post in posts) {
        setPost(post);
      }
    }

    if (avatars != null) {
      for (final avatar in avatars) {
        setAvatar(avatar);
      }
    }

    if (comments != null) {
      for (final comment in comments) {
        setComment(comment);
      }
    }

    if (likedPosts != null) {
      for (final entry in likedPosts.entries) {
        _appState.setPostLikeStatus(entry.key, entry.value);
      }
    }

    if (followingAvatars != null) {
      for (final entry in followingAvatars.entries) {
        _appState.setFollowStatus(entry.key, entry.value);
      }
    }

    if (bookmarkedPosts != null) {
      for (final entry in bookmarkedPosts.entries) {
        _appState.setBookmarkStatus(entry.key, entry.value);
      }
    }

    // State changes will be notified automatically by AppState
  }

  /// Batch update for better performance
  void batchUpdate(VoidCallback updates) {
    // For now, just execute updates directly
    // In a more sophisticated implementation, we could implement
    // notification batching to improve performance
    try {
      updates();
    } finally {
      // State changes will be notified automatically by AppState
    }
  }
}
