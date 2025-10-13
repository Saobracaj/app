import 'package:flutter/material.dart';
import 'dart:math' as math;

class TrafficConeWidget extends StatelessWidget {
  final double height;

  const TrafficConeWidget({super.key, this.height = 50});

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)  // перспектива
        ..rotateX(0.8),          // наклон "в сторону камеры"
      child: CustomPaint(
        size: Size(height * 0.6, height),
        painter: _TrafficConePainter(),
      ),
    );
  }
}

class _TrafficConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final conePaint = Paint()
      ..style = PaintingStyle.fill;

    final double baseWidth = size.width;
    final double height = size.height;

    // Нарисовать тело конуса
    Path coneBody = Path();
    coneBody.moveTo(baseWidth * 0.5, 0);
    coneBody.lineTo(0, height);
    coneBody.lineTo(baseWidth, height);
    coneBody.close();

    conePaint.color = Colors.orange.shade700;
    canvas.drawPath(coneBody, conePaint);

    // Белые полоски
    final stripePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(baseWidth * 0.25, height * 0.35, baseWidth * 0.5, height * 0.07),
      stripePaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(baseWidth * 0.25, height * 0.6, baseWidth * 0.5, height * 0.07),
      stripePaint,
    );

    // Основание (тень/платформа)
    final basePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    final baseHeight = height * 0.12;
    final baseRect = Rect.fromCenter(
      center: Offset(size.width / 2, height + baseHeight * 0.3),
      width: baseWidth * 1.2,
      height: baseHeight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, Radius.circular(4)),
      basePaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
