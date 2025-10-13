import 'package:flutter/material.dart';
import 'dart:math' as math;

class EmergencyTriangle extends StatelessWidget {
  final double size;
  final double rotationDegrees;

  const EmergencyTriangle({
    super.key,
    this.size = 20,
    this.rotationDegrees = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)   // перспектива
        ..rotateX(0.7)             // наклон по X — ближе к "лежит на дороге"
        ..rotateZ(rotationDegrees),
      child: CustomPaint(
        size: Size(size, size),
        painter: _EmergencyTrianglePainter(),
      ),
    );
  }
}

class _EmergencyTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidthOuter = size.width * 0.2;
    final strokeWidthInner = strokeWidthOuter * 0.2;

    final outerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidthOuter
      ..strokeJoin = StrokeJoin.round;

    final innerPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidthInner
      ..strokeJoin = StrokeJoin.round;

    final trianglePath = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(trianglePath, outerPaint);
    canvas.drawPath(trianglePath, innerPaint);

    // Штатив (ножки)
    final legPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = strokeWidthOuter * 0.5
      ..strokeCap = StrokeCap.round;

    final legLength = size.width * 0.15;
    final bottomY = size.height + strokeWidthOuter * 0.2;

    canvas.drawLine(
      Offset(size.width * 0.3, size.height),
      Offset(size.width * 0.3 - legLength, bottomY),
      legPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, size.height),
      Offset(size.width * 0.7 + legLength, bottomY),
      legPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
