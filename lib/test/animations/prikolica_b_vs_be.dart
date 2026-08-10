import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/prikolica_common.dart';

/// Прицеп к категории B против категории BE.
///
/// Три вопроса раздела (№8502, №8505, №8482) держатся на двух числах и одной
/// стрелке: 750 kg — потолок прицепа для B, 3.500 kg — потолок для BE, и BE не
/// выдают тому, у кого нет B. Схема показывает оба состава в одном масштабе,
/// чтобы разница «маленький прицеп / большой прицеп» читалась глазом, а числа
/// стояли рядом с тем прицепом, к которому относятся.
///
/// Отдельная сноска про *носивост* — потому что в №8505 неправильный вариант
/// отличается от правильного ровно этим словом.
class PrikolicaBvsBe extends StatelessWidget {
  const PrikolicaBvsBe({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 482,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

class _ScenePainter extends TrailerScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  static const _top = Rect.fromLTRB(2, 34, 398, 194);
  static const _bottom = Rect.fromLTRB(2, 202, 398, 362);

  @override
  void paint(Canvas canvas, Size size) {
    text(
      canvas,
      'B или BE? Одлучује највећа дозвољена маса приколице',
      const Offset(200, 16),
      colorScheme.onSurface,
      maxWidth: 396,
      fontSize: 12.5,
      isBold: true,
    );

    _row(
      canvas,
      _top,
      chipLabel: 'категорија B',
      chipFill: colorScheme.tertiaryContainer,
      chipInk: colorScheme.onTertiaryContainer,
      mass: 'највећа дозвољена маса\nприколице ≤ 750 kg',
      massRect: const Rect.fromLTRB(196, 76, 392, 112),
      carRect: const Rect.fromLTRB(16, 112, 146, 174),
      trailerRect: const Rect.fromLTRB(178, 130, 240, 174),
    );
    _row(
      canvas,
      _bottom,
      chipLabel: 'категорија BE',
      chipFill: colorScheme.primaryContainer,
      chipInk: colorScheme.onPrimaryContainer,
      mass: 'највећа дозвољена маса\nприколице ≤ 3.500 kg',
      massRect: const Rect.fromLTRB(196, 238, 392, 274),
      carRect: const Rect.fromLTRB(16, 280, 146, 342),
      trailerRect: const Rect.fromLTRB(178, 282, 340, 342),
    );

    _chain(canvas);

    calloutBox(
      canvas,
      'Свуда је реч о НАЈВЕЋОЈ ДОЗВОЉЕНОЈ МАСИ приколице — не о носивости!'
      '${gloss('\n(о наибольшей разрешённой массе, а не о грузоподъёмности)')}',
      const Rect.fromLTRB(2, 422, 398, 478),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      fontSize: 11.5,
      isBold: true,
    );
  }

  /// Одна строка сравнения: термин слева, состав внизу, число — над прицепом.
  /// Число стоит именно над прицепом, а не в общей легенде: в вопросе оно
  /// относится к приколици, и самая частая ошибка — отнести его к составу.
  void _row(
    Canvas canvas,
    Rect rect, {
    required String chipLabel,
    required Color chipFill,
    required Color chipInk,
    required String mass,
    required Rect massRect,
    required Rect carRect,
    required Rect trailerRect,
  }) {
    panel(canvas, rect);

    chip(
      canvas,
      chipLabel,
      Rect.fromLTWH(rect.left + 8, rect.top + 8, 110, 26),
      fill: chipFill,
      ink: chipInk,
    );
    // Земля: тонкая линия вместо полосы асфальта — сцена сравнительная, а не
    // дорожная, лишний асфальт здесь только отвлекает.
    canvas.drawLine(
      Offset(rect.left + 10, carRect.bottom),
      Offset(rect.right - 10, carRect.bottom),
      Paint()
        ..color = colorScheme.outline
        ..strokeWidth = 2.5,
    );

    carSide(canvas, carRect);
    final hitch = Offset(carRect.right + 4, carRect.bottom - 12);
    final nose = Offset(trailerRect.left, trailerRect.bottom - 22);
    towBall(canvas, Offset(carRect.right - 6, carRect.bottom - 18), hitch);
    drawbar(canvas, hitch, nose, spread: 6);
    trailerSide(canvas, trailerRect);

    // Выноска от плашки с массой к кузову прицепа.
    dashedLine(
      canvas,
      Offset(massRect.left + 44, massRect.bottom),
      Offset(trailerRect.left + trailerRect.width / 2, trailerRect.top - 2),
      dash: 4,
      gap: 3,
      width: 1.4,
    );
    calloutBox(
      canvas,
      mass,
      massRect,
      fill: colorScheme.surface,
      ink: colorScheme.onSurface,
      fontSize: 12,
      isBold: true,
    );
  }

  /// «B → BE»: категорию BE выдают только тому, у кого уже есть B (№8482).
  /// Ловушки в вопросе — B1 и A, поэтому стрелка нарисована именно от B.
  void _chain(Canvas canvas) {
    const rect = Rect.fromLTRB(2, 370, 398, 414);
    panel(canvas, rect, fill: colorScheme.surfaceContainerHighest);

    chip(canvas, 'B', const Rect.fromLTRB(14, 380, 54, 404),
        fill: colorScheme.tertiaryContainer,
        ink: colorScheme.onTertiaryContainer);
    arrow(canvas, const Offset(60, 392), const Offset(86, 392),
        color: colorScheme.onSurface, width: 2.5);
    chip(canvas, 'BE', const Rect.fromLTRB(92, 380, 140, 404),
        fill: colorScheme.primaryContainer, ink: colorScheme.onPrimaryContainer);
    textLeft(
      canvas,
      'BE се издаје само возачу који већ има B'
      '${gloss('\nBE выдают только тому, у кого уже есть B')}',
      const Offset(152, 392),
      colorScheme.onSurface,
      maxWidth: 238,
      fontSize: 11.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.colorScheme != colorScheme || old.gloss != gloss;
}
