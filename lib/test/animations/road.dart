import 'package:flutter/material.dart';

class RoadView extends StatefulWidget {
  final bool moving;

  const RoadView({super.key, this.moving = false});

  @override
  State<RoadView> createState() => _RoadViewState();
}

class _RoadViewState extends State<RoadView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          painter: RoadPainter(
            offset: widget.moving ? _controller.value : 0,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class RoadPainter extends CustomPainter {
  final double offset;

  RoadPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final roadWidth = size.height;
    final centerY = size.height / 2;
    final roadTop = centerY - roadWidth / 2;
    final roadBottom = centerY + roadWidth / 2;

    final roadPaint = Paint()..color = Colors.grey.shade800;
    final lanePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8;

    // Нарисовать дорогу
    final roadRect = Rect.fromLTRB(0, roadTop, size.width, roadBottom);
    canvas.drawRect(roadRect, roadPaint);

    // Нарисовать пунктирную линию
    const dashWidth = 20.0;
    const dashGap = 20.0;
    final dxOffset = (offset * (dashWidth + dashGap) * 4) % (dashWidth + dashGap);

    for (double x = -dxOffset; x < size.width; x += dashWidth + dashGap) {
      final start = Offset(x, centerY);
      final end = Offset(x + dashWidth, centerY);
      canvas.drawLine(start, end, lanePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RoadPainter oldDelegate) =>
      oldDelegate.offset != offset;
}
