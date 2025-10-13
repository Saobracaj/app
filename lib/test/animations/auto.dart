import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedAutoWidget extends StatefulWidget {
  final Color color;
  final bool leftIndicatorOn;

  final bool rightIndicatorOn;

  const AnimatedAutoWidget({Key? key, required this.color, this.leftIndicatorOn = false, this.rightIndicatorOn = false}) : super(key: key);

  @override
  State<AnimatedAutoWidget> createState() => _AnimatedAutoWidgetState();
}

class _AnimatedAutoWidgetState extends State<AnimatedAutoWidget> {
  bool leftIndicatorOn = false;
  bool rightIndicatorOn = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    leftIndicatorOn = widget.leftIndicatorOn;
    rightIndicatorOn = rightIndicatorOn;

    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        if (widget.leftIndicatorOn && widget.rightIndicatorOn) {
          leftIndicatorOn = !leftIndicatorOn;
          rightIndicatorOn = leftIndicatorOn;
        } else {
          if (widget.leftIndicatorOn) leftIndicatorOn = !leftIndicatorOn;
          if (widget.rightIndicatorOn) rightIndicatorOn = !rightIndicatorOn;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 300,
        height: 100,
        child: CustomPaint(painter: _AutoPainter(color: widget.color, leftIndicatorOn: leftIndicatorOn, rightIndicatorOn: rightIndicatorOn)),
      ),
    );
  }
}

class _AutoPainter extends CustomPainter {
  final Color color;
  final bool leftIndicatorOn;
  final bool rightIndicatorOn;

  _AutoPainter({required this.color, required this.leftIndicatorOn, required this.rightIndicatorOn});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final carLength = size.height * 0.8;
    final carWidth = size.width * 0.6;
    final carTop = size.height * 0.1;
    final carLeft = centerX - carWidth / 2;
    final carHeight = size.height * 0.8;

    // Draw a square with rounded corners, and round the top and right sides as well
    final squareRect = Rect.fromLTWH(carLeft, carTop, carWidth, carHeight);
    final squareRRect = RRect.fromRectAndCorners(
      squareRect,
      topLeft: Radius.circular(18),
      topRight: Radius.circular(32), // more rounded
      bottomRight: Radius.circular(32), // more rounded
      bottomLeft: Radius.circular(18),
    );
    final squarePaint = Paint()..color = color;
    canvas.drawRRect(squareRRect, squarePaint);

    // right mirror
    final mirrorStartX = carWidth + carLeft - (carWidth + carLeft - centerX) / 2;
    final mirrorStartY = carHeight + carTop;
    final mirrorWidth = 10;
    final mirrorHeight = 7;

    final mirrorPathLeft =
        Path()
          ..moveTo(mirrorStartX, mirrorStartY) // left base
          ..lineTo(mirrorStartX - mirrorWidth, mirrorStartY) // top
          ..lineTo(mirrorStartX - mirrorWidth, mirrorStartY + mirrorHeight) // right base
          ..close();

    final mirrorPaint = Paint()..color = color;
    canvas.drawPath(mirrorPathLeft, mirrorPaint);

    // left mirror
    final mirrorStartYLeft = carTop;
    final mirrorPathRight =
        Path()
          ..moveTo(mirrorStartX, mirrorStartYLeft)
          ..lineTo(mirrorStartX - mirrorWidth, mirrorStartYLeft)
          ..lineTo(mirrorStartX - mirrorWidth, mirrorStartYLeft - mirrorHeight)
          ..close();
    canvas.drawPath(mirrorPathRight, mirrorPaint);

    // Draw headlight (right side)
    // Draw a curved "splotch" headlight at the center

    final headlightHeight = 15;
    final headlightWidth = 10;
    final headlightStartX = carLeft + carWidth - 14;
    final headlightStartY = carTop + 16;

    final headlightPath =
        Path()
          ..moveTo(headlightStartX, headlightStartY)
          ..cubicTo(
            headlightStartX + headlightWidth * 0.5,
            headlightStartY - headlightHeight * 0.7, // верхняя левая изогнутая точка
            headlightStartX + headlightWidth,
            headlightStartY + headlightHeight * 0.2, // правая верхняя
            headlightStartX + headlightWidth * 0.8,
            headlightStartY + headlightHeight, // низ правее центра
          )
          ..quadraticBezierTo(
            headlightStartX + headlightWidth * 0.2,
            headlightStartY + headlightHeight * 1.1, // низ левее центра
            headlightStartX,
            headlightStartY, // замыкаем к исходной
          )
          ..close();

    final headlightPaint =
        Paint()
          ..color = Colors.yellowAccent.withOpacity(0.8)
          ..style = PaintingStyle.fill;

    canvas.drawPath(headlightPath, headlightPaint);

    // Draw a vertically flipped headlight (left side)
    final headlightStartXFlipped = carLeft + carWidth - headlightWidth - 4;
    final headlightStartYFlipped = carTop + carHeight - 16;

    final headlightPathFlipped =
        Path()
          ..moveTo(headlightStartXFlipped, headlightStartYFlipped)
          ..cubicTo(
            headlightStartXFlipped + headlightWidth * 0.5,
            headlightStartYFlipped + headlightHeight * 0.7, // нижняя левая изогнутая точка
            headlightStartXFlipped + headlightWidth,
            headlightStartYFlipped - headlightHeight * 0.2, // правая нижняя
            headlightStartXFlipped + headlightWidth * 0.8,
            headlightStartYFlipped - headlightHeight, // верх правее центра
          )
          ..quadraticBezierTo(
            headlightStartXFlipped + headlightWidth * 0.2,
            headlightStartYFlipped - headlightHeight * 1.1, // верх левее центра
            headlightStartXFlipped,
            headlightStartYFlipped, // замыкаем к исходной
          )
          ..close();

    canvas.drawPath(headlightPathFlipped, headlightPaint);

    final circlePaint =
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;

    final circleInactivePaint =
        Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.fill;

    final circleStrokePaint =
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

    if (leftIndicatorOn) {
      canvas.drawOval(Rect.fromCenter(center: Offset(carLeft + carWidth - 20, carTop + 5), width: 15, height: 8), circlePaint);
    }
    // canvas.drawOval(Rect.fromCenter(center: Offset(carLeft + carWidth - 20, carTop + 5), width: 15, height: 8), circleStrokePaint);
    if (rightIndicatorOn) {
      canvas.drawOval(Rect.fromCenter(center: Offset(carLeft + carWidth - 20, carTop + carHeight - 5), width: 15, height: 8), circlePaint);
    }
    // canvas.drawOval(Rect.fromCenter(center: Offset(carLeft + carWidth - 20, carTop + carHeight - 5), width: 15, height: 8), circleStrokePaint);

    // Draw windshield (top perspective, car moving left to right)
    final windshieldWidth = carWidth / 4;
    final windshieldHeight = carHeight - 20;
    final windshieldLeft = carLeft + carWidth - carWidth / 4;
    final windshieldTop = carTop + 10;

    final windshieldPath =
        Path()
          ..moveTo(windshieldLeft, windshieldTop)
          ..quadraticBezierTo(windshieldLeft + 10, windshieldTop + windshieldHeight / 2, windshieldLeft, windshieldTop + windshieldHeight)
          ..lineTo(windshieldLeft - windshieldWidth, windshieldTop + windshieldHeight - 5)
          ..quadraticBezierTo(
            windshieldLeft - windshieldWidth + 3,
            windshieldTop + (windshieldHeight - 10) / 2,
            windshieldLeft - windshieldWidth,
            windshieldTop + 5,
          )
          ..close();

    final windshieldPaint =
        Paint()
          ..color = Colors.black.withAlpha(100)
          ..style = PaintingStyle.fill;

    canvas.drawPath(windshieldPath, windshieldPaint);

    // Draw black hield
    final backWidth = carWidth / 6;
    final backHeight = carHeight - 20;
    final backLeft = carLeft + carWidth / 4;
    final backTop = carTop + 10;

    final persp = 5;

    final backPath =
        Path()
          ..moveTo(backLeft, backTop + persp)
          ..quadraticBezierTo(backLeft - 3, backTop + backHeight / 2, backLeft, backTop + backHeight - persp)
          ..lineTo(backLeft - backWidth, backTop + backHeight)
          ..quadraticBezierTo(backLeft - backWidth - 4, backTop + (backHeight - 2 * persp) / 2, backLeft - backWidth, backTop)
          ..close();

    canvas.drawPath(backPath, windshieldPaint);

    final sideTop = carTop + 5;
    final sideLeft = carLeft + carWidth * 0.09;

    final sideHeight = carHeight;
    final sideWidth = carWidth * 0.64;

    final sidePath =
        Path()
          ..moveTo(sideLeft, sideTop)
          ..quadraticBezierTo(sideLeft + (sideWidth / 2), sideTop + 15, sideLeft + sideWidth, sideTop)
          ..quadraticBezierTo(sideLeft + (sideWidth / 2), sideTop - 5, sideLeft, sideTop)
          ..close();
    final ppp =
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
    canvas.drawPath(sidePath, windshieldPaint);

    final side2Top = carTop + carHeight - 5;
    final side2Left = carLeft + carWidth * 0.09;

    final side2Height = carHeight;
    final side2Width = carWidth * 0.64;

    final side2Path =
        Path()
          ..moveTo(side2Left, side2Top)
          ..quadraticBezierTo(side2Left + (side2Width / 2), side2Top - 15, side2Left + side2Width, side2Top)
          ..quadraticBezierTo(side2Left + (side2Width / 2), side2Top + 5, side2Left, side2Top)
          ..close();

    canvas.drawPath(side2Path, windshieldPaint);

    // Draw a circle in the center
    final circleRadius = 6.0;

    // canvas.drawCircle(Offset(carLeft + 3, carTop + 14), circleRadius, circlePaint);
    // canvas.drawCircle(Offset(carLeft + 3, carTop + 14), circleRadius, circleStrokePaint);
    // canvas.drawCircle(Offset(carLeft + 3, carTop + carHeight  - 14), circleRadius, circlePaint);
    // canvas.drawCircle(Offset(carLeft + 3, carTop + carHeight  - 14), circleRadius, circleStrokePaint);

    final rect = Rect.fromCenter(center: Offset(carLeft + 3, carTop + 14), width: circleRadius, height: circleRadius * 2);
    final rect2 = Rect.fromCenter(center: Offset(carLeft + 3, carTop + carHeight - 14), width: circleRadius, height: circleRadius * 2);
    canvas.drawOval(rect, leftIndicatorOn ? circlePaint : circleInactivePaint);
    canvas.drawOval(rect, circleStrokePaint);
    canvas.drawOval(rect2, rightIndicatorOn ? circlePaint : circleInactivePaint);
    canvas.drawOval(rect2, circleStrokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
