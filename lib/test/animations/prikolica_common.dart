import 'dart:math' as math;

// easy_localization реэкспортирует свой TextDirection и перекрывает
// одноимённый тип из dart:ui, которым пользуется TextPainter.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Общая основа для схем про прицеп (`prikolica-b-vs-be`,
/// `katadiopteri-na-prikolici`, `raskinuta-veza-prikolice`).
///
/// Все три сцены рисуют одно и то же тело: легковой автомобиль сбоку, прицеп с
/// дышлом и сцепным узлом. Геометрия и палитра лежат здесь, чтобы прицеп в
/// разделе про категории и прицеп в разделе про тормоза выглядели одинаково —
/// иначе читатель, который встречает их в разных конспектах, каждый раз
/// заново разбирается, где что нарисовано.

/// Кузов, асфальт и резина — это их собственный цвет, а не роль в схеме,
/// поэтому они не берутся из темы.
const kCarBlue = Color(0xFF3D7BD6);
const kTrailerBody = Color(0xFF8B929B);
const kTrailerEdge = Color(0xFF5C626A);
const kTyre = Color(0xFF23262A);
const kAsphalt = Color(0xFF4E545B);
const kMarking = Color(0xFFF2F2F2);
const kGlass = Color(0xB3161A1F);

/// Цвета катафотов — содержание вопроса №8755/№8757, а не оформление.
const kReflectorWhite = Color(0xFFF4F5F7);
const kReflectorRed = Color(0xFFD32F2F);

/// Русские пояснения к сербским терминам. Сербский термин остаётся как есть
/// (он и есть содержание вопроса), а перевод показывается только тем, кто
/// читает конспект по-русски: сербу русская подпись — лишний шум.
///
/// Через локаль, а не через `LocaleKeys`: строки живут ровно в одном месте
/// вместе с картинкой, которую поясняют, и не тянут за собой прогон codegen.
@immutable
class Gloss {
  const Gloss(this.isRussian);

  factory Gloss.of(BuildContext context) =>
      Gloss(context.locale.languageCode == 'ru');

  final bool isRussian;

  /// Русский перевод или пустая строка — вызывающий сам решает, рисовать ли.
  String call(String russian) => isRussian ? russian : '';

  @override
  bool operator ==(Object other) =>
      other is Gloss && other.isRussian == isRussian;

  @override
  int get hashCode => isRussian.hashCode;
}

abstract class TrailerScenePainter extends CustomPainter {
  TrailerScenePainter(this.colorScheme);

  final ColorScheme colorScheme;

  // --- Транспорт ----------------------------------------------------------

  /// Легковой автомобиль сбоку. [rect] — габарит вместе с колёсами, колёса
  /// стоят на `rect.bottom`. При [facingLeft] сцена зеркалится: тягач смотрит
  /// влево, а прицеп цепляется справа — так состав читается слева направо
  /// («вот машина, вот что она тянет»).
  void carSide(Canvas canvas, Rect rect, {bool facingLeft = true}) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    if (facingLeft) {
      canvas.translate(rect.width, 0);
      canvas.scale(-1, 1);
    }

    final w = rect.width;
    final h = rect.height;
    final wheelR = h * 0.17;
    // Кузов приподнят над колёсами: без клиренса под ним не остаётся места
    // для сцепного узла, а именно он в этих схемах и есть содержание.
    final bodyBottom = h - wheelR * 1.35;
    final bodyTop = bodyBottom - h * 0.34;
    final roofTop = bodyTop - h * 0.30;

    // Крыша рисуется трапецией отдельно от кузова: силуэт «коробка со
    // скруглениями» без неё не читается как легковая машина.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.24, bodyTop + 2)
        ..lineTo(w * 0.38, roofTop)
        ..lineTo(w * 0.70, roofTop)
        ..lineTo(w * 0.80, bodyTop + 2)
        ..close(),
      Paint()..color = kCarBlue,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, bodyTop)
        ..lineTo(w * 0.40, roofTop + 4)
        ..lineTo(w * 0.68, roofTop + 4)
        ..lineTo(w * 0.76, bodyTop)
        ..close(),
      Paint()..color = kGlass,
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, bodyTop, w, bodyBottom),
      Radius.circular(h * 0.09),
    );
    canvas.drawRRect(body, Paint()..color = kCarBlue);
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    for (final x in [w * 0.22, w * 0.78]) {
      wheel(canvas, Offset(x, bodyBottom), wheelR);
    }
    canvas.restore();
  }

  /// Кузов прицепа сбоку: ящик на одной оси. [rect] — габарит вместе с
  /// колесом, колесо стоит на `rect.bottom`.
  void trailerSide(Canvas canvas, Rect rect) {
    final wheelR = rect.height * 0.19;
    final bodyBottom = rect.bottom - wheelR;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(rect.left, rect.top, rect.right, bodyBottom),
      const Radius.circular(4),
    );
    canvas.drawRRect(body, Paint()..color = kTrailerBody);
    canvas.drawRRect(
      body,
      Paint()
        ..color = kTrailerEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    // Борт: полоска вдоль верха, чтобы ящик не выглядел заливкой.
    canvas.drawLine(
      Offset(rect.left + 4, rect.top + 7),
      Offset(rect.right - 4, rect.top + 7),
      Paint()
        ..color = kTrailerEdge
        ..strokeWidth = 1.2,
    );
    wheel(canvas, Offset(rect.center.dx, bodyBottom), wheelR);
  }

  void wheel(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = kTyre);
    canvas.drawCircle(
      center,
      radius * 0.42,
      Paint()..color = const Color(0xFF9BA1A8),
    );
  }

  /// Дышло (*руда*) от сцепной точки [hitch] до кузова прицепа [nose]:
  /// треугольная рама, как у настоящего лёгкого прицепа.
  void drawbar(
    Canvas canvas,
    Offset hitch,
    Offset nose, {
    double spread = 9,
    Color? color,
    double width = 4,
  }) {
    final paint = Paint()
      ..color = color ?? kTrailerEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hitch, nose + Offset(0, -spread), paint);
    canvas.drawLine(hitch, nose + Offset(0, spread), paint);
  }

  /// Сцепной шар на кронштейне тягача. [base] — точка крепления к кузову,
  /// [ball] — центр шара.
  void towBall(Canvas canvas, Offset base, Offset ball) {
    canvas.drawLine(
      base,
      ball + const Offset(0, 6),
      Paint()
        ..color = kTrailerEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(ball, 6, Paint()..color = const Color(0xFF3F454C));
  }

  /// Сцепная головка прицепа — «чашка», которая надевается на шар. Рисуется
  /// отдельно от дышла: именно её сход с шара и есть событие анимации.
  void couplingHead(
    Canvas canvas,
    Offset center, {
    double angle = 0,
    Color? color,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      Path()
        ..moveTo(-3, -7)
        ..lineTo(10, -7)
        ..lineTo(10, 7)
        ..lineTo(-3, 7)
        ..arcToPoint(const Offset(-3, -7), radius: const Radius.circular(7))
        ..close(),
      Paint()..color = color ?? kTrailerEdge,
    );
    canvas.restore();
  }

  // --- Фон ----------------------------------------------------------------

  /// Полоса асфальта. Не берётся из темы: серый асфальт — узнаваемый признак
  /// того, что мы смотрим на дорогу, а не на схему.
  void asphalt(Canvas canvas, Rect rect, {bool centerLine = false}) {
    canvas.drawRect(rect, Paint()..color = kAsphalt);
    if (centerLine) {
      dashedLine(
        canvas,
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        dash: 14,
        gap: 12,
        width: 3,
        color: kMarking,
      );
    }
  }

  /// Карточка-панель под одну мысль.
  void panel(Canvas canvas, Rect rect, {Color? fill, double radius = 12}) {
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rrect,
      Paint()..color = fill ?? colorScheme.surfaceContainerHighest,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Плашка с коротким термином («категорија B»).
  void chip(
    Canvas canvas,
    String value,
    Rect rect, {
    required Color fill,
    required Color ink,
    double fontSize = 13,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = fill,
    );
    text(canvas, value, rect.center, ink,
        maxWidth: rect.width - 8, fontSize: fontSize, isBold: true);
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
    panel(canvas, rect, fill: fill ?? colorScheme.secondaryContainer);
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

  /// Подпись, прижатая к левому краю — для списков, где рваный правый край
  /// читается лучше, чем центрирование.
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
  /// она сливается с разметкой и перестаёт читаться.
  Rect roadLabel(
    Canvas canvas,
    String value,
    Offset center, {
    double fontSize = 11,
    double maxWidth = 220,
    Color background = const Color(0xE61B1F24),
    Color ink = const Color(0xFFF2F2F2),
    bool isBold = true,
  }) {
    final size =
        measure(value, maxWidth: maxWidth, fontSize: fontSize, isBold: isBold);
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
        maxWidth: maxWidth, fontSize: fontSize, isBold: isBold);
    return rect;
  }

  /// Размерная линия с подписью («0,15 m»): стрелки в обе стороны.
  void dimension(
    Canvas canvas,
    Offset from,
    Offset to,
    String label, {
    double fontSize = 11,
    Color? color,
    Offset labelOffset = const Offset(0, -10),
  }) {
    final ink = color ?? colorScheme.onSurface;
    arrow(canvas, from, to, color: ink, width: 1.6, head: 6);
    arrow(canvas, to, from, color: ink, width: 1.6, head: 6);
    text(canvas, label, Offset.lerp(from, to, 0.5)! + labelOffset, ink,
        maxWidth: 140, fontSize: fontSize, isBold: true);
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
