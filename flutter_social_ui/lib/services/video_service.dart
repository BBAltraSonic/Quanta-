import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Service for optimizing video loading and playback
class VideoService {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _preloadedVideos = {};
  
  /// Initialize video service
  Future<void> initialize() async {
    // Setup video optimization settings
    debugPrint('VideoService initialized');
  }

  /// Get or create video controller with optimization
  Future<VideoPlayerController> getController(String videoUrl) async {
    if (_controllers.containsKey(videoUrl)) {
      return _controllers[videoUrl]!;
    }

    final controller = VideoPlayerController.network(
      videoUrl,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );

    _controllers[videoUrl] = controller;
    
    try {
      await controller.initialize();
      _preloadedVideos[videoUrl] = true;
    } catch (e) {
      debugPrint('Error initializing video controller: $e');
      _preloadedVideos[videoUrl] = false;
    }

    return controller;
  }

  /// Preload video for smooth playback
  Future<void> preloadVideo(String videoUrl) async {
    if (_preloadedVideos.containsKey(videoUrl)) return;

    try {
      final controller = await getController(videoUrl);
      await controller.setLooping(true);
      _preloadedVideos[videoUrl] = true;
    } catch (e) {
      debugPrint('Error preloading video: $e');
      _preloadedVideos[videoUrl] = false;
    }
  }

  /// Play video with optimization
  Future<void> playVideo(String videoUrl) async {
    try {
      final controller = _controllers[videoUrl];
      if (controller != null && controller.value.isInitialized) {
        await controller.play();
      }
    } catch (e) {
      debugPrint('Error playing video: $e');
    }
  }

  /// Pause video
  Future<void> pauseVideo(String videoUrl) async {
    try {
      final controller = _controllers[videoUrl];
      if (controller != null && controller.value.isInitialized) {
        await controller.pause();
      }
    } catch (e) {
      debugPrint('Error pausing video: $e');
    }
  }

  /// Pause all videos (for memory management)
  Future<void> pauseAllVideos() async {
    for (final controller in _controllers.values) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        await controller.pause();
      }
    }
  }

  /// Dispose video controller
  void disposeController(String videoUrl) {
    final controller = _controllers[videoUrl];
    if (controller != null) {
      controller.dispose();
      _controllers.remove(videoUrl);
      _preloadedVideos.remove(videoUrl);
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

  /// Seek to position
  Future<void> seekTo(String videoUrl, Duration position) async {
    try {
      final controller = _controllers[videoUrl];
      if (controller != null && controller.value.isInitialized) {
        await controller.seekTo(position);
      }
    } catch (e) {
      debugPrint('Error seeking video: $e');
    }
  }

  /// Set video volume
  Future<void> setVolume(String videoUrl, double volume) async {
    try {
      final controller = _controllers[videoUrl];
      if (controller != null && controller.value.isInitialized) {
        await controller.setVolume(volume.clamp(0.0, 1.0));
      }
    } catch (e) {
      debugPrint('Error setting video volume: $e');
    }
  }

  /// Dispose all controllers
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _preloadedVideos.clear();
  }
}

/// Widget for optimized video player
class OptimizedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool showControls;
  final double aspectRatio;
  final VoidCallback? onVideoReady;
  final VoidCallback? onVideoError;

  const OptimizedVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.showControls = false,
    this.aspectRatio = 16 / 9,
    this.onVideoReady,
    this.onVideoError,
  });

  @override
  State<OptimizedVideoPlayer> createState() => _OptimizedVideoPlayerState();
}

class _OptimizedVideoPlayerState extends State<OptimizedVideoPlayer> {
  final VideoService _videoService = VideoService();
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = await _videoService.getController(widget.videoUrl);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (widget.autoPlay) {
          await _videoService.playVideo(widget.videoUrl);
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
    }
  }

  @override
  void dispose() {
    // Don't dispose controller here - let VideoService manage it
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
            child: Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}