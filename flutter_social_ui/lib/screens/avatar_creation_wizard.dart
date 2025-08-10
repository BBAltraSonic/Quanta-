import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';
import 'package:flutter_social_ui/services/avatar_service.dart';
import 'package:flutter_social_ui/services/auth_service.dart';
import 'package:flutter_social_ui/screens/app_shell.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AvatarCreationWizard extends StatefulWidget {
  const AvatarCreationWizard({super.key});

  @override
  _AvatarCreationWizardState createState() => _AvatarCreationWizardState();
}

class _AvatarCreationWizardState extends State<AvatarCreationWizard> {
  final PageController _pageController = PageController();
  final AvatarService _avatarService = AvatarService();
  final AuthService _authService = AuthService();

  int _currentStep = 0;
  bool _isCreating = false;

  // Avatar data
  String _name = '';
  String _bio = '';
  AvatarNiche _selectedNiche = AvatarNiche.lifestyle;
  final List<PersonalityTrait> _selectedTraits = [];
  File? _avatarImage;
  String? _backstory;

  final List<String> _stepTitles = [
    'Basic Info',
    'Personality',
    'Appearance',
    'Preview & Create',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text('Create Avatar (${_currentStep + 1}/4)'),
        backgroundColor: kBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: Text('Back', style: TextStyle(color: kPrimaryColor)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              backgroundColor: kCardColor,
              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
            ),
          ),

          // Step content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfoStep(),
                _buildPersonalityStep(),
                _buildAppearanceStep(),
                _buildPreviewStep(),
              ],
            ),
          ),

          // Navigation buttons
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                if (_currentStep < 3)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canProceed() ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (_currentStep == 3)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createAvatar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCreating
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Create Avatar',
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
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about your avatar',
            style: kHeadingTextStyle.copyWith(fontSize: 24),
          ),
          SizedBox(height: 8),
          Text(
            'Choose a name and describe what makes your avatar unique.',
            style: kBodyTextStyle.copyWith(color: kLightTextColor),
          ),
          SizedBox(height: 32),

          // Name field
          Text(
            'Avatar Name *',
            style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          TextField(
            style: kBodyTextStyle,
            decoration: InputDecoration(
              hintText: 'Enter avatar name',
              filled: true,
              fillColor: kCardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _name = value),
          ),

          SizedBox(height: 24),

          // Bio field
          Text(
            'Bio *',
            style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          TextField(
            style: kBodyTextStyle,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe your avatar in a few sentences...',
              filled: true,
              fillColor: kCardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _bio = value),
          ),

          SizedBox(height: 24),

          // Niche selection
          Text(
            'Niche *',
            style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AvatarNiche.values.map((niche) {
              final isSelected = _selectedNiche == niche;
              return FilterChip(
                label: Text(niche.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedNiche = niche);
                },
                backgroundColor: kCardColor,
                selectedColor: kPrimaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : kTextColor,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avatar Personality',
            style: kHeadingTextStyle.copyWith(fontSize: 24),
          ),
          SizedBox(height: 8),
          Text(
            'Select 3-5 personality traits that define your avatar.',
            style: kBodyTextStyle.copyWith(color: kLightTextColor),
          ),
          SizedBox(height: 32),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PersonalityTrait.values.map((trait) {
              final isSelected = _selectedTraits.contains(trait);
              return FilterChip(
                label: Text(trait.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (_selectedTraits.length < 5) {
                        _selectedTraits.add(trait);
                      }
                    } else {
                      _selectedTraits.remove(trait);
                    }
                  });
                },
                backgroundColor: kCardColor,
                selectedColor: kPrimaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : kTextColor,
                ),
              );
            }).toList(),
          ),

          SizedBox(height: 24),
          Text(
            'Selected: ${_selectedTraits.length}/5',
            style: kCaptionTextStyle.copyWith(color: kLightTextColor),
          ),

          SizedBox(height: 32),

          // Optional backstory
          Text(
            'Backstory (Optional)',
            style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          TextField(
            style: kBodyTextStyle,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Add a backstory to make your avatar more interesting...',
              filled: true,
              fillColor: kCardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _backstory = value),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avatar Appearance',
            style: kHeadingTextStyle.copyWith(fontSize: 24),
          ),
          SizedBox(height: 8),
          Text(
            'Upload a photo or choose an image for your avatar.',
            style: kBodyTextStyle.copyWith(color: kLightTextColor),
          ),
          SizedBox(height: 32),

          // Image picker
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: kPrimaryColor, width: 2),
                ),
                child: _avatarImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Image.file(_avatarImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            size: 48,
                            color: kPrimaryColor,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap to add photo',
                            style: kBodyTextStyle.copyWith(
                              color: kPrimaryColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          SizedBox(height: 24),

          if (_avatarImage != null)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _avatarImage = null),
                child: Text('Remove Photo'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview Your Avatar',
            style: kHeadingTextStyle.copyWith(fontSize: 24),
          ),
          SizedBox(height: 8),
          Text(
            'Review the details and create your AI avatar.',
            style: kBodyTextStyle.copyWith(color: kLightTextColor),
          ),
          SizedBox(height: 32),

          // Avatar preview card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Avatar image
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(60),
                    color: kBackgroundColor,
                  ),
                  child: _avatarImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(60),
                          child: Image.file(_avatarImage!, fit: BoxFit.cover),
                        )
                      : Icon(Icons.person, size: 60, color: kLightTextColor),
                ),

                SizedBox(height: 16),

                // Name and bio
                Text(_name, style: kHeadingTextStyle.copyWith(fontSize: 20)),
                SizedBox(height: 8),
                Text(_bio, style: kBodyTextStyle, textAlign: TextAlign.center),

                SizedBox(height: 16),

                // Niche
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selectedNiche.displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Personality traits
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedTraits.map((trait) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(trait.displayName, style: kCaptionTextStyle),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _name.isNotEmpty && _bio.isNotEmpty;
      case 1:
        return _selectedTraits.length >= 3;
      case 2:
        return true; // Image is optional
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _createAvatar() async {
    if (!_canProceed()) return;

    setState(() => _isCreating = true);

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create avatar
      final avatar = await _avatarService.createAvatar(
        name: _name,
        bio: _bio,
        niche: _selectedNiche,
        personalityTraits: _selectedTraits,
        backstory: _backstory,
        avatarImage: _avatarImage,
      );

      // Navigate to main app
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => AppShell()),
        (route) => false,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Avatar "$_name" created successfully! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating avatar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }
}
