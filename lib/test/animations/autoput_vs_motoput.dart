// Аутопут против мотопута: общее ядро (знак + список ТС) плюс четыре добавки,
// которые есть только у аутопута.
//
// Две схемы вид сверху рядом. Всё, чем аутопут отличается, помечено номером;
// расшифровка номеров — списком под схемами (стрелки к каждому месту на таком
// узком холсте наезжают друг на друга, номер + подпись читается надёжнее).

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/painters.dart';
import 'package:saobracaj/test/animations/road_sign.dart';

const double _w = 400;
const double _h = 478;

/// Вертикальные границы схем.
const double _roadTop = 78;
const double _roadBottom = 300;

/// Аутопут: две проезжие части, между ними разделитель, снаружи — остановочные.
const double _apShoulderL = 4;
const double _apCarriageALeft = 22;
const double _apCarriageARight = 78;
const double _apMedianRight = 96;
const double _apCarriageBRight = 152;
const double _apShoulderR = 170;

/// Мотопут: одна проезжая часть, по полосе в каждую сторону.
const double _mpLeft = 268;
const double _mpCenter = 300;
const double _mpRight = 332;

/// Пересечение с другой дорогой: у аутопута — путепроводом, у мотопута — в
/// одном уровне. По вертикали оба лежат на одной высоте, чтобы разницу было
/// видно сравнением.
const double _crossTop = 152;
const double _crossBottom = 188;

const Color _median = Color(0xFF4E7B45);

class AutoputVsMotoput extends StatelessWidget {
  const AutoputVsMotoput({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: RoadSignScope(
        signs: const ['III-68', 'III-21'],
        builder: (context, signs) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _w,
            height: _h,
            child: CustomPaint(
              painter: _AutoputVsMotoputPainter(
                  Theme.of(context).colorScheme, signs),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoputVsMotoputPainter extends CustomPainter {
  _AutoputVsMotoputPainter(this.scheme, this.signs);

  final ColorScheme scheme;
  final RoadSigns signs;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _drawHeaders(canvas);
    _drawAutoput(canvas);
    _drawMotoput(canvas);
    _drawSummaries(canvas);
    _drawLegend(canvas);
  }

  void _drawHeaders(Canvas canvas) {
    drawSchemeChip(
      canvas,
      'АУТОПУТ',
      const Offset(88, 14),
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
      fontSize: 13,
      bold: true,
    );
    drawSchemeChip(
      canvas,
      'МОТОПУТ',
      const Offset(300, 14),
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
      fontSize: 13,
      bold: true,
    );

    // Знак — единственный признак, общий для обоих: поэтому номер ① стоит
    // у обеих табличек. Аутопут — зелёный III-68, мотопут — синий III-21.
    signs.paint(canvas, 'III-68',
        Rect.fromCenter(center: const Offset(88, 52), width: 32, height: 46));
    _drawBadge(canvas, const Offset(118, 38), '1');
    signs.paint(canvas, 'III-21',
        Rect.fromCenter(center: const Offset(300, 52), width: 32, height: 46));
    _drawBadge(canvas, const Offset(330, 38), '1');
  }

  // --- левая схема ---------------------------------------------------------

  void _drawAutoput(Canvas canvas) {
    final asphalt = Paint()..color = kAsphalt;
    final shoulder = Paint()..color = kAsphaltShoulder;

    canvas.drawRect(
      const Rect.fromLTRB(_apCarriageALeft, _roadTop, _apCarriageARight, _roadBottom),
      asphalt,
    );
    canvas.drawRect(
      const Rect.fromLTRB(_apMedianRight, _roadTop, _apCarriageBRight, _roadBottom),
      asphalt,
    );
    canvas.drawRect(
      const Rect.fromLTRB(_apShoulderL, _roadTop, _apCarriageALeft, _roadBottom),
      shoulder,
    );
    canvas.drawRect(
      const Rect.fromLTRB(_apCarriageBRight, _roadTop, _apShoulderR, _roadBottom),
      shoulder,
    );

    // Разделитель: газон с отбойником посередине.
    canvas.drawRect(
      const Rect.fromLTRB(_apCarriageARight, _roadTop, _apMedianRight, _roadBottom),
      Paint()..color = _median,
    );
    canvas.drawLine(
      const Offset(87, _roadTop),
      const Offset(87, _roadBottom),
      Paint()
        ..color = kCarGrey
        ..strokeWidth = 3,
    );

    _drawExitRamp(canvas);

    final solid = Paint()
      ..color = kLineWhite
      ..strokeWidth = 2.5;
    for (final x in [
      _apCarriageALeft,
      _apCarriageARight,
      _apMedianRight,
      _apCarriageBRight,
    ]) {
      canvas.drawLine(
        Offset(x, _roadTop),
        Offset(x, _roadBottom),
        solid,
      );
    }
    // По две полосы в каждую сторону.
    for (final x in [50.0, 124.0]) {
      drawDashedLine(
        canvas,
        Offset(x, _roadTop),
        Offset(x, _roadBottom),
        kLineWhite,
        strokeWidth: 2.5,
      );
    }

    _drawVerticalCar(canvas, const Offset(36, 245), kCarBlue, up: false);
    _drawVerticalCar(canvas, const Offset(64, 120), kCarGrey, up: false);
    _drawVerticalCar(canvas, const Offset(110, 250), kCarGreen, up: true);
    _drawVerticalCar(canvas, const Offset(138, 115), kCarBlue, up: true);
    // Машина с аварийкой на остановочной полосе — ради неё полоса и нужна.
    _drawVerticalCar(canvas, const Offset(161, 118), kCarRed, up: true, hazard: true);

    _drawOverpass(canvas);

    _drawBadge(canvas, const Offset(87, 268), '2');
    _drawBadge(canvas, const Offset(161, 288), '3');
    _drawBadge(canvas, const Offset(178, 232), '4');
    _drawBadge(canvas, const Offset(20, 170), '5');
  }

  /// Съезд: попасть на аутопут и уйти с него можно только специально
  /// построенным путём.
  void _drawExitRamp(Canvas canvas) {
    final path = Path()
      ..moveTo(_apCarriageBRight, 214)
      ..quadraticBezierTo(186, 230, 192, 272);
    canvas.drawPath(
      path,
      Paint()
        ..color = kLineWhite
        ..strokeWidth = 24
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = kAsphaltShoulder
        ..strokeWidth = 20
        ..style = PaintingStyle.stroke,
    );
  }

  /// Путепровод: другая дорога проходит над аутопутом, они не пересекаются
  /// в одном уровне.
  void _drawOverpass(Canvas canvas) {
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 196, _h));
    // Тень — то единственное, чем на схеме «вид сверху» показывается, что
    // дорога идёт поверх.
    canvas.drawRect(
      const Rect.fromLTRB(0, _crossTop + 4, 196, _crossBottom + 6),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawRect(
      const Rect.fromLTRB(0, _crossTop, 196, _crossBottom),
      Paint()..color = kAsphalt,
    );
    final solid = Paint()
      ..color = kLineWhite
      ..strokeWidth = 2.5;
    canvas.drawLine(
      const Offset(0, _crossTop),
      const Offset(196, _crossTop),
      solid,
    );
    canvas.drawLine(
      const Offset(0, _crossBottom),
      const Offset(196, _crossBottom),
      solid,
    );
    drawDashedLine(
      canvas,
      const Offset(0, (_crossTop + _crossBottom) / 2),
      const Offset(196, (_crossTop + _crossBottom) / 2),
      kLineWhite,
      strokeWidth: 2,
      dash: 9,
      gap: 8,
    );
    drawSchemeText(
      canvas,
      'надвожњак',
      const Offset(132, (_crossTop + _crossBottom) / 2),
      kLineWhite,
      fontSize: 10,
      bold: true,
      maxWidth: 90,
    );
    canvas.restore();
  }

  // --- правая схема --------------------------------------------------------

  void _drawMotoput(Canvas canvas) {
    final asphalt = Paint()..color = kAsphalt;
    canvas.drawRect(
      const Rect.fromLTRB(_mpLeft, _roadTop, _mpRight, _roadBottom),
      asphalt,
    );
    // Другая дорога пересекает мотопут в одном уровне — обычная раскрсница.
    canvas.drawRect(
      const Rect.fromLTRB(206, _crossTop, 400, _crossBottom),
      asphalt,
    );

    final solid = Paint()
      ..color = kLineWhite
      ..strokeWidth = 2.5;
    // Края дороги прерываются на перекрёстке: это и есть «исти ниво».
    for (final x in [_mpLeft, _mpRight]) {
      canvas.drawLine(Offset(x, _roadTop), Offset(x, _crossTop), solid);
      canvas.drawLine(Offset(x, _crossBottom), Offset(x, _roadBottom), solid);
    }
    for (final y in [_crossTop, _crossBottom]) {
      canvas.drawLine(const Offset(206, 0) + Offset(0, y), Offset(_mpLeft, y), solid);
      canvas.drawLine(Offset(_mpRight, y), Offset(400, y), solid);
    }
    // Осевая — одна полоса в каждую сторону, физического разделения нет.
    drawDashedLine(
      canvas,
      const Offset(_mpCenter, _roadTop),
      const Offset(_mpCenter, _crossTop),
      kLineWhite,
      strokeWidth: 2.5,
    );
    drawDashedLine(
      canvas,
      const Offset(_mpCenter, _crossBottom),
      const Offset(_mpCenter, _roadBottom),
      kLineWhite,
      strokeWidth: 2.5,
    );
    drawDashedLine(
      canvas,
      const Offset(206, (_crossTop + _crossBottom) / 2),
      const Offset(_mpLeft, (_crossTop + _crossBottom) / 2),
      kLineWhite,
      strokeWidth: 2,
      dash: 9,
      gap: 8,
    );
    drawDashedLine(
      canvas,
      const Offset(_mpRight, (_crossTop + _crossBottom) / 2),
      const Offset(400, (_crossTop + _crossBottom) / 2),
      kLineWhite,
      strokeWidth: 2,
      dash: 9,
      gap: 8,
    );

    _drawVerticalCar(canvas, const Offset(284, 240), kCarBlue, up: false);
    _drawVerticalCar(canvas, const Offset(316, 110), kCarGreen, up: true);
    _drawVerticalCar(canvas, const Offset(316, 258), kCarGrey, up: true);

    drawSchemeText(
      canvas,
      'укрштање\nу истом нивоу',
      const Offset(232, 218),
      scheme.onSurface,
      fontSize: 10,
      bold: true,
      maxWidth: 90,
    );
  }

  // --- подписи -------------------------------------------------------------

  void _drawSummaries(Canvas canvas) {
    drawSchemeChip(
      canvas,
      'језгро ① + додаци ②③④⑤',
      const Offset(88, 318),
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
      maxWidth: 180,
      bold: true,
    );
    drawSchemeChip(
      canvas,
      'само језгро ①,\nниједан додатак',
      const Offset(300, 318),
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
      maxWidth: 180,
      bold: true,
    );
  }

  void _drawLegend(Canvas canvas) {
    const items = [
      (
        '1',
        'обележен саобраћајним знаком (важи и за аутопут и за мотопут)',
      ),
      ('2', 'коловозне траке за супротне смерове физички одвојене'),
      ('3', 'најмање две саобраћајне траке по смеру и зауставна трака'),
      (
        '4',
        'потпуна контрола приступа: укључивање и искључивање само посебно изграђеним путем',
      ),
      ('5', 'сва укрштања са другим путевима и пругама — у различитим нивоима'),
    ];

    var y = 352.0;
    for (final (number, text) in items) {
      final size = drawSchemeText(
        canvas,
        text,
        Offset(34, y),
        scheme.onSurface,
        fontSize: 11,
        maxWidth: 356,
        align: const Alignment(-1, -1),
        textAlign: TextAlign.left,
      );
      _drawBadge(canvas, Offset(16, y + size.height / 2), number);
      y += size.height + 8;
    }
  }

  // --- элементы ------------------------------------------------------------

  void _drawBadge(Canvas canvas, Offset center, String number) {
    canvas.drawCircle(center, 9, Paint()..color = scheme.primary);
    drawSchemeText(
      canvas,
      number,
      center,
      scheme.onPrimary,
      fontSize: 11,
      bold: true,
      maxWidth: 20,
    );
  }

  void _drawVerticalCar(
    Canvas canvas,
    Offset center,
    Color color, {
    required bool up,
    bool hazard = false,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Машина рисуется носом вправо, поэтому поворачиваем её вдоль дороги.
    canvas.rotate(up ? -3.14159 / 2 : 3.14159 / 2);
    drawSchematicCarTopView(
      canvas,
      Rect.fromCenter(center: Offset.zero, width: 34, height: 17),
      color,
      hazardOn: hazard,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AutoputVsMotoputPainter old) =>
      old.scheme != scheme || old.signs != signs;
}
