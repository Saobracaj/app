import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/auto.dart';

/// Какие лампы горят у машины на схеме.
///
/// В виде сверху «левая сторона» машины — это верхний край её прямоугольника,
/// когда машина смотрит носом вправо; при [CarTopView.facingLeft] стороны
/// зеркалятся вместе с кузовом.
enum CarLamps {
  /// Ничего не горит.
  none,

  /// Аварийка: все четыре показателя поворота.
  hazard,

  /// Показатели поворота с той стороны, которая на схеме сверху.
  turnUp,

  /// Показатели поворота с той стороны, которая на схеме снизу.
  turnDown,
}

/// Легковая машина видом сверху, нарисованная в заданный прямоугольник.
///
/// Отдельный примитив, а не `AnimatedAutoWidget`: тот моргает поворотниками
/// по `Timer.periodic`, поэтому на статичной схеме аварийка может попасть в
/// «погасшую» фазу, а в тестовом рендере кадр вообще не поймать. Здесь фазу
/// мигания задаёт вызывающий ([blinkOn]) — от контроллера анимации или
/// константой `true` для статичной иллюстрации.
void paintCarTopView(
  Canvas canvas,
  Rect rect, {
  required Color color,
  bool facingLeft = false,
  CarLamps lamps = CarLamps.none,
  bool blinkOn = true,
}) {
  canvas.save();
  if (facingLeft) {
    // Рисуем всегда носом вправо и зеркалим целиком — так геометрия кузова
    // описана один раз.
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(-1, 1);
    canvas.translate(-rect.center.dx, -rect.center.dy);
  }

  final w = rect.width; // длина машины вдоль дороги
  final h = rect.height; // ширина машины поперёк дороги

  // Кузов — общая машинка из auto.dart (та же, что в «Мимоилажење» и
  // «Претицање»). Канвас уже зеркалирован выше, поэтому носом вправо;
  // лампы поворотников схемы рисуем сами — у них своя логика сторон.
  paintAutoTopView(canvas, rect, color: color);

  if (lamps != CarLamps.none) {
    final up = lamps == CarLamps.hazard || lamps == CarLamps.turnUp;
    final down = lamps == CarLamps.hazard || lamps == CarLamps.turnDown;
    final corners = <Offset>[
      if (up) Offset(rect.left + w * 0.08, rect.top + h * 0.10),
      if (up) Offset(rect.right - w * 0.08, rect.top + h * 0.10),
      if (down) Offset(rect.left + w * 0.08, rect.bottom - h * 0.10),
      if (down) Offset(rect.right - w * 0.08, rect.bottom - h * 0.10),
    ];
    final r = h * 0.13;
    for (final c in corners) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = blinkOn
              ? const Color(0xFFFFA000)
              : const Color(0xFF6D6D6D),
      );
      if (!blinkOn) continue;
      // Лучики вокруг горящей лампы — «моргает», а не просто оранжевая точка.
      final ray = Paint()
        ..color = const Color(0xFFFFA000)
        ..strokeWidth = r * 0.45
        ..strokeCap = StrokeCap.round;
      for (final a in [-0.9, 0.0, 0.9]) {
        final dir = Offset.fromDirection(
          (c.dy < rect.center.dy ? -1.57 : 1.57) + a,
        );
        canvas.drawLine(c + dir * (r * 1.5), c + dir * (r * 2.4), ray);
      }
    }
  }

  canvas.restore();
}

/// Виджет-обёртка над [paintCarTopView] для сцен, собранных из `Positioned`.
class CarTopView extends StatelessWidget {
  final Size size;
  final Color color;
  final bool facingLeft;
  final CarLamps lamps;
  final bool blinkOn;

  const CarTopView({
    super.key,
    required this.size,
    required this.color,
    this.facingLeft = false,
    this.lamps = CarLamps.none,
    this.blinkOn = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _CarPainter(
        color: color,
        facingLeft: facingLeft,
        lamps: lamps,
        blinkOn: blinkOn,
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  final Color color;
  final bool facingLeft;
  final CarLamps lamps;
  final bool blinkOn;

  _CarPainter({
    required this.color,
    required this.facingLeft,
    required this.lamps,
    required this.blinkOn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintCarTopView(
      canvas,
      Offset.zero & size,
      color: color,
      facingLeft: facingLeft,
      lamps: lamps,
      blinkOn: blinkOn,
    );
  }

  @override
  bool shouldRepaint(covariant _CarPainter old) =>
      old.color != color ||
      old.facingLeft != facingLeft ||
      old.lamps != lamps ||
      old.blinkOn != blinkOn;
}
