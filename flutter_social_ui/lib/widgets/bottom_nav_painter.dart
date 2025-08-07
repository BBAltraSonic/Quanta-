import 'package:flutter/material.dart';

class BottomNavCurvePainter extends CustomPainter {
  final Color color;

  BottomNavCurvePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = color;
    Path path = Path();

    // Define the dimensions
    final double buttonRadius = 28; // Half of FAB width/height (56/2)
    final double centerX = size.width / 2;
    final double startY = 0; // Top of the bar

    // Start path from top-left
    path.lineTo(0, startY);

    // Left straight part
    path.lineTo(centerX - buttonRadius * 1.5, startY);

    // Left curve towards the center notch
    path.cubicTo(
      centerX - buttonRadius * 1.2,
      startY,
      centerX - buttonRadius * 1.1,
      buttonRadius * 0.9, // Control point for wave effect
      centerX - buttonRadius * 0.5,
      buttonRadius * 0.9, // End of left curve
    );

    // Straight part across the top of the notch
    path.lineTo(centerX + buttonRadius * 0.5, buttonRadius * 0.9);

    // Right curve away from the center notch
    path.cubicTo(
      centerX + buttonRadius * 1.1,
      buttonRadius * 0.9, // Control point for wave effect
      centerX + buttonRadius * 1.2,
      startY,
      centerX + buttonRadius * 1.5,
      startY, // End of right curve
    );

    // Right straight part
    path.lineTo(size.width, startY);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}
