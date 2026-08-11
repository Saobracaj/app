import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/alkohol_common.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';

/// Единственная цифра раздела «Возач» — 0,20 mg/ml.
///
/// В вопросе №10665 три числа: 0,20, 0,30 и 0,50, и все три выглядят
/// одинаково правдоподобно. На шкале видно, что правильное — самое левое, а
/// два других просто ничего не значат: они нарисованы серыми и перечёркнутыми.
/// Нулевая норма показана отдельной карточкой, потому что это про другое —
/// не про порог, а про список тех, кому нельзя ни грамма.
class SkalaAlkohola extends StatelessWidget {
  const SkalaAlkohola({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 330,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

class _ScenePainter extends AlkoholScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  static const _scale = PromileScale(left: 48, right: 366, axisY: 118, max: 0.6);
  static const _limit = 0.20;

  @override
  void paint(Canvas canvas, Size size) {
    chip(
      canvas,
      'ПОД ДЕЈСТВОМ АЛКОХОЛА: преко 0,20 mg/ml'
      '${gloss(' · порог')}',
      const Rect.fromLTRB(2, 2, 398, 32),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 13.5,
    );

    panel(canvas, const Rect.fromLTRB(2, 40, 398, 246));
    _bars(canvas);
    _ticks(canvas);
    _limitMark(canvas);
    text(
      canvas,
      'крв или алкометар — исти праг'
      '${gloss(' · 0,30 и 0,50 здесь приманки')}',
      const Offset(200, 230),
      colorScheme.onSurfaceVariant,
      maxWidth: 380,
      fontSize: 11,
    );

    _zeroCard(canvas);
  }

  void _bars(Canvas canvas) {
    scaleBar(canvas, _scale, 0, _limit, fill: kSoberFill, ink: kSoberInk);
    scaleBar(canvas, _scale, _limit, 0.6, fill: kDrunkFill, ink: kDrunkInk);

    // Подписи отрезков — плашками ровно под своим отрезком: так не нужно
    // гадать, где заканчивается зелёное и начинается красное.
    chip(
      canvas,
      'НИЈЕ под\nдејством',
      Rect.fromLTRB(_scale.left, 180, _scale.x(_limit) - 3, 214),
      fill: kSoberFill,
      ink: kSoberInk,
      fontSize: 11,
    );
    chip(
      canvas,
      'ПОД ДЕЈСТВОМ алкохола',
      Rect.fromLTRB(_scale.x(_limit) + 3, 180, _scale.right, 214),
      fill: kDrunkFill,
      ink: kDrunkInk,
      fontSize: 12,
    );
  }

  void _ticks(Canvas canvas) {
    scaleTick(canvas, _scale, 0);
    scaleTick(canvas, _scale, 0.6);
    // Серым и перечёркнутым — чтобы приманка не запомнилась как цифра из
    // правила: в этих вопросах 0,30 и 0,50 не значат ничего.
    for (final trap in [0.3, 0.5]) {
      scaleTick(
        canvas,
        _scale,
        trap,
        color: colorScheme.outline,
        crossed: true,
        caption: 'замка',
      );
    }
  }

  /// Сама граница: плашка со значением и вертикаль до шкалы.
  void _limitMark(Canvas canvas) {
    final x = _scale.x(_limit);
    chip(
      canvas,
      '0,20 mg/ml',
      Rect.fromCenter(center: Offset(x, 64), width: 100, height: 26),
      fill: kDrunkInk,
      ink: Colors.white,
      fontSize: 13,
    );
    canvas.drawLine(
      Offset(x, 77),
      Offset(x, _scale.axisY + AlkoholScenePainter.barHeight / 2 + 6),
      Paint()
        ..color = kDrunkInk
        ..strokeWidth = 2.5,
    );
  }

  /// Нулевая норма — вне шкалы: у неё нет «отрезка», это отдельное правило
  /// для списка водителей (см. раздел «Коме ни грам»).
  void _zeroCard(Canvas canvas) {
    const rect = Rect.fromLTRB(2, 254, 398, 326);
    panel(canvas, rect, fill: colorScheme.surfaceContainerHighest);

    canvas.drawCircle(
      const Offset(46, 290),
      13,
      Paint()..color = colorScheme.onSurface,
    );
    text(
      canvas,
      '0,00',
      const Offset(46, 290),
      colorScheme.surface,
      maxWidth: 30,
      fontSize: 11,
      isBold: true,
    );
    glassIcon(canvas, const Offset(84, 290), 30, colorScheme.onSurfaceVariant);

    textLeft(
      canvas,
      'ни грама: професионалци, кандидат за возача,\n'
      'пробна возачка дозвола, право првенства пролаза'
      '${gloss('\n(им порог 0,20 не помогает — нужен ноль)')}',
      const Offset(110, 290),
      colorScheme.onSurface,
      maxWidth: 280,
      fontSize: 11.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.gloss != gloss;
}
