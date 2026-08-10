import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/parkiranje_common.dart';

/// «Заустављање» против «паркирања».
///
/// На экзамене эту пару спрашивают через один и тот же сюжет: «прекид кретања
/// возила од два минута» — и ответ переворачивается только от того, вышел ли
/// водитель из машины (№7937 и №7938). Поэтому схема показывает **два
/// критерия сразу**: сколько длится перерыв и остался ли водитель в машине —
/// и подписывает, каким союзом они связаны. У заустављања это «И» (оба
/// условия), у паркирања — «ИЛИ» (достаточно одного).
///
/// Внизу — следствие, которое спрашивают отдельно (№7960, №7961): колонну
/// образуют только заустављена возила, паркирана — нет.
class ZaustavljenoVsParkirano extends StatelessWidget {
  const ZaustavljenoVsParkirano({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 524,
          child: CustomPaint(painter: _ScenePainter(scheme)),
        ),
      ),
    );
  }
}

class _ScenePainter extends ParkingScenePainter {
  _ScenePainter(super.colorScheme);

  static const _left = Rect.fromLTRB(2, 42, 196, 302);
  static const _right = Rect.fromLTRB(204, 42, 398, 302);

  @override
  void paint(Canvas canvas, Size size) {
    text(
      canvas,
      'Прекид кретања возила: гледају се два податка —\n'
      'колико траје и да ли возач напушта возило',
      const Offset(200, 18),
      colorScheme.onSurface,
      maxWidth: 396,
      fontSize: 12.5,
      isBold: true,
    );

    _panel(
      canvas,
      _left,
      title: 'ЗАУСТАВЉАЊЕ',
      titleFill: colorScheme.tertiaryContainer,
      titleInk: colorScheme.onTertiaryContainer,
      driverInside: true,
      time: 'до 3 минута',
      connector: 'И',
      driverLine: 'возач НЕ\nнапушта возило',
    );
    _panel(
      canvas,
      _right,
      title: 'ПАРКИРАЊЕ',
      titleFill: colorScheme.primaryContainer,
      titleInk: colorScheme.onPrimaryContainer,
      driverInside: false,
      time: 'дуже од 3 минута',
      connector: 'ИЛИ',
      driverLine: 'возач\nнапушта возило',
    );

    _examRows(canvas);

    calloutBox(
      canvas,
      'Прекид ради поступања по знаку или правилу (црвено светло,\n'
      'пропуштање пешака) није ни заустављање ни паркирање',
      const Rect.fromLTRB(2, 378, 398, 416),
      fill: colorScheme.secondaryContainer,
      ink: colorScheme.onSecondaryContainer,
      fontSize: 11.5,
    );

    _kolonaRows(canvas);
  }

  /// Одна из двух колонок: заголовок-термин, сценка и два критерия, между
  /// которыми стоит союз. Союз — главное отличие: «И» требует обоих условий,
  /// «ИЛИ» довольствуется любым.
  void _panel(
    Canvas canvas,
    Rect rect, {
    required String title,
    required Color titleFill,
    required Color titleInk,
    required bool driverInside,
    required String time,
    required String connector,
    required String driverLine,
  }) {
    final body = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(
      body,
      Paint()..color = colorScheme.surfaceContainerHighest,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final titleRect = Rect.fromLTRB(rect.left, rect.top, rect.right, rect.top + 28);
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(titleRect, Paint()..color = titleFill);
    canvas.restore();
    text(canvas, title, titleRect.center, titleInk,
        maxWidth: rect.width - 8, fontSize: 14, isBold: true);

    _scene(canvas, rect, driverInside: driverInside);

    // Строка «сколько длится»: часы плюс срок.
    final timeRect = Rect.fromLTRB(rect.left + 8, 186, rect.right - 8, 216);
    calloutBox(canvas, '', timeRect, fill: colorScheme.surface);
    clock(canvas, Offset(timeRect.left + 20, timeRect.center.dy), 10,
        colorScheme.onSurface);
    text(canvas, time, Offset(timeRect.center.dx + 14, timeRect.center.dy),
        colorScheme.onSurface,
        maxWidth: timeRect.width - 50, fontSize: 12.5, isBold: true);

    text(canvas, connector, Offset(rect.center.dx, 228), colorScheme.primary,
        maxWidth: 80, fontSize: 14, isBold: true);

    // Строка «вышел ли водитель» — второй критерий.
    final driverRect = Rect.fromLTRB(rect.left + 8, 240, rect.right - 8, 292);
    calloutBox(canvas, '', driverRect, fill: colorScheme.surface);
    personTop(canvas, Offset(driverRect.left + 22, driverRect.center.dy),
        colorScheme.onSurface);
    text(
      canvas,
      driverLine,
      Offset(driverRect.center.dx + 16, driverRect.center.dy),
      colorScheme.onSurface,
      maxWidth: driverRect.width - 52,
      fontSize: 12.5,
      isBold: true,
    );
  }

  /// Сценка «машина у тротуара»: одинаковая в обеих колонках, отличается
  /// только тем, где нарисован водитель. Это и есть весь вопрос.
  void _scene(Canvas canvas, Rect panel, {required bool driverInside}) {
    final scene = Rect.fromLTRB(panel.left + 8, 74, panel.right - 8, 176);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(scene, const Radius.circular(8)),
    );

    final walk = Rect.fromLTRB(scene.left, scene.top, scene.right, scene.top + 26);
    sidewalk(canvas, walk, curbAtBottom: true);
    roadStrip(
      canvas,
      Rect.fromLTRB(scene.left, walk.bottom, scene.right, scene.bottom),
      centerLine: false,
    );
    dashedLine(
      canvas,
      Offset(scene.left, scene.bottom - 12),
      Offset(scene.right, scene.bottom - 12),
      dash: 12,
      gap: 10,
      width: 2.5,
      color: kMarking,
    );

    // Машина стоит вплотную к тротуару: и заустављање, и паркирање делаются
    // «непосредно уз десну ивицу коловоза», посреди дороги их не бывает.
    final carCenter = Offset(scene.center.dx - 6, walk.bottom + 18);
    car(canvas, carCenter, kHeadingEast, kCarBlue, length: 58, width: 28);

    if (driverInside) {
      // Водитель за рулём: пиктограмма сидит на месте водителя, у левого
      // борта ближе к носу.
      personTop(canvas, carCenter + const Offset(9, -5), kCarWhite, r: 5);
      roadLabel(canvas, 'возач у возилу', Offset(scene.center.dx, scene.bottom - 26));
    } else {
      // Водитель ушёл: пиктограмма уже на тротуаре, пунктирная стрелка
      // показывает, что он вышел и удаляется.
      final person = Offset(scene.right - 26, walk.center.dy);
      arrow(canvas, carCenter + const Offset(14, -12), person + const Offset(-14, 4),
          color: kMarking, width: 2, head: 7, dashed: true);
      personTop(canvas, person, kForbidden, r: 6);
      roadLabel(canvas, 'возач изашао', Offset(scene.center.dx, scene.bottom - 26));
    }

    canvas.restore();
  }

  /// Две строчки ровно в формулировках вопросов №7937 и №7938: одинаковые два
  /// минуты, разный ответ.
  void _examRows(Canvas canvas) {
    text(
      canvas,
      'Прекид од 2 минута — одговор зависи само од возача:',
      const Offset(200, 320),
      colorScheme.onSurface,
      maxWidth: 396,
      fontSize: 12,
      isBold: true,
    );
    calloutBox(
      canvas,
      'возач није напустио возило → заустављање',
      const Rect.fromLTRB(2, 332, 198, 368),
      fill: colorScheme.tertiaryContainer,
      ink: colorScheme.onTertiaryContainer,
      fontSize: 11.5,
    );
    calloutBox(
      canvas,
      'возач је напустио возило → паркирање',
      const Rect.fromLTRB(202, 332, 398, 368),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 11.5,
    );
  }

  /// Следствие, которое спрашивают отдельным вопросом: колонна — это только
  /// заустављена возила.
  void _kolonaRows(Canvas canvas) {
    text(
      canvas,
      'Колона возила = најмање три возила једно иза другог:',
      const Offset(200, 432),
      colorScheme.onSurface,
      maxWidth: 396,
      fontSize: 12,
      isBold: true,
    );
    calloutBox(
      canvas,
      'заустављена возила јесу колона возила',
      const Rect.fromLTRB(2, 444, 398, 478),
      fill: colorScheme.tertiaryContainer,
      ink: colorScheme.onTertiaryContainer,
      check: true,
      fontSize: 12,
    );
    calloutBox(
      canvas,
      'паркирана возила нису колона возила',
      const Rect.fromLTRB(2, 484, 398, 518),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      cross: true,
      fontSize: 12,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme;
}
