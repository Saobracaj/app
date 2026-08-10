import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/raskrsnica_common.dart';

/// Занятый перекрёсток: зелёный сигнал ещё не разрешает въезд.
///
/// Ошибка, на которой построены вопросы подкатегории 137, ровно одна: зелёный
/// свет читают как «можно ехать», хотя ехать можно только тогда, когда за
/// перекрёстком есть место, чтобы его покинуть. Поэтому на схеме два варианта
/// одной и той же машины: правильный — перед стоп-линией, и полупрозрачный
/// неправильный — вставший на пешеходном переходе внутри затора.
///
/// Схема статичная: здесь нечего показывать в движении — вся суть в том, что
/// правильное действие и есть «стоять».
class BlokiranaRaskrsnica extends StatelessWidget {
  const BlokiranaRaskrsnica({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 470,
          child: CustomPaint(painter: _ScenePainter(scheme)),
        ),
      ),
    );
  }
}

class _ScenePainter extends RaskrsnicaPainter {
  _ScenePainter(super.colorScheme);

  static const _area = Rect.fromLTWH(0, 0, 400, 360);
  static const _center = Offset(200, 175);
  static const _armHalf = 52.0;

  /// Полоса, по которой подъезжает синий, и та же полоса за перекрёстком —
  /// именно в ней стоит колонна.
  static const _laneX = 226.0;

  /// Правильное положение: перед стоп-линией (она на 52 от края перекрёстка).
  static const _correctY = 316.0;

  /// Неправильное: на пешеходном переходе.
  static const _wrongY = 248.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(_area);

    intersection(
      canvas,
      area: _area,
      center: _center,
      armHalf: _armHalf,
      zebra: {Side.south, Side.north},
      stopLine: {Side.south},
    );

    // Колонна впереди стоит: одна машина уже застряла в самом перекрёстке,
    // две другие — за ним. Место, куда синий мог бы выехать, занято.
    car(canvas, const Offset(_laneX, 150), kHeadingNorth, kCarRed, brake: true);
    car(canvas, const Offset(_laneX, 88), kHeadingNorth, kCarGreen,
        brake: true);
    car(canvas, const Offset(_laneX, 26), kHeadingNorth, kCarYellow,
        brake: true);

    // Поперечное направление сейчас стоит на красный — но перекрёсток от
    // этого не свободен.
    car(canvas, const Offset(96, 201), kHeadingEast, kCarWhite, brake: true);

    // Пешеходы у перехода: если встать на зебру, идти им будет негде.
    person(canvas, const Offset(136, 240), 26, colorScheme.onSurface);
    person(canvas, const Offset(120, 233), 24, colorScheme.onSurface);

    // Светофор — слева от подъезда: справа стоят обе подписи вариантов, и
    // втроём они бы наехали друг на друга.
    trafficLight(canvas, const Offset(118, 248),
        signal: kSignalGreen, greenOn: true);
    text(canvas, 'зелено', const Offset(126, 302), colorScheme.onSurface,
        maxWidth: 80, fontSize: 12, isBold: true);

    // Неправильный вариант — полупрозрачный, поверх зебры, перечёркнут.
    car(canvas, const Offset(_laneX, _wrongY), kHeadingNorth, kCarBlue,
        opacity: 0.42);
    drawCross(canvas, const Offset(_laneX, _wrongY), 22, kForbidden, width: 5);
    roadLabel(canvas, 'не улази', const Offset(312, 248),
        fontSize: 12, background: kForbidden.withValues(alpha: 0.9));

    // Правильный вариант — за стоп-линией.
    car(canvas, const Offset(_laneX, _correctY), kHeadingNorth, kCarBlue,
        brake: true);
    final chip = roadLabel(canvas, 'чекај', const Offset(316, 316),
        fontSize: 13, background: kSignalGreen.withValues(alpha: 0.92));
    drawCheck(canvas, Offset(chip.left - 12, chip.center.dy), 8, kSignalGreen);

    // Пунктир «свободного места за перекрёстком нет» — от синего к хвосту
    // колонны: именно это, а не сигнал светофора, решает, можно ли ехать.
    dashedLine(canvas, const Offset(196, 302), const Offset(196, 178),
        color: kForbidden, width: 2.5, dash: 7, gap: 5);
    roadLabel(canvas, 'нема места\nиза раскрснице', const Offset(74, 150),
        fontSize: 12, maxWidth: 120);

    canvas.restore();

    calloutBox(
      canvas,
      'Зелено светло није дозвола за улазак:\n'
      'улази само ако можеш да прођеш без заустављања',
      const Rect.fromLTWH(6, 370, 388, 44),
      fill: colorScheme.tertiaryContainer,
      ink: colorScheme.onTertiaryContainer,
      check: true,
    );
    calloutBox(
      canvas,
      'Не улази ако ћеш стати у раскрсници или\n'
      'на пешачком прелазу — ометаш возила и пешаке',
      const Rect.fromLTWH(6, 420, 388, 44),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      cross: true,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme;
}
