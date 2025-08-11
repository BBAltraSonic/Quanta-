import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_social_ui/models/post_model.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';
import 'package:flutter_social_ui/services/content_upload_service.dart';
import 'package:flutter_social_ui/services/avatar_service.dart';
import 'package:flutter_social_ui/services/auth_service.dart';
import 'package:flutter_social_ui/screens/avatar_creation_wizard.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

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

  List<AvatarModel> _userAvatars = [];
  AvatarModel? _selectedAvatar;
  File? _selectedMedia;
  PostType _postType = PostType.image;
  VideoPlayerController? _videoController;
  List<String> _extractedHashtags = [];
  final bool _isLoading = false;
  bool _isUploading = false;
  bool _loadingAvatars = true;

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
            child: _isUploading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                    ),
                  )
                : Text(
                    'Share',
                    style: TextStyle(
                      color: _canUpload() ? kPrimaryColor : kLightTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
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

            SizedBox(height: 32),

            // Upload button
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
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                          SizedBox(width: 16),
                          Text('Uploading...'),
                        ],
                      )
                    : Text(
                        'Share Post',
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
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
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
        ],
      );
    } else if (_postType == PostType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _selectedMedia!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
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
        setState(() {
          _selectedMedia = File(pickedFile!.path);
        });

        if (_postType == PostType.video) {
          _videoController?.dispose();
          _videoController = VideoPlayerController.file(_selectedMedia!)
            ..initialize().then((_) {
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

    setState(() => _isUploading = true);

    try {
      final post = await _contentService.createPost(
        avatarId: _selectedAvatar!.id,
        type: _postType,
        mediaFile: _selectedMedia,
        caption: _captionController.text.trim(),
        hashtags: _extractedHashtags,
      );

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
      setState(() => _isUploading = false);
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
