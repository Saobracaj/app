import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/auto.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Общие рисовалки для иллюстраций из `lib/test/animations/`.
///
/// Здесь три слоя, выросшие независимо и сведённые в один файл:
/// свободные функции рисования текста, база [IllustrationPainter] со сценами
/// «вид сбоку» и набор `drawScheme*` для схем «вид сверху».

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
}

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

  /// Подпись поверх асфальта: белый текст на тёмной подложке. Без подложки
  /// подпись попадает то на разметку, то на машину и перестаёт читаться, а
  /// двигать её по сцене каждый раз — заведомо хрупко.
  void roadLabel(
    Canvas canvas,
    String value,
    Offset center, {
    double fontSize = 11,
    double maxWidth = 220,
  }) {
    final size =
        measure(value, maxWidth: maxWidth, fontSize: fontSize, isBold: true);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: size.width + 12,
          height: size.height + 6,
        ),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xCC1B1F24),
    );
    text(
      canvas,
      value,
      center,
      const Color(0xFFF2F2F2),
      maxWidth: maxWidth,
      fontSize: fontSize,
      isBold: true,
    );
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

/// Легковой автомобиль **вид сверху**, носом вправо, вписанный в [rect]
/// (включая колёса). Сцены «вид сверху на дорогу» рисуются в координатах
/// холста, поэтому виджет `AnimatedAutoWidget` из `auto.dart` тут не годится:
/// он живёт своим `Timer` и своим `FittedBox`.
///
/// Все дополнительные признаки — маячок, крест скорой, аварийка, смятый
/// перед — включаются флагами: сцена собирается из одной и той же машины, и
/// полицейская от участника отличается ровно тем, чем должна.
void drawCarTopView(
  Canvas canvas,
  IllustrationPainter p,
  Rect rect, {
  required Color body,
  bool noseRight = true,
  bool hazardOn = false,
  bool beacon = false,
  bool ambulanceCross = false,
  bool damagedFront = false,
  bool damagedRear = false,
  bool scratched = false,
  Color? outline,
}) {
  if (!noseRight) {
    // Отражаем относительно центра: геометрия ниже пишется один раз, для
    // машины носом вправо.
    canvas.save();
    canvas.translate(rect.center.dx, 0);
    canvas.scale(-1, 1);
    canvas.translate(-rect.center.dx, 0);
  }

  final scheme = p.colorScheme;
  final l = rect.width;
  final h = rect.height;

  // Кузов чуть уже габарита — зазор остался от старой рисовалки с колёсами,
  // и позиции машин в сценах подогнаны под него.
  final carBody = Rect.fromLTRB(
    rect.left,
    rect.top + h * 0.1,
    rect.right,
    rect.bottom - h * 0.1,
  );

  // Кузов — общая машинка из auto.dart (та же, что в «Мимоилажење» и
  // «Претицање»); признаки сцены (маячок, крест, аварийка, повреждения)
  // рисуются поверх неё.
  paintAutoTopView(canvas, carBody, color: body);

  // Крыша (между стёклами) — опора для маячка и креста скорой.
  final roof = Rect.fromLTRB(
    rect.left + l * 0.34,
    carBody.top + h * 0.12,
    rect.left + l * 0.62,
    carBody.bottom - h * 0.12,
  );

  if (beacon) {
    // Синий маячок поперёк крыши — цвет здесь и есть содержание.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: roof.center,
          width: l * 0.1,
          height: h * 0.66,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF1E63D0),
    );
  }
  if (ambulanceCross) {
    final c = roof.center;
    final arm = h * 0.26;
    final cross = Paint()
      ..color = const Color(0xFFD32F2F)
      ..strokeWidth = h * 0.12
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(c.dx - arm, c.dy), Offset(c.dx + arm, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - arm), Offset(c.dx, c.dy + arm), cross);
  }

  if (hazardOn) {
    // Аварийка: все четыре угла разом. Оранжевый — сигнальный цвет, из темы
    // его не взять.
    final blink = Paint()..color = const Color(0xFFFFA000);
    for (final cx in [rect.left + l * 0.04, rect.right - l * 0.04]) {
      for (final cy in [carBody.top + h * 0.14, carBody.bottom - h * 0.14]) {
        canvas.drawCircle(Offset(cx, cy), h * 0.11, blink);
      }
    }
  }

  if (damagedFront || damagedRear) {
    final crumple = Paint()
      ..color = scheme.onSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final edges = <double>[
      if (damagedFront) rect.right - l * 0.07,
      if (damagedRear) rect.left + l * 0.07,
    ];
    for (final x in edges) {
      final path = Path()..moveTo(x, carBody.top + h * 0.05);
      var up = true;
      for (var y = carBody.top + h * 0.05;
          y < carBody.bottom - h * 0.05;
          y += h * 0.18) {
        path.lineTo(x + (up ? l * 0.035 : -l * 0.035), y + h * 0.09);
        up = !up;
      }
      canvas.drawPath(path, crumple);
    }
  }
  if (scratched) {
    // Царапина: короткие штрихи по борту — «мања материјална штета».
    final scratch = Paint()
      ..color = scheme.onSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < 3; i++) {
      final x = rect.left + l * (0.62 + i * 0.07);
      canvas.drawLine(
        Offset(x, carBody.bottom - h * 0.06),
        Offset(x + l * 0.04, carBody.bottom - h * 0.24),
        scratch,
      );
    }
  }

  if (!noseRight) canvas.restore();
}

/// Пиктограмма человека **вид сверху**: плечи и голова. Ровно столько, чтобы
/// на сцене «вид сверху» человек не путался с предметом.
void drawPersonTopView(
  Canvas canvas,
  Offset center,
  double size,
  Color color, {
  bool lying = false,
}) {
  final paint = Paint()..color = color;
  if (lying) {
    // Лежащий: вытянутое тело, голова сбоку, руки в стороны — силуэт сразу
    // читается как «лице је повређено», а не как пятно на асфальте.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: size * 1.5,
          height: size * 0.5,
        ),
        Radius.circular(size * 0.24),
      ),
      paint,
    );
    canvas.drawCircle(Offset(-size * 0.9, 0), size * 0.32, paint);
    final limb = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-size * 0.2, 0), Offset(size * 0.2, -size * 0.6), limb);
    canvas.drawLine(Offset(size * 0.7, 0), Offset(size * 1.2, size * 0.45), limb);
    canvas.restore();
    return;
  }
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(center.dx, center.dy + size * 0.25),
      width: size * 0.95,
      height: size * 0.62,
    ),
    paint,
  );
  canvas.drawCircle(Offset(center.dx, center.dy - size * 0.22), size * 0.3, paint);
}

/// Асфальт. Литеральный цвет намеренно: разметка белая и жёлтая, и она
/// читается только на тёмном покрытии — в светлой теме тоже.
const Color kAsphalt = Color(0xFF4E535A);

/// Асфальт остановочной полосы и съездов — чуть светлее, чтобы полоса
/// отличалась от ходовых даже без подписи.
const Color kAsphaltShoulder = Color(0xFF6E757E);

/// Разметка.
const Color kLineWhite = Color(0xFFF2F2F2);
const Color kLineYellow = Color(0xFFF5C518);

/// Цвета участников. Разные машины должны различаться с одного взгляда.
const Color kCarBlue = Color(0xFF2E77D0);
const Color kCarGreen = Color(0xFF3C9B57);
const Color kCarRed = Color(0xFFD24B3E);
const Color kCarGrey = Color(0xFFB9C0C8);
const Color kHazardOn = Color(0xFFFF9A22);

/// Подпись на схеме. Всегда со шрифтом темы: без `fontFamily` в тестовом
/// рендере вместо букв получаются квадраты.
///
/// [anchor] — точка привязки, [align] — как относительно неё лежит блок
/// текста (по умолчанию центр).
Size drawSchemeText(
  Canvas canvas,
  String text,
  Offset anchor,
  Color color, {
  double fontSize = 11,
  bool bold = false,
  double maxWidth = 140,
  Alignment align = Alignment.center,
  TextAlign textAlign = TextAlign.center,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: kAppFontFamily,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        height: 1.2,
      ),
    ),
    textAlign: textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  // align == Alignment.center → блок центрирован по anchor;
  // (-1) — левый/верхний край блока в anchor, (1) — правый/нижний.
  final dx = anchor.dx - painter.width * (align.x + 1) / 2;
  final dy = anchor.dy - painter.height * (align.y + 1) / 2;
  painter.paint(canvas, Offset(dx, dy));
  return painter.size;
}

/// Подпись в «плашке» — читается поверх асфальта, где обычный текст теряется.
void drawSchemeChip(
  Canvas canvas,
  String text,
  Offset anchor,
  Color background,
  Color foreground, {
  double fontSize = 11,
  bool bold = false,
  double maxWidth = 150,
  Alignment align = Alignment.center,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: foreground,
        fontSize: fontSize,
        fontFamily: kAppFontFamily,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        height: 1.2,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  const padH = 5.0;
  const padV = 3.0;
  final w = painter.width + padH * 2;
  final h = painter.height + padV * 2;
  final left = anchor.dx - w * (align.x + 1) / 2;
  final top = anchor.dy - h * (align.y + 1) / 2;

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      const Radius.circular(5),
    ),
    Paint()..color = background,
  );
  painter.paint(canvas, Offset(left + padH, top + padV));
}

/// Стрелка от [start] к [end].
void drawSchemeArrow(
  Canvas canvas,
  Offset start,
  Offset end,
  Color color, {
  double strokeWidth = 2,
  double headLength = 9,
}) {
  final line = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(start, end, line);
  _drawArrowHead(canvas, start, end, color, headLength);
}

/// Стрелка по кривой Безье — для съездов и вливающихся полос.
void drawSchemeCurvedArrow(
  Canvas canvas,
  Offset start,
  Offset control,
  Offset end,
  Color color, {
  double strokeWidth = 2,
  double headLength = 9,
}) {
  final path = Path()
    ..moveTo(start.dx, start.dy)
    ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke,
  );
  _drawArrowHead(canvas, control, end, color, headLength);
}

void _drawArrowHead(
  Canvas canvas,
  Offset from,
  Offset tip,
  Color color,
  double length,
) {
  final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
  const spread = math.pi / 7;
  final path = Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(
      tip.dx - length * math.cos(angle - spread),
      tip.dy - length * math.sin(angle - spread),
    )
    ..lineTo(
      tip.dx - length * math.cos(angle + spread),
      tip.dy - length * math.sin(angle + spread),
    )
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

/// Прерывистая линия разметки.
void drawDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Color color, {
  double strokeWidth = 2,
  double dash = 12,
  double gap = 10,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke;
  final total = (end - start).distance;
  if (total == 0) return;
  final step = (end - start) / total;
  var travelled = 0.0;
  while (travelled < total) {
    final segment = math.min(dash, total - travelled);
    canvas.drawLine(
      start + step * travelled,
      start + step * (travelled + segment),
      paint,
    );
    travelled += dash + gap;
  }
}

/// Легковой автомобиль вид сверху, **носом вправо**, вписан в [rect]
/// (длина = ширина прямоугольника).
///
/// [hazardOn] — включённая аварийка (все четыре угла), [blinkOn] — фаза
/// мигания: гасить лампы можно снаружи, не пересобирая машину.
void drawSchematicCarTopView(
  Canvas canvas,
  Rect rect,
  Color body, {
  bool hazardOn = false,
  bool blinkOn = true,
}) {
  // Кузов — общая машинка из auto.dart (та же, что в «Мимоилажење» и
  // «Претицање»). Лампы аварийки схемы рисуем поверх сами — им нужна
  // фаза мигания [blinkOn].
  paintAutoTopView(canvas, rect, color: body);

  if (hazardOn && blinkOn) {
    final lamp = Paint()..color = kHazardOn;
    final r = rect.height * 0.13;
    for (final c in [
      Offset(rect.left + r * 1.4, rect.top + r * 1.4),
      Offset(rect.left + r * 1.4, rect.bottom - r * 1.4),
      Offset(rect.right - r * 1.4, rect.top + r * 1.4),
      Offset(rect.right - r * 1.4, rect.bottom - r * 1.4),
    ]) {
      canvas.drawCircle(c, r, lamp);
    }
  }
}

/// Грузовик вид сверху, носом вправо: кабина + кузов.
void drawTruckTopView(Canvas canvas, Rect rect, Color body) {
  final cabWidth = rect.width * 0.26;
  final boxRect = Rect.fromLTWH(
    rect.left,
    rect.top,
    rect.width - cabWidth - 2,
    rect.height,
  );
  final cabRect = Rect.fromLTWH(
    rect.right - cabWidth,
    rect.top + rect.height * 0.04,
    cabWidth,
    rect.height * 0.92,
  );
  final outline = Paint()
    ..color = Colors.black.withValues(alpha: 0.35)
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;

  canvas.drawRRect(
    RRect.fromRectAndRadius(boxRect, const Radius.circular(2)),
    Paint()..color = kCarGrey,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(boxRect, const Radius.circular(2)),
    outline,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(cabRect, Radius.circular(rect.height * 0.24)),
    Paint()..color = body,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(cabRect, Radius.circular(rect.height * 0.24)),
    outline,
  );
}

/// Автобус вид сверху, носом вправо.
void drawBusTopView(Canvas canvas, Rect rect, Color body) {
  final radius = Radius.circular(rect.height * 0.28);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, radius),
    Paint()..color = body,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, radius),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke,
  );
  final glass = Paint()..color = Colors.black.withValues(alpha: 0.4);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.right - rect.width * 0.12,
        rect.top + rect.height * 0.16,
        rect.width * 0.07,
        rect.height * 0.68,
      ),
      const Radius.circular(2),
    ),
    glass,
  );
  // Ряд окон вдоль борта — этого хватает, чтобы автобус читался автобусом.
  for (var i = 0; i < 4; i++) {
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left + rect.width * (0.12 + i * 0.17),
        rect.top + rect.height * 0.14,
        rect.width * 0.11,
        rect.height * 0.12,
      ),
      glass,
    );
  }
}
