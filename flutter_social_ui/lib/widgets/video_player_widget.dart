import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String? videoUrl;
  final String? fallbackImageUrl;
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onTap;

  const VideoPlayerWidget({
    super.key,
    this.videoUrl,
    this.fallbackImageUrl,
    this.isPlaying = false,
    this.onPlayPause,
    this.onTap,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializeVideo();
    }
    if (oldWidget.isPlaying != widget.isPlaying) {
      _updatePlayState();
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      setState(() {
        _hasError = true;
        _isInitialized = false;
      });
      return;
    }

    try {
      // Dispose of old controller
      await _controller?.dispose();

      // Create new controller
      if (widget.videoUrl!.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
      } else {
        _controller = VideoPlayerController.asset(widget.videoUrl!);
      }

      await _controller!.initialize();

      // Set up listener for video completion
      _controller!.addListener(() {
        if (_controller!.value.position >= _controller!.value.duration) {
          // Video ended, replay from beginning
          _controller!.seekTo(Duration.zero);
          if (widget.isPlaying) {
            _controller!.play();
          }
        }
      });

      setState(() {
        _isInitialized = true;
        _hasError = false;
      });

      _updatePlayState();
    } catch (e) {
      debugPrint('Error initializing video: $e');
      setState(() {
        _hasError = true;
        _isInitialized = false;
      });
    }
  }

  void _updatePlayState() {
    if (_controller != null && _isInitialized) {
      if (widget.isPlaying) {
        _controller!.play();
      } else {
        _controller!.pause();
      }
    }
  }

  void _togglePlayPause() {
    widget.onPlayPause?.call();
    
    // Also toggle local state for immediate feedback
    if (_controller != null && _isInitialized) {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });

    // Hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        _showControlsTemporarily();
      },
      onLongPress: _togglePlayPause,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video content
            if (_isInitialized && !_hasError)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_hasError || widget.videoUrl == null)
              // Fallback to image
              _buildFallbackImage()
            else
              // Loading state
              _buildLoadingState(),

            // Play/Pause overlay
            if (_showControls && _isInitialized && !_hasError)
              _buildPlayPauseOverlay(),

            // Volume indicator
            if (_showControls)
              _buildVolumeIndicator(),

            // Loading overlay
            if (!_isInitialized && !_hasError)
              _buildLoadingOverlay(),

            // Error overlay
            if (_hasError)
              _buildErrorOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    if (widget.fallbackImageUrl != null) {
      return widget.fallbackImageUrl!.startsWith('http')
          ? Image.network(
              widget.fallbackImageUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholder();
              },
            )
          : Image.asset(
              widget.fallbackImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholder();
              },
            );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library,
              color: Colors.white54,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No media available',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Loading video...',
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

  Widget _buildPlayPauseOverlay() {
    return Center(
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _controller?.value.isPlaying == true
                ? Icons.pause
                : Icons.play_arrow,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeIndicator() {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SvgPicture.asset(
          'assets/icons/volume.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Video failed to load',
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
