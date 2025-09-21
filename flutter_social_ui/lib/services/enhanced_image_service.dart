import 'dart:io';

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// Enhanced image service with compression, validation, and progress tracking
class EnhancedImageService {
  static final EnhancedImageService _instance = EnhancedImageService._internal();
  factory EnhancedImageService() => _instance;
  EnhancedImageService._internal();

  final ImagePicker _imagePicker = ImagePicker();

  // Image constraints
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const int maxWidth = 1024;
  static const int maxHeight = 1024;
  static const int compressionQuality = 85;

  /// Pick image with source selection and validation
  Future<ImagePickResult?> pickImage({
    ImageSource? source,
    int maxWidth = maxWidth,
    int maxHeight = maxHeight,
    int imageQuality = compressionQuality,
    bool enableCrop = false,
  }) async {
    try {
      ImageSource selectedSource;
      
      // If source is not specified, let user choose
      if (source == null) {
        selectedSource = await _showImageSourceDialog();
      } else {
        selectedSource = source;
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: selectedSource,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (pickedFile == null) {
        return null;
      }

      final file = File(pickedFile.path);
      
      // Validate image
      final validation = await validateImage(file);
      if (!validation.isValid) {
        return ImagePickResult(
          file: file,
          error: validation.errorMessage,
          isValid: false,
        );
      }

      // Compress image if needed
      final compressedFile = await compressImage(
        file,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: imageQuality,
      );

      return ImagePickResult(
        file: compressedFile,
        originalFile: file,
        isValid: true,
        wasCompressed: compressedFile.path != file.path,
        originalSize: await file.length(),
        compressedSize: await compressedFile.length(),
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      return ImagePickResult(
        file: null,
        error: 'Failed to pick image: $e',
        isValid: false,
      );
    }
  }

  /// Validate image file
  Future<ImageValidationResult> validateImage(File imageFile) async {
    try {
      // Check if file exists
      if (!await imageFile.exists()) {
        return const ImageValidationResult(
          isValid: false,
          errorMessage: 'Image file does not exist',
        );
      }

      // Check file size
      final fileSize = await imageFile.length();
      if (fileSize > maxFileSize) {
        final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        return ImageValidationResult(
          isValid: false,
          errorMessage: 'Image size (${sizeMB}MB) exceeds the maximum limit of 5MB',
        );
      }

      // Check file format by reading header
      final bytes = await imageFile.readAsBytes();
      if (!_isValidImageFormat(bytes)) {
        return const ImageValidationResult(
          isValid: false,
          errorMessage: 'Invalid image format. Please select a JPEG, PNG, or WebP image',
        );
      }

      // Try to decode the image to ensure it's not corrupted
      try {
        final image = img.decodeImage(bytes);
        if (image == null) {
          return const ImageValidationResult(
            isValid: false,
            errorMessage: 'Image file is corrupted or cannot be processed',
          );
        }

        // Check minimum dimensions
        if (image.width < 100 || image.height < 100) {
          return const ImageValidationResult(
            isValid: false,
            errorMessage: 'Image is too small. Minimum size is 100x100 pixels',
          );
        }

        return ImageValidationResult(
          isValid: true,
          width: image.width,
          height: image.height,
          fileSize: fileSize,
        );
      } catch (e) {
        return const ImageValidationResult(
          isValid: false,
          errorMessage: 'Image file is corrupted or in an unsupported format',
        );
      }
    } catch (e) {
      return ImageValidationResult(
        isValid: false,
        errorMessage: 'Error validating image: $e',
      );
    }
  }

  /// Compress image if needed
  Future<File> compressImage(
    File imageFile, {
    int maxWidth = maxWidth,
    int maxHeight = maxHeight,
    int quality = compressionQuality,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return imageFile; // Return original if can't decode
      }

      // Check if compression is needed
      final fileSize = await imageFile.length();
      bool needsResize = image.width > maxWidth || image.height > maxHeight;
      bool needsCompression = fileSize > (2 * 1024 * 1024); // 2MB threshold

      if (!needsResize && !needsCompression) {
        return imageFile; // No compression needed
      }

      // Calculate new dimensions while maintaining aspect ratio
      int newWidth = image.width;
      int newHeight = image.height;

      if (needsResize) {
        final aspectRatio = image.width / image.height;
        
        if (image.width > maxWidth) {
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        }
        
        if (newHeight > maxHeight) {
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
      }

      // Resize image if needed
      img.Image resizedImage = image;
      if (newWidth != image.width || newHeight != image.height) {
        resizedImage = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.cubic,
        );
      }

      // Compress to JPEG
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);

      // Save compressed image to a temporary file
      final compressedFile = File('${imageFile.path}_compressed.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      debugPrint('Image compressed: ${fileSize} -> ${compressedBytes.length} bytes');
      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageFile; // Return original file if compression fails
    }
  }

  /// Upload image with progress tracking
  Future<String> uploadImageWithProgress(
    File imageFile,
    String userId,
    Function(double progress)? onProgress,
  ) async {
    try {
      // This is a placeholder for the actual upload implementation
      // In a real app, you would implement progress tracking here
      
      onProgress?.call(0.1); // 10% - Starting upload
      
      await Future.delayed(const Duration(milliseconds: 500));
      onProgress?.call(0.3); // 30% - Uploading...
      
      await Future.delayed(const Duration(milliseconds: 500));
      onProgress?.call(0.6); // 60% - Processing...
      
      await Future.delayed(const Duration(milliseconds: 500));
      onProgress?.call(0.9); // 90% - Finalizing...
      
      // TODO: Replace with actual Supabase upload logic
      final fileName = '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await Future.delayed(const Duration(milliseconds: 300));
      onProgress?.call(1.0); // 100% - Complete
      
      // Return mock URL (replace with actual Supabase public URL)
      return 'https://mock-storage.supabase.co/storage/v1/object/public/avatars/$fileName';
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  /// Check if bytes represent a valid image format
  bool _isValidImageFormat(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // Check JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    
    // Check PNG
    if (bytes[0] == 0x89 && 
        bytes[1] == 0x50 && 
        bytes[2] == 0x4E && 
        bytes[3] == 0x47) return true;
    
    // Check WebP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && 
        bytes[1] == 0x49 && 
        bytes[2] == 0x46 && 
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 && 
        bytes[9] == 0x45 && 
        bytes[10] == 0x42 && 
        bytes[11] == 0x50) return true;

    return false;
  }

  /// Show dialog to select image source
  Future<ImageSource> _showImageSourceDialog() async {
    // This would normally show a dialog in the UI
    // For now, return gallery as default
    return ImageSource.gallery;
  }

  /// Crop image to specified dimensions
  Future<File?> cropImage(
    File imageFile, {
    required int x,
    required int y, 
    required int width,
    required int height,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;

      // Validate crop parameters
      if (x < 0 || y < 0 || 
          x + width > image.width || 
          y + height > image.height) {
        throw Exception('Invalid crop parameters');
      }

      final croppedImage = img.copyCrop(
        image,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      final croppedBytes = img.encodeJpg(croppedImage, quality: compressionQuality);
      
      final croppedFile = File('${imageFile.path}_cropped.jpg');
      await croppedFile.writeAsBytes(croppedBytes);
      
      return croppedFile;
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return null;
    }
  }
}

/// Result of image picking operation
class ImagePickResult {
  final File? file;
  final File? originalFile;
  final String? error;
  final bool isValid;
  final bool wasCompressed;
  final int? originalSize;
  final int? compressedSize;

  const ImagePickResult({
    this.file,
    this.originalFile,
    this.error,
    required this.isValid,
    this.wasCompressed = false,
    this.originalSize,
    this.compressedSize,
  });

  double? get compressionRatio {
    if (originalSize != null && compressedSize != null && originalSize! > 0) {
      return compressedSize! / originalSize!;
    }
    return null;
  }

  String get compressionInfo {
    if (wasCompressed && originalSize != null && compressedSize != null) {
      final originalMB = (originalSize! / (1024 * 1024)).toStringAsFixed(1);
      final compressedMB = (compressedSize! / (1024 * 1024)).toStringAsFixed(1);
      final ratio = ((1 - compressionRatio!) * 100).toStringAsFixed(0);
      return 'Compressed from ${originalMB}MB to ${compressedMB}MB (${ratio}% reduction)';
    }
    return 'No compression applied';
  }
}

/// Result of image validation
class ImageValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int? width;
  final int? height;
  final int? fileSize;

  const ImageValidationResult({
    required this.isValid,
    this.errorMessage,
    this.width,
    this.height,
    this.fileSize,
  });

  String get sizeInfo {
    if (width != null && height != null && fileSize != null) {
      final sizeMB = (fileSize! / (1024 * 1024)).toStringAsFixed(1);
      return '${width}x${height} pixels, ${sizeMB}MB';
    }
    return 'Size information unavailable';
  }
}
