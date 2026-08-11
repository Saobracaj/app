import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';
import 'package:saobracaj/test/animations/vozilo_bocno.dart';

/// Четыре числа, которые в этой секции просто надо знать: 12,00 · 18,75 ·
/// 2,55 · 4,00 m.
///
/// Вопросы №8679/№10407 (дужина возила), №8683 (возило са приколицом),
/// №8685 (ширина) и №8687 (висина) отличаются только тем, какой размер
/// назван, а варианты ответов у всех — соседние круглые числа. Поэтому длина
/// показана сбоку (там видно, что сцепка длиннее одиночного ТС), а ширина и
/// высота — спереди: 2,55 против 4,00 сразу видно, что возило выше, чем шире,
/// и числа перестают путаться местами.
class DimenzijeVozila extends StatelessWidget {
  const DimenzijeVozila({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 492,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

class _ScenePainter extends VoziloScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  @override
  void paint(Canvas canvas, Size size) {
    chip(
      canvas,
      'НАЈВЕЋЕ ДОЗВОЉЕНЕ ДИМЕНЗИЈЕ${gloss(' · габариты')}',
      const Rect.fromLTRB(2, 2, 398, 32),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 13,
    );

    _duzina(canvas);
    _sirinaIVisina(canvas);

    chip(
      canvas,
      'замке у одговорима: 2,50 · 2,80 · 4,05 · 4,10 · 16,50',
      const Rect.fromLTRB(2, 454, 398, 488),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      fontSize: 12,
    );
  }

  /// Длина: сцепка целиком и одиночное ТС на одной картинке — так видно, что
  /// 18,75 относится к «возилу са приколицом», а 12,00 — к самому возилу.
  void _duzina(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 40, 398, 240));

    const car = Rect.fromLTRB(238, 112, 368, 170);
    const trailer = Rect.fromLTRB(66, 122, 206, 170);
    trailerSide(canvas, trailer, const Offset(234, 158));
    carSide(canvas, car);
    kolovoz(canvas, 176, 16, 384);

    // «Највише», а не просто число: на картинке нарисован обычный автомобиль,
    // а цифра — это предел для вида ТС, а не длина именно этой машины.
    dimH(canvas, 98, 238, 368, 'моторно возило\nнајвише 12,00 m');
    dimH(
      canvas,
      196,
      66,
      368,
      'путничко возило са приколицом · највише 18,75 m',
      labelAbove: false,
    );
    text(
      canvas,
      'приколица',
      const Offset(136, 110),
      colorScheme.onSurface,
      maxWidth: 130,
      fontSize: 11,
    );
  }

  /// Ширина и высота: вид спереди, пропорции 2,55 × 4,00 выдержаны.
  void _sirinaIVisina(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 248, 398, 446));

    const front = Rect.fromLTRB(168, 264, 252, 396);
    voziloFront(canvas, front);
    kolovoz(canvas, 396, 60, 340);

    dimV(canvas, 132, 264, 396, 'висина\nнајвише\n4,00 m', labelWidth: 78);
    dimH(canvas, 416, 168, 252, 'ширина · највише 2,55 m', labelAbove: false);

    text(
      canvas,
      'висина се мери\nдо највише тачке\n(терет, кров, антена)',
      const Offset(330, 320),
      colorScheme.onSurface,
      maxWidth: 120,
      fontSize: 11,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.gloss != gloss;
}
