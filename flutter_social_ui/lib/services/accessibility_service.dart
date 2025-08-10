import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

class AccessibilityService {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  // Accessibility preferences
  bool _highContrastMode = false;
  bool _largeTextMode = false;
  bool _reduceMotionMode = false;
  bool _screenReaderMode = false;
  double _textScaleFactor = 1.0;

  // Getters
  bool get highContrastMode => _highContrastMode;
  bool get largeTextMode => _largeTextMode;
  bool get reduceMotionMode => _reduceMotionMode;
  bool get screenReaderMode => _screenReaderMode;
  double get textScaleFactor => _textScaleFactor;

  // Initialize accessibility service
  Future<void> initialize() async {
    try {
      // Check system accessibility settings
      await _checkSystemAccessibilitySettings();
    } catch (e) {
      debugPrint('Error initializing accessibility service: $e');
    }
  }

  // Check system accessibility settings
  Future<void> _checkSystemAccessibilitySettings() async {
    try {
      // This would check actual system settings in a real implementation
      // For now, we'll use default values
      _highContrastMode = false;
      _largeTextMode = false;
      _reduceMotionMode = false;
      _screenReaderMode = false;
      _textScaleFactor = 1.0;
    } catch (e) {
      debugPrint('Error checking system accessibility settings: $e');
    }
  }

  // Set high contrast mode
  void setHighContrastMode(bool enabled) {
    _highContrastMode = enabled;
  }

  // Set large text mode
  void setLargeTextMode(bool enabled) {
    _largeTextMode = enabled;
    _textScaleFactor = enabled ? 1.3 : 1.0;
  }

  // Set reduce motion mode
  void setReduceMotionMode(bool enabled) {
    _reduceMotionMode = enabled;
  }

  // Set screen reader mode
  void setScreenReaderMode(bool enabled) {
    _screenReaderMode = enabled;
  }

  // Get accessible text style
  TextStyle getAccessibleTextStyle(TextStyle baseStyle) {
    TextStyle style = baseStyle;
    
    if (_largeTextMode) {
      style = style.copyWith(
        fontSize: (style.fontSize ?? 14) * _textScaleFactor,
      );
    }
    
    if (_highContrastMode) {
      style = style.copyWith(
        color: _getHighContrastColor(style.color ?? Colors.black),
        fontWeight: FontWeight.w600,
      );
    }
    
    return style;
  }

  // Get high contrast color
  Color _getHighContrastColor(Color originalColor) {
    // Simple high contrast logic - make dark colors darker and light colors lighter
    final luminance = originalColor.computeLuminance();
    if (luminance > 0.5) {
      return Colors.white;
    } else {
      return Colors.black;
    }
  }

  // Get accessible colors
  Color getAccessibleBackgroundColor(Color originalColor) {
    if (!_highContrastMode) return originalColor;
    
    final luminance = originalColor.computeLuminance();
    if (luminance > 0.5) {
      return Colors.white;
    } else {
      return Colors.black;
    }
  }

  Color getAccessibleForegroundColor(Color backgroundColor) {
    if (!_highContrastMode) return Colors.black;
    
    final luminance = backgroundColor.computeLuminance();
    if (luminance > 0.5) {
      return Colors.black;
    } else {
      return Colors.white;
    }
  }

  // Get animation duration (reduced if reduce motion is enabled)
  Duration getAnimationDuration(Duration originalDuration) {
    if (_reduceMotionMode) {
      return Duration(milliseconds: (originalDuration.inMilliseconds * 0.3).round());
    }
    return originalDuration;
  }

  // Create semantic widget wrapper
  Widget createSemanticWrapper({
    required Widget child,
    required String label,
    String? hint,
    String? value,
    bool? button,
    bool? header,
    bool? textField,
    bool? image,
    bool? link,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onIncrease,
    VoidCallback? onDecrease,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: button ?? false,
      header: header ?? false,
      textField: textField ?? false,
      image: image ?? false,
      link: link ?? false,
      onTap: onTap,
      onLongPress: onLongPress,
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      child: child,
    );
  }

  // Create accessible button
  Widget createAccessibleButton({
    required Widget child,
    required String semanticLabel,
    String? semanticHint,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return createSemanticWrapper(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      onTap: enabled ? onPressed : null,
      child: child,
    );
  }

  // Create accessible text field
  Widget createAccessibleTextField({
    required Widget child,
    required String semanticLabel,
    String? semanticHint,
    String? semanticValue,
  }) {
    return createSemanticWrapper(
      label: semanticLabel,
      hint: semanticHint,
      value: semanticValue,
      textField: true,
      child: child,
    );
  }

  // Create accessible image
  Widget createAccessibleImage({
    required Widget child,
    required String semanticLabel,
    String? semanticHint,
  }) {
    return createSemanticWrapper(
      label: semanticLabel,
      hint: semanticHint,
      image: true,
      child: child,
    );
  }

  // Create accessible header
  Widget createAccessibleHeader({
    required Widget child,
    required String semanticLabel,
  }) {
    return createSemanticWrapper(
      label: semanticLabel,
      header: true,
      child: child,
    );
  }

  // Create accessible link
  Widget createAccessibleLink({
    required Widget child,
    required String semanticLabel,
    String? semanticHint,
    required VoidCallback onTap,
  }) {
    return createSemanticWrapper(
      label: semanticLabel,
      hint: semanticHint,
      link: true,
      onTap: onTap,
      child: child,
    );
  }

  // Announce to screen reader
  void announceToScreenReader(String message) {
    if (_screenReaderMode) {
      SemanticsService.announce(message, TextDirection.ltr);
    }
  }

  // Focus management
  void requestFocus(FocusNode focusNode) {
    focusNode.requestFocus();
  }

  void clearFocus(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  // Keyboard navigation helpers
  Widget createKeyboardNavigable({
    required Widget child,
    required FocusNode focusNode,
    VoidCallback? onEnterPressed,
    VoidCallback? onSpacePressed,
    Function(RawKeyEvent)? onKeyEvent,
  }) {
    return RawKeyboardListener(
      focusNode: focusNode,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            onEnterPressed?.call();
          } else if (event.logicalKey == LogicalKeyboardKey.space) {
            onSpacePressed?.call();
          }
        }
        onKeyEvent?.call(event);
      },
      child: child,
    );
  }

  // Color contrast checker
  bool hasGoodContrast(Color foreground, Color background) {
    final foregroundLuminance = foreground.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    
    final lighter = foregroundLuminance > backgroundLuminance 
        ? foregroundLuminance 
        : backgroundLuminance;
    final darker = foregroundLuminance > backgroundLuminance 
        ? backgroundLuminance 
        : foregroundLuminance;
    
    final contrastRatio = (lighter + 0.05) / (darker + 0.05);
    
    // WCAG AA standard requires 4.5:1 for normal text, 3:1 for large text
    return contrastRatio >= 4.5;
  }

  // Get minimum touch target size
  Size getMinimumTouchTargetSize() {
    // WCAG guidelines recommend minimum 44x44 logical pixels
    return Size(44.0, 44.0);
  }

  // Create accessible touch target
  Widget createAccessibleTouchTarget({
    required Widget child,
    required VoidCallback onTap,
    String? semanticLabel,
    Size? minimumSize,
  }) {
    final minSize = minimumSize ?? getMinimumTouchTargetSize();
    
    return createSemanticWrapper(
      label: semanticLabel ?? 'Button',
      button: true,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minWidth: minSize.width,
          minHeight: minSize.height,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(child: child),
        ),
      ),
    );
  }

  // Create accessible list item
  Widget createAccessibleListItem({
    required Widget child,
    required String semanticLabel,
    String? semanticValue,
    int? index,
    int? totalCount,
    VoidCallback? onTap,
  }) {
    String fullLabel = semanticLabel;
    if (index != null && totalCount != null) {
      fullLabel = '$semanticLabel, item ${index + 1} of $totalCount';
    }
    
    return createSemanticWrapper(
      label: fullLabel,
      value: semanticValue,
      button: onTap != null,
      onTap: onTap,
      child: child,
    );
  }

  // Create accessible form field
  Widget createAccessibleFormField({
    required Widget child,
    required String label,
    String? hint,
    String? error,
    bool required = false,
  }) {
    String semanticLabel = label;
    if (required) {
      semanticLabel += ', required';
    }
    
    String? semanticHint = hint;
    if (error != null) {
      semanticHint = error;
    }
    
    return createSemanticWrapper(
      label: semanticLabel,
      hint: semanticHint,
      textField: true,
      child: child,
    );
  }

  // Create accessible progress indicator
  Widget createAccessibleProgressIndicator({
    required Widget child,
    required double progress,
    String? label,
  }) {
    final percentage = (progress * 100).round();
    final semanticValue = '$percentage percent';
    
    return createSemanticWrapper(
      label: label ?? 'Progress',
      value: semanticValue,
      child: child,
    );
  }

  // Create accessible tab
  Widget createAccessibleTab({
    required Widget child,
    required String label,
    required bool selected,
    required int index,
    required int totalTabs,
    required VoidCallback onTap,
  }) {
    final semanticLabel = '$label, tab ${index + 1} of $totalTabs';
    final semanticHint = selected ? 'selected' : 'not selected, double tap to select';
    
    return createSemanticWrapper(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      onTap: onTap,
      child: child,
    );
  }

  // Accessibility testing helpers
  Map<String, dynamic> getAccessibilityReport() {
    return {
      'high_contrast_mode': _highContrastMode,
      'large_text_mode': _largeTextMode,
      'reduce_motion_mode': _reduceMotionMode,
      'screen_reader_mode': _screenReaderMode,
      'text_scale_factor': _textScaleFactor,
      'minimum_touch_target_size': getMinimumTouchTargetSize().toString(),
    };
  }

  // Voice over / TalkBack helpers
  void enableVoiceOver() {
    _screenReaderMode = true;
  }

  void disableVoiceOver() {
    _screenReaderMode = false;
  }

  // Reading order helpers
  Widget createReadingOrderGroup({
    required List<Widget> children,
    String? groupLabel,
  }) {
    return Semantics(
      label: groupLabel,
      child: Column(
        children: children.map((child) => 
          ExcludeSemantics(
            excluding: false,
            child: child,
          )
        ).toList(),
      ),
    );
  }

  // Live region for dynamic content updates
  Widget createLiveRegion({
    required Widget child,
    required String liveRegionLabel,
    bool polite = true,
  }) {
    return Semantics(
      label: liveRegionLabel,
      liveRegion: true,
      child: child,
    );
  }
}

// Accessibility-aware widget extensions
extension AccessibilityExtensions on Widget {
  Widget withAccessibility({
    required String label,
    String? hint,
    String? value,
    bool? button,
    bool? header,
    bool? textField,
    bool? image,
    bool? link,
    VoidCallback? onTap,
  }) {
    return AccessibilityService().createSemanticWrapper(
      label: label,
      hint: hint,
      value: value,
      button: button,
      header: header,
      textField: textField,
      image: image,
      link: link,
      onTap: onTap,
      child: this,
    );
  }

  Widget withMinimumTouchTarget({
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return AccessibilityService().createAccessibleTouchTarget(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: this,
    );
  }
}