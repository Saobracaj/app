import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/parkiranje_common.dart';

/// Сводная схема «где нельзя заустављати и паркирати».
///
/// Вопросы подкатегории 140 — это два десятка почти одинаковых формулировок
/// «Возач не сме да заустави или паркира возило: …», и вся разница между
/// вариантами ответа в одном числе: 5 m, 10 m или «само на самом месту».
/// Списком это не запоминается, поэтому все запретные места собраны на одной
/// улице: у мест «с расстоянием» красная зона нарисована и подписана
/// размерной линией, у мест «всегда» она покрывает объект целиком.
///
/// Нумерация на схеме совпадает с легендой внизу: легенда группирует места не
/// по названию, а по числу — 5 m, 15 m, всегда. Именно это число и
/// спрашивают.
class ZabranaZaustavljanjaParkiranja extends StatelessWidget {
  const ZabranaZaustavljanjaParkiranja({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 710,
          child: CustomPaint(painter: _ScenePainter(scheme)),
        ),
      ),
    );
  }
}

class _ScenePainter extends ParkingScenePainter {
  _ScenePainter(super.colorScheme);

  /// Масштаб схемы: 5 метров — 40 пикселей. Он один на всю картинку, поэтому
  /// зона у остановки (15 m) втрое длиннее зоны у перехода — это видно
  /// глазом, без чтения подписей.
  static const _metre = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    text(
      canvas,
      'Возач не сме да заустави, нити да паркира возило:',
      const Offset(200, 13),
      colorScheme.onSurface,
      maxWidth: 396,
      fontSize: 13,
      isBold: true,
    );

    _bandCrossingAndJunction(canvas);
    _bandBusStopAndBikeLane(canvas);
    _bandRailBridgeTunnel(canvas);
    _bandCurveAndCrest(canvas);
    _legend(canvas);
  }

  // --- Полоса 1: тротуар, пешеходный переход, перекрёсток -----------------

  void _bandCrossingAndJunction(Canvas canvas) {
    const walkTop = Rect.fromLTRB(0, 32, 400, 50);
    const road = Rect.fromLTRB(0, 50, 400, 138);
    const walkBottom = Rect.fromLTRB(0, 138, 400, 156);

    sidewalk(canvas, walkTop, curbAtBottom: true);
    roadStrip(canvas, road);
    sidewalk(canvas, walkBottom, curbAtBottom: false);

    // Поперечная улица перекрёстка уходит вниз, разрывая тротуар.
    const cross = Rect.fromLTRB(250, 138, 330, 156);
    canvas.drawRect(cross, Paint()..color = kAsphalt);

    // 3 — тротуар: запрещён целиком, без всяких расстояний. Штриховкой
    // помечены оба тротуара, иначе нижний читается как разрешённый.
    forbiddenZone(canvas, walkTop, alpha: 0.3);
    forbiddenZone(canvas, const Rect.fromLTRB(0, 138, 250, 156), alpha: 0.3);
    forbiddenZone(canvas, const Rect.fromLTRB(330, 138, 400, 156), alpha: 0.3);
    roadLabel(canvas, 'тротоар и пешачка стаза', const Offset(292, 41),
        fontSize: 10.5);
    numberBadge(canvas, const Offset(14, 41), '3');

    // 1 — пешеходный переход и 5 m перед ним и за ним.
    const zebraRect = Rect.fromLTRB(96, 50, 140, 138);
    zebra(canvas, zebraRect);
    forbiddenZone(canvas, const Rect.fromLTRB(56, 50, 180, 138));
    zebra(canvas, zebraRect); // поверх штриховки: переход должен быть виден
    dimension(canvas, const Offset(56, 128), const Offset(96, 128), '5 m');
    dimension(canvas, const Offset(140, 128), const Offset(180, 128), '5 m');
    numberBadge(canvas, const Offset(118, 62), '1');

    // 2 — перекрёсток: 5 m от ближайшего края поперечной проезжей части.
    forbiddenZone(canvas, Rect.fromLTRB(250 - 5 * _metre, 50, 330 + 5 * _metre, 138));
    dimension(canvas, const Offset(210, 128), const Offset(250, 128), '5 m');
    dimension(canvas, const Offset(330, 128), const Offset(370, 128), '5 m');
    numberBadge(canvas, const Offset(290, 62), '2');
    // Подпись внутри зоны, а не над поперечной улицей: иначе она закрывает
    // сам съезд, по которому перекрёсток и опознаётся.
    roadLabel(canvas, 'раскрсница', const Offset(290, 110), fontSize: 10.5);
  }

  // --- Полоса 2: остановка транспорта и велополоса ------------------------

  void _bandBusStopAndBikeLane(Canvas canvas) {
    const walk = Rect.fromLTRB(0, 172, 400, 190);
    const bike = Rect.fromLTRB(0, 190, 400, 206);
    const road = Rect.fromLTRB(0, 206, 400, 296);

    sidewalk(canvas, walk, curbAtBottom: true);
    canvas.drawRect(bike, Paint()..color = kBikeLane);
    roadStrip(canvas, road);

    // 5 — велодорожка и велополоса: запрет без расстояний.
    forbiddenZone(canvas, bike, alpha: 0.34);
    roadLabel(canvas, 'бициклистичка стаза и трака', const Offset(300, 198),
        fontSize: 10.5);
    numberBadge(canvas, const Offset(14, 198), '5');

    // 4 — остановка общественного транспорта: 15 m в обе стороны от разметки.
    const markLeft = 170.0;
    const markRight = 250.0;
    forbiddenZone(
      canvas,
      const Rect.fromLTRB(markLeft - 15 * _metre, 206, markRight + 15 * _metre, 296),
    );
    // Разметка остановки: жёлтый контур на асфальте, внутри стоит автобус.
    canvas.drawRect(
      const Rect.fromLTRB(markLeft, 250, markRight, 292),
      Paint()
        ..color = const Color(0xFFE0A32E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    car(canvas, const Offset(210, 271), kHeadingEast, kCarWhite,
        length: 72, width: 26);
    dimension(canvas, const Offset(50, 224), const Offset(markLeft, 224), '15 m');
    dimension(canvas, const Offset(markRight, 224), const Offset(370, 224), '15 m');
    numberBadge(canvas, const Offset(210, 240), '4');
    text(canvas, 'стајалиште возила јавног превоза', const Offset(200, 306),
        colorScheme.onSurface,
        maxWidth: 300, fontSize: 10.5);
  }

  // --- Полоса 3: пути, мост, тоннель --------------------------------------

  void _bandRailBridgeTunnel(Canvas canvas) {
    const road = Rect.fromLTRB(0, 322, 400, 430);
    roadStrip(canvas, road);

    // 6 — переезд через пути: 5 m перед и за ним.
    const railRect = Rect.fromLTRB(44, 322, 76, 430);
    rails(canvas, railRect);
    forbiddenZone(canvas, const Rect.fromLTRB(4, 322, 116, 430));
    rails(canvas, railRect);
    dimension(canvas, const Offset(4, 420), const Offset(44, 420), '5 m');
    dimension(canvas, const Offset(76, 420), const Offset(116, 420), '5 m');
    numberBadge(canvas, const Offset(60, 334), '6');

    // 7 — мост и путепровод: запрещено на всём сооружении.
    const bridge = Rect.fromLTRB(140, 322, 258, 430);
    final railing = Paint()
      ..color = kSidewalk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawLine(const Offset(140, 324), const Offset(258, 324), railing);
    canvas.drawLine(const Offset(140, 428), const Offset(258, 428), railing);
    forbiddenZone(canvas, bridge);
    numberBadge(canvas, const Offset(199, 334), '7');

    // 8 — тоннель и подземный переезд: тоже целиком.
    const tunnel = Rect.fromLTRB(288, 322, 400, 430);
    canvas.drawRect(tunnel, Paint()..color = const Color(0xFF20242A));
    canvas.drawArc(
      const Rect.fromLTRB(276, 322, 300, 430),
      -1.4,
      2.8,
      false,
      Paint()
        ..color = kSidewalk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    forbiddenZone(canvas, tunnel);
    numberBadge(canvas, const Offset(344, 334), '8');

    for (final caption in const [
      ('пруга и трамвајске шине', 60.0),
      ('мост, надвожњак', 199.0),
      ('тунел, подвожњак', 344.0),
    ]) {
      text(canvas, caption.$1, Offset(caption.$2, 440), colorScheme.onSurface,
          maxWidth: 130, fontSize: 10.5);
    }
  }

  // --- Полоса 4: непросматриваемый поворот и вершина подъёма --------------

  void _bandCurveAndCrest(Canvas canvas) {
    const left = Rect.fromLTRB(2, 456, 196, 556);
    const right = Rect.fromLTRB(204, 456, 398, 556);
    for (final rect in [left, right]) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(
        rrect,
        Paint()..color = colorScheme.surfaceContainerHighest,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = colorScheme.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Слева — поворот вид сверху: дорога уходит за поворот, стоящую машину
    // из-за него не видно.
    final bend = Path()
      ..moveTo(16, 548)
      ..quadraticBezierTo(120, 548, 130, 480);
    canvas.drawPath(
      bend,
      Paint()
        ..color = kAsphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..strokeCap = StrokeCap.butt,
    );
    canvas.drawPath(
      bend,
      Paint()
        ..color = kForbidden.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34,
    );
    // Осевая по дуге: без неё красная лента не читается как дорога.
    canvas.drawPath(
      _dashPath(bend),
      Paint()
        ..color = kMarking
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    car(canvas, const Offset(108, 522), -0.9, kCarRed, length: 34, width: 19);
    drawCross(canvas, const Offset(64, 492), 9, kForbidden, width: 4);
    numberBadge(canvas, const Offset(16, 470), '9');
    text(canvas, 'непрегледна кривина', const Offset(99, 470),
        colorScheme.onSurface,
        maxWidth: 180, fontSize: 11, isBold: true);

    // Справа — профиль подъёма: у самой вершины встречный водитель увидит
    // машину слишком поздно.
    final hill = Path()
      ..moveTo(212, 548)
      ..quadraticBezierTo(300, 470, 390, 548)
      ..lineTo(212, 548)
      ..close();
    canvas.drawPath(hill, Paint()..color = kSidewalk);
    canvas.drawPath(
      Path()
        ..moveTo(212, 548)
        ..quadraticBezierTo(300, 470, 390, 548),
      Paint()
        ..color = kAsphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    _carSide(canvas, const Offset(288, 496), kCarRed);
    drawCross(canvas, const Offset(342, 492), 9, kForbidden, width: 4);
    numberBadge(canvas, const Offset(218, 470), '9');
    text(canvas, 'врх превоја', const Offset(301, 470), colorScheme.onSurface,
        maxWidth: 180, fontSize: 11, isBold: true);
  }

  /// Пунктир по кривой: прямой `dashedLine` для дуги не годится.
  Path _dashPath(Path source, {double dash = 9, double gap = 7}) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        result.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gap;
      }
    }
    return result;
  }

  /// Машина сбоку — только для профиля подъёма: вид сверху на склоне не
  /// читается как «вершина», а весь смысл этой врезки в профиле.
  void _carSide(Canvas canvas, Offset center, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.32); // машина стоит на склоне
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-17, -6, 17, 3),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-8, -12, 8, -5),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
    final tyre = Paint()..color = const Color(0xFF23262A);
    canvas.drawCircle(const Offset(-10, 4), 3.5, tyre);
    canvas.drawCircle(const Offset(10, 4), 3.5, tyre);
    canvas.restore();
  }

  // --- Легенда ------------------------------------------------------------

  void _legend(Canvas canvas) {
    // Легенда сгруппирована по расстоянию, а не по названию места: в вариантах
    // ответа спрашивают именно число.
    calloutBox(
      canvas,
      '5 m испред и иза: 1 пешачки прелаз · 2 раскрсница · 6 прелаз преко '
      'пруге, трамвајских шина и бициклистичке стазе',
      const Rect.fromLTRB(2, 572, 398, 612),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      fontSize: 11,
      align: TextAlign.left,
    );
    calloutBox(
      canvas,
      '15 m испред и иза ознаке: 4 стајалиште возила јавног превоза',
      const Rect.fromLTRB(2, 618, 398, 646),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      fontSize: 11,
      align: TextAlign.left,
    );
    calloutBox(
      canvas,
      'увек: 3 тротоар и пешачка стаза · 5 бициклистичка стаза и трака · '
      '7 мост и надвожњак · 8 тунел и подвожњак · 9 непрегледна кривина и '
      'врх превоја',
      const Rect.fromLTRB(2, 652, 398, 706),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      fontSize: 11,
      align: TextAlign.left,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme;
}
