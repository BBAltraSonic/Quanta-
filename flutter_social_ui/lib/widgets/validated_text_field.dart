import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../services/validation_service.dart';

/// Enhanced text field with real-time validation support
class ValidatedTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? initialValue;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final void Function(String)? onFieldSubmitted;
  final IconData? prefixIcon;
  final IconData? icon; // Alias for prefixIcon for backward compatibility
  final Widget? suffixIcon;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final FocusNode? focusNode;
  final bool autofocus;
  
  // Validation properties
  final Future<ValidationResult> Function(String)? asyncValidator;
  final ValidationResult Function(String)? syncValidator;
  final Duration validationDelay;
  final bool showValidationIcon;
  final bool showCharacterCount;

  const ValidatedTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.initialValue,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.icon,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.focusNode,
    this.autofocus = false,
    this.asyncValidator,
    this.syncValidator,
    this.validationDelay = const Duration(milliseconds: 800),
    this.showValidationIcon = true,
    this.showCharacterCount = false,
  });

  @override
  State<ValidatedTextField> createState() => _ValidatedTextFieldState();
}

class _ValidatedTextFieldState extends State<ValidatedTextField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  
  bool _isFocused = false;
  ValidationResult? _validationResult;
  bool _isValidating = false;
  Timer? _validationTimer;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
    
    // Initial validation if text is not empty
    if (_controller.text.isNotEmpty) {
      _validateText(_controller.text);
    }
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChange);
    }
    
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    
    // Validate when focus is lost
    if (!_isFocused && _controller.text.isNotEmpty) {
      _validateText(_controller.text);
    }
  }

  void _onTextChange() {
    final text = _controller.text;
    widget.onChanged?.call(text);
    
    // Cancel previous validation timer
    _validationTimer?.cancel();
    
    // Clear validation result if text is empty
    if (text.isEmpty) {
      setState(() {
        _validationResult = null;
        _isValidating = false;
      });
      return;
    }
    
    // Start new validation timer
    _validationTimer = Timer(widget.validationDelay, () {
      _validateText(text);
    });
  }

  void _validateText(String text) async {
    if (widget.syncValidator == null && widget.asyncValidator == null) {
      return;
    }

    setState(() {
      _isValidating = true;
    });

    ValidationResult? result;
    
    // Run sync validation first
    if (widget.syncValidator != null) {
      result = widget.syncValidator!(text);
      
      // If sync validation fails, don't run async validation
      if (!result.isValid) {
        setState(() {
          _validationResult = result;
          _isValidating = false;
        });
        return;
      }
    }

    // Run async validation
    if (widget.asyncValidator != null) {
      try {
        result = await widget.asyncValidator!(text);
      } catch (e) {
        result = const ValidationResult(
          isValid: false,
          errorMessage: 'Validation error occurred',
        );
      }
    }

    if (mounted) {
      setState(() {
        _validationResult = result;
        _isValidating = false;
      });
    }
  }

  Widget? _buildSuffixIcon() {
    Widget? validationIcon;
    
    if (widget.showValidationIcon && _controller.text.isNotEmpty) {
      if (_isValidating) {
        validationIcon = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: kPrimaryColor,
          ),
        );
      } else if (_validationResult != null) {
        switch (_validationResult!.severity) {
          case ValidationSeverity.error:
            validationIcon = Icon(
              _validationResult!.isValid ? Icons.check_circle : Icons.error,
              color: _validationResult!.isValid ? Colors.green : Colors.red,
              size: 20,
            );
            break;
          case ValidationSeverity.warning:
            validationIcon = const Icon(
              Icons.warning,
              color: Colors.orange,
              size: 20,
            );
            break;
          case ValidationSeverity.info:
            validationIcon = const Icon(
              Icons.info,
              color: kPrimaryColor,
              size: 20,
            );
            break;
        }
      }
    }
    
    // Combine with existing suffix icon if present
    if (widget.suffixIcon != null && validationIcon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          validationIcon,
          const SizedBox(width: 8),
          widget.suffixIcon!,
        ],
      );
    }
    
    return validationIcon ?? widget.suffixIcon;
  }

  Color _getBorderColor() {
    if (_validationResult != null && !_validationResult!.isValid) {
      return Colors.red;
    }
    
    if (_isFocused) {
      return kPrimaryColor;
    }
    
    return kLightTextColor.withOpacity(0.1);
  }

  String? _getErrorText() {
    if (_validationResult != null && !_validationResult!.isValid) {
      return _validationResult!.errorMessage;
    }
    
    if (_validationResult != null && 
        _validationResult!.severity == ValidationSeverity.warning && 
        _validationResult!.errorMessage != null) {
      return _validationResult!.errorMessage;
    }
    
    return null;
  }

  Color _getErrorTextColor() {
    if (_validationResult?.severity == ValidationSeverity.warning) {
      return Colors.orange;
    }
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[ 
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label!,
                style: const TextStyle(
                  color: kTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.showCharacterCount && widget.maxLength != null)
                Text(
                  '${_controller.text.length}/${widget.maxLength}',
                  style: TextStyle(
                    color: _controller.text.length > (widget.maxLength! * 0.9)
                        ? (_controller.text.length >= widget.maxLength! 
                            ? Colors.red 
                            : Colors.orange)
                        : kLightTextColor,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          onTap: widget.onTap,
          onFieldSubmitted: widget.onFieldSubmitted,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          autofocus: widget.autofocus,
          style: const TextStyle(
            color: kTextColor,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: kLightTextColor.withOpacity(0.6),
              fontSize: 16,
            ),
            errorText: _getErrorText(),
            errorStyle: TextStyle(
              color: _getErrorTextColor(),
              fontSize: 12,
            ),
            prefixIcon: (widget.prefixIcon ?? widget.icon) != null
                ? Icon(
                    widget.prefixIcon ?? widget.icon,
                    color: _isFocused ? kPrimaryColor : kLightTextColor,
                    size: 20,
                  )
                : null,
            suffixIcon: _buildSuffixIcon(),
            filled: true,
            fillColor: kCardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kDefaultBorderRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kDefaultBorderRadius),
              borderSide: BorderSide(
                color: _getBorderColor(),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kDefaultBorderRadius),
              borderSide: BorderSide(
                color: _getBorderColor(),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kDefaultBorderRadius),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kDefaultBorderRadius),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kDefaultBorderRadius),
              borderSide: BorderSide(
                color: kLightTextColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            counterStyle: TextStyle(
              color: kLightTextColor.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
