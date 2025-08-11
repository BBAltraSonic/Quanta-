import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../models/user_model.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;

  File? _selectedImage;
  String? _currentImageUrl;
  final bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.user.displayName ?? '',
    );
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
    _currentImageUrl = widget.user.profileImageUrl;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameController.text.trim().isEmpty) {
      _showError('Username is required');
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      _showError('Email is required');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
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
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
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
                                  child: _selectedImage != null
                                      ? Image.file(
                                          _selectedImage!,
                                          fit: BoxFit.cover,
                                        )
                                      : _currentImageUrl != null
                                      ? _currentImageUrl!.startsWith('assets/')
                                            ? Image.asset(
                                                _currentImageUrl!,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.network(
                                                _currentImageUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const Icon(
                                                        Icons.person,
                                                        size: 60,
                                                        color: kLightTextColor,
                                                      );
                                                    },
                                              )
                                      : const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: kLightTextColor,
                                        ),
                                ),
                              ),
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
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _pickImage,
                          child: const Text(
                            'Change Profile Photo',
                            style: TextStyle(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Form Fields
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        CustomTextField(
                          controller: _displayNameController,
                          hintText: 'Display Name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _usernameController,
                          hintText: 'Username',
                          icon: Icons.alternate_email,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _emailController,
                          hintText: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
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
