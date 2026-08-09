import 'dart:math';

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/auto.dart';

class RastojanjeOndsojanje extends StatelessWidget {
  const RastojanjeOndsojanje({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      // padding: EdgeInsets.all(16),
      child: ClipRRect(
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.grey.shade800)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),
                  SizedBox(height: 40, child: AnimatedAutoWidget(color: Colors.blue)),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: SizedBox(height: 90, child: VerticalDistanceLine(text: "Растојање")),
                  ),
                  Row(
                    children: [
                      SizedBox(height: 40, child: AnimatedAutoWidget(color: Colors.red)),
                      SizedBox(width: 150, height: 20, child: HorizontalDistanceLine(text: 'Одстојање')),
                      SizedBox(height: 40, child: AnimatedAutoWidget(color: Colors.yellow)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Виджет горизонтальной линии
class HorizontalDistanceLine extends StatelessWidget {
  final String text;

  const HorizontalDistanceLine({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 50),
      painter: _HorizontalDistancePainter(text: text),
    );
  }
}

/// Виджет вертикальной линии
class VerticalDistanceLine extends StatelessWidget {
  final String text;

  const VerticalDistanceLine({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(50, double.infinity),
      painter: _VerticalDistancePainter(text: text),
    );
  }
}

// ================= PAINTERS ================= //

class _HorizontalDistancePainter extends CustomPainter {
  final String text;

  _HorizontalDistancePainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final double y = size.height / 2;
    const double arrowSize = 10.0;

    // Основная линия
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    // Левая стрелка
    canvas.drawLine(Offset(0, y), Offset(arrowSize, y - arrowSize / 2), paint);
    canvas.drawLine(Offset(0, y), Offset(arrowSize, y + arrowSize / 2), paint);

    // Правая стрелка
    canvas.drawLine(Offset(size.width, y), Offset(size.width - arrowSize, y - arrowSize / 2), paint);
    canvas.drawLine(Offset(size.width, y), Offset(size.width - arrowSize, y + arrowSize / 2), paint);

    // Отрисовка текста
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Центрируем текст над линией
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, y - textPainter.height - 4));
  }

  @override
  bool shouldRepaint(covariant _HorizontalDistancePainter oldDelegate) {
    return oldDelegate.text != text;
  }
}

class _VerticalDistancePainter extends CustomPainter {
  final String text;

  _VerticalDistancePainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final double x = size.width / 2;
    const double arrowSize = 10.0;

    // Основная линия
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

    // Верхняя стрелка
    canvas.drawLine(Offset(x, 0), Offset(x - arrowSize / 2, arrowSize), paint);
    canvas.drawLine(Offset(x, 0), Offset(x + arrowSize / 2, arrowSize), paint);

    // Нижняя стрелка
    canvas.drawLine(Offset(x, size.height), Offset(x - arrowSize / 2, size.height - arrowSize), paint);
    canvas.drawLine(Offset(x, size.height), Offset(x + arrowSize / 2, size.height - arrowSize), paint);

    // Отрисовка текста
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Поворачиваем текст на 90 градусов (вертикально вдоль линии)
    canvas.save();
    canvas.translate(x + 8, size.height / 2 + textPainter.width / 2);
    canvas.rotate(-pi / 2); // Поворот на -90 градусов
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VerticalDistancePainter oldDelegate) {
    return oldDelegate.text != text;
  }
}
