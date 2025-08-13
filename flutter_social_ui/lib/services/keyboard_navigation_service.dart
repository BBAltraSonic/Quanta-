import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service to handle keyboard navigation and shortcuts
class KeyboardNavigationService {
  static final KeyboardNavigationService _instance = KeyboardNavigationService._internal();
  factory KeyboardNavigationService() => _instance;
  KeyboardNavigationService._internal();

  /// Common keyboard shortcuts for the app
  static const Map<String, LogicalKeySet> shortcuts = {
    'save': LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS),
    'cancel': LogicalKeySet(LogicalKeyboardKey.escape),
    'next_field': LogicalKeySet(LogicalKeyboardKey.tab),
    'prev_field': LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab),
    'submit': LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter),
    'focus_username': LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyU),
    'focus_email': LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE),
    'focus_bio': LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB),
    'toggle_private': LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP),
  };

  /// Create keyboard shortcuts widget
  Widget wrapWithShortcuts({
    required Widget child,
    required Map<LogicalKeySet, VoidCallback> shortcuts,
  }) {
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: _createActions(shortcuts),
        child: child,
      ),
    );
  }

  /// Create focus traversal group for better keyboard navigation
  Widget createFocusTraversalGroup({
    required Widget child,
    FocusTraversalPolicy? policy,
    bool requestFocus = false,
  }) {
    return FocusTraversalGroup(
      policy: policy ?? OrderedTraversalPolicy(),
      child: requestFocus
          ? Focus(
              autofocus: true,
              child: child,
            )
          : child,
    );
  }

  /// Create a focusable field with proper keyboard navigation
  Widget createFocusableField({
    required Widget child,
    FocusNode? focusNode,
    bool autofocus = false,
    VoidCallback? onFocus,
    VoidCallback? onUnfocus,
    String? semanticLabel,
    String? tooltip,
  }) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        } else {
          onUnfocus?.call();
        }
      },
      child: Semantics(
        label: semanticLabel,
        tooltip: tooltip,
        child: child,
      ),
    );
  }

  /// Create keyboard shortcut help dialog
  Widget createShortcutsHelpDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildShortcutRow('Save changes', 'Ctrl + S'),
            _buildShortcutRow('Cancel/Close', 'Escape'),
            _buildShortcutRow('Next field', 'Tab'),
            _buildShortcutRow('Previous field', 'Shift + Tab'),
            _buildShortcutRow('Submit form', 'Ctrl + Enter'),
            _buildShortcutRow('Focus username', 'Ctrl + U'),
            _buildShortcutRow('Focus email', 'Ctrl + E'),
            _buildShortcutRow('Focus bio', 'Ctrl + B'),
            _buildShortcutRow('Toggle privacy', 'Ctrl + P'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  /// Show keyboard shortcuts help
  void showShortcutsHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: createShortcutsHelpDialog,
    );
  }

  Map<Type, Action<Intent>> _createActions(Map<LogicalKeySet, VoidCallback> shortcuts) {
    final actions = <Type, Action<Intent>>{};
    
    for (final entry in shortcuts.entries) {
      final intent = _createIntentForShortcut(entry.key);
      actions[intent.runtimeType] = _createCallbackAction(entry.value);
    }
    
    return actions;
  }

  Intent _createIntentForShortcut(LogicalKeySet shortcut) {
    // Create a unique intent for each shortcut
    return _CustomIntent(shortcut.hashCode);
  }

  Action<Intent> _createCallbackAction(VoidCallback callback) {
    return CallbackAction<Intent>(
      onInvoke: (intent) {
        callback();
        return null;
      },
    );
  }

  Widget _buildShortcutRow(String description, String shortcut) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(description),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                shortcut,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomIntent extends Intent {
  final int id;
  const _CustomIntent(this.id);

  @override
  bool operator ==(Object other) => 
      identical(this, other) || 
      (other is _CustomIntent && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Mixin to add keyboard navigation support to StatefulWidgets
mixin KeyboardNavigationMixin<T extends StatefulWidget> on State<T> {
  final KeyboardNavigationService _navigationService = KeyboardNavigationService();
  
  final Map<String, FocusNode> _focusNodes = {};
  
  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Get or create a focus node for a field
  FocusNode getFocusNode(String fieldName) {
    return _focusNodes.putIfAbsent(fieldName, () => FocusNode());
  }

  /// Focus a specific field
  void focusField(String fieldName) {
    final node = _focusNodes[fieldName];
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
    }
  }

  /// Get keyboard shortcuts for the screen
  Map<LogicalKeySet, VoidCallback> getKeyboardShortcuts();

  /// Wrap widget with keyboard shortcuts
  Widget wrapWithKeyboardShortcuts(Widget child) {
    return _navigationService.wrapWithShortcuts(
      shortcuts: getKeyboardShortcuts(),
      child: child,
    );
  }

  /// Create focus traversal group
  Widget createFocusGroup(Widget child, {FocusTraversalPolicy? policy}) {
    return _navigationService.createFocusTraversalGroup(
      child: child,
      policy: policy,
    );
  }

  /// Show shortcuts help
  void showShortcutsHelp() {
    _navigationService.showShortcutsHelp(context);
  }
}

/// Custom focus traversal policy for forms
class FormFocusTraversalPolicy extends FocusTraversalPolicy {
  final List<String> fieldOrder;

  const FormFocusTraversalPolicy(this.fieldOrder);

  @override
  FocusNode? findFirstFocus(FocusNode currentNode) {
    return _getOrderedNodes(currentNode).firstOrNull;
  }

  @override
  FocusNode? findLastFocus(FocusNode currentNode) {
    final nodes = _getOrderedNodes(currentNode);
    return nodes.isNotEmpty ? nodes.last : null;
  }

  @override
  FocusNode? findNextFocus(FocusNode currentNode, {TraversalDirection? direction}) {
    final nodes = _getOrderedNodes(currentNode);
    final currentIndex = nodes.indexOf(currentNode);
    
    if (currentIndex == -1 || currentIndex == nodes.length - 1) {
      return null;
    }
    
    return nodes[currentIndex + 1];
  }

  @override
  FocusNode? findPreviousFocus(FocusNode currentNode, {TraversalDirection? direction}) {
    final nodes = _getOrderedNodes(currentNode);
    final currentIndex = nodes.indexOf(currentNode);
    
    if (currentIndex <= 0) {
      return null;
    }
    
    return nodes[currentIndex - 1];
  }

  List<FocusNode> _getOrderedNodes(FocusNode currentNode) {
    final scopeNode = currentNode.nearestScope;
    if (scopeNode == null) return [];
    
    final allNodes = scopeNode.descendants
        .where((node) => node.canRequestFocus)
        .toList();
    
    // Sort based on fieldOrder if available
    allNodes.sort((a, b) {
      // This is a simplified sorting - in practice you'd want to
      // associate nodes with field names and use fieldOrder
      return 0;
    });
    
    return allNodes;
  }
}

/// Utility class for common keyboard navigation patterns
class KeyboardNavigationUtils {
  /// Create a text field with proper keyboard navigation
  static Widget createNavigableTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
    int? maxLines = 1,
    int? maxLength,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onEditingComplete: onEditingComplete,
      onChanged: onChanged,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      ),
      // Add semantic properties for accessibility
      onTap: () {
        if (focusNode.canRequestFocus) {
          focusNode.requestFocus();
        }
      },
    );
  }

  /// Create a switch with keyboard navigation
  static Widget createNavigableSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
    required String label,
    FocusNode? focusNode,
    String? semanticLabel,
  }) {
    return Focus(
      focusNode: focusNode,
      child: Semantics(
        label: semanticLabel ?? label,
        child: SwitchListTile(
          title: Text(label),
          value: value,
          onChanged: onChanged,
          focusNode: focusNode,
        ),
      ),
    );
  }
}
