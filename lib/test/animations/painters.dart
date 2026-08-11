import 'package:flutter/material.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Общие рисовалки для иллюстраций из `lib/test/animations/`.
///
/// Своя копия `_drawText` была уже в `decision_tree_widget.dart`; чтобы не
/// плодить четвёртую, текст на холсте рисуется отсюда.

/// Рисует [text] на холсте, привязывая его к точке [anchorPoint].
///
/// [anchor] задаёт, какой угол/сторона блока текста попадает в эту точку:
/// [Alignment.center] — центр (подпись под фигурой), [Alignment.centerLeft] —
/// левый край при той же высоте (строка списка).
///
/// `fontFamily` задаётся всегда: без него `TextPainter` берёт системный шрифт,
/// а в тестовом рендере — заглушку с квадратными глифами.
void drawCanvasText(
  Canvas canvas,
  String text,
  Offset anchorPoint,
  Color color, {
  required double maxWidth,
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.normal,
  TextAlign textAlign = TextAlign.center,
  Alignment anchor = Alignment.center,
  double lineHeight = 1.2,
  double letterSpacing = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: kAppFontFamily,
        height: lineHeight,
        letterSpacing: letterSpacing,
      ),
    ),
    textAlign: textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  painter.paint(
    canvas,
    Offset(
      anchorPoint.dx - painter.width * (anchor.x + 1) / 2,
      anchorPoint.dy - painter.height * (anchor.y + 1) / 2,
    ),
  );
}

/// Ширина строки [text] при тех же настройках, что и у [drawCanvasText].
/// Нужна, когда элементы выкладываются в ряд и надо знать, сколько они займут.
double measureCanvasText(
  String text, {
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.normal,
  double letterSpacing = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: kAppFontFamily,
        letterSpacing: letterSpacing,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Общая основа для статичных схем-иллюстраций.
///
/// Вспомогательные рисовалки (текст, стрелка, пунктир, рамка панели, выноска)
/// до этого копировались из файла в файл — здесь они лежат в одном месте, и
/// все схемы получаются одинаковыми на вид: та же толщина линий, тот же
/// радиус скругления, тот же кегль подписей.
///
/// Все цвета берутся из [colorScheme], поэтому схема читается и в тёмной теме.
abstract class IllustrationPainter extends CustomPainter {
  IllustrationPainter(this.colorScheme);

  final ColorScheme colorScheme;

  /// Подпись по центру [center]. Кегль по умолчанию — минимально читаемый
  /// на холсте шириной 400 после [FittedBox]. Возвращает фактический размер
  /// текста: он нужен, когда по подписи надо что-то дорисовать (например,
  /// перечеркнуть её ровно по длине).
  Size text(
    Canvas canvas,
    String value,
    Offset center,
    Color color, {
    required double maxWidth,
    double fontSize = 11,
    bool isBold = false,
    bool isItalic = false,
    TextAlign align = TextAlign.center,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          // Без явного fontFamily в тестовом рендере вместо букв квадраты.
          fontFamily: kAppFontFamily,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          height: 1.2,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
    return painter.size;
  }

  /// Размер подписи без отрисовки — чтобы разложить несколько подписей одну
  /// под другой и гарантированно не дать им наехать друг на друга.
  Size measure(
    String value, {
    required double maxWidth,
    double fontSize = 11,
    bool isBold = false,
    bool isItalic = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: kAppFontFamily,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          height: 1.2,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.size;
  }

  /// Рамка панели: схема из нескольких сюжетов разделяется рамками, иначе
  /// подписи одного сюжета читаются как подписи соседнего.
  void panelFrame(Canvas canvas, Rect rect, {Color? fill, Color? border}) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    if (fill != null) {
      canvas.drawRRect(rrect, Paint()..color = fill);
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border ?? colorScheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Плашка с текстом. [swatch] рисует образец цвета слева (когда стрелка
  /// пересекла бы рисунок), [check] — зелёную галочку, [cross] — крестик.
  void calloutBox(
    Canvas canvas,
    String value,
    Rect rect, {
    Color? fill,
    Color? textColor,
    Color? swatch,
    bool check = false,
    bool cross = false,
    double fontSize = 11,
    bool isBold = false,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
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

    final ink = textColor ?? colorScheme.onSecondaryContainer;
    var textLeft = rect.left + 8;
    if (swatch != null) {
      canvas.drawLine(
        Offset(rect.left + 10, rect.center.dy),
        Offset(rect.left + 26, rect.center.dy),
        Paint()
          ..color = swatch
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      textLeft = rect.left + 34;
    }
    if (check) {
      drawCheck(canvas, Offset(rect.left + 18, rect.center.dy), 9, ink);
      textLeft = rect.left + 34;
    }
    if (cross) {
      drawCross(canvas, Offset(rect.left + 18, rect.center.dy), 8, ink,
          width: 3);
      textLeft = rect.left + 34;
    }

    final width = rect.right - 8 - textLeft;
    text(
      canvas,
      value,
      Offset(textLeft + width / 2, rect.center.dy),
      ink,
      maxWidth: width,
      fontSize: fontSize,
      isBold: isBold,
    );
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
      center + Offset(-size, -size),
      center + Offset(size, size),
      paint,
    );
    canvas.drawLine(
      center + Offset(size, -size),
      center + Offset(-size, size),
      paint,
    );
  }

  /// Крупный крест поверх сюжета — «так нельзя». Полупрозрачным, чтобы под
  /// ним осталось видно, что именно запрещено.
  void crossOutRect(Canvas canvas, Rect rect, Color color, {double width = 5}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, paint);
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

  void dashedRect(Canvas canvas, Rect rect, {Color? color}) {
    dashedLine(canvas, rect.topLeft, rect.topRight, color: color);
    dashedLine(canvas, rect.topRight, rect.bottomRight, color: color);
    dashedLine(canvas, rect.bottomRight, rect.bottomLeft, color: color);
    dashedLine(canvas, rect.bottomLeft, rect.topLeft, color: color);
  }

  void arrow(
    Canvas canvas,
    Offset start,
    Offset end, {
    double width = 2,
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
    const arrowAngle = math.pi / 6;
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - head * math.cos(angle - arrowAngle),
            end.dy - head * math.sin(angle - arrowAngle))
        ..lineTo(end.dx - head * math.cos(angle + arrowAngle),
            end.dy - head * math.sin(angle + arrowAngle))
        ..close(),
      Paint()..color = ink,
    );
  }

  /// Размерная линия: двусторонняя стрелка с засечками по краям. Подпись
  /// рисует вызывающий — она может стоять и над линией, и под ней.
  void dimensionLine(
    Canvas canvas,
    Offset from,
    Offset to, {
    Color? color,
    double tick = 7,
  }) {
    final ink = color ?? colorScheme.primary;
    arrow(canvas, from, to, color: ink, head: 8);
    arrow(canvas, to, from, color: ink, head: 8);
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Засечки перпендикулярны линии — так видно, откуда и докуда меряем.
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx) + math.pi / 2;
    final n = Offset(math.cos(angle), math.sin(angle)) * tick;
    canvas.drawLine(from - n, from + n, paint);
    canvas.drawLine(to - n, to + n, paint);
  }

  /// Пиктограмма человека: голова и туловище. Больше и не нужно — смысл несут
  /// подписи, а не анатомия.
  void person(
    Canvas canvas,
    Offset feet,
    double height,
    Color color, {
    bool sitting = false,
  }) {
    final headR = height * 0.2;
    final paint = Paint()..color = color;
    if (sitting) {
      // Сидящий: торс, бедро вперёд (вправо) и голень вниз — без голени
      // силуэт читается как буква «Г».
      final hip = feet + Offset(0, -height * 0.34);
      final knee = hip + Offset(height * 0.3, 0);
      final limb = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = height * 0.16
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(hip, knee, limb);
      canvas.drawLine(knee, Offset(knee.dx, feet.dy), limb);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            hip.dx - height * 0.14,
            hip.dy - height * 0.46,
            height * 0.28,
            height * 0.46,
          ),
          Radius.circular(height * 0.1),
        ),
        paint,
      );
      canvas.drawCircle(hip + Offset(0, -height * 0.62), headR, paint);
      return;
    }
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
    canvas.drawCircle(feet + Offset(0, -height * 0.78), headR, paint);
  }

  /// Колесо: тёмная покрышка и светлый диск. Цвета можно задать явно — так
  /// колесо остаётся видимым на сцене со своим фоном (например, ночной).
  void wheel(
    Canvas canvas,
    Offset center,
    double radius, {
    Color? tire,
    Color? hub,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = tire ?? colorScheme.onSurface,
    );
    canvas.drawCircle(
      center,
      radius * 0.42,
      Paint()..color = hub ?? colorScheme.surface,
    );
  }
}

/// Палитра силуэта машины. По умолчанию берётся из темы; сцена со своим фоном
/// (ночь, затемнение) задаёт цвета явно, иначе силуэт сливается с фоном.
class VehiclePalette {
  const VehiclePalette({
    required this.body,
    required this.outline,
    required this.glass,
    required this.tire,
  });

  factory VehiclePalette.of(ColorScheme scheme) => VehiclePalette(
        body: scheme.surfaceContainerHighest,
        outline: scheme.outline,
        glass: scheme.surface,
        tire: scheme.onSurface,
      );

  final Color body;
  final Color outline;
  final Color glass;
  final Color tire;
}

/// Что вернула отрисовка силуэта машины: куда класть груз и где границы
/// кузова. Координаты — в системе холста вызывающего.
class VehicleParts {
  const VehicleParts({
    required this.bed,
    required this.cabin,
    required this.frontBumper,
    required this.rearEdge,
    required this.groundY,
  });

  /// Грузовое пространство (у легкового — багажник/крыша) — сюда ложится груз.
  final Rect bed;
  final Rect cabin;

  /// Самая выступающая точка спереди — от неё меряется выступ груза вперёд.
  final double frontBumper;

  /// Задний борт — от него меряется выступ назад.
  final double rearEdge;
  final double groundY;
}

/// Грузовик в профиль, **носом вправо**, вписанный в [rect] (включая колёса).
///
/// Кузов открытый: рисуются пол, задний и передний борта, верх свободен —
/// в него удобно положить груз или посадить (в запрещающих схемах) людей.
VehicleParts drawTruckProfile(
  Canvas canvas,
  IllustrationPainter p,
  Rect rect, {
  VehiclePalette? palette,
  double bedWallHeight = 0.22,
  double cabTop = 0.2,
}) {
  final colors = palette ?? VehiclePalette.of(p.colorScheme);
  final h = rect.height;
  final wheelR = h * 0.15;
  final groundY = rect.bottom;
  final axleY = groundY - wheelR;
  final chassisY = axleY - wheelR * 0.35;

  final outline = Paint()
    ..color = colors.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final fill = Paint()..color = colors.body;

  final cabW = rect.width * 0.26;
  final cabin = Rect.fromLTRB(
    rect.right - cabW,
    rect.top + h * cabTop,
    rect.right,
    chassisY,
  );
  final bedTop = chassisY - h * bedWallHeight * 2;
  final bed = Rect.fromLTRB(rect.left, bedTop, rect.right - cabW - 4, chassisY);

  // Рама между кузовом и кабиной — иначе машина распадается на два блока.
  canvas.drawRect(
    Rect.fromLTRB(rect.left, chassisY - h * 0.06, rect.right, chassisY),
    fill,
  );

  // Кузов: пол и два борта, верх открыт — внутрь видно, что там лежит (или,
  // в запрещающих схемах, кто там сидит).
  final bedPath = Path()
    ..moveTo(bed.left, bed.top)
    ..lineTo(bed.left, bed.bottom)
    ..lineTo(bed.right, bed.bottom)
    ..lineTo(bed.right, bed.top);
  canvas.drawRect(
    Rect.fromLTRB(bed.left, bed.top, bed.left + 7, bed.bottom),
    fill,
  );
  canvas.drawRect(
    Rect.fromLTRB(bed.right - 7, bed.top, bed.right, bed.bottom),
    fill,
  );
  canvas.drawRect(
    Rect.fromLTRB(bed.left, bed.bottom - 9, bed.right, bed.bottom),
    fill,
  );
  canvas.drawPath(bedPath, outline);

  // Кабина со скошенным лобовым стеклом.
  final cabPath = Path()
    ..moveTo(cabin.left, cabin.bottom)
    ..lineTo(cabin.left, cabin.top)
    ..lineTo(cabin.right - cabin.width * 0.3, cabin.top)
    ..lineTo(cabin.right, cabin.top + cabin.height * 0.45)
    ..lineTo(cabin.right, cabin.bottom)
    ..close();
  canvas.drawPath(cabPath, Paint()..color = colors.body);
  canvas.drawPath(cabPath, outline);
  // Окно — светлое пятно, по нему кабина отличается от кузова.
  canvas.drawRect(
    Rect.fromLTRB(
      cabin.left + cabin.width * 0.18,
      cabin.top + cabin.height * 0.12,
      cabin.right - cabin.width * 0.22,
      cabin.top + cabin.height * 0.5,
    ),
    Paint()..color = colors.glass,
  );

  p.wheel(canvas, Offset(rect.left + rect.width * 0.2, axleY), wheelR,
      tire: colors.tire, hub: colors.body);
  p.wheel(canvas, Offset(rect.right - cabW * 0.5, axleY), wheelR,
      tire: colors.tire, hub: colors.body);

  return VehicleParts(
    bed: bed,
    cabin: cabin,
    frontBumper: rect.right,
    rearEdge: rect.left,
    groundY: groundY,
  );
}

/// Легковой автомобиль в профиль, **носом вправо**, вписанный в [rect].
/// `bed` возвращается как площадка на крыше — там в схемах лежит груз.
VehicleParts drawCarProfile(
  Canvas canvas,
  IllustrationPainter p,
  Rect rect, {
  VehiclePalette? palette,
}) {
  final colors = palette ?? VehiclePalette.of(p.colorScheme);
  final h = rect.height;
  final wheelR = h * 0.18;
  final groundY = rect.bottom;
  final axleY = groundY - wheelR;
  final bodyBottom = axleY + wheelR * 0.2;
  final bodyTop = rect.top + h * 0.42;
  final roofTop = rect.top + h * 0.05;

  final outline = Paint()
    ..color = colors.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  final path = Path()
    ..moveTo(rect.left, bodyBottom)
    ..lineTo(rect.left, bodyTop + h * 0.06)
    ..lineTo(rect.left + rect.width * 0.16, bodyTop)
    ..lineTo(rect.left + rect.width * 0.3, roofTop)
    ..lineTo(rect.left + rect.width * 0.62, roofTop)
    ..lineTo(rect.left + rect.width * 0.8, bodyTop)
    ..lineTo(rect.right, bodyTop + h * 0.1)
    ..lineTo(rect.right, bodyBottom)
    ..close();
  canvas.drawPath(path, Paint()..color = colors.body);
  canvas.drawPath(path, outline);

  // Стёкла: по ним силуэт читается как легковой, а не как фургон.
  final glass = Paint()..color = colors.glass;
  canvas.drawPath(
    Path()
      ..moveTo(rect.left + rect.width * 0.32, roofTop + 3)
      ..lineTo(rect.left + rect.width * 0.6, roofTop + 3)
      ..lineTo(rect.left + rect.width * 0.72, bodyTop - 2)
      ..lineTo(rect.left + rect.width * 0.2, bodyTop - 2)
      ..close(),
    glass,
  );

  p.wheel(canvas, Offset(rect.left + rect.width * 0.22, axleY), wheelR,
      tire: colors.tire, hub: colors.body);
  p.wheel(canvas, Offset(rect.right - rect.width * 0.2, axleY), wheelR,
      tire: colors.tire, hub: colors.body);

  return VehicleParts(
    bed: Rect.fromLTRB(
      rect.left + rect.width * 0.3,
      roofTop - 6,
      rect.left + rect.width * 0.62,
      roofTop,
    ),
    cabin: Rect.fromLTRB(
      rect.left + rect.width * 0.2,
      roofTop,
      rect.left + rect.width * 0.72,
      bodyTop,
    ),
    frontBumper: rect.right,
    rearEdge: rect.left,
    groundY: groundY,
  );
}
