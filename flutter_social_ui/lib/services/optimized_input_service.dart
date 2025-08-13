import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service to optimize text input and prevent keyboard timeout issues
class OptimizedInputService {
  static final OptimizedInputService _instance = OptimizedInputService._internal();
  factory OptimizedInputService() => _instance;
  OptimizedInputService._internal();

  final Map<String, Timer> _debounceTimers = {};
  final Map<String, StreamController<String>> _inputStreams = {};

  /// Create a debounced text input controller
  TextEditingController createDebouncedController({
    String? initialText,
    Duration debounceDelay = const Duration(milliseconds: 300),
  }) {
    final controller = TextEditingController(text: initialText);
    final controllerId = controller.hashCode.toString();
    
    // Create stream for this controller
    _inputStreams[controllerId] = StreamController<String>.broadcast();
    
    // Listen to changes and debounce them
    controller.addListener(() {
      _debounceInput(controllerId, controller.text, debounceDelay);
    });
    
    return controller;
  }

  /// Get the debounced input stream for a controller
  Stream<String>? getDebouncedStream(TextEditingController controller) {
    final controllerId = controller.hashCode.toString();
    return _inputStreams[controllerId]?.stream;
  }

  /// Debounce input to prevent excessive processing
  void _debounceInput(String controllerId, String text, Duration delay) {
    // Cancel existing timer
    _debounceTimers[controllerId]?.cancel();
    
    // Create new timer
    _debounceTimers[controllerId] = Timer(delay, () {
      final stream = _inputStreams[controllerId];
      if (stream != null && !stream.isClosed) {
        stream.add(text);
      }
    });
  }

  /// Dispose a controller and clean up resources
  void disposeController(TextEditingController controller) {
    final controllerId = controller.hashCode.toString();
    
    _debounceTimers[controllerId]?.cancel();
    _debounceTimers.remove(controllerId);
    
    _inputStreams[controllerId]?.close();
    _inputStreams.remove(controllerId);
  }

  /// Create an optimized text field that prevents blocking
  Widget createOptimizedTextField({
    required TextEditingController controller,
    String? hintText,
    int? maxLines = 1,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    Function(String)? onSubmitted,
    InputDecoration? decoration,
    bool enabled = true,
  }) {
    return OptimizedTextField(
      controller: controller,
      hintText: hintText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: decoration,
      enabled: enabled,
    );
  }

  /// Dispose all resources
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    
    for (final stream in _inputStreams.values) {
      stream.close();
    }
    _inputStreams.clear();
  }
}

/// Optimized text field widget that prevents main thread blocking
class OptimizedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final int? maxLines;
  final TextInputType? keyboardType;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final InputDecoration? decoration;
  final bool enabled;

  const OptimizedTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.decoration,
    this.enabled = true,
  });

  @override
  State<OptimizedTextField> createState() => _OptimizedTextFieldState();
}

class _OptimizedTextFieldState extends State<OptimizedTextField> {
  late FocusNode _focusNode;
  bool _isComposing = false;
  Timer? _inputTimer;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    
    // Listen to focus changes
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _inputTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Cancel any pending operations when focus is lost
      _inputTimer?.cancel();
      setState(() {
        _isComposing = false;
      });
    }
  }

  void _handleTextChange(String text) {
    // Cancel previous timer
    _inputTimer?.cancel();
    
    // Set composing state
    setState(() {
      _isComposing = true;
    });
    
    // Debounce the callback
    _inputTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isComposing = false;
        });
        widget.onChanged?.call(text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      onChanged: _handleTextChange,
      onSubmitted: widget.onSubmitted,
      // Optimize text input configuration
      textInputAction: widget.maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      // Reduce input lag
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      decoration: (widget.decoration ?? InputDecoration(
        hintText: widget.hintText,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      )).copyWith(
        // Add composing indicator if needed
        suffixIcon: _isComposing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              )
            : widget.decoration?.suffixIcon,
      ),
    );
  }
}

/// Mixin for widgets that handle text input efficiently
mixin OptimizedTextInputMixin<T extends StatefulWidget> on State<T> {
  final OptimizedInputService _inputService = OptimizedInputService();
  final List<TextEditingController> _controllers = [];

  /// Create a debounced controller
  TextEditingController createDebouncedController({
    String? initialText,
    Duration debounceDelay = const Duration(milliseconds: 300),
  }) {
    final controller = _inputService.createDebouncedController(
      initialText: initialText,
      debounceDelay: debounceDelay,
    );
    _controllers.add(controller);
    return controller;
  }

  /// Get debounced stream for a controller
  Stream<String>? getDebouncedStream(TextEditingController controller) {
    return _inputService.getDebouncedStream(controller);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      _inputService.disposeController(controller);
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }
}

/// Optimized search field with async suggestions
class OptimizedSearchField extends StatefulWidget {
  final String? hintText;
  final Function(String)? onSearch;
  final Future<List<String>> Function(String)? getSuggestions;
  final Function(String)? onSuggestionSelected;
  final Duration debounceDelay;

  const OptimizedSearchField({
    super.key,
    this.hintText,
    this.onSearch,
    this.getSuggestions,
    this.onSuggestionSelected,
    this.debounceDelay = const Duration(milliseconds: 500),
  });

  @override
  State<OptimizedSearchField> createState() => _OptimizedSearchFieldState();
}

class _OptimizedSearchFieldState extends State<OptimizedSearchField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  List<String> _suggestions = [];
  bool _isLoading = false;
  Timer? _searchTimer;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    
    // Cancel previous search
    _searchTimer?.cancel();
    
    if (text.isEmpty) {
      setState(() {
        _suggestions.clear();
        _isLoading = false;
      });
      return;
    }
    
    // Show loading state
    setState(() {
      _isLoading = true;
    });
    
    // Debounce the search
    _searchTimer = Timer(widget.debounceDelay, () async {
      if (mounted) {
        await _performSearch(text);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      if (widget.getSuggestions != null) {
        final suggestions = await widget.getSuggestions!(query);
        if (mounted) {
          setState(() {
            _suggestions = suggestions;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
      
      widget.onSearch?.call(query);
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions.clear();
          _isLoading = false;
        });
      }
      debugPrint('Search error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OptimizedTextField(
          controller: _controller,
          hintText: widget.hintText ?? 'Search...',
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'Search...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _focusNode.unfocus();
                        },
                      )
                    : null,
            border: const OutlineInputBorder(),
          ),
        ),
        
        // Suggestions dropdown
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Card(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(suggestion),
                    onTap: () {
                      _controller.text = suggestion;
                      _focusNode.unfocus();
                      setState(() {
                        _suggestions.clear();
                      });
                      widget.onSuggestionSelected?.call(suggestion);
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
