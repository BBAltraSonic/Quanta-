import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';

enum ShareType {
  copyLink,
  shareToFriends,
  shareToSocial,
  embedCode,
}

/// Service for handling different types of sharing functionality
class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  /// Show share bottom sheet with different sharing options
  Future<void> showShareSheet(BuildContext context, {
    required String postId,
    required String avatarName,
    required String caption,
    String? mediaUrl,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShareBottomSheet(
        postId: postId,
        avatarName: avatarName,
        caption: caption,
        mediaUrl: mediaUrl,
      ),
    );
  }

  /// Generate shareable link for a post
  String generatePostLink(String postId) {
    // TODO: Replace with actual domain when deployed
    return 'https://quanta.app/post/$postId';
  }

  /// Copy link to clipboard
  Future<void> copyLinkToClipboard(String postId) async {
    final link = generatePostLink(postId);
    await Clipboard.setData(ClipboardData(text: link));
  }

  /// Generate embed code for a post
  String generateEmbedCode(String postId) {
    final link = generatePostLink(postId);
    return '''<iframe src="$link/embed" width="400" height="600" frameborder="0"></iframe>''';
  }

  /// Share to external apps (would integrate with share_plus package)
  Future<void> shareToExternal(String text, String url) async {
    // TODO: Implement with share_plus package
    // Share.share('$text\n\n$url');
    debugPrint('Sharing: $text\n$url');
  }
}

class _ShareBottomSheet extends StatelessWidget {
  final String postId;
  final String avatarName;
  final String caption;
  final String? mediaUrl;

  const _ShareBottomSheet({
    required this.postId,
    required this.avatarName,
    required this.caption,
    this.mediaUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kLightTextColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Share this post',
                  style: TextStyle(
                    color: kTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'by $avatarName',
                  style: const TextStyle(
                    color: kLightTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Post preview
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Media thumbnail
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[800],
                  ),
                  child: mediaUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: mediaUrl!.startsWith('assets/')
                              ? Image.asset(
                                  mediaUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  mediaUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.broken_image,
                                      color: kLightTextColor,
                                    );
                                  },
                                ),
                        )
                      : const Icon(
                          Icons.video_library,
                          color: kLightTextColor,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 12),
                
                // Caption
                Expanded(
                  child: Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kTextColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Share options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _ShareOption(
                  icon: Icons.link,
                  title: 'Copy link',
                  subtitle: 'Share link to this post',
                  onTap: () async {
                    await ShareService().copyLinkToClipboard(postId);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard!'),
                          backgroundColor: kPrimaryColor,
                        ),
                      );
                    }
                  },
                ),
                
                _ShareOption(
                  icon: Icons.people,
                  title: 'Share to friends',
                  subtitle: 'Send to your Quanta friends',
                  onTap: () {
                    Navigator.pop(context);
                    _showComingSoon(context, 'Share to Friends');
                  },
                ),
                
                _ShareOption(
                  icon: Icons.share,
                  title: 'Share to social media',
                  subtitle: 'Post on other platforms',
                  onTap: () async {
                    final link = ShareService().generatePostLink(postId);
                    await ShareService().shareToExternal(
                      'Check out this amazing post by $avatarName on Quanta!',
                      link,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
                
                _ShareOption(
                  icon: Icons.code,
                  title: 'Embed code',
                  subtitle: 'Get HTML code to embed',
                  onTap: () async {
                    final embedCode = ShareService().generateEmbedCode(postId);
                    await Clipboard.setData(ClipboardData(text: embedCode));
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Embed code copied to clipboard!'),
                          backgroundColor: kPrimaryColor,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          
          // Cancel button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: kLightTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Text(feature, style: const TextStyle(color: kTextColor)),
        content: Text(
          '$feature is coming soon! Stay tuned for updates.',
          style: const TextStyle(color: kLightTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
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
      title: Text(
        title,
        style: const TextStyle(
          color: kTextColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: kLightTextColor,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: kLightTextColor,
      ),
      onTap: onTap,
    );
  }
}
