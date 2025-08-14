import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/db_config.dart';
import 'auth_service.dart';

/// Analytics service for tracking user interactions and events
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Event queue for batch processing
  final List<Map<String, dynamic>> _eventQueue = [];
  static const int _batchSize = 20; // Increased batch size
  static const int _flushIntervalMs = 15000; // Increased to 15 seconds
  
  /// Initialize analytics service
  Future<void> initialize() async {
    // Start periodic flush of events
    _startPeriodicFlush();
    debugPrint('✅ AnalyticsService initialized');
  }

  /// Track a user interaction event
  Future<void> trackEvent(String eventType, Map<String, dynamic> properties) async {
    final userId = _authService.currentUserId;
    
    if (userId == null && !_isSystemEvent(eventType)) {
      // Skip user events if not authenticated
      return;
    }

    final event = {
      'event_type': eventType,
      'user_id': userId,
      'event_data': properties,
      'session_id': _generateSessionId(),
      'created_at': DateTime.now().toIso8601String(),
    };

    // Add to queue for batch processing
    _eventQueue.add(event);
    
    // Flush if queue is full
    if (_eventQueue.length >= _batchSize) {
      await _flushEvents();
    }

    // Also log for debugging in development
    if (kDebugMode) {
      debugPrint('📊 Analytics: $eventType - $properties');
    }
  }

  /// Track post view event
  Future<void> trackPostView(String postId, {
    int? durationSeconds,
    double? watchPercentage,
    String? postType,
    String? authorId,
  }) async {
    await trackEvent(AnalyticsEvents.postView, {
      'post_id': postId,
      'duration_seconds': durationSeconds,
      'watch_percentage': watchPercentage,
      'post_type': postType,
      'author_id': authorId,
    });
  }

  /// Track like toggle event
  Future<void> trackLikeToggle(String postId, bool liked, {
    String? postType,
    String? authorId,
    int? likesCount,
  }) async {
    await trackEvent(AnalyticsEvents.likeToggle, {
      'post_id': postId,
      'liked': liked,
      'post_type': postType,
      'author_id': authorId,
      'likes_count': likesCount,
    });
  }

  /// Track comment add event
  Future<void> trackCommentAdd(String postId, String commentId, {
    String? postType,
    String? authorId,
    int? commentLength,
  }) async {
    await trackEvent(AnalyticsEvents.commentAdd, {
      'post_id': postId,
      'comment_id': commentId,
      'post_type': postType,
      'author_id': authorId,
      'comment_length': commentLength,
    });
  }

  /// Track share attempt event
  Future<void> trackShareAttempt(String postId, String shareMethod, {
    String? postType,
    String? authorId,
    bool? successful,
  }) async {
    await trackEvent(AnalyticsEvents.shareAttempt, {
      'post_id': postId,
      'share_method': shareMethod,
      'post_type': postType,
      'author_id': authorId,
      'successful': successful,
    });
  }

  /// Track bookmark toggle event
  Future<void> trackBookmarkToggle(String postId, bool bookmarked, {
    String? postType,
    String? authorId,
  }) async {
    await trackEvent(AnalyticsEvents.bookmarkToggle, {
      'post_id': postId,
      'bookmarked': bookmarked,
      'post_type': postType,
      'author_id': authorId,
    });
  }

  /// Track follow toggle event
  Future<void> trackFollowToggle(String avatarId, bool followed, {
    String? avatarName,
    String? niche,
  }) async {
    await trackEvent(AnalyticsEvents.followToggle, {
      'avatar_id': avatarId,
      'followed': followed,
      'avatar_name': avatarName,
      'niche': niche,
    });
  }

  /// Track video playback events
  Future<void> trackVideoEvent(String eventType, String postId, Map<String, dynamic> data) async {
    await trackEvent(eventType, {
      'post_id': postId,
      ...data,
    });
  }

  /// Track comment modal events
  Future<void> trackCommentModalOpen(String postId, {
    String? postType,
    String? authorId,
    int? commentsCount,
  }) async {
    await trackEvent(AnalyticsEvents.commentModalOpen, {
      'post_id': postId,
      'post_type': postType,
      'author_id': authorId,
      'comments_count': commentsCount,
    });
  }

  /// Track screen navigation events
  Future<void> trackScreenView(String screenName, {Map<String, dynamic>? properties}) async {
    await trackEvent(AnalyticsEvents.screenView, {
      'screen_name': screenName,
      ...?properties,
    });
  }

  /// Track error events
  Future<void> trackError(String errorType, String errorMessage, {
    String? stackTrace,
    String? context,
  }) async {
    await trackEvent(AnalyticsEvents.error, {
      'error_type': errorType,
      'error_message': errorMessage,
      'stack_trace': stackTrace,
      'context': context,
    });
  }

  /// Track search events
  Future<void> trackSearch(String query, {
    int? resultsCount,
    String? searchType,
  }) async {
    await trackEvent(AnalyticsEvents.search, {
      'query': query,
      'results_count': resultsCount,
      'search_type': searchType,
    });
  }

  /// Track content upload events
  Future<void> trackContentUpload(String eventType, {
    String? contentType,
    int? fileSizeBytes,
    int? durationSeconds,
  }) async {
    await trackEvent(eventType, {
      'content_type': contentType,
      'file_size_bytes': fileSizeBytes,
      'duration_seconds': durationSeconds,
    });
  }

  /// Check if event doesn't require authentication
  bool _isSystemEvent(String eventType) {
    const systemEvents = [
      AnalyticsEvents.error,
      AnalyticsEvents.screenView,
      AnalyticsEvents.appStart,
      AnalyticsEvents.appBackground,
    ];
    return systemEvents.contains(eventType);
  }

  /// Generate session ID (simple implementation)
  String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Start periodic flush timer
  void _startPeriodicFlush() {
    Stream.periodic(Duration(milliseconds: _flushIntervalMs)).listen((_) {
      if (_eventQueue.isNotEmpty) {
        _flushEvents();
      }
    });
  }

  /// Flush events to database
  Future<void> _flushEvents() async {
    if (_eventQueue.isEmpty) return;

    final eventsToFlush = List<Map<String, dynamic>>.from(_eventQueue);
    _eventQueue.clear();

    try {
      // Store in analytics_events table
      await _supabase.from('analytics_events').insert(eventsToFlush);
      
      if (kDebugMode) {
        debugPrint('📊 Flushed ${eventsToFlush.length} analytics events');
      }
    } catch (e) {
      // If flush fails, only retry if it's a temporary network error
      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        _eventQueue.addAll(eventsToFlush);
      } else {
        // For 404 errors or schema errors, don't retry to avoid endless loops
        if (kDebugMode) {
          debugPrint('⚠️ Discarding ${eventsToFlush.length} analytics events due to persistent error');
        }
      }
      
      if (kDebugMode) {
        debugPrint('❌ Failed to flush analytics events: $e');
      }
    }
  }

  /// Manually flush all pending events
  Future<void> flush() async {
    await _flushEvents();
  }

  /// Dispose analytics service
  void dispose() {
    _flushEvents(); // Final flush
  }
}

/// Analytics event constants
class AnalyticsEvents {
  // Core user interactions
  static const String postView = 'post_view';
  static const String likeToggle = 'like_toggle';
  static const String commentAdd = 'comment_add';
  static const String shareAttempt = 'share_attempt';
  static const String bookmarkToggle = 'bookmark_toggle';
  static const String followToggle = 'follow_toggle';
  
  // Video events
  static const String videoPlay = 'video_play';
  static const String videoPause = 'video_pause';
  static const String videoSeek = 'video_seek';
  static const String videoComplete = 'video_complete';
  
  // UI interactions
  static const String commentModalOpen = 'comment_modal_open';
  static const String screenView = 'screen_view';
  static const String search = 'search';
  
  // Content creation
  static const String uploadStart = 'upload_start';
  static const String uploadComplete = 'upload_complete';
  static const String uploadFailed = 'upload_failed';
  
  // System events
  static const String appStart = 'app_start';
  static const String appBackground = 'app_background';
  static const String error = 'error';
  
  // Social interactions
  static const String commentLike = 'comment_like';
  static const String reportContent = 'report_content';
  static const String blockUser = 'block_user';
  static const String muteUser = 'mute_user';
  
  // Navigation
  static const String tabSwitch = 'tab_switch';
  static const String profileView = 'profile_view';
  static const String feedRefresh = 'feed_refresh';
}
