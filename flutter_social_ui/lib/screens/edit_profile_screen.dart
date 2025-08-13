import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../services/validation_service.dart';
import '../services/enhanced_image_service.dart';
import '../widgets/custom_text_field.dart';
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
  final AuthService _authService = AuthService();
  final ValidationService _validationService = ValidationService();
  final EnhancedImageService _imageService = EnhancedImageService();

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
  double _uploadProgress = 0.0;
  StreamController<double>? _progressController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.user.displayName ?? '',
    );
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _firstNameController = TextEditingController(text: widget.user.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.user.lastName ?? '');
    _currentImageUrl = widget.user.profileImageUrl;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
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
        
        // Show compression info if image was compressed
        if (result.wasCompressed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image optimized: ${result.compressionInfo}'),
              backgroundColor: kPrimaryColor,
              duration: const Duration(seconds: 3),
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
        _showError(errorMessage);
        return;
      }

      String? imageUrl = _currentImageUrl;

      // Upload new image if selected
      if (_selectedImage != null) {
        imageUrl = await _profileService.uploadProfileImage(
          _selectedImage!,
          widget.user.id,
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: kPrimaryColor,
          ),
        );
        Navigator.pop(context, updatedUser);
      }
    } catch (e) {
      _showError('Failed to update profile: $e');
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

  void _navigateToAvatarManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AvatarManagementScreen(),
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
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
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
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w600,
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
                            backgroundColor: kPrimaryColor.withOpacity(0.1),
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
                    child: CustomButton(
                      text: _isSaving ? 'Saving...' : 'Save Changes',
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving ? null : Icons.save,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Cancel',
                      onPressed: () => Navigator.pop(context),
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
