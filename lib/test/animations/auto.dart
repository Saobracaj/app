import 'dart:async';

import 'package:flutter/material.dart';

const _indicatorWidth = 20.0;
const _indicatorHeight = 10.0;

// Вся геометрия машинки исторически описана в холсте 190×100, где кузов
// занимает прямоугольник (9.5, 10, 171×80). paintAutoTopView отображает этот
// кузов в произвольный [Rect], поэтому литеральные размеры ниже так и живут
// в «родной» системе координат.
const _kCanvasWidth = 190.0;
const _kCanvasHeight = 100.0;
const _kBodyLeft = _kCanvasWidth * 0.05;
const _kBodyTop = _kCanvasHeight * 0.1;
const _kBodyWidth = _kCanvasWidth * 0.9;
const _kBodyHeight = _kCanvasHeight * 0.8;

/// Легковая машинка вид сверху — та самая, что едет в анимациях
/// «Мимоилажење» и «Претицање». Кузов вписывается в [rect] (ширина —
/// длина машины, высота — её ширина); зеркала и лампы чуть выступают
/// за прямоугольник, как у настоящей машины — габарит.
///
/// Нос смотрит вправо; [facingLeft] зеркалит машину целиком, поэтому
/// [leftIndicatorOn]/[rightIndicatorOn] — это стороны **самой машины**
/// (при носе вправо левый борт — верх схемы, при [facingLeft] — низ).
/// Фазу мигания задаёт вызывающий: функция рисует лампы «горящими»,
/// гасить их в такт сцены — забота вызывающего кода.
/// [brakeOn] зажигает оба задних фонаря — для сцен, где важно показать
/// торможение.
void paintAutoTopView(
  Canvas canvas,
  Rect rect, {
  required Color color,
  bool facingLeft = false,
  bool leftIndicatorOn = false,
  bool rightIndicatorOn = false,
  bool brakeOn = false,
}) {
  canvas.save();
  // Вписываем «родной» прямоугольник кузова в rect; зеркалим уже внутри
  // родной системы, чтобы стороны машины не зависели от направления.
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / _kBodyWidth, rect.height / _kBodyHeight);
  canvas.translate(-_kBodyLeft, -_kBodyTop);
  if (facingLeft) {
    canvas.translate(_kCanvasWidth / 2, 0);
    canvas.scale(-1, 1);
    canvas.translate(-_kCanvasWidth / 2, 0);
  }
  _paintAuto(
    canvas,
    color: color,
    leftIndicatorOn: leftIndicatorOn,
    rightIndicatorOn: rightIndicatorOn,
    brakeOn: brakeOn,
  );
  canvas.restore();
}

/// Отрисовка машины в родном холсте 190×100, носом вправо.
void _paintAuto(
  Canvas canvas, {
  required Color color,
  required bool leftIndicatorOn,
  required bool rightIndicatorOn,
  bool brakeOn = false,
}) {
  const centerX = _kCanvasWidth / 2;
  const carWidth = _kBodyWidth;
  const carTop = _kBodyTop;
  const carLeft = _kBodyLeft;
  const carHeight = _kBodyHeight;

  // Draw a square with rounded corners, and round the top and right sides as well
  final squareRect = const Rect.fromLTWH(carLeft, carTop, carWidth, carHeight);
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
  const mirrorWidth = 10;
  const mirrorHeight = 7;

  final mirrorPathLeft =
      Path()
        ..moveTo(mirrorStartX, mirrorStartY) // left base
        ..lineTo(mirrorStartX - mirrorWidth, mirrorStartY) // top
        ..lineTo(mirrorStartX - mirrorWidth, mirrorStartY + mirrorHeight) // right base
        ..close();

  final mirrorPaint = Paint()..color = color;
  canvas.drawPath(mirrorPathLeft, mirrorPaint);

  // left mirror
  const mirrorStartYLeft = carTop;
  final mirrorPathRight =
      Path()
        ..moveTo(mirrorStartX, mirrorStartYLeft)
        ..lineTo(mirrorStartX - mirrorWidth, mirrorStartYLeft)
        ..lineTo(mirrorStartX - mirrorWidth, mirrorStartYLeft - mirrorHeight)
        ..close();
  canvas.drawPath(mirrorPathRight, mirrorPaint);

  // Draw headlight (right side)
  // Draw a curved "splotch" headlight at the center

  const headlightHeight = 15;
  const headlightWidth = 10;
  const headlightStartX = carLeft + carWidth - 14;
  const headlightStartY = carTop + 16;

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
        ..color = Colors.yellowAccent.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

  canvas.drawPath(headlightPath, headlightPaint);

  // Draw a vertically flipped headlight (left side)
  const headlightStartXFlipped = carLeft + carWidth - headlightWidth - 4;
  const headlightStartYFlipped = carTop + carHeight - 16;

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
    canvas.drawOval(Rect.fromCenter(center: Offset(carLeft + carWidth - 20, carTop + 5), width: _indicatorWidth, height: _indicatorHeight), circlePaint);
  }
  if (rightIndicatorOn) {
    canvas.drawOval(Rect.fromCenter(center: Offset(carLeft + carWidth - 20, carTop + carHeight - 5), width: _indicatorWidth, height: _indicatorHeight), circlePaint);
  }

  // Draw windshield (top perspective, car moving left to right)
  const windshieldWidth = carWidth / 4;
  const windshieldHeight = carHeight - 20;
  const windshieldLeft = carLeft + carWidth - carWidth / 4;
  const windshieldTop = carTop + 10;

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
  const backWidth = carWidth / 6;
  const backHeight = carHeight - 20;
  const backLeft = carLeft + carWidth / 4;
  const backTop = carTop + 10;

  const persp = 5;

  final backPath =
      Path()
        ..moveTo(backLeft, backTop + persp)
        ..quadraticBezierTo(backLeft - 3, backTop + backHeight / 2, backLeft, backTop + backHeight - persp)
        ..lineTo(backLeft - backWidth, backTop + backHeight)
        ..quadraticBezierTo(backLeft - backWidth - 4, backTop + (backHeight - 2 * persp) / 2, backLeft - backWidth, backTop)
        ..close();

  canvas.drawPath(backPath, windshieldPaint);

  const sideTop = carTop + 5;
  const sideLeft = carLeft + carWidth * 0.09;

  const sideWidth = carWidth * 0.64;

  final sidePath =
      Path()
        ..moveTo(sideLeft, sideTop)
        ..quadraticBezierTo(sideLeft + (sideWidth / 2), sideTop + 15, sideLeft + sideWidth, sideTop)
        ..quadraticBezierTo(sideLeft + (sideWidth / 2), sideTop - 5, sideLeft, sideTop)
        ..close();
  canvas.drawPath(sidePath, windshieldPaint);

  const side2Top = carTop + carHeight - 5;
  const side2Left = carLeft + carWidth * 0.09;

  const side2Width = carWidth * 0.64;

  final side2Path =
      Path()
        ..moveTo(side2Left, side2Top)
        ..quadraticBezierTo(side2Left + (side2Width / 2), side2Top - 15, side2Left + side2Width, side2Top)
        ..quadraticBezierTo(side2Left + (side2Width / 2), side2Top + 5, side2Left, side2Top)
        ..close();

  canvas.drawPath(side2Path, windshieldPaint);

  // Задние фонари: красные, когда горит показатель той стороны или тормоз.
  const circleRadius = 6.0;

  final rect = Rect.fromCenter(center: Offset(carLeft + 3, carTop + 14), width: circleRadius, height: circleRadius * 2);
  final rect2 = Rect.fromCenter(center: Offset(carLeft + 3, carTop + carHeight - 14), width: circleRadius, height: circleRadius * 2);
  canvas.drawOval(rect, leftIndicatorOn || brakeOn ? circlePaint : circleInactivePaint);
  canvas.drawOval(rect, circleStrokePaint);
  canvas.drawOval(rect2, rightIndicatorOn || brakeOn ? circlePaint : circleInactivePaint);
  canvas.drawOval(rect2, circleStrokePaint);
}

class AnimatedAutoWidget extends StatefulWidget {
  final Color color;
  final bool leftIndicatorOn;

  final bool rightIndicatorOn;

  const AnimatedAutoWidget({super.key, required this.color, this.leftIndicatorOn = false, this.rightIndicatorOn = false});

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
        width: 190,
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
    paintAutoTopView(
      canvas,
      Rect.fromLTWH(
        size.width * 0.05,
        size.height * 0.1,
        size.width * 0.9,
        size.height * 0.8,
      ),
      color: color,
      leftIndicatorOn: leftIndicatorOn,
      rightIndicatorOn: rightIndicatorOn,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
