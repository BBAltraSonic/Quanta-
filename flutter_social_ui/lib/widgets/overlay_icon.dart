import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OverlayIcon extends StatelessWidget {
  final String assetPath;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const OverlayIcon({
    super.key,
    required this.assetPath,
    this.size = 40,
    this.iconSize = 20,
    this.backgroundColor = const Color(0x59000000), // black 35% opacity
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Center(
        child: SvgPicture.asset(
          assetPath,
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: child,
      );
    }
    return child;
  }
}
