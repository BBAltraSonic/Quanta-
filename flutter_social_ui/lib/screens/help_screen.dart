import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../services/bug_reporting_service.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int _expandedSection = -1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        title: const Text(
          'Help & Support',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 32),

            // FAQ Section
            _buildSectionTitle('Frequently Asked Questions'),
            const SizedBox(height: 16),
            _buildFAQSection(),
            const SizedBox(height: 32),

            // Getting Started Guide
            _buildSectionTitle('Getting Started'),
            const SizedBox(height: 16),
            _buildGettingStartedSection(),
            const SizedBox(height: 32),

            // Troubleshooting
            _buildSectionTitle('Troubleshooting'),
            const SizedBox(height: 16),
            _buildTroubleshootingSection(),
            const SizedBox(height: 32),

            // Contact Support
            _buildSectionTitle('Contact Support'),
            const SizedBox(height: 16),
            _buildContactSection(),
            const SizedBox(height: 32),

            // App Information
            _buildAppInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.bug_report,
                  title: 'Report Bug',
                  onTap: () => _showBugReportDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.feedback,
                  title: 'Send Feedback',
                  onTap: () => _showFeedbackDialog(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.email,
                  title: 'Contact Us',
                  onTap: () => _launchEmail(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.help_outline,
                  title: 'User Guide',
                  onTap: () => _showUserGuide(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: kPrimaryColor, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: kTextColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildFAQSection() {
    final faqItems = [
      {
        'question': 'How do I create my first AI avatar?',
        'answer':
            'Tap the "Create Avatar" button on your profile screen. Follow the avatar creation wizard to customize appearance, personality traits, and characteristics. You can create multiple avatars for different purposes.',
      },
      {
        'question': 'Can I switch between different avatars?',
        'answer':
            'Yes! Tap on your avatar profile picture and select "Switch Avatar" from the menu. You can seamlessly switch between all your created avatars at any time.',
      },
      {
        'question': 'How do I upload videos and images?',
        'answer':
            'Tap the "+" button at the bottom of your screen, then select "Create Post". Choose to upload photos or videos from your gallery, or use the camera to capture new content.',
      },
      {
        'question': 'Why aren\'t my posts showing up in the feed?',
        'answer':
            'Posts may take a few minutes to appear. Ensure your content follows our community guidelines. If the issue persists, try refreshing the feed or restarting the app.',
      },
      {
        'question': 'How do I report inappropriate content?',
        'answer':
            'Tap and hold on any post or comment, then select "Report" from the menu. Choose the appropriate reason and our moderation team will review it promptly.',
      },
      {
        'question': 'Can I delete my account and data?',
        'answer':
            'Yes, go to Settings > Privacy & Security > Account Management > Delete Account. This will permanently remove all your data, avatars, and posts.',
      },
    ];

    return Column(
      children: faqItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _buildExpandableItem(index, item['question']!, item['answer']!);
      }).toList(),
    );
  }

  Widget _buildGettingStartedSection() {
    return Column(
      children: [
        _buildGuideStep(
          1,
          'Create Your Profile',
          'Set up your account with a username and profile information.',
          Icons.person_add,
        ),
        _buildGuideStep(
          2,
          'Create Your First Avatar',
          'Use the avatar creation wizard to design your AI persona with unique traits.',
          Icons.smart_toy,
        ),
        _buildGuideStep(
          3,
          'Explore the Feed',
          'Discover content from other creators in the vertical video feed.',
          Icons.explore,
        ),
        _buildGuideStep(
          4,
          'Create Content',
          'Upload videos, images, and start engaging with the community.',
          Icons.add_circle,
        ),
        _buildGuideStep(
          5,
          'Connect & Engage',
          'Follow other avatars, like posts, and participate in conversations.',
          Icons.favorite,
        ),
      ],
    );
  }

  Widget _buildGuideStep(
    int step,
    String title,
    String description,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kPrimaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                  style: const TextStyle(color: kLightTextColor, fontSize: 14),
                ),
              ],
            ),
          ),
          Icon(icon, color: kPrimaryColor),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingSection() {
    final troubleshootingItems = [
      {
        'problem': 'App crashes or freezes',
        'solution':
            '1. Force close and restart the app\n2. Restart your device\n3. Update to the latest version\n4. Clear app cache in device settings',
      },
      {
        'problem': 'Videos won\'t play or load slowly',
        'solution':
            '1. Check your internet connection\n2. Switch between Wi-Fi and mobile data\n3. Lower video quality in settings\n4. Clear app cache',
      },
      {
        'problem': 'Can\'t upload photos or videos',
        'solution':
            '1. Check camera and storage permissions\n2. Ensure sufficient storage space\n3. Try uploading smaller files\n4. Restart the app',
      },
      {
        'problem': 'Avatar creation fails',
        'solution':
            '1. Ensure stable internet connection\n2. Try creating avatar with simpler settings\n3. Restart the app and try again\n4. Contact support if issue persists',
      },
    ];

    return Column(
      children: troubleshootingItems.asMap().entries.map((entry) {
        final index = entry.key + 100; // Different index range
        final item = entry.value;
        return _buildExpandableItem(index, item['problem']!, item['solution']!);
      }).toList(),
    );
  }

  Widget _buildExpandableItem(int index, String title, String content) {
    final isExpanded = _expandedSection == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: kLightTextColor,
            ),
            onTap: () {
              setState(() {
                _expandedSection = isExpanded ? -1 : index;
              });
            },
          ),
          if (isExpanded) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                content,
                style: const TextStyle(
                  color: kLightTextColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Need more help?',
            style: TextStyle(
              color: kTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Our support team is here to help you with any questions or issues.',
            style: TextStyle(color: kLightTextColor, fontSize: 14),
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: 'Email Support',
            onPressed: () => _launchEmail(),
            icon: Icons.email,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildContactMethod(
                  'Response Time',
                  '24-48 hours',
                  Icons.schedule,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactMethod(
                  'Support Hours',
                  '9 AM - 5 PM EST',
                  Icons.access_time,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactMethod(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: kPrimaryColor, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: kTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: const TextStyle(color: kLightTextColor, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'App Information',
            style: TextStyle(
              color: kTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Version', '1.0.0+1'),
          _buildInfoRow('Build', 'Production'),
          _buildInfoRow('Platform', 'Flutter'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _launchUrl('https://quanta-app.com/privacy'),
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(color: kPrimaryColor),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _launchUrl('https://quanta-app.com/terms'),
                  child: const Text(
                    'Terms of Service',
                    style: TextStyle(color: kPrimaryColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: kLightTextColor, fontSize: 14),
          ),
          Text(value, style: const TextStyle(color: kTextColor, fontSize: 14)),
        ],
      ),
    );
  }

  void _showBugReportDialog() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const BugReportScreen()));
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Send Feedback', style: TextStyle(color: kTextColor)),
        content: const Text(
          'We\'d love to hear from you! Please email us at feedback@quanta-app.com with your suggestions.',
          style: TextStyle(color: kLightTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: kPrimaryColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchEmail('feedback');
            },
            child: const Text(
              'Open Email',
              style: TextStyle(color: kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('User Guide', style: TextStyle(color: kTextColor)),
        content: const Text(
          'The getting started section above covers the basics. For detailed guides, visit our website at quanta-app.com/help',
          style: TextStyle(color: kLightTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: kPrimaryColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl('https://quanta-app.com/help');
            },
            child: const Text(
              'Visit Website',
              style: TextStyle(color: kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _launchEmail([String? type]) async {
    final subject = type == 'feedback'
        ? 'Quanta Feedback'
        : 'Quanta Support Request';
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@quanta-app.com',
      query: 'subject=$subject',
    );

    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open email app. Please email support@quanta-app.com',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Bug Report Screen (comprehensive implementation)
class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final _expectedController = TextEditingController();
  final _actualController = TextEditingController();

  BugCategory _selectedCategory = BugCategory.other;
  BugSeverity _selectedSeverity = BugSeverity.medium;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        title: const Text(
          'Report a Bug',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: kPrimaryColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Help us improve Quanta',
                            style: TextStyle(
                              color: kTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Report bugs to help us fix issues and improve your experience.',
                            style: TextStyle(
                              color: kLightTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bug Title
              CustomTextField(
                controller: _titleController,
                label: 'Bug Title *',
                hintText: 'Brief description of the bug',
                prefixIcon: Icons.title,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a bug title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category and Severity
              Row(
                children: [
                  Expanded(child: _buildCategoryDropdown()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSeverityDropdown()),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              CustomTextField(
                controller: _descriptionController,
                label: 'Description *',
                hintText: 'Describe the bug in detail...',
                maxLines: 4,
                prefixIcon: Icons.description,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please describe the bug';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Steps to reproduce
              CustomTextField(
                controller: _stepsController,
                label: 'Steps to Reproduce *',
                hintText: '1. Open the app\n2. Navigate to...\n3. Tap on...',
                maxLines: 4,
                prefixIcon: Icons.format_list_numbered,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please provide steps to reproduce';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Expected behavior
              CustomTextField(
                controller: _expectedController,
                label: 'Expected Behavior',
                hintText: 'What should have happened?',
                maxLines: 2,
                prefixIcon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 16),

              // Actual behavior
              CustomTextField(
                controller: _actualController,
                label: 'Actual Behavior',
                hintText: 'What actually happened?',
                maxLines: 2,
                prefixIcon: Icons.error_outline,
              ),
              const SizedBox(height: 24),

              // Submit button
              CustomButton(
                text: _isSubmitting ? 'Submitting...' : 'Submit Bug Report',
                onPressed: _isSubmitting ? null : _submitBugReport,
                icon: _isSubmitting ? null : Icons.send,
                isLoading: _isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category *',
          style: TextStyle(
            color: kTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: kBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BugCategory>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: kCardColor,
              style: const TextStyle(color: kTextColor),
              items: BugCategory.values.map((category) {
                return DropdownMenuItem<BugCategory>(
                  value: category,
                  child: Row(
                    children: [
                      Icon(
                        BugReportingService.getCategoryIcon(category),
                        size: 18,
                        color: kLightTextColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        BugReportingService.getCategoryDisplayName(category),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeverityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Severity *',
          style: TextStyle(
            color: kTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: kBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BugSeverity>(
              value: _selectedSeverity,
              isExpanded: true,
              dropdownColor: kCardColor,
              style: const TextStyle(color: kTextColor),
              items: BugSeverity.values.map((severity) {
                return DropdownMenuItem<BugSeverity>(
                  value: severity,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: BugReportingService.getSeverityColor(severity),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        BugReportingService.getSeverityDisplayName(severity),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedSeverity = value;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  void _submitBugReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final bugReportingService = BugReportingService();

      final bugReport = await bugReportingService.createBugReport(
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        severity: _selectedSeverity,
        steps: _stepsController.text
            .split('\n')
            .where((s) => s.isNotEmpty)
            .toList(),
        expectedBehavior: _expectedController.text.isNotEmpty
            ? _expectedController.text
            : null,
        actualBehavior: _actualController.text.isNotEmpty
            ? _actualController.text
            : null,
      );

      final reportId = await bugReportingService.submitBugReport(bugReport);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bug report submitted! ID: $reportId'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit bug report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
