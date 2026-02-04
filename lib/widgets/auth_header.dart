import 'package:flutter/material.dart';
import 'orientation_logo.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        children: [
          // Background with geometric shapes
          const GeometricBackground(),
          // Logo centered
          const Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: Center(
              child: OrientationLogo(),
            ),
          ),
        ],
      ),
    );
  }
}

class GeometricBackground extends StatelessWidget {
  const GeometricBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GeometricPainter(),
      size: Size.infinite,
    );
  }
}

class _GeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 390;
    final scaleY = size.height / 220;

    void drawRect({
      required double left,
      required double top,
      required double w,
      required double h,
      required double rotation,
      required Color color,
    }) {
      final paint = Paint()..color = color;

      canvas.save();
      canvas.translate(left * scaleX, top * scaleY);
      canvas.rotate(rotation * 3.1415926535 / 180);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w * scaleX, h * scaleY),
        paint,
      );
      canvas.restore();
    }


    // 🔶 Rectangle 34 (right shape)
    drawRect(
      left: 100,      // move right more
      top: -35,       // move up
      w: 220,         // bigger
      h: 95,
      rotation: -44.7,
      color: const Color(0xFF170001),
    );

    // 🔶 Rectangle 32 (left shape)
    drawRect(
      left: -170,      // more left
      top: 10,        // slight down
      w: 210,         // slightly bigger
      h: 180,
      rotation: -44.7,
      color: const Color(0xFF170001),
    );
    // 🔶 Rectangle 33 (center big shape)
    drawRect(
      left: 0,       // move slightly right
      top: 0,       // move up
      w: 110,         // bigger
      h: 150,
      rotation: -44.7,
      color: const Color(0xFF260002),
    );



    // Fade bottom
    final overlay = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.35),
          Colors.black,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlay);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

