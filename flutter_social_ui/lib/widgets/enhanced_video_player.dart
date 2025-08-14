import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/enhanced_video_service.dart';

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
