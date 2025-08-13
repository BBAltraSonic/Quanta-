import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_social_ui/models/post_model.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';
import 'package:flutter_social_ui/services/content_upload_service.dart';
import 'package:flutter_social_ui/services/avatar_service.dart';
import 'package:flutter_social_ui/services/auth_service.dart';
import 'package:flutter_social_ui/services/content_moderation_service.dart';
import 'package:flutter_social_ui/screens/avatar_creation_wizard.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import '../utils/environment.dart';

class ContentUploadScreen extends StatefulWidget {
  const ContentUploadScreen({super.key});

  @override
  _ContentUploadScreenState createState() => _ContentUploadScreenState();
}

class _ContentUploadScreenState extends State<ContentUploadScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ContentUploadService _contentService = ContentUploadService();
  final AvatarService _avatarService = AvatarService();
  final AuthService _authService = AuthService();
  final ContentModerationService _moderationService = ContentModerationService();

  List<AvatarModel> _userAvatars = [];
  AvatarModel? _selectedAvatar;
  File? _selectedMedia;
  PostType _postType = PostType.image;
  VideoPlayerController? _videoController;
  List<String> _extractedHashtags = [];
  final bool _isLoading = false;
  bool _isUploading = false;
  bool _loadingAvatars = true;
  String _uploadStep = '';
  double _uploadProgress = 0.0;
  int? _videoDurationSeconds;
  String? _mediaSizeLabelMB;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _contentService.initialize();
      _loadUserAvatars();
    } catch (e) {
      debugPrint('Error initializing services: $e');
      _loadUserAvatars(); // Still load avatars
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserAvatars() async {
    try {
      final avatars = await _avatarService.getUserAvatars();
      setState(() {
        _userAvatars = avatars;
        _selectedAvatar = avatars.isNotEmpty ? avatars.first : null;
        _loadingAvatars = false;
      });
    } catch (e) {
      setState(() => _loadingAvatars = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading avatars: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAvatars) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          title: Text('Create Post'),
          backgroundColor: kBackgroundColor,
        ),
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    if (_userAvatars.isEmpty) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          title: Text('Create Post'),
          backgroundColor: kBackgroundColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add, size: 64, color: kLightTextColor),
              SizedBox(height: 16),
              Text(
                'No Avatars Found',
                style: kHeadingTextStyle.copyWith(fontSize: 20),
              ),
              SizedBox(height: 8),
              Text(
                'Create an avatar first to start posting content',
                style: kBodyTextStyle.copyWith(color: kLightTextColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  // Navigate to avatar creation
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AvatarCreationWizard(),
                    ),
                  );
                  
                  // Reload avatars after creation
                  if (result != null) {
                    await _loadUserAvatars();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                child: Text('Create Avatar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text('Create Post'),
        backgroundColor: kBackgroundColor,
        actions: [
          TextButton(
            onPressed: _canUpload() ? _uploadContent : null,
            child: Text(
              'Share',
              style: TextStyle(
                color: _canUpload() ? kPrimaryColor : kLightTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        bottom: _isUploading
            ? PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: _uploadProgress > 0 && _uploadProgress < 1.0 ? _uploadProgress : null,
                  backgroundColor: kLightTextColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                ),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar selection
            Text(
              'Post as:',
              style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AvatarModel>(
                  value: _selectedAvatar,
                  dropdownColor: kCardColor,
                  items: _userAvatars.map((avatar) {
                    return DropdownMenuItem(
                      value: avatar,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: avatar.imageUrl != null
                                ? NetworkImage(avatar.imageUrl!)
                                : null,
                            child: avatar.imageUrl == null
                                ? Icon(Icons.person, size: 16)
                                : null,
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(avatar.name, style: kBodyTextStyle),
                              Text(
                                avatar.niche.displayName,
                                style: kCaptionTextStyle.copyWith(
                                  color: kLightTextColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (avatar) {
                    setState(() => _selectedAvatar = avatar);
                  },
                ),
              ),
            ),

            SizedBox(height: 24),

            // Media picker section
            Text(
              'Content:',
              style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            // Media preview or picker
            GestureDetector(
              onTap: _pickMedia,
              child: Container(
                width: double.infinity,
                height: _selectedMedia != null ? 300 : 200,
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                ),
                child: _selectedMedia != null
                    ? _buildMediaPreview()
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 48,
                            color: kPrimaryColor,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tap to add photo or video',
                            style: kBodyTextStyle.copyWith(
                              color: kPrimaryColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _MediaTypeButton(
                                icon: Icons.photo,
                                label: 'Photo',
                                onTap: () => _pickMedia(
                                  source: ImageSource.gallery,
                                  isVideo: false,
                                ),
                              ),
                              SizedBox(width: 16),
                              _MediaTypeButton(
                                icon: Icons.videocam,
                                label: 'Video',
                                onTap: () => _pickMedia(
                                  source: ImageSource.gallery,
                                  isVideo: true,
                                ),
                              ),
                              SizedBox(width: 16),
                              _MediaTypeButton(
                                icon: Icons.camera_alt,
                                label: 'Camera',
                                onTap: () => _showCameraOptions(),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),

            if (_selectedMedia != null) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _selectedMedia = null;
                      _videoController?.dispose();
                      _videoController = null;
                      _postType = PostType.image;
                    }),
                    icon: Icon(Icons.close, color: Colors.red),
                    label: Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                  Spacer(),
                  TextButton.icon(
                    onPressed: _pickMedia,
                    icon: Icon(Icons.swap_horiz, color: kPrimaryColor),
                    label: Text(
                      'Change',
                      style: TextStyle(color: kPrimaryColor),
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 24),

            // Caption section
            Text(
              'Caption:',
              style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _captionController,
              style: kBodyTextStyle,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Write a caption... Use #hashtags to reach more people',
                filled: true,
                fillColor: kCardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterText: '${_captionController.text.length}/2000',
              ),
              maxLength: 2000,
              onChanged: (text) {
                setState(() {
                  _extractedHashtags = PostModel.extractHashtags(text);
                });
              },
            ),

            // Hashtags preview
            if (_extractedHashtags.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Hashtags:',
                style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _extractedHashtags.map((hashtag) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hashtag,
                      style: kCaptionTextStyle.copyWith(color: kPrimaryColor),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Suggested hashtags (tap to insert)
            if (_selectedAvatar != null) ...[
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ContentUploadService()
                    .suggestHashtags(_captionController.text, _selectedAvatar!)
                    .map((tag) => GestureDetector(
                          onTap: () {
                            final t = _captionController.text.trim();
                            final newText = t.isEmpty ? tag : '$t $tag';
                            _captionController.text = newText;
                            _captionController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _captionController.text.length),
                            );
                            setState(() {
                              _extractedHashtags = PostModel.extractHashtags(_captionController.text);
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(tag, style: kCaptionTextStyle.copyWith(color: kPrimaryColor)),
                          ),
                        ))
                    .toList(),
              ),
            ],

            SizedBox(height: 32),

            // Upload button (no spinner)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canUpload() ? _uploadContent : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isUploading ? 'Sharing…' : 'Share Post',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_postType == PostType.video && _videoController != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.black,
              width: double.infinity,
              height: 300,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            ),
          ),
          if (_videoDurationSeconds != null || _mediaSizeLabelMB != null)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_videoDurationSeconds != null ? '${_videoDurationSeconds}s' : ''}${_videoDurationSeconds != null && _mediaSizeLabelMB != null ? ' • ' : ''}${_mediaSizeLabelMB ?? ''}',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Semantics(
              button: true,
              label: 'Play or pause video',
              child: FloatingActionButton.small(
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
                backgroundColor: Colors.black54,
                child: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_postType == PostType.image) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedMedia!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          if (_mediaSizeLabelMB != null)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _mediaSizeLabelMB!,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      );
    }

    return Container();
  }

  Future<void> _pickMedia({ImageSource? source, bool? isVideo}) async {
    final picker = ImagePicker();

    if (source == null) {
      // Show bottom sheet to choose source
      showModalBottomSheet(
        context: context,
        backgroundColor: kCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Media',
                style: kHeadingTextStyle.copyWith(fontSize: 18),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MediaPickerOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(source: ImageSource.gallery, isVideo: false);
                    },
                  ),
                  _MediaPickerOption(
                    icon: Icons.video_library,
                    label: 'Video',
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(source: ImageSource.gallery, isVideo: true);
                    },
                  ),
                  _MediaPickerOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _showCameraOptions();
                    },
                  ),
                  _MediaPickerOption(
                    icon: Icons.link,
                    label: 'Import',
                    onTap: () {
                      Navigator.pop(context);
                      _showExternalImportOptions();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      return;
    }

    try {
      final XFile? pickedFile;

      if (isVideo == true) {
        pickedFile = await picker.pickVideo(source: source);
        _postType = PostType.video;
      } else {
        pickedFile = await picker.pickImage(source: source);
        _postType = PostType.image;
      }

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        
        // Validate video if it's a video file
        if (isVideo == true) {
          final isValid = await _validateVideoFile(file);
          if (!isValid) {
            return; // Don't set the file if validation failed
          }
        }

        setState(() {
          _selectedMedia = file;
          final bytes = file.lengthSync();
          _mediaSizeLabelMB = (bytes / (1024 * 1024)).toStringAsFixed(1) + 'MB';
        });

        if (_postType == PostType.video) {
          _videoController?.dispose();
          _videoController = VideoPlayerController.file(_selectedMedia!)
            ..initialize().then((_) async {
              try {
                final info = await VideoCompress.getMediaInfo(_selectedMedia!.path);
                final durationMs = info.duration ?? 0;
                _videoDurationSeconds = (durationMs / 1000).round();
              } catch (_) {
                _videoDurationSeconds = null;
              }
              setState(() {});
            });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking media: $e')));
    }
  }

  void _showCameraOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Camera Options',
              style: kHeadingTextStyle.copyWith(fontSize: 18),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MediaPickerOption(
                  icon: Icons.camera_alt,
                  label: 'Photo',
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia(source: ImageSource.camera, isVideo: false);
                  },
                ),
                _MediaPickerOption(
                  icon: Icons.videocam,
                  label: 'Video',
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia(source: ImageSource.camera, isVideo: true);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canUpload() {
    return _selectedAvatar != null &&
        _selectedMedia != null &&
        _captionController.text.trim().isNotEmpty &&
        !_isUploading;
  }

  Future<void> _uploadContent() async {
    if (!_canUpload()) return;

    setState(() {
      _isUploading = true;
      _uploadStep = 'Validating content...';
      _uploadProgress = 0.1;
    });

    try {
      // Step 1: Validate content
      final validation = await _contentService.validateContent(
        caption: _captionController.text.trim(),
        mediaFile: _selectedMedia,
        type: _postType,
      );

      if (!validation.isValid) {
        throw Exception(validation.errors.join(', '));
      }

      setState(() {
        _uploadStep = 'Checking content safety...';
        _uploadProgress = 0.2;
      });

      // Step 2: Content moderation (create a mock post for moderation)
      final mockPost = PostModel.create(
        avatarId: _selectedAvatar!.id,
        type: _postType,
        caption: _captionController.text.trim(),
        hashtags: _extractedHashtags,
      );

      final moderationResult = await _moderationService.moderatePost(mockPost);
      
      // Handle moderation result
      if (moderationResult.action == ModerationAction.block) {
        throw Exception('Content violates community guidelines: ${moderationResult.reasons.join(', ')}');
      }
      
      if (moderationResult.action == ModerationAction.warn) {
        // Show warning dialog but allow to proceed
        final shouldContinue = await _showModerationWarning(moderationResult);
        if (!shouldContinue) {
          return;
        }
      }

      setState(() {
        _uploadStep = 'Creating post...';
        _uploadProgress = 0.4;
      });

      // Step 3: Create post
      final post = await _contentService.createPost(
        avatarId: _selectedAvatar!.id,
        type: _postType,
        mediaFile: _selectedMedia,
        caption: _captionController.text.trim(),
        hashtags: _extractedHashtags,
      );

      setState(() {
        _uploadStep = 'Finalizing...';
        _uploadProgress = 1.0;
      });

      if (post != null) {
        Navigator.pop(context, post); // Return the created post
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post shared successfully! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
        _uploadStep = '';
        _uploadProgress = 0.0;
      });
    }
  }

  Future<bool> _showModerationWarning(dynamic moderationResult) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Content Warning'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your content has been flagged for potential issues:'),
            SizedBox(height: 8),
            ...moderationResult.reasons.map<Widget>((reason) => 
              Padding(
                padding: EdgeInsets.only(left: 16, bottom: 4),
                child: Text('• $reason'),
              ),
            ),
            SizedBox(height: 16),
            Text('Do you want to publish anyway?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Publish Anyway'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _validateVideoFile(File videoFile) async {
    try {
      // Check file size
      final fileSize = videoFile.lengthSync();
      final maxSize = Environment.maxVideoSizeMB * 1024 * 1024;
      
      if (fileSize > maxSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video file is too large. Maximum size is ${Environment.maxVideoSizeMB}MB.'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // Check video duration
      final info = await VideoCompress.getMediaInfo(videoFile.path);
      final duration = info.duration;
      
      if (duration != null && duration > Environment.maxVideoLengthSeconds * 1000) {
        final durationSeconds = (duration / 1000).round();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video is too long ($durationSeconds seconds). Maximum length is ${Environment.maxVideoLengthSeconds} seconds.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error validating video: $e');
      // If we can't validate, allow the upload (validation will happen again in service)
      return true;
    }
  }

  void _showExternalImportOptions() {
    final urlController = TextEditingController();
    String? selectedPlatform;
    PostType selectedType = PostType.image;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import from External Platform',
                style: kHeadingTextStyle.copyWith(fontSize: 18),
              ),
              SizedBox(height: 20),
              
              // Platform selection
              Text('Platform:', style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedPlatform,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Select platform',
                ),
                items: _contentService.getSupportedPlatforms().map((platform) {
                  return DropdownMenuItem(
                    value: platform.id,
                    child: Row(
                      children: [
                        Text(platform.icon),
                        SizedBox(width: 8),
                        Text(platform.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setModalState(() {
                    selectedPlatform = value;
                  });
                },
              ),
              SizedBox(height: 16),
              
              // Content type selection
              Text('Content Type:', style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<PostType>(
                      title: Text('Image'),
                      value: PostType.image,
                      groupValue: selectedType,
                      onChanged: (value) {
                        setModalState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<PostType>(
                      title: Text('Video'),
                      value: PostType.video,
                      groupValue: selectedType,
                      onChanged: (value) {
                        setModalState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // URL input
              Text('Content URL:', style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: urlController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Paste the content URL here',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
              SizedBox(height: 24),
              
              // Import button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (selectedPlatform != null && urlController.text.isNotEmpty)
                      ? () => _importExternalContent(
                            selectedPlatform!,
                            urlController.text,
                            selectedType,
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Import Content',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importExternalContent(String platform, String url, PostType type) async {
    Navigator.pop(context); // Close the modal
    
    try {
      setState(() {
        _isUploading = true;
        _uploadStep = 'Importing content...';
        _uploadProgress = 0.3;
      });

      // Import content using the service
      final post = await _contentService.importExternalContent(
        avatarId: _selectedAvatar!.id,
        caption: _captionController.text.trim(),
        sourceUrl: url,
        sourcePlatform: platform,
        type: type,
        metadata: {
          'imported_at': DateTime.now().toIso8601String(),
        },
      );

      setState(() {
        _selectedMedia = null; // Clear local file
        _postType = type;
        _uploadStep = 'Content imported successfully';
        _uploadProgress = 1.0;
      });

      // Navigate back with the created post
      Navigator.pop(context, post);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Content imported from $platform successfully! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import content: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
        _uploadStep = '';
        _uploadProgress = 0.0;
      });
    }
  }
}

class _MediaTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaTypeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kPrimaryColor),
          ),
          SizedBox(height: 4),
          Text(label, style: kCaptionTextStyle.copyWith(color: kPrimaryColor)),
        ],
      ),
    );
  }
}

class _MediaPickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaPickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: kPrimaryColor),
          ),
          SizedBox(height: 8),
          Text(label, style: kBodyTextStyle),
        ],
      ),
    );
  }
}
