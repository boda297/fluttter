import 'package:flutter/material.dart';

class OrientationLogo extends StatelessWidget {
  const OrientationLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const PlayButtonIcon(),
        const Text(
          'rientation',
          style: TextStyle(
            color: Color(0xFFE50914),
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class PlayButtonIcon extends StatelessWidget {
  const PlayButtonIcon({super.key});

  static const Color brandRed = Color(0xFFE50914);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: CustomPaint(
        painter: _PlayButtonPainter(),
      ),
    );
  }
}

class _PlayButtonPainter extends CustomPainter {
  static const Color brandRed = Color(0xFFE50914);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw the circle
    final circlePaint = Paint()
      ..color = brandRed
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, circlePaint);

    // Draw the play triangle
    final trianglePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final trianglePath = Path();
    
    // Calculate triangle points - slightly offset to the right for visual centering
    final triangleWidth = size.width * 0.35;
    final triangleHeight = size.height * 0.45;
    
    final leftX = center.dx - triangleWidth * 0.3;
    final rightX = center.dx + triangleWidth * 0.7;
    
    trianglePath.moveTo(leftX, center.dy - triangleHeight / 2);
    trianglePath.lineTo(rightX, center.dy);
    trianglePath.lineTo(leftX, center.dy + triangleHeight / 2);
    trianglePath.close();

    canvas.drawPath(trianglePath, trianglePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

