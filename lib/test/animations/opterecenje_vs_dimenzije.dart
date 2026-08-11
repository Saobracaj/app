import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';
import 'package:saobracaj/test/animations/vozilo_bocno.dart';

/// Развилка «масса или габариты»: что нельзя никогда, а что можно с
/// разрешением.
///
/// Все вопросы подкатегории (№8615, №8618, №8621, №10681, №8650) собраны из
/// одного набора вариантов, и выбор в них решается одним вопросом: превышаем
/// массу/осевую нагрузку — *није дозвољено* при любой дозволе; превышаем
/// размеры — можно, но только *уз посебну дозволу надлежног органа*. Третий
/// элемент внизу — красные таблички: они появляются в вариантах всех трёх
/// вопросов и всегда неверны.
class OpterecenjeVsDimenzije extends StatelessWidget {
  const OpterecenjeVsDimenzije({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 430,
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
      'ПРЕКОРАЧЕЊЕ${gloss(' · что можно с разрешением')}',
      const Rect.fromLTRB(2, 2, 398, 34),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 13.5,
    );

    _masaBranch(canvas);
    _dimenzijeBranch(canvas);
    _crveneTablice(canvas);
  }

  /// Левая ветка: масса и осевая нагрузка — запрет без исключений.
  void _masaBranch(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 42, 196, 312));

    chip(
      canvas,
      'укупна маса\nосовинско оптерећење',
      const Rect.fromLTRB(10, 50, 188, 86),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      fontSize: 11.5,
    );

    const truck = Rect.fromLTRB(28, 100, 172, 154);
    final axles = truckSide(canvas, truck);
    kolovoz(canvas, 162, 16, 184);

    // Груз давит сверху, оси давят в коловоз — перегруз показан двумя
    // встречными наборами стрелок, а не одной подписью «тяжело».
    for (final dx in [70.0, 100.0, 130.0]) {
      arrow(canvas, Offset(dx, 92), Offset(dx, 104),
          color: colorScheme.error, width: 2.5, head: 7);
    }
    for (final axle in axles) {
      arrow(canvas, Offset(axle.dx, 168), Offset(axle.dx, 186),
          color: colorScheme.error, width: 3, head: 8);
    }

    stamp(
      canvas,
      const Rect.fromLTRB(20, 196, 178, 232),
      'посебна дозвола',
      fill: colorScheme.surface,
      ink: colorScheme.onSurface,
      border: kBanRed,
      crossed: true,
    );

    chip(
      canvas,
      'НИЈЕ ДОЗВОЉЕНО',
      const Rect.fromLTRB(16, 242, 182, 278),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      fontSize: 13,
    );
    text(
      canvas,
      'ни уз какву дозволу${gloss('\nникогда')}',
      const Offset(99, 294),
      colorScheme.onSurface,
      maxWidth: 176,
      fontSize: 11,
    );
  }

  /// Правая ветка: размеры — можно, но только с разрешением.
  void _dimenzijeBranch(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(204, 42, 398, 312));

    chip(
      canvas,
      'димензије:\nдужина · ширина · висина',
      const Rect.fromLTRB(212, 50, 390, 86),
      fill: colorScheme.tertiaryContainer,
      ink: colorScheme.onTertiaryContainer,
      fontSize: 11.5,
    );

    // Пунктир — разрешённый габарит, груз из него торчит: именно про этот
    // случай спрашивают («терет премашује највеће дозвољене димензије»).
    const truck = Rect.fromLTRB(258, 118, 368, 154);
    truckSide(canvas, truck, cargoSideExtra: 26, cargoTopExtra: 20);
    kolovoz(canvas, 162, 214, 386);
    dashedBox(
      canvas,
      const Rect.fromLTRB(252, 110, 374, 158),
      color: colorScheme.tertiary,
    );
    text(
      canvas,
      'терет прелази габарит',
      const Offset(301, 176),
      colorScheme.onSurface,
      maxWidth: 184,
      fontSize: 11,
    );

    stamp(
      canvas,
      const Rect.fromLTRB(214, 190, 388, 232),
      'посебна дозвола\nнадлежног органа',
      fill: colorScheme.surface,
      ink: colorScheme.onSurface,
      border: colorScheme.tertiary,
    );
    drawCheck(canvas, const Offset(224, 260), 8, colorScheme.tertiary);

    chip(
      canvas,
      'ДОЗВОЉЕНО',
      const Rect.fromLTRB(240, 242, 390, 278),
      fill: colorScheme.tertiaryContainer,
      ink: colorScheme.onTertiaryContainer,
      fontSize: 13,
    );
    text(
      canvas,
      'ванредни превоз${gloss('\nнегабаритная перевозка')}',
      const Offset(301, 294),
      colorScheme.onSurface,
      maxWidth: 180,
      fontSize: 11,
    );
  }

  /// Третий элемент: красные таблички — приманка во всех вопросах темы.
  void _crveneTablice(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 320, 398, 426));

    const plateRect = Rect.fromLTRB(20, 348, 140, 390);
    plate(canvas, plateRect, 'BG 123-AB');
    drawCross(canvas, plateRect.center, 26, kSignInk, width: 4.5);

    text(
      canvas,
      'регистарске таблице црвене боје —\nувек погрешан одговор',
      const Offset(272, 350),
      colorScheme.onSurface,
      maxWidth: 240,
      fontSize: 12,
      isBold: true,
    );
    text(
      canvas,
      'дају се за пробну вожњу, а не за терет.\nиста замка: „највише за 1,5 m“',
      const Offset(272, 392),
      colorScheme.onSurface,
      maxWidth: 240,
      fontSize: 11,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.gloss != gloss;
}
