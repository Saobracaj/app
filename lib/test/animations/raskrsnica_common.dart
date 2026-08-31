import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/auto.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Общая основа для сцен «перекрёсток вид сверху».
///
/// Три сцены — `pravilo-desne-strane`, `klinc-raskrsnica` и
/// `blokirana-raskrsnica` — рисуют один и тот же перекрёсток с одними и теми
/// же машинами, и отличаются только сюжетом. Геометрия и палитра лежат здесь,
/// чтобы во всех трёх дорога, зебра и автомобили выглядели одинаково: иначе
/// пользователь, который смотрит их подряд в одном конспекте, каждый раз
/// заново разбирается, где что нарисовано.

/// Асфальт, разметка и цвета машин не зависят от темы — это их собственный
/// цвет, а не роль в схеме.
const kAsphalt = Color(0xFF4E545B);
const kAsphaltEdge = Color(0xFF3A3F45);
const kMarking = Color(0xFFF2F2F2);
const kCarBlue = Color(0xFF3D7BD6);
const kCarGreen = Color(0xFF3E9B57);
const kCarRed = Color(0xFFD24B45);
const kCarYellow = Color(0xFFE0A32E);
const kCarWhite = Color(0xFFE3E5E8);
const kSignalGreen = Color(0xFF37B24D);
const kForbidden = Color(0xFFD32F2F);

/// Сторона перекрёстка. Названия — по направлению света, а не по «сверху» и
/// «снизу»: так короче в геометрии (север — верх холста).
enum Side { north, east, south, west }

/// Курс машины в радианах: 0 — носом вправо (на восток).
const double kHeadingEast = 0;
const double kHeadingSouth = math.pi / 2;
const double kHeadingWest = math.pi;
const double kHeadingNorth = -math.pi / 2;

abstract class RaskrsnicaPainter extends CustomPainter {
  RaskrsnicaPainter(this.colorScheme);

  final ColorScheme colorScheme;

  // --- Дорога -------------------------------------------------------------

  /// Перекрёсток двух двухполосных дорог. [armHalf] — половина ширины
  /// проезжей части, то есть ширина одной полосы; полоса встречного движения
  /// зеркальна относительно центра.
  ///
  /// [zebra] — стороны, на которых нарисован пешеходный переход, [stopLine] —
  /// стороны, где размечена линия остановки (только на полосе, которая
  /// подъезжает к перекрёстку).
  void intersection(
    Canvas canvas, {
    required Rect area,
    required Offset center,
    double armHalf = 52,
    Set<Side> zebra = const {},
    Set<Side> stopLine = const {},
  }) {
    final asphalt = Paint()..color = kAsphalt;
    final horizontal = Rect.fromLTRB(
      area.left,
      center.dy - armHalf,
      area.right,
      center.dy + armHalf,
    );
    final vertical = Rect.fromLTRB(
      center.dx - armHalf,
      area.top,
      center.dx + armHalf,
      area.bottom,
    );
    canvas.drawRect(horizontal, asphalt);
    canvas.drawRect(vertical, asphalt);

    // Кромки: без них асфальт сливается с тёмным фоном темы.
    final edge = Paint()
      ..color = kAsphaltEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _armEdges(canvas, area, center, armHalf, edge);

    // Осевая прерывистая — только на подходах, внутри перекрёстка разметки
    // нет (это и есть признак перекрёстка на схеме).
    final markingPaint = Paint()
      ..color = kMarking
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    dashedLine(canvas, Offset(area.left, center.dy),
        Offset(center.dx - armHalf, center.dy),
        dash: 12, gap: 10, width: 2.5, color: kMarking);
    dashedLine(canvas, Offset(center.dx + armHalf, center.dy),
        Offset(area.right, center.dy),
        dash: 12, gap: 10, width: 2.5, color: kMarking);
    dashedLine(canvas, Offset(center.dx, area.top),
        Offset(center.dx, center.dy - armHalf),
        dash: 12, gap: 10, width: 2.5, color: kMarking);
    dashedLine(canvas, Offset(center.dx, center.dy + armHalf),
        Offset(center.dx, area.bottom),
        dash: 12, gap: 10, width: 2.5, color: kMarking);
    markingPaint.strokeWidth = 2.5;

    for (final side in zebra) {
      _zebra(canvas, center, armHalf, side);
    }
    for (final side in stopLine) {
      _stopLine(canvas, center, armHalf, side);
    }
  }

  void _armEdges(
    Canvas canvas,
    Rect area,
    Offset center,
    double armHalf,
    Paint edge,
  ) {
    final l = center.dx - armHalf;
    final r = center.dx + armHalf;
    final t = center.dy - armHalf;
    final b = center.dy + armHalf;
    // Каждая кромка обрывается на въезде в перекрёсток.
    canvas.drawLine(Offset(area.left, t), Offset(l, t), edge);
    canvas.drawLine(Offset(area.left, b), Offset(l, b), edge);
    canvas.drawLine(Offset(r, t), Offset(area.right, t), edge);
    canvas.drawLine(Offset(r, b), Offset(area.right, b), edge);
    canvas.drawLine(Offset(l, area.top), Offset(l, t), edge);
    canvas.drawLine(Offset(r, area.top), Offset(r, t), edge);
    canvas.drawLine(Offset(l, b), Offset(l, area.bottom), edge);
    canvas.drawLine(Offset(r, b), Offset(r, area.bottom), edge);
  }

  /// Зебра: полосы поперёк проезжей части сразу за перекрёстком.
  void _zebra(Canvas canvas, Offset center, double armHalf, Side side) {
    const near = 8.0; // отступ от края перекрёстка
    const depth = 26.0; // «глубина» перехода вдоль дороги
    const stripe = 7.0;
    const step = 13.0;
    final paint = Paint()..color = kMarking;

    switch (side) {
      case Side.south:
      case Side.north:
        final top = side == Side.south
            ? center.dy + armHalf + near
            : center.dy - armHalf - near - depth;
        for (var x = center.dx - armHalf + 4;
            x < center.dx + armHalf - 4;
            x += step) {
          canvas.drawRect(Rect.fromLTWH(x, top, stripe, depth), paint);
        }
      case Side.east:
      case Side.west:
        final left = side == Side.east
            ? center.dx + armHalf + near
            : center.dx - armHalf - near - depth;
        for (var y = center.dy - armHalf + 4;
            y < center.dy + armHalf - 4;
            y += step) {
          canvas.drawRect(Rect.fromLTWH(left, y, depth, stripe), paint);
        }
    }
  }

  /// Линия остановки — поперёк той полосы, по которой подъезжают с этой
  /// стороны (движение правостороннее).
  void _stopLine(Canvas canvas, Offset center, double armHalf, Side side) {
    const offset = 52.0; // за зеброй, считая от края перекрёстка
    final paint = Paint()
      ..color = kMarking
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    switch (side) {
      case Side.south:
        final y = center.dy + armHalf + offset;
        canvas.drawLine(
            Offset(center.dx + 2, y), Offset(center.dx + armHalf - 2, y), paint);
      case Side.north:
        final y = center.dy - armHalf - offset;
        canvas.drawLine(
            Offset(center.dx - armHalf + 2, y), Offset(center.dx - 2, y), paint);
      case Side.east:
        final x = center.dx + armHalf + offset;
        canvas.drawLine(Offset(x, center.dy - armHalf + 2),
            Offset(x, center.dy - 2), paint);
      case Side.west:
        final x = center.dx - armHalf - offset;
        canvas.drawLine(Offset(x, center.dy + 2),
            Offset(x, center.dy + armHalf - 2), paint);
    }
  }

  // --- Машина -------------------------------------------------------------

  /// Легковой автомобиль вид сверху. [heading] — курс в радианах (0 — вправо),
  /// [ghost] — полупрозрачный «неправильный» вариант той же машины.
  void car(
    Canvas canvas,
    Offset center,
    double heading,
    Color color, {
    double length = 50,
    double width = 28,
    bool brake = false,
    double opacity = 1,
  }) {
    canvas.save();
    if (opacity < 1) {
      canvas.saveLayer(
        Rect.fromCircle(center: center, radius: length),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading);

    // Кузов — общая машинка из auto.dart (та же, что в «Мимоилажење» и
    // «Претицање»); курс задан поворотом канваса выше.
    paintAutoTopView(
      canvas,
      Rect.fromCenter(center: Offset.zero, width: length, height: width),
      color: color,
      brakeOn: brake,
    );

    canvas.restore();
    if (opacity < 1) canvas.restore();
  }

  /// Кружок с номером над машиной — очередь проезда. Номер виден и на
  /// стоп-кадре, поэтому порядок понятен даже без анимации.
  void orderBadge(Canvas canvas, Offset center, String value, Color fill,
      {Color? ink, double radius = 11}) {
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    text(canvas, value, center, ink ?? Colors.white,
        maxWidth: radius * 2, fontSize: 13, isBold: true);
  }

  // --- Подписи и указатели ------------------------------------------------

  /// Подпись по центру [center]. Возвращает фактический размер текста.
  Size text(
    Canvas canvas,
    String value,
    Offset center,
    Color color, {
    required double maxWidth,
    double fontSize = 12,
    bool isBold = false,
    TextAlign align = TextAlign.center,
  }) {
    final painter = _layout(value,
        maxWidth: maxWidth,
        fontSize: fontSize,
        isBold: isBold,
        align: align,
        color: color);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
    return painter.size;
  }

  /// Размер подписи без отрисовки — чтобы под неё заранее отвести место.
  Size measure(
    String value, {
    required double maxWidth,
    double fontSize = 12,
    bool isBold = false,
  }) =>
      _layout(value,
              maxWidth: maxWidth,
              fontSize: fontSize,
              isBold: isBold,
              align: TextAlign.center,
              color: const Color(0xFF000000))
          .size;

  TextPainter _layout(
    String value, {
    required double maxWidth,
    required double fontSize,
    required bool isBold,
    required TextAlign align,
    required Color color,
  }) =>
      TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            // Без явного fontFamily в тестовом рендере вместо букв квадраты.
            fontFamily: kAppFontFamily,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            height: 1.2,
          ),
        ),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

  /// Подпись поверх асфальта: светлый текст на тёмной подложке. Без подложки
  /// она попадает то на разметку, то на машину и перестаёт читаться.
  Rect roadLabel(
    Canvas canvas,
    String value,
    Offset center, {
    double fontSize = 12,
    double maxWidth = 200,
    Color background = const Color(0xE61B1F24),
    Color ink = const Color(0xFFF2F2F2),
  }) {
    final size =
        measure(value, maxWidth: maxWidth, fontSize: fontSize, isBold: true);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width + 14,
      height: size.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = background,
    );
    text(canvas, value, center, ink,
        maxWidth: maxWidth, fontSize: fontSize, isBold: true);
    return rect;
  }

  /// Плашка-пояснение под сценой. [check] рисует галочку, [cross] — крестик:
  /// смысл не должен держаться на одном лишь цвете.
  void calloutBox(
    Canvas canvas,
    String value,
    Rect rect, {
    Color? fill,
    Color? ink,
    bool check = false,
    bool cross = false,
    double fontSize = 12,
    bool isBold = false,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(
        rrect, Paint()..color = fill ?? colorScheme.secondaryContainer);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final textInk = ink ?? colorScheme.onSecondaryContainer;
    var left = rect.left + 10;
    if (check) {
      drawCheck(canvas, Offset(rect.left + 20, rect.center.dy), 9, textInk);
      left = rect.left + 38;
    }
    if (cross) {
      drawCross(canvas, Offset(rect.left + 20, rect.center.dy), 8, textInk,
          width: 3);
      left = rect.left + 38;
    }
    final width = rect.right - 10 - left;
    text(canvas, value, Offset(left + width / 2, rect.center.dy), textInk,
        maxWidth: width, fontSize: fontSize, isBold: isBold);
  }

  /// Галочку и крест рисуем путём, а не глифами ✓ / ✗: в шрифте их может не
  /// быть, и вместо знака выйдет пустой квадрат.
  void drawCheck(Canvas canvas, Offset center, double size, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - size * 0.9, center.dy)
        ..lineTo(center.dx - size * 0.25, center.dy + size * 0.75)
        ..lineTo(center.dx + size, center.dy - size * 0.9),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size / 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void drawCross(
    Canvas canvas,
    Offset center,
    double size,
    Color color, {
    double width = 4,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        center + Offset(-size, -size), center + Offset(size, size), paint);
    canvas.drawLine(
        center + Offset(size, -size), center + Offset(-size, size), paint);
  }

  void dashedLine(
    Canvas canvas,
    Offset from,
    Offset to, {
    double dash = 6,
    double gap = 4,
    double width = 1.5,
    Color? color,
  }) {
    final paint = Paint()
      ..color = color ?? colorScheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final total = (to - from).distance;
    if (total == 0) return;
    final step = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(from + step * travelled, from + step * end, paint);
      travelled = end + gap;
    }
  }

  void arrow(
    Canvas canvas,
    Offset start,
    Offset end, {
    double width = 2.5,
    Color? color,
    double head = 10,
  }) {
    final ink = color ?? colorScheme.outline;
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    _arrowHead(canvas, end, math.atan2(end.dy - start.dy, end.dx - start.dx),
        head, ink);
  }

  /// Дугообразная стрелка «уступи тому, кто справа»: прямая линия между
  /// машинами прошла бы через перекрёсток и слилась бы с траекториями.
  void curvedArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Offset control, {
    Color? color,
    double width = 2.5,
    double head = 9,
    bool dashed = false,
  }) {
    final ink = color ?? colorScheme.outline;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(dashed ? _dash(path) : path, paint);
    // Направление в конце дуги — касательная, а она идёт из контрольной точки.
    _arrowHead(
        canvas, end, math.atan2(end.dy - control.dy, end.dx - control.dx), head, ink);
  }

  Path _dash(Path source, {double dash = 7, double gap = 5}) {
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

  void _arrowHead(
      Canvas canvas, Offset tip, double angle, double head, Color ink) {
    const spread = math.pi / 6;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - head * math.cos(angle - spread),
            tip.dy - head * math.sin(angle - spread))
        ..lineTo(tip.dx - head * math.cos(angle + spread),
            tip.dy - head * math.sin(angle + spread))
        ..close(),
      Paint()..color = ink,
    );
  }

  /// Светофор сбоку от полосы: корпус с тремя секциями, горит [signal].
  void trafficLight(
    Canvas canvas,
    Offset topLeft, {
    required Color signal,
    bool greenOn = true,
  }) {
    const w = 16.0;
    const h = 40.0;
    final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF23262A),
    );
    final off = Paint()..color = const Color(0xFF3C4147);
    final centers = [
      Offset(rect.center.dx, rect.top + 8),
      Offset(rect.center.dx, rect.center.dy),
      Offset(rect.center.dx, rect.bottom - 8),
    ];
    for (final c in centers) {
      canvas.drawCircle(c, 5, off);
    }
    final lit = greenOn ? centers[2] : centers[0];
    canvas.drawCircle(lit, 5, Paint()..color = signal);
    // Ореол: на маленькой картинке иначе непонятно, какая секция горит.
    canvas.drawCircle(
        lit, 8, Paint()..color = signal.withValues(alpha: 0.28));
  }

  /// Пиктограмма пешехода: голова и туловище. Больше и не нужно — смысл несут
  /// подписи, а не анатомия.
  void person(Canvas canvas, Offset feet, double height, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          feet.dx - height * 0.14,
          feet.dy - height * 0.62,
          height * 0.28,
          height * 0.62,
        ),
        Radius.circular(height * 0.12),
      ),
      paint,
    );
    canvas.drawCircle(feet + Offset(0, -height * 0.78), height * 0.2, paint);
  }

  /// Пиктограмма руки в окне: знак рукой, которым водитель пропускает
  /// другого. Ладонь и четыре пальца — этого достаточно, чтобы прочитать жест.
  void handSign(Canvas canvas, Offset center, Color color, {double size = 14}) {
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center, width: size * 0.8, height: size * 0.75),
        Radius.circular(size * 0.2),
      ),
      paint,
    );
    final finger = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.15
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final x = center.dx - size * 0.3 + i * size * 0.2;
      canvas.drawLine(
        Offset(x, center.dy - size * 0.35),
        Offset(x, center.dy - size * 0.62),
        finger,
      );
    }
    // Большой палец — сбоку, иначе ладонь читается как гребёнка.
    canvas.drawLine(
      Offset(center.dx - size * 0.42, center.dy - size * 0.1),
      Offset(center.dx - size * 0.62, center.dy + size * 0.12),
      finger,
    );
  }
}
