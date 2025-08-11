import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/video_service.dart';

class FeedsVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool isActive;
  final bool autoPlay;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final ValueChanged<bool>? onPlayStateChanged;
  final ValueChanged<Duration>? onPositionChanged;
  final bool showPlayButton;

  const FeedsVideoPlayer({
    super.key,
    required this.videoUrl,
    this.isActive = true,
    this.autoPlay = true,
    this.onTap,
    this.onDoubleTap,
    this.onPlayStateChanged,
    this.onPositionChanged,
    this.showPlayButton = true,
  });

  @override
  State<FeedsVideoPlayer> createState() => _FeedsVideoPlayerState();
}

class _FeedsVideoPlayerState extends State<FeedsVideoPlayer>
    with SingleTickerProviderStateMixin {
  final VideoService _videoService = VideoService();
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _showPlayButton = false;
  bool _isPlaying = false;
  late AnimationController _playButtonAnimationController;
  late Animation<double> _playButtonAnimation;

  @override
  void initState() {
    super.initState();
    _playButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _playButtonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _playButtonAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _initializeVideo();
  }

  @override
  void didUpdateWidget(FeedsVideoPlayer oldWidget) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
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
      _playButtonAnimationController.reverse();
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
      _playButtonAnimationController.forward();
    } catch (e) {
      debugPrint('Error pausing video: $e');
    }
  }

  Future<void> _togglePlayState() async {
    if (_isPlaying) {
      await _pauseVideo();
    } else {
      await _playVideo();
    }
  }

  void _handleTap() {
    widget.onTap?.call();
    if (widget.showPlayButton) {
      _togglePlayState();
    }
  }

  void _handleDoubleTap() {
    widget.onDoubleTap?.call();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoPlayerUpdate);
    _playButtonAnimationController.dispose();
    // Don't dispose controller here - VideoService manages it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Player
            if (_controller != null && 
                _controller!.value.isInitialized && 
                !_hasError)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_hasError)
              _buildErrorState()
            else
              _buildLoadingState(),

            // Play button overlay
            if (_showPlayButton && widget.showPlayButton && !_hasError)
              Center(
                child: AnimatedBuilder(
                  animation: _playButtonAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * _playButtonAnimation.value),
                      child: Opacity(
                        opacity: _playButtonAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Failed to load video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
