import 'package:flutter/material.dart';
import 'dart:math';

class RoadObstacleWidget extends StatelessWidget {
  final double size;

  const RoadObstacleWidget({super.key, this.size = 50});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RoadObstaclePainter(),
    );
  }
}

class _RoadObstaclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final holePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    final random = Random();

    // Основная "яма"
    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.5, 0, size.width * 0.7, size.height * 0.2);
    path.quadraticBezierTo(size.width, size.height * 0.5, size.width * 0.7, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.5, size.height, size.width * 0.3, size.height * 0.8);
    path.quadraticBezierTo(0, size.height * 0.5, size.width * 0.3, size.height * 0.2);
    canvas.drawPath(path, holePaint);

    // "Камешки" вокруг (имитация гравия/щебня)
    final gravelPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 10; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double radius = 1.5 + random.nextDouble() * 2.5;
      canvas.drawCircle(Offset(x, y), radius, gravelPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
