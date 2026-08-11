import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';
import 'package:saobracaj/test/animations/vozilo_bocno.dart';

/// Пять терминов про массу, которые в вопросах постоянно подменяют друг другом.
///
/// №7977 (укупна маса = маса возила + лица и терет), №7981 (осовинско
/// оптерећење — доля общей массы, которой одна ось давит на коловоз в покое),
/// №10683 (маса празног возила — то, что декларирует производитель),
/// №10685 (носивост = НДМ − маса возила) и №10686 (НДМ декларирует
/// производитель). Все варианты ответов во всех пяти — один и тот же список
/// терминов, поэтому картинка показывает не «как выглядит грузовик», а кто из
/// терминов чему равен: сверху — откуда берётся каждая масса, ниже — две
/// формулы и граница, которую нельзя переходить.
class MaseVozila extends StatelessWidget {
  const MaseVozila({super.key});

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
      'МАСЕ ВОЗИЛА${gloss(' · кто есть кто')}',
      const Rect.fromLTRB(2, 2, 398, 32),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 13.5,
    );

    _truckPanel(canvas);
    _ukupnaMasa(canvas);
    _nosivost(canvas);

    chip(
      canvas,
      'укупна маса ≤ НДМ   ·   осовинско оптерећење ≤ произвођачка таблица',
      const Rect.fromLTRB(2, 428, 398, 466),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 12,
    );
  }

  /// Верхний лист: откуда берётся каждая масса на самом ТС.
  void _truckPanel(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 40, 398, 244));

    const truck = Rect.fromLTRB(104, 78, 336, 168);
    final axles = truckSide(canvas, truck);
    kolovoz(canvas, 178, 24, 380);

    // Люди — в кабине: «лица» из определения это не абстракция, а пассажиры.
    personIcon(canvas, const Offset(300, 138), 22, kVoziloGlass);
    personIcon(canvas, const Offset(316, 138), 22, kVoziloGlass);

    // Выноска слева — про само возило, справа — про то, чем оно нагружено.
    text(
      canvas,
      'маса возила${gloss('\nтолько сама машина')}',
      const Offset(52, 66),
      colorScheme.onSurface,
      maxWidth: 92,
      fontSize: 12,
      isBold: true,
    );
    arrow(canvas, const Offset(52, 92), const Offset(112, 150));

    text(
      canvas,
      'лица + терет',
      const Offset(322, 56),
      colorScheme.onSurface,
      maxWidth: 130,
      fontSize: 12,
      isBold: true,
    );
    // Две выноски от одной подписи: терет — в кузов, лица — в кабину.
    arrow(canvas, const Offset(288, 62), const Offset(230, 88));
    arrow(canvas, const Offset(342, 70), const Offset(330, 102));

    // Осевые нагрузки: стрелка вниз от каждого колеса в коловоз.
    for (final axle in axles) {
      arrow(
        canvas,
        Offset(axle.dx, 186),
        Offset(axle.dx, 206),
        color: colorScheme.error,
        width: 3,
        head: 8,
      );
    }
    text(
      canvas,
      'осовинско оптерећење — колико једна осовина '
      'притиска коловоз док возило мирује',
      const Offset(200, 222),
      colorScheme.onSurface,
      maxWidth: 372,
      fontSize: 11.5,
    );
  }

  /// Формула укупне масе.
  void _ukupnaMasa(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 252, 398, 334));

    _formulaRow(
      canvas,
      top: 262,
      left: 'маса\nвозила',
      operator: '+',
      middle: 'лица\n+ терет',
      result: 'УКУПНА\nМАСА',
      resultFill: colorScheme.secondaryContainer,
      resultInk: colorScheme.onSecondaryContainer,
    );
    text(
      canvas,
      'маса празног возила = возило без терета и лица '
      '(гориво и опрема се рачунају)',
      const Offset(200, 320),
      colorScheme.onSurface,
      maxWidth: 372,
      fontSize: 11,
    );
  }

  /// Формула носивости — единственное место, где НДМ участвует в вычитании.
  void _nosivost(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 342, 398, 420));

    _formulaRow(
      canvas,
      top: 352,
      left: 'НАЈВЕЋА\nДОЗВОЉЕНА МАСА',
      operator: '−',
      middle: 'маса\nвозила',
      result: 'НОСИВОСТ',
      leftFill: colorScheme.errorContainer,
      leftInk: colorScheme.onErrorContainer,
      resultFill: colorScheme.tertiaryContainer,
      resultInk: colorScheme.onTertiaryContainer,
      leftFontSize: 10.5,
    );
    text(
      canvas,
      'НДМ = највећа дозвољена маса, декларише је произвођач',
      const Offset(200, 402),
      colorScheme.onSurface,
      maxWidth: 372,
      fontSize: 11,
    );
  }

  /// Строка «A ⊕ B = C»: три плашки и два знака между ними.
  void _formulaRow(
    Canvas canvas, {
    required double top,
    required String left,
    required String operator,
    required String middle,
    required String result,
    required Color resultFill,
    required Color resultInk,
    Color? leftFill,
    Color? leftInk,
    double leftFontSize = 11.5,
  }) {
    const height = 42.0;
    final boxes = [
      const Rect.fromLTWH(10, 0, 116, height),
      const Rect.fromLTWH(150, 0, 100, height),
      const Rect.fromLTWH(274, 0, 116, height),
    ].map((it) => it.translate(0, top)).toList();

    chip(
      canvas,
      left,
      boxes[0],
      fill: leftFill ?? colorScheme.surface,
      ink: leftInk ?? colorScheme.onSurface,
      fontSize: leftFontSize,
    );
    chip(
      canvas,
      middle,
      boxes[1],
      fill: colorScheme.surface,
      ink: colorScheme.onSurface,
      fontSize: 11.5,
    );
    chip(canvas, result, boxes[2], fill: resultFill, ink: resultInk, fontSize: 12.5);

    text(canvas, operator, Offset(138, top + height / 2), colorScheme.onSurface,
        maxWidth: 24, fontSize: 20, isBold: true);
    text(canvas, '=', Offset(262, top + height / 2), colorScheme.onSurface,
        maxWidth: 24, fontSize: 20, isBold: true);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.gloss != gloss;
}
