// Специальные полосы внутри коловоза: что где лежит и как называется.
//
// Верхняя схема — участок аутопута (дорога общая с autoput_trake.dart, см.
// autoput_road.dart: обе картинки объясняют одни и те же полосы, и дорога
// должна выглядеть одинаково). Ниже две врезки: полоса для медленных
// транспортных средств и полоса общественного транспорта — они на аутопуте
// не встречаются, поэтому вынесены отдельно.

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/autoput_road.dart';
import 'package:saobracaj/test/animations/painters.dart';

const double _w = kAutoputRoadWidth;
const double _h = 404;

/// Участок аутопута: верхний край коловоза на y = 46, ниже — две ходовые
/// полосы и зауставна трака.
final AutoputRoad _road = AutoputRoad(top: 46);

class PosebneTrakeAutoput extends StatelessWidget {
  const PosebneTrakeAutoput({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _w,
          height: _h,
          child: CustomPaint(
            painter: _PosebneTrakePainter(Theme.of(context).colorScheme),
          ),
        ),
      ),
    );
  }
}

class _PosebneTrakePainter extends CustomPainter {
  _PosebneTrakePainter(this.scheme);

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _drawHeader(canvas);
    _drawMotorway(canvas);
    _drawSlowLaneCard(canvas);
    _drawBusLaneCard(canvas);
  }

  void _drawHeader(Canvas canvas) {
    drawSchemeChip(
      canvas,
      'Посебне траке на аутопуту',
      const Offset(_w / 2, 14),
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
      fontSize: 13,
      bold: true,
      maxWidth: 320,
    );
  }

  // --- верхняя схема: аутопут ---------------------------------------------

  void _drawMotorway(Canvas canvas) {
    _road.paint(canvas);
    _drawRampArrows(canvas);

    // Сломавшаяся машина с аварийкой — единственное, ради чего остановочная
    // полоса и существует.
    drawSchematicCarTopView(
      canvas,
      Rect.fromCenter(
        center: Offset(215, _road.yShoulder),
        width: 42,
        height: 20,
      ),
      kCarRed,
      hazardOn: true,
    );

    drawSchemeChip(
      canvas,
      'две саобраћајне траке',
      Offset(72, _road.laneDivider),
      scheme.surface,
      scheme.onSurface,
      maxWidth: 130,
      bold: true,
    );
    drawSchemeChip(
      canvas,
      'зауставна трака',
      const Offset(196, 174),
      scheme.errorContainer,
      scheme.onErrorContainer,
      maxWidth: 150,
      bold: true,
    );
    drawSchemeArrow(
      canvas,
      const Offset(215, 164),
      Offset(215, _road.bandBottom + 3),
      scheme.onSurface,
    );
    drawSchemeChip(
      canvas,
      'трака за укључивање\n(улазим ↗)',
      const Offset(4, 222),
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
      align: const Alignment(-1, 0),
      maxWidth: 120,
      bold: true,
    );
    drawSchemeChip(
      canvas,
      'трака за искључивање\n(излазим ↘)',
      const Offset(_w - 4, 222),
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
      align: const Alignment(1, 0),
      maxWidth: 120,
      bold: true,
    );
    // Стрелки упираются в нижнюю кромку съездов.
    drawSchemeArrow(
      canvas,
      const Offset(60, 206),
      _road.rampIn.offsetAt(0.45, kAutoputAuxWidth / 2 + 3),
      scheme.onSurface,
    );
    drawSchemeArrow(
      canvas,
      const Offset(348, 206),
      _road.rampOut.offsetAt(0.55, kAutoputAuxWidth / 2 + 3),
      scheme.onSurface,
    );
  }

  /// Куда едет тот, кто на этой полосе: «улазим» — вливаюсь в поток,
  /// «излазим» — ухожу с дороги. Стрелка идёт по оси съезда.
  void _drawRampArrows(Canvas canvas) {
    _drawCurveArrow(canvas, _road.rampIn, from: 0.12, to: 0.9);
    _drawCurveArrow(canvas, _road.rampOut, from: 0.1, to: 0.72);
  }

  /// Квадратичная стрелка, повторяющая кусок кубической оси съезда: концы
  /// совпадают, контрольная точка подобрана так, чтобы пройти через середину.
  void _drawCurveArrow(
    Canvas canvas,
    CubicCurve curve, {
    required double from,
    required double to,
  }) {
    final start = curve.pointAt(from);
    final end = curve.pointAt(to);
    final middle = curve.pointAt((from + to) / 2);
    final control = middle * 2 - (start + end) / 2;
    drawSchemeCurvedArrow(
      canvas,
      start,
      control,
      end,
      kLineWhite,
      strokeWidth: 3,
      headLength: 11,
    );
  }

  // --- врезки --------------------------------------------------------------

  void _drawCard(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = scheme.surfaceContainerHighest,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..color = scheme.outline
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  /// Полоса для медленных ТС: дополнительная полоса справа, обычно на подъёме.
  void _drawSlowLaneCard(Canvas canvas) {
    const rect = Rect.fromLTRB(0, 250, 194, 396);
    _drawCard(canvas, rect);

    drawSchemeText(
      canvas,
      'саобраћајна трака\nза спора возила',
      const Offset(97, 262),
      scheme.onSurface,
      fontSize: 11,
      bold: true,
      maxWidth: 180,
    );

    canvas.drawRect(
      const Rect.fromLTRB(10, 302, 184, 358),
      Paint()..color = kAsphalt,
    );
    final solid = Paint()
      ..color = kLineWhite
      ..strokeWidth = 2.5;
    canvas.drawLine(const Offset(10, 302), const Offset(184, 302), solid);
    canvas.drawLine(const Offset(10, 358), const Offset(184, 358), solid);
    drawDashedLine(
      canvas,
      const Offset(10, 330),
      const Offset(184, 330),
      kLineWhite,
      strokeWidth: 2.5,
      dash: 10,
      gap: 8,
    );

    drawSchematicCarTopView(
      canvas,
      Rect.fromCenter(center: const Offset(130, 316), width: 38, height: 18),
      kCarBlue,
    );
    drawTruckTopView(
      canvas,
      Rect.fromCenter(center: const Offset(96, 344), width: 70, height: 20),
      kCarGreen,
    );

    _drawSpeedSign(canvas, const Offset(26, 378), '30');
    drawSchemeText(
      canvas,
      'додатна трака, обично\nна узбрдици',
      const Offset(46, 378),
      scheme.onSurface,
      fontSize: 10,
      maxWidth: 140,
      align: const Alignment(-1, 0),
      textAlign: TextAlign.left,
    );
  }

  /// Полоса общественного транспорта: её граница — жёлтая линия.
  void _drawBusLaneCard(Canvas canvas) {
    const rect = Rect.fromLTRB(206, 250, 400, 396);
    _drawCard(canvas, rect);

    drawSchemeText(
      canvas,
      'трака за возила\nјавног превоза',
      const Offset(303, 262),
      scheme.onSurface,
      fontSize: 11,
      bold: true,
      maxWidth: 180,
    );

    canvas.drawRect(
      const Rect.fromLTRB(216, 302, 390, 358),
      Paint()..color = kAsphalt,
    );
    final solid = Paint()
      ..color = kLineWhite
      ..strokeWidth = 2.5;
    canvas.drawLine(const Offset(216, 302), const Offset(390, 302), solid);
    canvas.drawLine(const Offset(216, 358), const Offset(390, 358), solid);
    // Жёлтая сплошная — единственный признак, по которому эта полоса
    // узнаётся на фотографии.
    canvas.drawLine(
      const Offset(216, 330),
      const Offset(390, 330),
      Paint()
        ..color = kLineYellow
        ..strokeWidth = 3.5,
    );

    drawSchematicCarTopView(
      canvas,
      Rect.fromCenter(center: const Offset(250, 316), width: 38, height: 18),
      kCarBlue,
    );
    drawBusTopView(
      canvas,
      Rect.fromCenter(center: const Offset(310, 344), width: 84, height: 20),
      kCarGreen,
    );

    drawSchemeText(
      canvas,
      'граница те траке је\nжута линија',
      const Offset(303, 378),
      scheme.onSurface,
      fontSize: 10,
      maxWidth: 180,
    );
  }

  /// Синий квадратный знак с цифрой — им обозначают полосу для медленных ТС.
  void _drawSpeedSign(Canvas canvas, Offset center, String text) {
    final rect = Rect.fromCenter(center: center, width: 26, height: 26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = const Color(0xFF1B5FAC),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = kLineWhite
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    drawSchemeText(
      canvas,
      text,
      center,
      kLineWhite,
      fontSize: 13,
      bold: true,
      maxWidth: 26,
    );
  }

  @override
  bool shouldRepaint(covariant _PosebneTrakePainter old) =>
      old.scheme != scheme;
}
