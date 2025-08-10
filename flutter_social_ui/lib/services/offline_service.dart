import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../models/user_model.dart';

/// Service for handling offline functionality
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  SharedPreferences? _prefs;
  bool _isOnline = true;
  final List<VoidCallback> _connectivityListeners = [];

  // Cache keys
  static const String _cachedPostsKey = 'cached_posts';
  static const String _cachedAvatarsKey = 'cached_avatars';
  static const String _cachedUserKey = 'cached_user';
  static const String _offlineActionsKey = 'offline_actions';
  static const String _lastSyncKey = 'last_sync';

  /// Initialize offline service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Check initial connectivity
    await _checkConnectivity();

    // Periodically check connectivity
    _startConnectivityMonitoring();

    debugPrint('OfflineService initialized - Online: $_isOnline');
  }

  /// Check connectivity by attempting to reach a reliable host
  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final wasOnline = _isOnline;
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (!wasOnline && _isOnline) {
        // Just came back online - sync offline actions
        _syncOfflineActions();
      }
      
      // Notify listeners
      for (final listener in _connectivityListeners) {
        listener();
      }
    } catch (e) {
      _isOnline = false;
    }
  }

  /// Start monitoring connectivity
  void _startConnectivityMonitoring() {
    // Check connectivity every 30 seconds
    Stream.periodic(const Duration(seconds: 30)).listen((_) {
      _checkConnectivity();
    });
  }

  /// Check if device is online
  bool get isOnline => _isOnline;

  /// Add connectivity listener
  void addConnectivityListener(VoidCallback listener) {
    _connectivityListeners.add(listener);
  }

  /// Remove connectivity listener
  void removeConnectivityListener(VoidCallback listener) {
    _connectivityListeners.remove(listener);
  }

  /// Cache posts for offline access
  Future<void> cachePosts(List<PostModel> posts) async {
    if (_prefs == null) return;

    try {
      final postsJson = posts.map((post) => post.toJson()).toList();
      await _prefs!.setString(_cachedPostsKey, jsonEncode(postsJson));
      await _prefs!.setString(_lastSyncKey, DateTime.now().toIso8601String());
      debugPrint('Cached ${posts.length} posts for offline access');
    } catch (e) {
      debugPrint('Error caching posts: $e');
    }
  }

  /// Get cached posts
  List<PostModel> getCachedPosts() {
    if (_prefs == null) return [];

    try {
      final cachedData = _prefs!.getString(_cachedPostsKey);
      if (cachedData != null) {
        final List<dynamic> postsJson = jsonDecode(cachedData);
        return postsJson.map((json) => PostModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading cached posts: $e');
    }
    
    return [];
  }

  /// Cache avatars for offline access
  Future<void> cacheAvatars(Map<String, AvatarModel> avatars) async {
    if (_prefs == null) return;

    try {
      final avatarsJson = avatars.map((key, avatar) => 
        MapEntry(key, avatar.toJson()));
      await _prefs!.setString(_cachedAvatarsKey, jsonEncode(avatarsJson));
      debugPrint('Cached ${avatars.length} avatars for offline access');
    } catch (e) {
      debugPrint('Error caching avatars: $e');
    }
  }

  /// Get cached avatars
  Map<String, AvatarModel> getCachedAvatars() {
    if (_prefs == null) return {};

    try {
      final cachedData = _prefs!.getString(_cachedAvatarsKey);
      if (cachedData != null) {
        final Map<String, dynamic> avatarsJson = jsonDecode(cachedData);
        return avatarsJson.map((key, json) => 
          MapEntry(key, AvatarModel.fromJson(json)));
      }
    } catch (e) {
      debugPrint('Error loading cached avatars: $e');
    }
    
    return {};
  }

  /// Cache user data
  Future<void> cacheUser(UserModel user) async {
    if (_prefs == null) return;

    try {
      await _prefs!.setString(_cachedUserKey, jsonEncode(user.toJson()));
      debugPrint('Cached user data for offline access');
    } catch (e) {
      debugPrint('Error caching user: $e');
    }
  }

  /// Get cached user
  UserModel? getCachedUser() {
    if (_prefs == null) return null;

    try {
      final cachedData = _prefs!.getString(_cachedUserKey);
      if (cachedData != null) {
        return UserModel.fromJson(jsonDecode(cachedData));
      }
    } catch (e) {
      debugPrint('Error loading cached user: $e');
    }
    
    return null;
  }

  /// Queue action for when back online
  Future<void> queueOfflineAction(OfflineAction action) async {
    if (_prefs == null) return;

    try {
      final existingActions = getOfflineActions();
      existingActions.add(action);
      
      final actionsJson = existingActions.map((a) => a.toJson()).toList();
      await _prefs!.setString(_offlineActionsKey, jsonEncode(actionsJson));
      
      debugPrint('Queued offline action: ${action.type}');
    } catch (e) {
      debugPrint('Error queuing offline action: $e');
    }
  }

  /// Get queued offline actions
  List<OfflineAction> getOfflineActions() {
    if (_prefs == null) return [];

    try {
      final cachedData = _prefs!.getString(_offlineActionsKey);
      if (cachedData != null) {
        final List<dynamic> actionsJson = jsonDecode(cachedData);
        return actionsJson.map((json) => OfflineAction.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading offline actions: $e');
    }
    
    return [];
  }

  /// Sync offline actions when back online
  Future<void> _syncOfflineActions() async {
    if (!_isOnline || _prefs == null) return;

    final actions = getOfflineActions();
    if (actions.isEmpty) return;

    debugPrint('Syncing ${actions.length} offline actions...');

    final successfulActions = <OfflineAction>[];

    for (final action in actions) {
      try {
        final success = await _executeOfflineAction(action);
        if (success) {
          successfulActions.add(action);
        }
      } catch (e) {
        debugPrint('Error syncing offline action: $e');
      }
    }

    // Remove successful actions
    if (successfulActions.isNotEmpty) {
      final remainingActions = actions
          .where((a) => !successfulActions.contains(a))
          .toList();
      
      final actionsJson = remainingActions.map((a) => a.toJson()).toList();
      await _prefs!.setString(_offlineActionsKey, jsonEncode(actionsJson));
      
      debugPrint('Synced ${successfulActions.length} offline actions');
    }
  }

  /// Execute a single offline action
  Future<bool> _executeOfflineAction(OfflineAction action) async {
    // This would integrate with your actual services
    // For now, just simulate success
    await Future.delayed(const Duration(milliseconds: 100));
    
    switch (action.type) {
      case OfflineActionType.like:
        debugPrint('Syncing like action for post: ${action.data['postId']}');
        break;
      case OfflineActionType.comment:
        debugPrint('Syncing comment action for post: ${action.data['postId']}');
        break;
      case OfflineActionType.follow:
        debugPrint('Syncing follow action for avatar: ${action.data['avatarId']}');
        break;
      case OfflineActionType.createPost:
        debugPrint('Syncing create post action');
        break;
    }
    
    return true; // Simulate success
  }

  /// Get last sync time
  DateTime? getLastSyncTime() {
    if (_prefs == null) return null;

    try {
      final lastSyncString = _prefs!.getString(_lastSyncKey);
      if (lastSyncString != null) {
        return DateTime.parse(lastSyncString);
      }
    } catch (e) {
      debugPrint('Error getting last sync time: $e');
    }
    
    return null;
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    if (_prefs == null) return;

    try {
      await _prefs!.remove(_cachedPostsKey);
      await _prefs!.remove(_cachedAvatarsKey);
      await _prefs!.remove(_cachedUserKey);
      await _prefs!.remove(_offlineActionsKey);
      await _prefs!.remove(_lastSyncKey);
      
      debugPrint('Cleared all cached data');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Get cache size info
  Map<String, int> getCacheInfo() {
    if (_prefs == null) return {};

    return {
      'posts': getCachedPosts().length,
      'avatars': getCachedAvatars().length,
      'offlineActions': getOfflineActions().length,
    };
  }
}

/// Types of actions that can be queued for offline sync
enum OfflineActionType {
  like,
  comment,
  follow,
  createPost,
}

/// Represents an action performed while offline
class OfflineAction {
  final OfflineActionType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  OfflineAction({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
    type: OfflineActionType.values.firstWhere(
      (e) => e.name == json['type'],
    ),
    data: json['data'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

/// Widget to show offline status
class OfflineIndicator extends StatefulWidget {
  const OfflineIndicator({super.key});

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  final OfflineService _offlineService = OfflineService();
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _isOnline = _offlineService.isOnline;
    _offlineService.addConnectivityListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _offlineService.removeConnectivityListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (mounted) {
      setState(() {
        _isOnline = _offlineService.isOnline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'You\'re offline. Some features may be limited.',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}