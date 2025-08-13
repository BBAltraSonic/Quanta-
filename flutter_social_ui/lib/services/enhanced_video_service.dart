import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/db_config.dart';
import 'analytics_service.dart';

/// Enhanced video service with advanced playback controls and analytics
class EnhancedVideoService {
  static final EnhancedVideoService _instance = EnhancedVideoService._internal();
  factory EnhancedVideoService() => _instance;
  EnhancedVideoService._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _preloadedVideos = {};
  final Map<String, Duration> _lastPositions = {};
  final Map<String, DateTime> _playStartTimes = {};
  final Map<String, int> _totalWatchTime = {};
  
  bool _isMuted = false;
  double _volume = 1.0;
  String? _currentlyPlayingUrl;
  
  // Analytics service
  final AnalyticsService _analyticsService = AnalyticsService();
  
  // Event callbacks (deprecated - use analytics service instead)
  Function(String url, String event, Map<String, dynamic> data)? onAnalyticsEvent;
  
  /// Initialize video service
  Future<void> initialize() async {
    await _loadSettings();
    debugPrint('✅ EnhancedVideoService initialized');
  }

  /// Load user settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMuted = prefs.getBool('video_muted') ?? false;
      _volume = prefs.getDouble('video_volume') ?? 1.0;
    } catch (e) {
      debugPrint('Error loading video settings: $e');
    }
  }

  /// Save user settings to storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('video_muted', _isMuted);
      await prefs.setDouble('video_volume', _volume);
    } catch (e) {
      debugPrint('Error saving video settings: $e');
    }
  }

  /// Get or create video controller with optimization
  Future<VideoPlayerController> getController(String videoUrl) async {
    if (_controllers.containsKey(videoUrl)) {
      return _controllers[videoUrl]!;
    }

    // Use networkUrl with auto format detection for standard MP4/HLS/others
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );

    _controllers[videoUrl] = controller;
    
    // Initialize video in background to prevent UI blocking
    _initializeControllerAsync(controller, videoUrl);
    
    return controller;
  }
  
  /// Initialize controller asynchronously to prevent main thread blocking
  Future<void> _initializeControllerAsync(VideoPlayerController controller, String videoUrl) async {
    try {
      // Initialize controller with timeout to prevent hanging
      await controller.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Video initialization timeout', const Duration(seconds: 10)),
      );
      
      // Batch video configuration to reduce MediaCodec calls
      await Future.wait([
        controller.setLooping(true),
        controller.setVolume(_isMuted ? 0.0 : _volume),
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Video configuration timeout for $videoUrl');
          return <void>[];
        },
      );
      
      // Only restore position if it's significant (> 1 second)
      final lastPosition = _lastPositions[videoUrl];
      if (lastPosition != null && lastPosition > const Duration(seconds: 1)) {
        await controller.seekTo(lastPosition).timeout(
          const Duration(seconds: 3),
          onTimeout: () => debugPrint('Seek timeout for $videoUrl'),
        );
      }
      
      _preloadedVideos[videoUrl] = true;
    } catch (e) {
      debugPrint('Error initializing video controller: $e');
      _preloadedVideos[videoUrl] = false;
    }
  }

  /// Preload video for smooth playback (non-blocking)
  Future<void> preloadVideo(String videoUrl) async {
    if (_preloadedVideos.containsKey(videoUrl)) return;

    // Preload in background to avoid blocking UI
    Future.microtask(() async {
      try {
        await getController(videoUrl);
        _preloadedVideos[videoUrl] = true;
      } catch (e) {
        debugPrint('Error preloading video: $e');
        _preloadedVideos[videoUrl] = false;
      }
    });
  }

  /// Play video with analytics
  Future<void> playVideo(String videoUrl) async {
    try {
      // Pause currently playing video
      if (_currentlyPlayingUrl != null && _currentlyPlayingUrl != videoUrl) {
        await pauseVideo(_currentlyPlayingUrl!);
      }

      final controller = _controllers[videoUrl];
      if (controller != null && controller.value.isInitialized) {
        _playStartTimes[videoUrl] = DateTime.now();
        _currentlyPlayingUrl = videoUrl;
        
        await controller.play();
        
        // Track analytics event
        _trackEvent(videoUrl, DbConfig.playEvent, {
          'position': controller.value.position.inSeconds,
          'duration': controller.value.duration.inSeconds,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error playing video: $e');
    }
  }

  /// Pause video with analytics
  Future<void> pauseVideo(String videoUrl) async {
    try {
      final controller = _controllers[videoUrl];
      if (controller != null && controller.value.isInitialized && controller.value.isPlaying) {
        // Track watch time
        final startTime = _playStartTimes[videoUrl];
        if (startTime != null) {
          final watchDuration = DateTime.now().difference(startTime).inSeconds;
          _totalWatchTime[videoUrl] = (_totalWatchTime[videoUrl] ?? 0) + watchDuration;
        }
        
        // Save current position
        _lastPositions[videoUrl] = controller.value.position;
        
        await controller.pause();
        
        if (_currentlyPlayingUrl == videoUrl) {
          _currentlyPlayingUrl = null;
        }
        
        // Track analytics event
        _trackEvent(videoUrl, DbConfig.pauseEvent, {
          'position': controller.value.position.inSeconds,
          'duration': controller.value.duration.inSeconds,
          'watch_time': _totalWatchTime[videoUrl] ?? 0,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error pausing video: $e');
    }
  }

  /// Toggle play/pause
  Future<bool> togglePlayPause(String videoUrl) async {
    final controller = _controllers[videoUrl];
    if (controller != null && controller.value.isInitialized) {
      if (controller.value.isPlaying) {
        await pauseVideo(videoUrl);
        return false;
      } else {
        await playVideo(videoUrl);
        return true;
      }
    }
    return false;
  }

  /// Set video volume
  Future<void> setVolume(String videoUrl, double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _saveSettings();
      
      final controller = _controllers[videoUrl];
      if (controller != null && controller.value.isInitialized) {
        await controller.setVolume(_isMuted ? 0.0 : _volume);
      }
    } catch (e) {
      debugPrint('Error setting video volume: $e');
    }
  }

  /// Toggle mute/unmute
  Future<bool> toggleMute(String? videoUrl) async {
    try {
      _isMuted = !_isMuted;
      await _saveSettings();
      
      // Apply to all controllers if no specific URL
      if (videoUrl == null) {
        for (final controller in _controllers.values) {
          if (controller.value.isInitialized) {
            await controller.setVolume(_isMuted ? 0.0 : _volume);
          }
        }
      } else {
        final controller = _controllers[videoUrl];
        if (controller != null && controller.value.isInitialized) {
          await controller.setVolume(_isMuted ? 0.0 : _volume);
        }
      }
      
      return _isMuted;
    } catch (e) {
      debugPrint('Error toggling mute: $e');
      return _isMuted;
    }
  }

  /// Mute all videos
  Future<void> muteAllVideos() async {
    try {
      _isMuted = true;
      await _saveSettings();
      
      for (final controller in _controllers.values) {
        if (controller.value.isInitialized) {
          await controller.setVolume(0.0);
        }
      }
    } catch (e) {
      debugPrint('Error muting all videos: $e');
    }
  }

  /// Unmute all videos
  Future<void> unmuteAllVideos() async {
    try {
      _isMuted = false;
      await _saveSettings();
      
      for (final controller in _controllers.values) {
        if (controller.value.isInitialized) {
          await controller.setVolume(_volume);
        }
      }
    } catch (e) {
      debugPrint('Error unmuting all videos: $e');
    }
  }

  /// Seek to position with analytics
  Future<void> seekTo(String videoUrl, Duration position) async {
    try {
      final controller = _controllers[videoUrl];
      if (controller != null && controller.value.isInitialized) {
        final oldPosition = controller.value.position;
        await controller.seekTo(position);
        _lastPositions[videoUrl] = position;
        
        // Track analytics event
        _trackEvent(videoUrl, DbConfig.seekEvent, {
          'from_position': oldPosition.inSeconds,
          'to_position': position.inSeconds,
          'duration': controller.value.duration.inSeconds,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error seeking video: $e');
    }
  }

  /// Pause all videos (for memory management)
  Future<void> pauseAllVideos() async {
    for (final url in _controllers.keys.toList()) {
      final controller = _controllers[url];
      if (controller != null && controller.value.isInitialized && controller.value.isPlaying) {
        await pauseVideo(url);
      }
    }
    _currentlyPlayingUrl = null;
  }

  /// Dispose video controller
  void disposeController(String videoUrl) {
    final controller = _controllers[videoUrl];
    if (controller != null) {
      // Save position before disposing
      if (controller.value.isInitialized) {
        _lastPositions[videoUrl] = controller.value.position;
      }
      
      controller.dispose();
      _controllers.remove(videoUrl);
      _preloadedVideos.remove(videoUrl);
      _playStartTimes.remove(videoUrl);
    }
  }

  /// Clean up unused controllers (memory management)
  void cleanupUnusedControllers(List<String> activeVideoUrls) {
    final urlsToRemove = <String>[];
    
    for (final url in _controllers.keys) {
      if (!activeVideoUrls.contains(url)) {
        urlsToRemove.add(url);
      }
    }

    for (final url in urlsToRemove) {
      disposeController(url);
    }
  }

  /// Check if video is ready to play
  bool isVideoReady(String videoUrl) {
    return _preloadedVideos[videoUrl] == true;
  }

  /// Check if video is currently playing
  bool isVideoPlaying(String videoUrl) {
    final controller = _controllers[videoUrl];
    return controller != null && controller.value.isInitialized && controller.value.isPlaying;
  }

  /// Get video duration
  Duration? getVideoDuration(String videoUrl) {
    final controller = _controllers[videoUrl];
    if (controller != null && controller.value.isInitialized) {
      return controller.value.duration;
    }
    return null;
  }

  /// Get video position
  Duration? getVideoPosition(String videoUrl) {
    final controller = _controllers[videoUrl];
    if (controller != null && controller.value.isInitialized) {
      return controller.value.position;
    }
    return null;
  }

  /// Get video controller
  VideoPlayerController? getVideoController(String videoUrl) {
    return _controllers[videoUrl];
  }

  /// Get watch percentage
  double getWatchPercentage(String videoUrl) {
    final controller = _controllers[videoUrl];
    if (controller != null && controller.value.isInitialized) {
      final position = controller.value.position.inSeconds;
      final duration = controller.value.duration.inSeconds;
      if (duration > 0) {
        return (position / duration).clamp(0.0, 1.0);
      }
    }
    return 0.0;
  }

  /// Get total watch time for a video
  int getTotalWatchTime(String videoUrl) {
    return _totalWatchTime[videoUrl] ?? 0;
  }

  /// Check if video should be considered "viewed"
  bool isVideoViewed(String videoUrl) {
    final watchTime = getTotalWatchTime(videoUrl);
    final percentage = getWatchPercentage(videoUrl);
    
    return watchTime >= DbConfig.viewThresholdSeconds || 
           percentage >= DbConfig.significantWatchPercentage;
  }

  /// Get current settings
  Map<String, dynamic> getCurrentSettings() {
    return {
      'isMuted': _isMuted,
      'volume': _volume,
      'currentlyPlaying': _currentlyPlayingUrl,
    };
  }

  /// Track analytics event
  void _trackEvent(String videoUrl, String event, Map<String, dynamic> data) {
    // Use analytics service for proper tracking
    _analyticsService.trackVideoEvent(event, _getPostIdFromUrl(videoUrl), data);
    
    // Also call legacy callback if set
    onAnalyticsEvent?.call(videoUrl, event, data);
  }
  
  /// Extract post ID from video URL (simple implementation)
  String _getPostIdFromUrl(String videoUrl) {
    // In a real implementation, you'd have a proper mapping
    // For now, use the URL as a fallback identifier
    return videoUrl.hashCode.toString();
  }

  /// Dispose all controllers
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _preloadedVideos.clear();
    _lastPositions.clear();
    _playStartTimes.clear();
    _totalWatchTime.clear();
    _currentlyPlayingUrl = null;
  }
}

/// Enhanced video player widget with full controls
class EnhancedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool showControls;
  final bool isActive;
  final double aspectRatio;
  final VoidCallback? onVideoReady;
  final VoidCallback? onVideoError;
  final Function(bool isPlaying)? onPlayStateChanged;
  final Function(Duration position)? onPositionChanged;

  const EnhancedVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.showControls = false,
    this.isActive = true,
    this.aspectRatio = 16 / 9,
    this.onVideoReady,
    this.onVideoError,
    this.onPlayStateChanged,
    this.onPositionChanged,
  });

  @override
  State<EnhancedVideoPlayer> createState() => _EnhancedVideoPlayerState();
}

class _EnhancedVideoPlayerState extends State<EnhancedVideoPlayer> {
  final EnhancedVideoService _videoService = EnhancedVideoService();
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _showPlayButton = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(EnhancedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializeVideo();
    }
    
    if (oldWidget.isActive != widget.isActive) {
      _handleActiveStateChange();
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.videoUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _controller = await _videoService.getController(widget.videoUrl);
      
      if (mounted) {
        // Listen to player state changes
        _controller!.addListener(_onVideoPlayerUpdate);
        
        setState(() {
          _isLoading = false;
        });

        // Auto-play if active and enabled
        if (widget.isActive && widget.autoPlay) {
          await _playVideo();
        }

        widget.onVideoReady?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        widget.onVideoError?.call();
      }
      debugPrint('Error initializing video: $e');
    }
  }

  void _onVideoPlayerUpdate() {
    if (!mounted || _controller == null) return;
    
    final isPlaying = _controller!.value.isPlaying;
    if (_isPlaying != isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
      widget.onPlayStateChanged?.call(isPlaying);
    }

    // Report position changes
    widget.onPositionChanged?.call(_controller!.value.position);
  }

  void _handleActiveStateChange() {
    if (!mounted || _controller == null) return;
    
    if (widget.isActive) {
      if (widget.autoPlay) {
        _playVideo();
      }
    } else {
      _pauseVideo();
    }
  }

  Future<void> _playVideo() async {
    try {
      await _videoService.playVideo(widget.videoUrl);
      setState(() {
        _isPlaying = true;
        _showPlayButton = false;
      });
    } catch (e) {
      debugPrint('Error playing video: $e');
    }
  }

  Future<void> _pauseVideo() async {
    try {
      await _videoService.pauseVideo(widget.videoUrl);
      setState(() {
        _isPlaying = false;
        _showPlayButton = true;
      });
    } catch (e) {
      debugPrint('Error pausing video: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    final isPlaying = await _videoService.togglePlayPause(widget.videoUrl);
    setState(() {
      _isPlaying = isPlaying;
      _showPlayButton = !isPlaying;
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoPlayerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    if (_hasError || _controller == null) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white54,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Video not available',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: GestureDetector(
        onTap: widget.showControls ? _togglePlayPause : null,
        child: Stack(
          children: [
            VideoPlayer(_controller!),
            
            // Play button overlay
            if (_showPlayButton && widget.showControls)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
