// Специальные полосы внутри коловоза: что где лежит и как называется.
//
// Верхняя схема — участок аутопута (та же геометрия и палитра, что в
// autoput_trake.dart: обе картинки объясняют одни и те же полосы, и дорога
// должна выглядеть одинаково). Ниже две врезки: полоса для медленных
// транспортных средств и полоса общественного транспорта — они на аутопуте
// не встречаются, поэтому вынесены отдельно.

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/painters.dart';

const double _w = 400;
const double _h = 404;

/// Оси полос аутопута. Две ходовые полосы разделены прерывистой на y = 82.
const double _yShoulder = 133; // зауставна трака
const double _roadTop = 46;
const double _shoulderTop = 118;
const double _shoulderBottom = 148;

const Offset _rampInStart = Offset(-14, 196);
const Offset _rampInControl = Offset(60, 190);
const Offset _rampInEnd = Offset(140, _yShoulder);

const Offset _rampOutStart = Offset(296, _yShoulder);
const Offset _rampOutControl = Offset(360, 150);
const Offset _rampOutEnd = Offset(416, 200);

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
    canvas.drawRect(
      const Rect.fromLTRB(0, _roadTop, _w, _shoulderTop),
      Paint()..color = kAsphalt,
    );
    canvas.drawRect(
      const Rect.fromLTRB(0, _shoulderTop, _w, _shoulderBottom),
      Paint()..color = kAsphaltShoulder,
    );
    _drawRamps(canvas);

    final solid = Paint()
      ..color = kLineWhite
      ..strokeWidth = 2.5;
    canvas.drawLine(
      const Offset(0, _roadTop),
      const Offset(_w, _roadTop),
      solid,
    );
    // Нижний край коловоза есть только между съездами.
    canvas.drawLine(
      const Offset(150, _shoulderBottom),
      const Offset(292, _shoulderBottom),
      solid,
    );
    drawDashedLine(
      canvas,
      const Offset(0, 82),
      const Offset(_w, 82),
      kLineWhite,
      strokeWidth: 2.5,
    );
    // Зауставна трака отделена сплошной: заезжать на неё без нужды нельзя.
    // На длине полос разгона и торможения линия прерывистая.
    drawDashedLine(
      canvas,
      const Offset(0, _shoulderTop),
      const Offset(150, _shoulderTop),
      kLineWhite,
      strokeWidth: 2.5,
    );
    canvas.drawLine(
      const Offset(150, _shoulderTop),
      const Offset(292, _shoulderTop),
      solid,
    );
    drawDashedLine(
      canvas,
      const Offset(292, _shoulderTop),
      const Offset(_w, _shoulderTop),
      kLineWhite,
      strokeWidth: 2.5,
    );

    // Сломавшаяся машина с аварийкой — единственное, ради чего остановочная
    // полоса и существует.
    drawCarTopView(
      canvas,
      Rect.fromCenter(
        center: const Offset(215, _yShoulder),
        width: 42,
        height: 20,
      ),
      kCarRed,
      hazardOn: true,
    );

    drawSchemeChip(
      canvas,
      'две саобраћајне траке',
      const Offset(72, 82),
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
      const Offset(215, 148),
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
    drawSchemeArrow(
      canvas,
      const Offset(70, 208),
      const Offset(88, 190),
      scheme.onSurface,
    );
    drawSchemeArrow(
      canvas,
      const Offset(330, 208),
      const Offset(350, 190),
      scheme.onSurface,
    );
  }

  void _drawRamps(Canvas canvas) {
    for (final ramp in [
      (_rampInStart, _rampInControl, _rampInEnd),
      (_rampOutStart, _rampOutControl, _rampOutEnd),
    ]) {
      final path = Path()
        ..moveTo(ramp.$1.dx, ramp.$1.dy)
        ..quadraticBezierTo(ramp.$2.dx, ramp.$2.dy, ramp.$3.dx, ramp.$3.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = kLineWhite
          ..strokeWidth = 34
          ..style = PaintingStyle.stroke,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = kAsphaltShoulder
          ..strokeWidth = 30
          ..style = PaintingStyle.stroke,
      );
    }

    // Куда едет тот, кто на этой полосе: «улазим» — вливаюсь в поток,
    // «излазим» — ухожу с дороги.
    drawSchemeCurvedArrow(
      canvas,
      const Offset(16, 176),
      const Offset(70, 172),
      const Offset(126, 130),
      kLineWhite,
      strokeWidth: 3,
      headLength: 11,
    );
    drawSchemeCurvedArrow(
      canvas,
      const Offset(306, 130),
      const Offset(356, 158),
      const Offset(392, 186),
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

    drawCarTopView(
      canvas,
      Rect.fromCenter(
        center: const Offset(130, 316),
        width: 38,
        height: 18,
      ),
      kCarBlue,
    );
    drawTruckTopView(
      canvas,
      Rect.fromCenter(
        center: const Offset(96, 344),
        width: 70,
        height: 20,
      ),
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

    drawCarTopView(
      canvas,
      Rect.fromCenter(
        center: const Offset(250, 316),
        width: 38,
        height: 18,
      ),
      kCarBlue,
    );
    drawBusTopView(
      canvas,
      Rect.fromCenter(
        center: const Offset(310, 344),
        width: 84,
        height: 20,
      ),
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
