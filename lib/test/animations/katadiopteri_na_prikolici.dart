import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/prikolica_common.dart';

/// Катафоты (*катадиоптери*) на прицепе: перед и зад рядом.
///
/// Вопросы №8755, №8756 и №8757 отличаются одним признаком — формой и цветом,
/// и все три ловушки построены на подмене «предњи троугласти» / «задњи
/// правоугаони». Поэтому обе стороны нарисованы в одном кадре: сравнить их
/// глазом дешевле, чем помнить две отдельные формулировки.
class KatadiopteriNaPrikolici extends StatelessWidget {
  const KatadiopteriNaPrikolici({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 386,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

class _ScenePainter extends TrailerScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  static const _front = Rect.fromLTRB(2, 34, 196, 272);
  static const _rear = Rect.fromLTRB(204, 34, 398, 272);

  /// Кузов прицепа в обеих проекциях стоит одинаково — иначе перед и зад
  /// сравниваются не по катафотам, а по случайной разнице в рисунке.
  static const _frontBody = Rect.fromLTRB(40, 76, 160, 176);
  static const _rearBody = Rect.fromLTRB(242, 76, 362, 176);
  static const _groundY = 182.0;

  @override
  void paint(Canvas canvas, Size size) {
    text(
      canvas,
      'Катадиоптери на приколици: напред и назад',
      const Offset(200, 16),
      colorScheme.onSurface,
      maxWidth: 396,
      fontSize: 13,
      isBold: true,
    );

    _frontPanel(canvas);
    _rearPanel(canvas);
    _mnemonic(canvas);
  }

  void _frontPanel(Canvas canvas) {
    panel(canvas, _front);
    chip(
      canvas,
      'ПРЕДЊА СТРАНА${gloss('  ·  спереди')}',
      const Rect.fromLTRB(10, 42, 188, 66),
      fill: colorScheme.secondaryContainer,
      ink: colorScheme.onSecondaryContainer,
      fontSize: 11.5,
    );

    _trailerFace(canvas, _frontBody);
    // Сцепная головка снизу по центру: по ней видно, что это перед прицепа,
    // а не зад — сам кузов спереди и сзади одинаков.
    canvas.drawCircle(
      Offset(_frontBody.center.dx, _frontBody.bottom - 6),
      7,
      Paint()..color = kTrailerEdge,
    );

    // Два белых прямоугольника — форма и есть ответ (№8755, №8756).
    for (final left in [56.0, 112.0]) {
      final rect = Rect.fromLTWH(left, 132, 32, 17);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = kReflectorWhite,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..color = const Color(0xFF3A3F45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    _caption(
      canvas,
      _front,
      'бели, правоугаони —\nНИСУ троугласти',
      gloss('белые, прямоугольные,\nне треугольные'),
    );
  }

  void _rearPanel(Canvas canvas) {
    panel(canvas, _rear);
    chip(
      canvas,
      'ЗАДЊА СТРАНА${gloss('  ·  сзади')}',
      const Rect.fromLTRB(212, 42, 390, 66),
      fill: colorScheme.secondaryContainer,
      ink: colorScheme.onSecondaryContainer,
      fontSize: 11.5,
    );

    _trailerFace(canvas, _rearBody);

    // Равносторонний треугольник вершиной вверх: высота = сторона * √3/2.
    const side = 34.0;
    const baseY = 140.0;
    final height = side * math.sqrt(3) / 2;
    for (final cx in [272.0, 332.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx, baseY - height)
          ..lineTo(cx + side / 2, baseY)
          ..lineTo(cx - side / 2, baseY)
          ..close(),
        Paint()..color = kReflectorRed,
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx, baseY - height)
          ..lineTo(cx + side / 2, baseY)
          ..lineTo(cx - side / 2, baseY)
          ..close(),
        Paint()
          ..color = const Color(0xFF7A1512)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    dimension(
      canvas,
      const Offset(272 - side / 2, 150),
      const Offset(272 + side / 2, 150),
      'страница ≥ 0,15 m',
      color: kMarking,
      fontSize: 10.5,
      labelOffset: const Offset(30, 14),
    );

    _caption(
      canvas,
      _rear,
      'црвени, равнострани троугао,\nврх навише',
      gloss('красные, равносторонний\nтреугольник вершиной вверх'),
    );
  }

  /// Кузов прицепа анфас: ящик, два колеса по бокам и линия земли.
  void _trailerFace(Canvas canvas, Rect body) {
    final rrect = RRect.fromRectAndRadius(body, const Radius.circular(5));
    canvas.drawRRect(rrect, Paint()..color = kTrailerBody);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = kTrailerEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    final tyre = Paint()..color = kTyre;
    for (final x in [body.left - 12, body.right - 1]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 136, 13, 46),
          const Radius.circular(4),
        ),
        tyre,
      );
    }
    canvas.drawLine(
      Offset(body.left - 26, _groundY),
      Offset(body.right + 26, _groundY),
      Paint()
        ..color = colorScheme.outline
        ..strokeWidth = 2.5,
    );
  }

  /// Подпись под проекцией: сербский термин крупно, русский перевод мельче.
  void _caption(Canvas canvas, Rect panelRect, String serbian, String russian) {
    text(canvas, serbian, Offset(panelRect.center.dx, 208),
        colorScheme.onSurface,
        maxWidth: panelRect.width - 20, fontSize: 11.5, isBold: true);
    if (russian.isNotEmpty) {
      text(canvas, russian, Offset(panelRect.center.dx, 248),
          colorScheme.onSurfaceVariant,
          maxWidth: panelRect.width - 20, fontSize: 10);
    }
  }

  /// Мнемоника внизу — она же ответ на все три вопроса сразу.
  void _mnemonic(Canvas canvas) {
    const rect = Rect.fromLTRB(2, 280, 398, 378);
    panel(canvas, rect, fill: colorScheme.surfaceContainerHighest);

    // Перечёркнутый треугольник: «спереди треугольного не бывает».
    const side = 24.0;
    final height = side * math.sqrt(3) / 2;
    canvas.drawPath(
      Path()
        ..moveTo(30, 316 - height / 2)
        ..lineTo(30 + side / 2, 316 + height / 2)
        ..lineTo(30 - side / 2, 316 + height / 2)
        ..close(),
      Paint()..color = kReflectorRed,
    );
    drawCross(canvas, const Offset(30, 316), 14, colorScheme.error, width: 3.4);
    text(canvas, 'напред', const Offset(30, 342), colorScheme.onSurfaceVariant,
        maxWidth: 56, fontSize: 9.5);

    textLeft(
      canvas,
      'Троугласти катадиоптер постоји само ПОЗАДИ и само ЦРВЕН. '
      'Напред су бели и правоугаони — и на приколици, и на возилу '
      'са скривајућим фаровима.'
      '${gloss('\nТреугольный катафот — только сзади и только красный.')}',
      const Offset(58, 329),
      colorScheme.onSurface,
      maxWidth: 330,
      fontSize: 11,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.colorScheme != colorScheme || old.gloss != gloss;
}
