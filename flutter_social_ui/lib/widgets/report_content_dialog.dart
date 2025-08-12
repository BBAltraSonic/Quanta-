import 'package:flutter/material.dart';
import '../services/user_safety_service.dart';
import '../constants.dart';

/// Dialog for reporting content (posts, comments, etc.)
class ReportContentDialog extends StatefulWidget {
  final String contentId;
  final ContentType contentType;
  final String? reportedUserId;

  const ReportContentDialog({
    super.key,
    required this.contentId,
    required this.contentType,
    this.reportedUserId,
  });

  @override
  State<ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<ReportContentDialog> {
  final UserSafetyService _safetyService = UserSafetyService();
  final TextEditingController _detailsController = TextEditingController();
  
  ReportReason? _selectedReason;
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<ReportReason> _reportReasons = [
    ReportReason.spam,
    ReportReason.harassment,
    ReportReason.hateContent,
    ReportReason.violence,
    ReportReason.explicitContent,
    ReportReason.misinformation,
    ReportReason.copyright,
    ReportReason.other,
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _getReasonDisplayText(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.harassment:
        return 'Harassment or Bullying';
      case ReportReason.hateContent:
        return 'Hate Speech';
      case ReportReason.violence:
        return 'Violence or Threats';
      case ReportReason.explicitContent:
        return 'Explicit Content';
      case ReportReason.misinformation:
        return 'Misinformation';
      case ReportReason.copyright:
        return 'Copyright Violation';
      case ReportReason.other:
        return 'Other';
    }
  }

  String _getReasonDescription(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'Repetitive, unwanted, or promotional content';
      case ReportReason.harassment:
        return 'Targeting someone with abuse or threats';
      case ReportReason.hateContent:
        return 'Content that attacks people based on identity';
      case ReportReason.violence:
        return 'Content containing or promoting violence';
      case ReportReason.explicitContent:
        return 'Sexual or graphic content';
      case ReportReason.misinformation:
        return 'False or misleading information';
      case ReportReason.copyright:
        return 'Unauthorized use of copyrighted material';
      case ReportReason.other:
        return 'Doesn\'t fit other categories';
    }
  }

  String _getContentTypeText() {
    switch (widget.contentType) {
      case ContentType.post:
        return 'post';
      case ContentType.comment:
        return 'comment';
      case ContentType.message:
        return 'message';
      case ContentType.profile:
        return 'profile';
    }
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      setState(() {
        _errorMessage = 'Please select a reason for reporting';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await _safetyService.reportContent(
        contentId: widget.contentId,
        contentType: widget.contentType,
        reason: _selectedReason!,
        additionalInfo: _detailsController.text.trim().isNotEmpty 
            ? _detailsController.text.trim() 
            : null,
        reportedUserId: widget.reportedUserId,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Thank you for your report. We\'ll review it soon.'),
              backgroundColor: kPrimaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to submit report. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCardColor,
      title: Text(
        'Report ${_getContentTypeText()}',
        style: kHeadingTextStyle.copyWith(fontSize: 20),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this ${_getContentTypeText()}?',
              style: kBodyTextStyle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            // Report reasons list
            ...(_reportReasons.map((reason) => 
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedReason == reason 
                        ? kPrimaryColor 
                        : kLightTextColor.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RadioListTile<ReportReason>(
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                      _errorMessage = null;
                    });
                  },
                  title: Text(
                    _getReasonDisplayText(reason),
                    style: kBodyTextStyle.copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    _getReasonDescription(reason),
                    style: kBodyTextStyle.copyWith(
                      fontSize: 12,
                      color: kLightTextColor,
                    ),
                  ),
                  activeColor: kPrimaryColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            )),
            
            const SizedBox(height: 16),
            
            // Additional details text field
            Text(
              'Additional details (optional)',
              style: kBodyTextStyle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 500,
              style: kBodyTextStyle,
              decoration: InputDecoration(
                hintText: 'Provide any additional context that might help us review this report...',
                hintStyle: kBodyTextStyle.copyWith(color: kLightTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kLightTextColor.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kLightTextColor.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kPrimaryColor),
                ),
                filled: true,
                fillColor: kBackgroundColor,
                counterStyle: kBodyTextStyle.copyWith(
                  fontSize: 12,
                  color: kLightTextColor,
                ),
              ),
            ),
            
            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: kBodyTextStyle.copyWith(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: kLightTextColor),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Submit Report'),
        ),
      ],
    );
  }
}
