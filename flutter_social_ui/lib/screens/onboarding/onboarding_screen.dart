import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../widgets/custom_button.dart';
import '../app_shell.dart';
import '../avatar_creation_wizard.dart';
import '../../services/auth_service.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kDefaultPadding),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Welcome Section
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Welcome to Quanta!',
                      style: TextStyle(
                        color: kTextColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Create your AI avatar and start building your virtual influencer presence',
                      style: TextStyle(
                        color: kLightTextColor,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    
                    // Features List
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: kCardColor,
                        borderRadius: BorderRadius.circular(kDefaultBorderRadius),
                      ),
                      child: Column(
                        children: const [
                          _FeatureItem(
                            icon: Icons.person_add,
                            title: 'Create Your Avatar',
                            description: 'Design your unique AI personality',
                          ),
                          SizedBox(height: 24),
                          _FeatureItem(
                            icon: Icons.video_library,
                            title: 'Share Content',
                            description: 'Upload and showcase your avatar\'s videos',
                          ),
                          SizedBox(height: 24),
                          _FeatureItem(
                            icon: Icons.chat,
                            title: 'AI Conversations',
                            description: 'Let your avatar chat with fans',
                          ),
                          SizedBox(height: 24),
                          _FeatureItem(
                            icon: Icons.trending_up,
                            title: 'Grow Your Following',
                            description: 'Build a community around your avatar',
                          ),
                        ],
                      ),
                    ),
                  ],
                  ),
                ),
              ),
              
              // Action Buttons
              Column(
                children: [
                  CustomButton(
                    text: 'Create My Avatar',
                    onPressed: () async {
                      // Mark onboarding completed and navigate to avatar creation wizard
                      final authService = AuthService();
                      await authService.markOnboardingCompleted();
                      
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const AvatarCreationWizard(),
                        ),
                      );
                    },
                    icon: Icons.arrow_forward,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Skip for Now',
                    onPressed: () async {
                      // Mark onboarding completed and navigate to main app
                      final authService = AuthService();
                      await authService.markOnboardingCompleted();
                      
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const AppShell(),
                        ),
                      );
                    },
                    isOutlined: true,
                    backgroundColor: kLightTextColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text(
          'Coming Soon',
          style: TextStyle(color: kTextColor),
        ),
        content: const Text(
          'Avatar creation wizard is being implemented. For now, you can explore the app with the beautiful TikTok-style interface!',
          style: TextStyle(color: kLightTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Mark onboarding completed and navigate to main app
              final authService = AuthService();
              await authService.markOnboardingCompleted();
              
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const AvatarCreationWizard(),
                      ),
                    );
            },
            child: const Text(
              'Continue to App',
              style: TextStyle(color: kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: kPrimaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: kLightTextColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
