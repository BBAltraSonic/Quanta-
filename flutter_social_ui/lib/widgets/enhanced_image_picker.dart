import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../services/enhanced_image_service.dart';

/// Enhanced image picker widget with progress tracking and validation
class EnhancedImagePicker {
  static final EnhancedImageService _imageService = EnhancedImageService();

  /// Show image source selection dialog
  static Future<ImagePickResult?> showImagePicker(
    BuildContext context, {
    bool enableCrop = false,
    Function(double progress)? onProgress,
  }) async {
    return showModalBottomSheet<ImagePickResult?>(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ImagePickerSheet(
        enableCrop: enableCrop,
        onProgress: onProgress,
      ),
    );
  }

  /// Show upload progress dialog
  static void showUploadProgress(
    BuildContext context,
    Stream<double> progressStream,
    String title,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UploadProgressDialog(
        progressStream: progressStream,
        title: title,
      ),
    );
  }
}

class _ImagePickerSheet extends StatelessWidget {
  final bool enableCrop;
  final Function(double progress)? onProgress;

  const _ImagePickerSheet({
    required this.enableCrop,
    this.onProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kLightTextColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Select Image Source',
            style: TextStyle(
              color: kTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              // Camera option
              Expanded(
                child: _ImageSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(context, ImageSource.camera);
                  },
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Gallery option  
              Expanded(
                child: _ImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(context, ImageSource.gallery);
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Cancel button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: kLightTextColor,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _LoadingDialog(message: 'Processing image...'),
    );

    try {
      final result = await EnhancedImageService().pickImage(source: source);
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (result != null) {
        if (result.isValid) {
          // Show compression info if image was compressed
          if (result.wasCompressed && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.compressionInfo),
                backgroundColor: kPrimaryColor,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          
          if (context.mounted) {
            Navigator.pop(context, result);
          }
        } else {
          // Show error
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.error ?? 'Unknown error occurred'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: kBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kLightTextColor.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: kPrimaryColor,
                size: 30,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              label,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  final String message;

  const _LoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCardColor,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: kPrimaryColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: kTextColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadProgressDialog extends StatelessWidget {
  final Stream<double> progressStream;
  final String title;

  const _UploadProgressDialog({
    required this.progressStream,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCardColor,
      title: Text(
        title,
        style: const TextStyle(
          color: kTextColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<double>(
            stream: progressStream,
            builder: (context, snapshot) {
              final progress = snapshot.data ?? 0.0;
              final percentage = (progress * 100).toInt();
              
              return Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: kLightTextColor.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryColor),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: kTextColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _getProgressMessage(progress),
                    style: TextStyle(
                      color: kLightTextColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        StreamBuilder<double>(
          stream: progressStream,
          builder: (context, snapshot) {
            final progress = snapshot.data ?? 0.0;
            
            if (progress >= 1.0) {
              return TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Done',
                  style: TextStyle(color: kPrimaryColor),
                ),
              );
            }
            
            return TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: kLightTextColor),
              ),
            );
          },
        ),
      ],
    );
  }

  String _getProgressMessage(double progress) {
    if (progress < 0.2) {
      return 'Preparing upload...';
    } else if (progress < 0.5) {
      return 'Uploading image...';
    } else if (progress < 0.8) {
      return 'Processing...';
    } else if (progress < 1.0) {
      return 'Finalizing...';
    } else {
      return 'Upload complete!';
    }
  }
}

/// Enhanced profile image widget with upload progress
class EnhancedProfileImage extends StatelessWidget {
  final String? currentImageUrl;
  final File? selectedImage;
  final VoidCallback onTap;
  final double? uploadProgress;
  final bool isUploading;

  const EnhancedProfileImage({
    super.key,
    this.currentImageUrl,
    this.selectedImage,
    required this.onTap,
    this.uploadProgress,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: kPrimaryColor,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: _buildImageContent(),
            ),
          ),
          
          // Upload progress overlay
          if (isUploading)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.6),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: uploadProgress,
                        strokeWidth: 3,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    if (uploadProgress != null)
                      Text(
                        '${(uploadProgress! * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // Camera icon
          if (!isUploading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    if (selectedImage != null) {
      return Image.file(
        selectedImage!,
        fit: BoxFit.cover,
      );
    }
    
    if (currentImageUrl != null) {
      if (currentImageUrl!.startsWith('assets/')) {
        return Image.asset(
          currentImageUrl!,
          fit: BoxFit.cover,
        );
      } else {
        return Image.network(
          currentImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person,
              size: 60,
              color: kLightTextColor,
            );
          },
        );
      }
    }
    
    return const Icon(
      Icons.person,
      size: 60,
      color: kLightTextColor,
    );
  }
}
