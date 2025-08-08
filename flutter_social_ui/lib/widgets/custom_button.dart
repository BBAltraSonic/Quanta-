import 'package:flutter/material.dart';
import '../constants.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? width;
  final double height;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;
    
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isEnabled ? onPressed : null,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kDefaultBorderRadius),
                ),
                side: BorderSide(
                  color: isEnabled 
                      ? (backgroundColor ?? kPrimaryColor)
                      : kLightTextColor.withOpacity(0.3),
                  width: 2,
                ),
                backgroundColor: Colors.transparent,
              ),
              child: _buildContent(),
            )
          : ElevatedButton(
              onPressed: isEnabled ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor ?? kPrimaryColor,
                disabledBackgroundColor: kLightTextColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kDefaultBorderRadius),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOutlined
                    ? (backgroundColor ?? kPrimaryColor)
                    : (textColor ?? Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading...',
            style: TextStyle(
              color: isOutlined
                  ? (backgroundColor ?? kPrimaryColor)
                  : (textColor ?? Colors.white),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final List<Widget> children = [];
    
    if (icon != null) {
      children.add(Icon(
        icon,
        color: isOutlined
            ? (backgroundColor ?? kPrimaryColor)
            : (textColor ?? Colors.white),
        size: 20,
      ));
      children.add(const SizedBox(width: 8));
    }
    
    children.add(Text(
      text,
      style: TextStyle(
        color: isOutlined
            ? (backgroundColor ?? kPrimaryColor)
            : (textColor ?? Colors.white),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
