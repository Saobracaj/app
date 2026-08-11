import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/preticanje_common.dart';

/// С какой стороны обгоняют: по умолчанию слева, справа — в двух случаях,
/// и отдельно случай, который обгоном вообще не считается.
///
/// Схема статичная: три случая надо сравнивать глазами одновременно, анимация
/// тут только мешала бы.
class PreticanjeStrane extends StatelessWidget {
  const PreticanjeStrane({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 400,
        height: 512,
        child: CustomPaint(painter: _StranePainter(scheme)),
      ),
    );
  }
}

const Color _blue = Color(0xFF1E88E5);
const Color _green = Color(0xFF43A047);
const Color _grey = Color(0xFF90A4AE);

class _StranePainter extends CustomPainter {
  _StranePainter(this.scheme);

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    _drawLeftCase(canvas);
    _drawRightCase(canvas);
    _drawNotOvertaking(canvas);
  }

  /// 1. Обычный случай: обгон слева.
  void _drawLeftCase(Canvas canvas) {
    _title(canvas, '1 · претицање — лево', 0);

    const road = Rect.fromLTRB(0, 22, 400, 122);
    const axisY = 72.0;
    const oncomingY = 47.0;
    const ownY = 97.0;
    drawAsphalt(canvas, road);
    drawEdgeLines(canvas, road);
    drawDashedLine(canvas, axisY, 4, 396);

    // Траектория манёвра: выехал, опередил, вернулся.
    final path = Path()
      ..moveTo(95, ownY)
      ..quadraticBezierTo(125, ownY, 145, oncomingY)
      ..lineTo(250, oncomingY);
    drawDashedPath(canvas, path, color: kMarking);
    drawArrow(
      canvas,
      const Offset(255, oncomingY),
      const Offset(300, ownY),
      color: kMarking,
    );

    drawTruck(canvas, const Offset(215, ownY));
    drawCar(
      canvas,
      const Offset(180, oncomingY),
      color: _blue,
      leftBlinker: true,
    );
    drawTagOnRoad(
      canvas,
      'трака за супротни смер',
      at: const Offset(8, 28),
    );

    _note(
      canvas,
      'Возило које се креће претиче се са леве стране — то је правило.',
      128,
    );
  }

  /// 2. Два случая, когда обгоняют справа.
  void _drawRightCase(Canvas canvas) {
    _title(canvas, '2 · претиче се здесна — два случаја', 158);

    const road = Rect.fromLTRB(0, 180, 400, 300);
    const axisY = 240.0;
    const passY = 276.0;
    drawAsphalt(canvas, road);
    drawEdgeLines(canvas, road);
    drawDashedLine(canvas, axisY, 4, 396);

    // Слева: трамвай идёт по рельсам посреди проезжей части.
    drawTram(canvas, const Offset(95, axisY));
    drawTagOnRoad(
      canvas,
      'трамвај на средини',
      at: const Offset(95, 190),
      anchor: Alignment.topCenter,
    );
    drawCar(canvas, const Offset(95, passY), color: _blue);
    drawArrow(
      canvas,
      const Offset(126, passY),
      const Offset(158, passY),
      color: kMarking,
    );

    // Справа: впереди идущий подал знак и встал к осевой — он поворачивает
    // налево, поэтому его обходят справа.
    drawCar(
      canvas,
      const Offset(295, 245),
      color: _green,
      leftBlinker: true,
    );
    drawTagOnRoad(
      canvas,
      'скреће улево',
      at: const Offset(295, 190),
      anchor: Alignment.topCenter,
    );
    drawArrow(
      canvas,
      const Offset(295, 231),
      const Offset(268, 212),
      color: kMarking,
      headSize: 5,
    );
    drawCar(canvas, const Offset(295, passY), color: _blue);
    drawArrow(
      canvas,
      const Offset(326, passY),
      const Offset(358, passY),
      color: kMarking,
    );

    _note(
      canvas,
      'Здесна — само кад возило испред јасно скреће улево (показивач правца и '
      'положај уз осу) и кад трамвај иде средином коловоза.',
      306,
    );
  }

  /// 3. Не обгон: две полосы в одну сторону, колонны разной скорости.
  void _drawNotOvertaking(Canvas canvas) {
    _title(canvas, '3 · није претицање', 350);

    const road = Rect.fromLTRB(0, 372, 400, 468);
    const dividerY = 420.0;
    const fastY = 396.0;
    const slowY = 444.0;
    drawAsphalt(canvas, road);
    drawEdgeLines(canvas, road);
    drawDashedLine(canvas, dividerY, 4, 396);

    for (final x in [150.0, 240.0]) {
      drawCar(canvas, Offset(x, fastY), color: _blue);
    }
    for (final x in [110.0, 200.0, 290.0]) {
      drawCar(canvas, Offset(x, slowY), color: _grey);
    }

    // Длина стрелки = скорость колонны: левая идёт быстрее правой.
    drawArrow(
      canvas,
      const Offset(272, fastY),
      const Offset(372, fastY),
      color: kMarking,
    );
    drawArrow(
      canvas,
      const Offset(322, slowY),
      const Offset(372, slowY),
      color: kMarking,
    );
    drawTagOnRoad(
      canvas,
      'брже',
      at: const Offset(8, fastY),
      anchor: Alignment.centerLeft,
    );
    drawTagOnRoad(
      canvas,
      'спорије',
      at: const Offset(8, slowY),
      anchor: Alignment.centerLeft,
    );

    _note(
      canvas,
      'Две траке у истом смеру: брже кретање у својој траци није претицање '
      '(као ни пролазак здесна на путу у насељу).',
      474,
    );
  }

  void _title(Canvas canvas, String text, double y) {
    drawText(
      canvas,
      text,
      at: Offset(0, y),
      color: scheme.onSurface,
      size: 14,
      bold: true,
    );
  }

  void _note(Canvas canvas, String text, double y) {
    drawText(
      canvas,
      text,
      at: Offset(0, y),
      color: scheme.onSurfaceVariant,
      size: 12,
      maxWidth: 400,
    );
  }

  @override
  bool shouldRepaint(covariant _StranePainter old) => old.scheme != scheme;
}
