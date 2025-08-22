import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../services/auth_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'General';
  String _selectedPriority = 'Medium';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'General',
    'Technical Issue',
    'Account Problem',
    'Content Moderation',
    'Avatar Creation',
    'Payment & Billing',
    'Feature Request',
    'Bug Report',
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() {
    final user = AuthService().currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? user.username;
      _emailController.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
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
          'Support',
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
            // Quick Contact Options
            _buildQuickContactSection(),
            const SizedBox(height: 32),

            // Support Ticket Form
            _buildTicketFormSection(),
            const SizedBox(height: 32),

            // Common Issues
            _buildCommonIssuesSection(),
            const SizedBox(height: 32),

            // Contact Information
            _buildContactInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: kPrimaryColor, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Need Help?',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose the best way to get support for your issue:',
            style: TextStyle(color: kLightTextColor, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildQuickContactButton(
                  icon: Icons.email,
                  title: 'Email Support',
                  subtitle: '24-48h response',
                  color: kPrimaryColor,
                  onTap: () => _launchEmail(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickContactButton(
                  icon: Icons.help_outline,
                  title: 'FAQ',
                  subtitle: 'Instant answers',
                  color: Colors.green,
                  onTap: () => Navigator.pushNamed(context, '/help'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickContactButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: kTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: kLightTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketFormSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support, color: kPrimaryColor, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Submit Support Ticket',
                  style: TextStyle(
                    color: kTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Name Field
            CustomTextField(
              controller: _nameController,
              label: 'Full Name',
              hintText: 'Your full name',
              prefixIcon: Icons.person_outline,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email Field
            CustomTextField(
              controller: _emailController,
              label: 'Email Address',
              hintText: 'your.email@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your email';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value!)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category and Priority Row
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Category',
                    value: _selectedCategory,
                    items: _categories,
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown(
                    label: 'Priority',
                    value: _selectedPriority,
                    items: _priorities,
                    onChanged: (value) {
                      setState(() {
                        _selectedPriority = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Subject Field
            CustomTextField(
              controller: _subjectController,
              label: 'Subject',
              hintText: 'Brief description of your issue',
              prefixIcon: Icons.title,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter a subject';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description Field
            CustomTextField(
              controller: _descriptionController,
              label: 'Description',
              hintText: 'Please describe your issue in detail...',
              maxLines: 5,
              prefixIcon: Icons.description,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please describe your issue';
                }
                if (value!.length < 10) {
                  return 'Please provide more details (at least 10 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Submit Button
            CustomButton(
              text: _isSubmitting ? 'Submitting...' : 'Submit Support Ticket',
              onPressed: _isSubmitting ? null : _submitTicket,
              icon: _isSubmitting ? null : Icons.send,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
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
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: kCardColor,
              style: const TextStyle(color: kTextColor),
              items: items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommonIssuesSection() {
    final commonIssues = [
      {
        'title': 'Login Problems',
        'description': 'Can\'t sign in or forgot password',
        'solution': 'Use the "Forgot Password" link or contact support',
      },
      {
        'title': 'Avatar Creation Issues',
        'description': 'Problems creating or customizing avatars',
        'solution': 'Check internet connection and try again',
      },
      {
        'title': 'Video Upload Fails',
        'description': 'Cannot upload videos or posts',
        'solution': 'Check file size and format requirements',
      },
      {
        'title': 'App Performance',
        'description': 'App is slow or crashes frequently',
        'solution': 'Update app, restart device, or clear cache',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: kPrimaryColor, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Common Issues',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...commonIssues.map(
            (issue) => _buildIssueItem(
              issue['title']!,
              issue['description']!,
              issue['solution']!,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueItem(String title, String description, String solution) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: kLightTextColor, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Solution: $solution',
            style: TextStyle(
              color: kPrimaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_support, color: kPrimaryColor, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Contact Information',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContactRow(
            Icons.email,
            'Email',
            'support@quanta-app.com',
            () => _launchEmail(),
          ),
          _buildContactRow(
            Icons.language,
            'Website',
            'www.quanta-app.com',
            () => _launchUrl('https://quanta-app.com'),
          ),
          _buildContactRow(
            Icons.schedule,
            'Support Hours',
            'Monday - Friday, 9 AM - 5 PM EST',
            null,
          ),
          _buildContactRow(
            Icons.access_time,
            'Response Time',
            'Usually within 24-48 hours',
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String label,
    String value,
    VoidCallback? onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: kLightTextColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: kLightTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: onTap != null ? kPrimaryColor : kTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: onTap != null
                          ? TextDecoration.underline
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.launch, color: kPrimaryColor, size: 16),
          ],
        ),
      ),
    );
  }

  void _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // In a real implementation, this would send to your support system
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      // For now, we'll open email with the ticket information
      final ticketInfo =
          '''
Name: ${_nameController.text}
Email: ${_emailController.text}
Category: $_selectedCategory
Priority: $_selectedPriority
Subject: ${_subjectController.text}

Description:
${_descriptionController.text}
''';

      await _launchEmailWithTicket(ticketInfo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Support ticket created! We\'ll get back to you soon.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit ticket: $e'),
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

  void _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@quanta-app.com',
      query: 'subject=Quanta Support Request',
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

  void _launchEmailWithTicket(String ticketInfo) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@quanta-app.com',
      query:
          'subject=Support Ticket - ${_subjectController.text}&body=${Uri.encodeComponent(ticketInfo)}',
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
