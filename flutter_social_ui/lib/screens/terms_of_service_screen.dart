import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../widgets/custom_button.dart';

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
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
          'Terms of Service',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: kTextColor),
            onPressed: () => _shareTerms(),
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
                    Icon(Icons.gavel, color: kPrimaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Effective Date: August 22, 2025',
                      style: TextStyle(
                        color: kTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'These terms govern your use of the Quanta AI Avatar Social Platform.',
                  style: TextStyle(color: kLightTextColor, fontSize: 14),
                ),
              ],
            ),
          ),

          // Terms content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('1. Acceptance of Terms', _acceptanceOfTerms),
                  _buildSection(
                    '2. Description of Service',
                    _descriptionOfService,
                  ),
                  _buildSection('3. User Accounts', _userAccounts),
                  _buildSection(
                    '4. User Content and Conduct',
                    _userContentAndConduct,
                  ),
                  _buildSection('5. AI Avatar Usage', _aiAvatarUsage),
                  _buildSection(
                    '6. Prohibited Activities',
                    _prohibitedActivities,
                  ),
                  _buildSection(
                    '7. Intellectual Property',
                    _intellectualProperty,
                  ),
                  _buildSection(
                    '8. Privacy and Data Protection',
                    _privacyAndData,
                  ),
                  _buildSection('9. Content Moderation', _contentModeration),
                  _buildSection('10. Termination', _termination),
                  _buildSection(
                    '11. Disclaimers and Limitation of Liability',
                    _disclaimers,
                  ),
                  _buildSection('12. Indemnification', _indemnification),
                  _buildSection('13. Dispute Resolution', _disputeResolution),
                  _buildSection('14. Changes to Terms', _changesToTerms),
                  _buildSection('15. Contact Information', _contactInformation),
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _downloadTerms(),
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
                    text: 'Contact Legal',
                    onPressed: () => _contactLegal(),
                    icon: Icons.email,
                  ),
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

  void _shareTerms() async {
    const url = 'https://quanta-app.com/terms';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not share terms of service'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadTerms() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text(
          'Download Terms of Service',
          style: TextStyle(color: kTextColor),
        ),
        content: const Text(
          'To download a PDF version of our terms of service, please visit our website at quanta-app.com/terms',
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
              launchUrl(Uri.parse('https://quanta-app.com/terms'));
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

  void _contactLegal() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'legal@quanta-app.com',
      query: 'subject=Terms of Service Inquiry',
    );

    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open email app. Please email legal@quanta-app.com',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Terms of service content sections
  static const String _acceptanceOfTerms = '''
By accessing or using the Quanta mobile application and related services (the "Service"), you agree to be bound by these Terms of Service ("Terms").

If you do not agree to these Terms, do not access or use our Service.

These Terms apply to all users of the Service, including without limitation users who are browsers, customers, merchants, contributors of content, information, and other materials or services on the Service.

Your access to and use of the Service is conditioned on your acceptance of and compliance with these Terms. These Terms apply to all visitors, users, and others who access or use the Service.

By accessing or using our Service, you agree to be bound by these Terms and our Privacy Policy. If you disagree with any part of these terms, then you may not access the Service.''';

  static const String _descriptionOfService = '''
Quanta is an AI-powered avatar social platform that allows users to:

• Create and customize AI avatars with unique personalities
• Share content including videos, images, and text
• Interact with other users through their avatars
• Engage in social networking activities
• Access AI-powered features and recommendations

Our Service includes:

• Mobile applications for iOS and Android
• Web-based platform access
• AI avatar creation and management tools
• Content sharing and discovery features
• Social interaction and messaging capabilities
• Analytics and insights tools

We reserve the right to modify, suspend, or discontinue any part of the Service at any time without notice. We may also impose limits on certain features or restrict access to parts or all of the Service without notice or liability.''';

  static const String _userAccounts = '''
To access certain features of the Service, you must create an account. You agree to:

• Provide accurate, current, and complete information
• Maintain the security of your password and account
• Accept responsibility for all activities under your account
• Notify us immediately of any unauthorized use

Account Requirements:

• You must be at least 13 years old to create an account
• Users under 18 should have parental consent
• One person may not maintain more than one account
• Accounts are non-transferable

Account Security:

• You are responsible for maintaining account confidentiality
• We are not liable for any loss or damage from unauthorized account access
• You must notify us immediately of any security breaches
• We may suspend or terminate accounts that appear to be compromised

Account Termination:

• You may delete your account at any time
• We may terminate accounts that violate these Terms
• Upon termination, your right to use the Service ceases immediately''';

  static const String _userContentAndConduct = '''
Users may submit, post, and share content through the Service. By submitting content, you:

• Retain ownership of your intellectual property rights
• Grant us a license to use, modify, and distribute your content
• Represent that you have the right to share the content
• Agree that your content may be viewed by other users

Content Guidelines:

• Content must not violate applicable laws or regulations
• Content must not infringe on third-party rights
• Content should be appropriate for a general audience
• Content must not contain harmful or malicious elements

User Conduct:

• Respect other users and their privacy
• Do not engage in harassment, bullying, or abuse
• Do not impersonate others or create fake accounts
• Do not attempt to circumvent security measures
• Follow all applicable laws and regulations

Content Moderation:

• We reserve the right to review and remove content
• Content may be removed without notice
• Repeat violations may result in account suspension
• Appeals process available for content decisions''';

  static const String _aiAvatarUsage = '''
Our AI avatar system allows you to create digital personas with unique characteristics. By using AI avatars, you understand and agree that:

Avatar Creation:

• AI avatars are generated using artificial intelligence technology
• Avatar characteristics may be based on user inputs and preferences
• We do not guarantee specific avatar appearances or behaviors
• Avatar creation is subject to our content policies

Avatar Interactions:

• AI avatars may interact with other users' avatars
• Avatar responses are generated by AI and may not reflect user views
• We are not responsible for AI-generated content or interactions
• Users should not rely on AI avatars for important decisions

Avatar Ownership:

• You retain rights to avatars you create within our system
• We may use avatar data to improve our AI technology
• Avatars created using our system must comply with these Terms
• We reserve the right to remove avatars that violate policies

AI Technology Limitations:

• AI responses may not always be accurate or appropriate
• AI technology is continuously evolving and improving
• We do not guarantee AI avatar performance or availability
• Technical issues may occasionally affect AI functionality''';

  static const String _prohibitedActivities = '''
You may not use our Service to:

Illegal Activities:

• Engage in any unlawful activities
• Violate any applicable local, state, national, or international laws
• Infringe on intellectual property rights
• Engage in fraudulent or deceptive practices

Harmful Content:

• Post content that is defamatory, libelous, or false
• Share content that promotes violence or hatred
• Upload malicious software or harmful code
• Distribute spam or unsolicited communications

Platform Abuse:

• Attempt to gain unauthorized access to our systems
• Reverse engineer or decompile our software
• Use automated systems to access the Service
• Interfere with the proper functioning of the Service

Commercial Violations:

• Use the Service for unauthorized commercial purposes
• Sell, transfer, or sublicense your account
• Engage in unauthorized advertising or promotion
• Violate any applicable commercial regulations

Privacy Violations:

• Share other users' personal information without consent
• Engage in stalking or harassment
• Attempt to collect user data without authorization
• Violate applicable privacy laws and regulations''';

  static const String _intellectualProperty = '''
The Service and its original content, features, and functionality are owned by Quanta and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.

Our Rights:

• We own all rights to the Quanta platform and technology
• Our trademarks, logos, and brand elements are protected
• AI technology and algorithms are proprietary
• Service design and functionality are protected

User Content Rights:

• You retain ownership of content you create and share
• You grant us a license to use your content within our Service
• This license includes the right to modify, adapt, and distribute content
• The license continues until you delete your content or terminate your account

Permitted Use:

• You may use the Service for personal, non-commercial purposes
• You may not copy, modify, or distribute our proprietary content
• You may not use our intellectual property without permission
• Fair use and other legal exceptions may apply

Copyright Protection:

• We respect intellectual property rights
• We respond to valid DMCA takedown notices
• Users who repeatedly infringe copyrights may have accounts terminated
• We provide a process for counter-notifications

Trademark Policy:

• Our trademarks may not be used without permission
• User content should not confuse users about the source of goods or services
• We may remove content that infringes on trademark rights
• Trademark disputes are handled according to applicable law''';

  static const String _privacyAndData = '''
Your privacy is important to us. Our Privacy Policy explains how we collect, use, and protect your information when you use our Service.

Data Collection:

• We collect information you provide directly to us
• We automatically collect certain usage and device information
• We may collect location information with your permission
• We use cookies and similar technologies

Data Use:

• We use your information to provide and improve our Service
• We may use data for analytics and research purposes
• We may personalize your experience based on your data
• We may use data for safety and security purposes

Data Protection:

• We implement security measures to protect your data
• We limit access to your information on a need-to-know basis
• We use encryption and other security technologies
• We regularly review and update our security practices

Your Rights:

• You can access and update your personal information
• You can request deletion of your data
• You can opt out of certain data uses
• You can contact us with privacy-related questions

International Transfers:

• Your data may be transferred and stored in different countries
• We ensure appropriate safeguards for international transfers
• Data protection laws may vary by jurisdiction
• We comply with applicable data protection regulations''';

  static const String _contentModeration = '''
We strive to maintain a safe and positive environment for all users. Our content moderation practices include:

Automated Moderation:

• We use AI and automated systems to detect policy violations
• Automated systems may flag or remove content
• False positives may occur and can be appealed
• Technology is continuously improving

Human Review:

• Trained moderators review flagged content
• Complex cases receive human evaluation
• Cultural and contextual factors are considered
• Moderation decisions aim to be fair and consistent

Community Reporting:

• Users can report content that violates policies
• Reports are reviewed promptly
• Reporter identity is kept confidential
• False reports may result in penalties

Enforcement Actions:

• Content removal for policy violations
• Account warnings for minor violations
• Account suspension for serious violations
• Permanent account termination for severe violations

Appeals Process:

• Users can appeal moderation decisions
• Appeals are reviewed by a different team
• Additional context and evidence can be provided
• Appeal decisions are generally final

Transparency:

• We provide clear community guidelines
• We explain moderation decisions when possible
• We publish transparency reports regularly
• We engage with users about policy updates''';

  static const String _termination = '''
Either party may terminate this agreement at any time:

User Termination:

• You may delete your account at any time
• Account deletion removes access to the Service
• Some data may be retained for legal or operational purposes
• You remain responsible for activities prior to termination

Our Termination Rights:

• We may suspend or terminate accounts that violate these Terms
• We may terminate accounts for prolonged inactivity
• We may terminate the Service entirely with notice
• We may terminate for business or legal reasons

Immediate Termination:

• Accounts may be immediately terminated for severe violations
• No notice may be provided for serious safety concerns
• Emergency terminations may occur for legal compliance
• Immediate termination may be necessary to protect users

Effects of Termination:

• Access to the Service ceases immediately
• User content may be deleted or made inaccessible
• Outstanding obligations survive termination
• Certain provisions of these Terms continue to apply

Data After Termination:

• Some data may be retained as required by law
• Personal data is handled according to our Privacy Policy
• User content may be deleted according to our policies
• Backup systems may retain data for limited periods''';

  static const String _disclaimers = '''
THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND.

Service Disclaimers:

• We do not guarantee Service availability or reliability
• Features may change or be discontinued without notice
• AI technology may not always produce expected results
• User experience may vary based on device and connection

Content Disclaimers:

• We do not endorse user-generated content
• Content accuracy is not guaranteed
• AI-generated content may not be reliable
• Users are responsible for evaluating content

Limitation of Liability:

• We are not liable for indirect, incidental, or consequential damages
• Our liability is limited to the maximum extent permitted by law
• We are not responsible for user conduct or content
• Technical issues are addressed on a best-effort basis

Third-Party Services:

• We may integrate with third-party services
• We are not responsible for third-party service availability
• Third-party terms and privacy policies apply
• Integration with third parties may change without notice

Force Majeure:

• We are not liable for events beyond our reasonable control
• Natural disasters, government actions, and technical failures are excluded
• Service interruptions due to force majeure are not compensated
• We will make reasonable efforts to restore Service after such events''';

  static const String _indemnification = '''
You agree to defend, indemnify, and hold harmless Quanta, its officers, directors, employees, agents, and affiliates from and against any claims, damages, costs, and expenses (including reasonable attorneys' fees) arising from:

User Conduct:

• Your use or misuse of the Service
• Your violation of these Terms or applicable laws
• Your infringement of third-party rights
• Your interactions with other users

Content Liability:

• Content you submit, post, or share
• Claims that your content violates third-party rights
• Damages resulting from your content
• Costs of defending against content-related claims

Account Responsibility:

• Activities conducted through your account
• Unauthorized use of your account due to your negligence
• Sharing of account credentials
• Failure to secure your account

Breach of Agreement:

• Violation of any provision of these Terms
• Failure to comply with applicable laws while using the Service
• Actions that harm other users or the Service
• Commercial use without proper authorization

Limitation:

• Indemnification obligations are subject to applicable law
• We will provide notice of claims requiring indemnification
• You have the right to participate in defense of claims
• Settlement of claims requires mutual agreement''';

  static const String _disputeResolution = '''
We prefer to resolve disputes amicably and efficiently:

Informal Resolution:

• Contact us first to discuss any concerns
• Many issues can be resolved through direct communication
• We aim to respond to dispute notices within 30 days
• Good faith efforts will be made to reach resolution

Binding Arbitration:

• Disputes that cannot be resolved informally may be subject to arbitration
• Arbitration is conducted according to applicable rules and procedures
• Arbitration takes place in the jurisdiction where our company is located
• Arbitration decisions are final and binding

Class Action Waiver:

• Disputes must be brought individually, not as part of a class action
• You waive the right to participate in class action lawsuits
• Disputes cannot be consolidated with other users' claims
• This waiver applies to the maximum extent permitted by law

Governing Law:

• These Terms are governed by the laws of [Your Jurisdiction]
• Disputes are resolved according to applicable local laws
• International users may have additional protections under local law
• Conflict of laws principles do not apply

Exceptions:

• Either party may seek injunctive relief in court
• Intellectual property disputes may be brought in court
• Small claims court proceedings are not affected
• Emergency relief may be sought without arbitration''';

  static const String _changesToTerms = '''
We may update these Terms from time to time:

Notice of Changes:

• Updated Terms will be posted in the app and on our website
• We will update the "Effective Date" at the top of these Terms
• Significant changes may be announced through additional channels
• We may provide email notice for material changes

Review Period:

• Changes become effective 30 days after posting (unless noted otherwise)
• You should review Terms periodically for updates
• Continued use of the Service constitutes acceptance of changes
• You may terminate your account if you disagree with changes

Material Changes:

• Significant modifications to core Terms will be highlighted
• Changes affecting your rights will be clearly communicated
• We may provide additional notice for changes to dispute resolution
• Privacy-related changes are governed by our Privacy Policy

Version History:

• Previous versions of Terms may be available upon request
• We maintain records of significant Term changes
• Legal requirements may dictate certain change procedures
• Users can contact us with questions about Term modifications''';

  static const String _contactInformation = '''
If you have any questions about these Terms of Service, please contact us:

General Inquiries:
Email: legal@quanta-app.com
Website: https://quanta-app.com/terms

Legal Department:
Email: legal@quanta-app.com
Phone: [Your Phone Number]

Mailing Address:
Quanta Legal Department
[Your Company Address]
[City, State, ZIP Code]
[Country]

Response Time:
• We aim to respond to legal inquiries within 5-10 business days
• Complex matters may require additional time
• Urgent legal matters should be marked as such

Additional Resources:
• Privacy Policy: https://quanta-app.com/privacy
• Community Guidelines: https://quanta-app.com/guidelines
• Support Center: https://quanta-app.com/support

These Terms of Service constitute the entire agreement between you and Quanta regarding your use of the Service.''';
}
