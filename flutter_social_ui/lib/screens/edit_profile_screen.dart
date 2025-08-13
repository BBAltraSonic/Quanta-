import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';
import '../services/validation_service.dart';
import '../widgets/validated_text_field.dart';
import '../widgets/enhanced_image_picker.dart';
import '../widgets/custom_button.dart';
import '../screens/avatar_management_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final ValidationService _validationService = ValidationService();

  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  File? _selectedImage;
  String? _currentImageUrl;
  final bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  final double _uploadProgress = 0.0;
  StreamController<double>? _progressController;
  
  // Track form changes for unsaved warning
  bool _hasUnsavedChanges = false;
  Map<String, String> _originalValues = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _displayNameController = TextEditingController(
      text: widget.user.displayName ?? '',
    );
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _firstNameController = TextEditingController(text: widget.user.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.user.lastName ?? '');
    _currentImageUrl = widget.user.profileImageUrl;
    
    // Store original values for change detection
    _originalValues = {
      'displayName': widget.user.displayName ?? '',
      'username': widget.user.username,
      'email': widget.user.email,
      'bio': widget.user.bio ?? '',
      'firstName': widget.user.firstName ?? '',
      'lastName': widget.user.lastName ?? '',
    };
    
    // Setup change listeners
    _displayNameController.addListener(_trackChanges);
    _usernameController.addListener(_trackChanges);
    _emailController.addListener(_trackChanges);
    _bioController.addListener(_trackChanges);
    _firstNameController.addListener(_trackChanges);
    _lastNameController.addListener(_trackChanges);
  }

  @override
  void dispose() {
    // Remove listeners
    _displayNameController.removeListener(_trackChanges);
    _usernameController.removeListener(_trackChanges);
    _emailController.removeListener(_trackChanges);
    _bioController.removeListener(_trackChanges);
    _firstNameController.removeListener(_trackChanges);
    _lastNameController.removeListener(_trackChanges);
    
    // Dispose controllers
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    
    // Dispose progress controller
    _progressController?.close();
    
    super.dispose();
  }

  // Track changes for unsaved warning
  void _trackChanges() {
    final hasChanges = _displayNameController.text != _originalValues['displayName'] ||
        _usernameController.text != _originalValues['username'] ||
        _emailController.text != _originalValues['email'] ||
        _bioController.text != _originalValues['bio'] ||
        _firstNameController.text != _originalValues['firstName'] ||
        _lastNameController.text != _originalValues['lastName'] ||
        _selectedImage != null;
    
    if (_hasUnsavedChanges != hasChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }
  
  Future<void> _pickImage() async {
    try {
      final result = await EnhancedImagePicker.showImagePicker(
        context,
        enableCrop: true,
      );

      if (result != null && result.isValid && result.file != null) {
        setState(() {
          _selectedImage = result.file;
        });
        
        // Track this as a change
        _trackChanges();
        
        // Show compression info with enhanced styling
        if (result.wasCompressed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Image optimized: ${result.compressionInfo}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: kPrimaryColor,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else if (result != null && !result.isValid) {
        _showError(result.error ?? 'Failed to process image');
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _saveProfile() async {
    // Show loading with haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() {
      _isSaving = true;
    });

    try {
      // Validate all fields before saving
      final validations = await _validationService.validateAllFields(
        username: _usernameController.text,
        email: _emailController.text,
        bio: _bioController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        displayName: _displayNameController.text,
        currentUserId: widget.user.id,
      );

      // Check if all validations passed
      if (!_validationService.allValidationsPassed(validations)) {
        final errorMessage = _validationService.getValidationErrorsString(validations);
        _showEnhancedError(errorMessage);
        return;
      }

      String? imageUrl = _currentImageUrl;

      // Upload new image if selected with progress tracking
      if (_selectedImage != null) {
        setState(() {
          _isUploadingImage = true;
        });
        
        try {
          imageUrl = await _profileService.uploadProfileImage(
            _selectedImage!,
            widget.user.id,
          );
        } finally {
          setState(() {
            _isUploadingImage = false;
          });
        }
      }

      // Update profile
      final updatedUser = await _profileService.updateUserProfile(
        userId: widget.user.id,
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        profileImageUrl: imageUrl,
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        firstName: _firstNameController.text.trim().isEmpty
            ? null
            : _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty
            ? null
            : _lastNameController.text.trim(),
      );

      if (mounted) {
        // Show enhanced success message
        _showSuccessMessage();
        
        // Reset unsaved changes flag
        _hasUnsavedChanges = false;
        
        // Navigate back with result
        Navigator.pop(context, updatedUser);
      }
    } catch (e) {
      _showEnhancedError('Failed to update profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
  
  void _showEnhancedError(String message) {
    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }
  
  void _showSuccessMessage() {
    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Profile updated successfully',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: kPrimaryColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _navigateToAvatarManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AvatarManagementScreen(),
      ),
    );
  }
  
  Future<void> _handleBackPress() async {
    if (_hasUnsavedChanges) {
      final shouldLeave = await _showUnsavedChangesDialog();
      if (shouldLeave == true && mounted) {
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }
  
  Future<void> _handleCancel() async {
    if (_hasUnsavedChanges) {
      final shouldLeave = await _showUnsavedChangesDialog();
      if (shouldLeave == true && mounted) {
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }
  
  Future<bool?> _showUnsavedChangesDialog() async {
    HapticFeedback.mediumImpact();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            const Text(
              'Unsaved Changes',
              style: TextStyle(
                color: kTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave without saving?',
          style: TextStyle(
            color: kLightTextColor,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep Editing',
              style: TextStyle(
                color: kLightTextColor,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Leave',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kCardColor,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(color: kTextColor, fontWeight: FontWeight.w600),
            ),
            if (_hasUnsavedChanges) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          onPressed: () => _handleBackPress(),
          icon: const Icon(Icons.arrow_back, color: kTextColor),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kPrimaryColor,
                ),
              ),
            )
          else
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: TextButton(
                onPressed: _hasUnsavedChanges ? _saveProfile : null,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: _hasUnsavedChanges ? kPrimaryColor : kLightTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Image Section
                  Center(
                    child: Column(
                      children: [
                        EnhancedProfileImage(
                          currentImageUrl: _currentImageUrl,
                          selectedImage: _selectedImage,
                          onTap: _pickImage,
                          isUploading: _isUploadingImage,
                          uploadProgress: _uploadProgress,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _pickImage,
                          child: Text(
                            _isUploadingImage 
                                ? 'Uploading...' 
                                : 'Change Profile Photo',
                            style: TextStyle(
                              color: _isUploadingImage 
                                  ? kLightTextColor 
                                  : kPrimaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Personal Information Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            color: kTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ValidatedTextField(
                                controller: _firstNameController,
                                hintText: 'First Name',
                                icon: Icons.person_outline,
                                syncValidator: (value) => _validationService.validateName(value, 'First name'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ValidatedTextField(
                                controller: _lastNameController,
                                hintText: 'Last Name',
                                icon: Icons.person_outline,
                                syncValidator: (value) => _validationService.validateName(value, 'Last name'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ValidatedTextField(
                          controller: _displayNameController,
                          hintText: 'Display Name (Public)',
                          icon: Icons.badge_outlined,
                          syncValidator: (value) => _validationService.validateDisplayName(value),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Account Information Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Information',
                          style: TextStyle(
                            color: kTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ValidatedTextField(
                          controller: _usernameController,
                          hintText: 'Username',
                          icon: Icons.alternate_email,
                          asyncValidator: (value) => _validationService.validateUsername(value, widget.user.id),
                        ),
                        const SizedBox(height: 20),
                        ValidatedTextField(
                          controller: _emailController,
                          hintText: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          asyncValidator: (value) => _validationService.validateEmail(value, widget.user.id),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bio Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Bio',
                              style: TextStyle(
                                color: kTextColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_bioController.text.length}/160',
                              style: TextStyle(
                                color: _bioController.text.length > 160 
                                    ? Colors.red 
                                    : kLightTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ValidatedTextField(
                          controller: _bioController,
                          hintText: 'Tell people a little about yourself...',
                          icon: Icons.info_outline,
                          maxLines: 3,
                          maxLength: 160,
                          showCharacterCount: true,
                          syncValidator: (value) => _validationService.validateBio(value),
                          onChanged: (value) {
                            setState(() {}); // Rebuild to update character count in header
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Avatar Management Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Avatar Management',
                          style: TextStyle(
                            color: kTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create and manage your virtual avatars for content creation',
                          style: TextStyle(
                            color: kLightTextColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            text: 'Manage Avatars',
                            onPressed: _navigateToAvatarManagement,
                            icon: Icons.person_add,
                            backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                            textColor: kPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: CustomButton(
                        text: _isSaving 
                            ? 'Saving...' 
                            : (_hasUnsavedChanges ? 'Save Changes' : 'No Changes'),
                        onPressed: (_isSaving || !_hasUnsavedChanges) ? null : _saveProfile,
                        icon: _isSaving 
                            ? null 
                            : (_hasUnsavedChanges ? Icons.save : Icons.check),
                        backgroundColor: _hasUnsavedChanges 
                            ? null 
                            : kLightTextColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Cancel',
                      onPressed: _handleCancel,
                      isOutlined: true,
                      backgroundColor: kLightTextColor,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
