import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Общая основа для схем про остановку и стоянку (`zaustavljeno-vs-parkirano`,
/// `zabrana-zaustavljanja-parkiranja`, `dopunske-table-parkiranje`).
///
/// Все три сцены рисуют одно и то же: кусок проезжей части, бордюр с
/// тротуаром и машину у края. Геометрия и палитра лежат здесь, чтобы во всех
/// трёх дорога и автомобиль выглядели одинаково — иначе читатель, который
/// смотрит их подряд в одном разборе, каждый раз заново разбирается, где что
/// нарисовано.

/// Асфальт, разметка, тротуар и цвета машин — это их собственный цвет, а не
/// роль в схеме, поэтому они не берутся из темы.
const kAsphalt = Color(0xFF4E545B);
const kAsphaltEdge = Color(0xFF3A3F45);
const kMarking = Color(0xFFF2F2F2);
const kSidewalk = Color(0xFF9AA1A9);
const kSidewalkEdge = Color(0xFF6E757C);
const kCarBlue = Color(0xFF3D7BD6);
const kCarRed = Color(0xFFD24B45);
const kCarWhite = Color(0xFFE3E5E8);

/// Красный «запрещено» — тоже смысловая константа: на дорожной схеме он
/// узнаётся мгновенно, а `errorContainer` темы для этого слишком бледен.
const kForbidden = Color(0xFFD32F2F);
const kBikeLane = Color(0xFF2F6E4E);

/// Курс машины в радианах: 0 — носом вправо, дальше по часовой стрелке.
const double kHeadingEast = 0;

abstract class ParkingScenePainter extends CustomPainter {
  ParkingScenePainter(this.colorScheme);

  final ColorScheme colorScheme;

  // --- Дорога -------------------------------------------------------------

  /// Прямой участок дороги вид сверху: асфальт с прерывистой осевой.
  void roadStrip(
    Canvas canvas,
    Rect rect, {
    bool centerLine = true,
  }) {
    canvas.drawRect(rect, Paint()..color = kAsphalt);
    canvas.drawRect(
      rect,
      Paint()
        ..color = kAsphaltEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (centerLine) {
      dashedLine(
        canvas,
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        dash: 12,
        gap: 10,
        width: 2.5,
        color: kMarking,
      );
    }
  }

  /// Тротуар: светлая полоса с бордюрной кромкой со стороны проезжей части.
  void sidewalk(Canvas canvas, Rect rect, {required bool curbAtBottom}) {
    canvas.drawRect(rect, Paint()..color = kSidewalk);
    final curb = Paint()
      ..color = kSidewalkEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final y = curbAtBottom ? rect.bottom : rect.top;
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), curb);
  }

  /// Пешеходный переход поперёк дороги («зебра»).
  void zebra(Canvas canvas, Rect rect) {
    final paint = Paint()..color = kMarking;
    const stripe = 7.0;
    const step = 13.0;
    for (var x = rect.left; x < rect.right - 2; x += step) {
      canvas.drawRect(
        Rect.fromLTWH(x, rect.top + 3, stripe, rect.height - 6),
        paint,
      );
    }
  }

  /// Рельсы поперёк дороги: две пары ниток на шпальном основании.
  void rails(Canvas canvas, Rect rect) {
    final sleeper = Paint()..color = const Color(0xFF6B5B4B);
    canvas.drawRect(rect, sleeper);
    final rail = Paint()
      ..color = const Color(0xFFD7D9DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final x in [rect.left + 5, rect.right - 5]) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), rail);
    }
  }

  // --- Запрет -------------------------------------------------------------

  /// Красная штриховка «здесь нельзя»: диагональные полосы и рамка. Штриховка,
  /// а не заливка — под ней должно быть видно, что именно запрещено (зебра,
  /// рельсы, край перекрёстка).
  void forbiddenZone(Canvas canvas, Rect rect, {double alpha = 0.42}) {
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..color = kForbidden.withValues(alpha: 0.18));
    final stroke = Paint()
      ..color = kForbidden.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (var x = rect.left - rect.height; x < rect.right; x += 12) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        stroke,
      );
    }
    canvas.restore();
    canvas.drawRect(
      rect,
      Paint()
        ..color = kForbidden
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  /// Размерная линия с подписью («5 m»). Стрелки в обе стороны, подпись на
  /// подложке — иначе она теряется на штриховке.
  void dimension(
    Canvas canvas,
    Offset from,
    Offset to,
    String label, {
    double fontSize = 11,
  }) {
    const ink = Color(0xFFFFFFFF);
    arrow(canvas, from, to, color: ink, width: 2, head: 7);
    arrow(canvas, to, from, color: ink, width: 2, head: 7);
    roadLabel(canvas, label, Offset.lerp(from, to, 0.5)!, fontSize: fontSize);
  }

  // --- Машина и человек ---------------------------------------------------

  /// Легковой автомобиль вид сверху. [heading] — курс в радианах (0 — вправо).
  void car(
    Canvas canvas,
    Offset center,
    double heading,
    Color color, {
    double length = 46,
    double width = 25,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading);

    final half = length / 2;
    final halfW = width / 2;

    // Колёса выступают за кузов: нарисованные вровень, они прячутся под ним и
    // силуэт читается как коробка, а не как машина.
    final tyre = Paint()..color = const Color(0xFF23262A);
    for (final x in [half * 0.55, -half * 0.55]) {
      for (final y in [-halfW - 2.5, halfW - 3.5]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 6, y, 12, 6),
            const Radius.circular(2),
          ),
          tyre,
        );
      }
    }

    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(-half, -halfW, half, halfW),
      const Radius.circular(6),
    );
    canvas.drawRRect(body, Paint()..color = color);
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Стёкла: лобовое ближе к носу, заднее — к корме. По ним видно, куда
    // машина смотрит, даже когда стоит.
    final glass = Paint()..color = const Color(0xB3161A1F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(half * 0.25, -halfW + 3, half * 0.62, halfW - 3),
        const Radius.circular(3),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-half * 0.66, -halfW + 3, -half * 0.34, halfW - 3),
        const Radius.circular(3),
      ),
      glass,
    );
    // Крыша светлее кузова — иначе на тёмной теме машина выглядит плоской.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-half * 0.28, -halfW + 3, half * 0.18, halfW - 3),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );

    canvas.restore();
  }

  /// Пиктограмма человека вид сверху: голова и плечи. Больше и не нужно —
  /// смысл несут подписи, а не анатомия. Голова смещена вверх относительно
  /// плеч: нарисованные концентрично, они сливаются в пятно.
  void personTop(Canvas canvas, Offset center, Color color, {double r = 6}) {
    final paint = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, r * 0.5),
        width: r * 2.1,
        height: r * 1.2,
      ),
      paint,
    );
    final head = center + Offset(0, -r * 0.45);
    canvas.drawCircle(head, r * 0.72, paint);
    canvas.drawCircle(
      head,
      r * 0.72,
      Paint()
        ..color = const Color(0x99000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  /// Циферблат с подписью времени: два критерия («сколько» и «вышел ли
  /// водитель») должны читаться как два разных значка.
  void clock(Canvas canvas, Offset center, double radius, Color ink) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final hand = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center + Offset(0, -radius * 0.62), hand);
    canvas.drawLine(center, center + Offset(radius * 0.45, 0), hand);
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
    final painter = _layout(
      value,
      maxWidth: maxWidth,
      fontSize: fontSize,
      isBold: isBold,
      align: align,
      color: color,
    );
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
    return painter.size;
  }

  /// Подпись, прижатая к левому краю [left] — для списков, где рваный правый
  /// край читается лучше, чем центрирование.
  Size textLeft(
    Canvas canvas,
    String value,
    Offset left,
    Color color, {
    required double maxWidth,
    double fontSize = 12,
    bool isBold = false,
  }) {
    final painter = _layout(
      value,
      maxWidth: maxWidth,
      fontSize: fontSize,
      isBold: isBold,
      align: TextAlign.left,
      color: color,
    );
    painter.paint(canvas, Offset(left.dx, left.dy - painter.height / 2));
    return painter.size;
  }

  /// Размер подписи без отрисовки — чтобы под неё заранее отвести место.
  Size measure(
    String value, {
    required double maxWidth,
    double fontSize = 12,
    bool isBold = false,
  }) =>
      _layout(
        value,
        maxWidth: maxWidth,
        fontSize: fontSize,
        isBold: isBold,
        align: TextAlign.center,
        color: const Color(0xFF000000),
      ).size;

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
            height: 1.25,
          ),
        ),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

  /// Подпись поверх асфальта: светлый текст на тёмной подложке. Без подложки
  /// она попадает то на разметку, то на штриховку и перестаёт читаться.
  Rect roadLabel(
    Canvas canvas,
    String value,
    Offset center, {
    double fontSize = 11,
    double maxWidth = 200,
    Color background = const Color(0xE61B1F24),
    Color ink = const Color(0xFFF2F2F2),
  }) {
    final size =
        measure(value, maxWidth: maxWidth, fontSize: fontSize, isBold: true);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width + 12,
      height: size.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = background,
    );
    text(canvas, value, center, ink,
        maxWidth: maxWidth, fontSize: fontSize, isBold: true);
    return rect;
  }

  /// Кружок с номером: связывает место на схеме со строкой легенды.
  void numberBadge(
    Canvas canvas,
    Offset center,
    String value, {
    Color fill = kForbidden,
    Color ink = Colors.white,
    double radius = 10,
  }) {
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    text(canvas, value, center, ink,
        maxWidth: radius * 2.4, fontSize: 12, isBold: true);
  }

  /// Плашка-пояснение. [check] рисует галочку, [cross] — крестик: смысл не
  /// должен держаться на одном лишь цвете.
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
    TextAlign align = TextAlign.center,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(
      rrect,
      Paint()..color = fill ?? colorScheme.secondaryContainer,
    );
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
      drawCheck(canvas, Offset(rect.left + 19, rect.center.dy), 8, textInk);
      left = rect.left + 34;
    }
    if (cross) {
      drawCross(canvas, Offset(rect.left + 19, rect.center.dy), 7, textInk,
          width: 3);
      left = rect.left + 34;
    }
    final width = rect.right - 10 - left;
    if (align == TextAlign.left) {
      textLeft(canvas, value, Offset(left, rect.center.dy), textInk,
          maxWidth: width, fontSize: fontSize, isBold: isBold);
    } else {
      text(canvas, value, Offset(left + width / 2, rect.center.dy), textInk,
          maxWidth: width, fontSize: fontSize, isBold: isBold);
    }
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
    double head = 9,
    bool dashed = false,
  }) {
    final ink = color ?? colorScheme.outline;
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    if (dashed) {
      dashedLine(canvas, start, end, dash: 6, gap: 4, width: width, color: ink);
    } else {
      canvas.drawLine(start, end, paint);
    }
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const spread = math.pi / 6;
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - head * math.cos(angle - spread),
            end.dy - head * math.sin(angle - spread))
        ..lineTo(end.dx - head * math.cos(angle + spread),
            end.dy - head * math.sin(angle + spread))
        ..close(),
      Paint()..color = ink,
    );
  }
}
