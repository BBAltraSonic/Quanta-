import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../widgets/custom_button.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
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
          'Privacy Policy',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: kTextColor),
            onPressed: () => _sharePolicy(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Last updated info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: kPrimaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Last Updated: August 22, 2025',
                      style: TextStyle(
                        color: kTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'This privacy policy explains how Quanta collects, uses, and protects your personal information.',
                  style: TextStyle(color: kLightTextColor, fontSize: 14),
                ),
              ],
            ),
          ),

          // Privacy policy content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    '1. Information We Collect',
                    _informationWeCollect,
                  ),
                  _buildSection(
                    '2. How We Use Your Information',
                    _howWeUseInformation,
                  ),
                  _buildSection(
                    '3. Information Sharing and Disclosure',
                    _informationSharing,
                  ),
                  _buildSection('4. Data Security', _dataSecurity),
                  _buildSection('5. Your Privacy Rights', _privacyRights),
                  _buildSection(
                    '6. International Data Transfers',
                    _dataTransfers,
                  ),
                  _buildSection('7. Children\'s Privacy', _childrensPrivacy),
                  _buildSection('8. Data Retention', _dataRetention),
                  _buildSection('9. Updates to This Policy', _policyUpdates),
                  _buildSection('10. Contact Us', _contactInfo),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _downloadPolicy(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrimaryColor,
                          side: BorderSide(color: kPrimaryColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download, size: 18),
                            const SizedBox(width: 8),
                            const Text('Download'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'Contact Us',
                        onPressed: () => _contactSupport(),
                        icon: Icons.email,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              color: kLightTextColor,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _sharePolicy() async {
    // In a real app, you might use the share_plus package
    const url = 'https://quanta-app.com/privacy';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not share privacy policy'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text(
          'Download Privacy Policy',
          style: TextStyle(color: kTextColor),
        ),
        content: const Text(
          'To download a PDF version of our privacy policy, please visit our website at quanta-app.com/privacy',
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
              launchUrl(Uri.parse('https://quanta-app.com/privacy'));
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

  void _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'privacy@quanta-app.com',
      query: 'subject=Privacy Policy Inquiry',
    );

    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open email app. Please email privacy@quanta-app.com',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Privacy policy content sections
  static const String _informationWeCollect = '''
We collect information you provide directly to us, such as when you:

• Create an account or profile
• Create and customize AI avatars
• Upload content (videos, images, text)
• Communicate with other users
• Contact our support team
• Participate in surveys or promotions

This may include your name, email address, username, profile information, avatar characteristics, and any content you create or share.

We also automatically collect certain information about your device and usage, including:

• Device information (type, operating system, unique identifiers)
• Usage data (app interactions, features used, session duration)
• Technical data (IP address, browser type, app version)
• Location information (if you grant permission)
• Analytics and performance data''';

  static const String _howWeUseInformation = '''
We use the information we collect to:

• Provide and improve our services
• Create and manage your account
• Generate and customize AI avatars
• Facilitate content creation and sharing
• Enable social features and interactions
• Provide customer support
• Send important notifications
• Analyze usage patterns and improve our app
• Ensure platform safety and security
• Comply with legal obligations

We may use your information to personalize your experience, including:

• Customizing your feed and recommendations
• Suggesting relevant content and users
• Improving AI avatar responses
• Enhancing app performance for your device''';

  static const String _informationSharing = '''
We do not sell, trade, or otherwise transfer your personal information to third parties, except as described in this policy:

• **Service Providers**: We may share information with trusted third-party service providers who assist us in operating our app, conducting business, or serving users.

• **Legal Requirements**: We may disclose information when required by law, regulation, legal process, or governmental request.

• **Safety and Security**: We may share information to protect the rights, property, or safety of Quanta, our users, or others.

• **Business Transfers**: In the event of a merger, acquisition, or sale of assets, user information may be transferred.

• **With Your Consent**: We may share information for any other purpose with your explicit consent.

Public Information:
• Your profile information and content you share publicly will be visible to other users
• AI avatar interactions may be visible to other users based on your privacy settings''';

  static const String _dataSecurity = '''
We implement appropriate technical and organizational security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.

Our security measures include:

• Encryption of data in transit and at rest
• Secure servers and databases
• Access controls and authentication
• Regular security assessments
• Employee training on data protection
• Incident response procedures

However, no method of transmission over the internet or electronic storage is 100% secure. While we strive to protect your personal information, we cannot guarantee absolute security.

You can help protect your account by:

• Using a strong, unique password
• Enabling two-factor authentication (when available)
• Not sharing your login credentials
• Logging out of shared devices
• Reporting suspicious activity''';

  static const String _privacyRights = '''
Depending on your location, you may have certain rights regarding your personal information:

**Access**: Request information about the personal data we have about you

**Correction**: Request that we correct inaccurate or incomplete information

**Deletion**: Request deletion of your personal information ("right to be forgotten")

**Portability**: Request a copy of your data in a machine-readable format

**Restriction**: Request that we limit how we use your information

**Objection**: Object to our processing of your information

**Withdrawal**: Withdraw consent for processing (where applicable)

To exercise these rights, contact us at privacy@quanta-app.com. We will respond to your request within the timeframes required by applicable law.

**California Residents**: You have additional rights under the California Consumer Privacy Act (CCPA)

**European Residents**: You have rights under the General Data Protection Regulation (GDPR)''';

  static const String _dataTransfers = '''
Quanta is based in the United States. If you are accessing our services from outside the United States, please be aware that your information may be transferred to, stored, and processed in the United States and other countries.

These countries may have different data protection laws than your country of residence. By using our services, you consent to the transfer of your information to the United States and other countries.

When we transfer personal information internationally, we implement appropriate safeguards, including:

• Standard contractual clauses
• Adequacy decisions
• Certification mechanisms
• Codes of conduct

We ensure that any international transfers comply with applicable data protection laws.''';

  static const String _childrensPrivacy = '''
Quanta is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13.

If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information promptly.

Users between 13 and 17 should have parental or guardian consent before using our services. Parents and guardians can contact us at privacy@quanta-app.com if they believe their child has provided personal information without consent.

For users in the European Union, the minimum age may be higher in accordance with local laws.''';

  static const String _dataRetention = '''
We retain your personal information for as long as necessary to provide our services and fulfill the purposes described in this policy.

Specific retention periods:

• **Account Information**: Retained while your account is active
• **Content**: Retained according to your privacy settings and applicable law
• **Usage Data**: Typically retained for 2-3 years for analytics purposes
• **Support Communications**: Retained for 3 years for quality assurance

When we no longer need your information, we will delete or anonymize it in accordance with our data retention policy and applicable law.

You can request deletion of your account and associated data at any time by contacting us at privacy@quanta-app.com.''';

  static const String _policyUpdates = '''
We may update this privacy policy from time to time to reflect changes in our practices, technology, legal requirements, or other factors.

When we make changes:

• We will post the updated policy on our app and website
• We will update the "Last Updated" date at the top of this policy
• For material changes, we may provide additional notice (such as email notification or in-app notification)

We encourage you to review this policy periodically to stay informed about how we protect your privacy.

Your continued use of our services after any changes to this policy constitutes your acceptance of the updated terms.''';

  static const String _contactInfo = '''
If you have any questions, concerns, or requests regarding this privacy policy or our data practices, please contact us:

**Email**: privacy@quanta-app.com
**Website**: https://quanta-app.com/privacy
**Mail**: Quanta Privacy Team
        [Your Company Address]
        [City, State, ZIP Code]

**Data Protection Officer**: For EU residents, you can contact our Data Protection Officer at dpo@quanta-app.com

**Response Time**: We will respond to your privacy-related inquiries within 30 days (or as required by applicable law)

You also have the right to file a complaint with your local data protection authority if you believe we have not adequately addressed your concerns.''';
}
