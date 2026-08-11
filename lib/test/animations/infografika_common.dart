import 'dart:math' as math;

// easy_localization реэкспортирует свой TextDirection и перекрывает
// одноимённый тип из dart:ui, которым пользуется TextPainter.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Общая основа для схем-инфографик: карточка, плашка, подпись, стрелка,
/// крестик и мелкие пиктограммы.
///
/// В отличие от дорожных сцен здесь нет ни асфальта, ни движения: содержание
/// несут короткий сербский термин и значок рядом с ним. Общая база нужна, чтобы
/// у всех таких листов совпадали радиусы, отступы и кегль — иначе два конспекта
/// подряд выглядят как из разных приложений.

/// Русские пояснения к сербским терминам. Сербский термин остаётся как есть
/// (он и есть содержание вопроса), а перевод показывается только тем, кто
/// читает конспект по-русски.
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

/// Красный «запрещающий» цвет — это содержание (перечёркнуто, нельзя), а не
/// оформление, поэтому он не берётся из темы: на обеих темах он одинаковый.
const kBanRed = Color(0xFFD32F2F);
const kSignFace = Color(0xFFF7F7F7);
const kSignInk = Color(0xFF17191C);

abstract class InfoScenePainter extends CustomPainter {
  InfoScenePainter(this.colorScheme);

  final ColorScheme colorScheme;

  // --- Блоки --------------------------------------------------------------

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

  /// Плашка с коротким термином («аутопут», «пробна возачка дозвола»).
  void chip(
    Canvas canvas,
    String value,
    Rect rect, {
    required Color fill,
    required Color ink,
    double fontSize = 13,
    double radius = 8,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = fill,
    );
    text(
      canvas,
      value,
      rect.center,
      ink,
      maxWidth: rect.width - 8,
      fontSize: fontSize,
      isBold: true,
    );
  }

  // --- Подписи ------------------------------------------------------------

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
  /// читается лучше, чем центрирование. [left] — середина левого края.
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

  // --- Указатели и знаки --------------------------------------------------

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

  /// Косая черта запрета поверх пиктограммы. Отдельно от [drawCross], потому
  /// что «перечёркнуто одной чертой» — это знакомый знак «нельзя», а крест из
  /// двух линий читается как «ошибка».
  void banSlash(Canvas canvas, Offset center, double radius, {double width = 4}) {
    final d = radius * 0.72;
    canvas.drawLine(
      center + Offset(-d, d),
      center + Offset(d, -d),
      Paint()
        ..color = kBanRed
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Круг запрета с косой чертой — «нельзя» вокруг иконки.
  void banRing(Canvas canvas, Offset center, double radius, {double width = 4}) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = kBanRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
    banSlash(canvas, center, radius, width: width);
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

  // --- Пиктограммы --------------------------------------------------------

  /// Человечек: круг-голова и трапеция-плечи. Пиктограммы достаточно —
  /// фотореализм в схеме только мешает.
  void personIcon(Canvas canvas, Offset center, double height, Color color) {
    final headR = height * 0.22;
    final fill = Paint()..color = color;
    canvas.drawCircle(
      Offset(center.dx, center.dy - height / 2 + headR),
      headR,
      fill,
    );
    final bodyTop = center.dy - height / 2 + headR * 2.4;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - height * 0.30, center.dy + height / 2)
        ..lineTo(center.dx - height * 0.20, bodyTop)
        ..lineTo(center.dx + height * 0.20, bodyTop)
        ..lineTo(center.dx + height * 0.30, center.dy + height / 2)
        ..close(),
      fill,
    );
  }

  /// Круглый знак ограничения скорости: белое поле, красный обод, число.
  /// Цвета литеральные — у дорожного знака цвет и есть содержание.
  void speedSign(
    Canvas canvas,
    Offset center,
    double radius,
    String value, {
    double opacity = 1,
    bool crossedOut = false,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = kSignFace.withValues(alpha: opacity),
    );
    canvas.drawCircle(
      center,
      radius - radius * 0.11,
      Paint()
        ..color = kBanRed.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.22,
    );
    text(
      canvas,
      value,
      center,
      kSignInk.withValues(alpha: opacity),
      maxWidth: radius * 1.7,
      fontSize: radius * 0.78,
      isBold: true,
    );
    if (crossedOut) {
      canvas.drawLine(
        center + Offset(-radius, radius),
        center + Offset(radius, -radius),
        Paint()
          ..color = kBanRed
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Легковой автомобиль вид сверху, носом вверх. [rect] — габарит кузова.
  void carTop(Canvas canvas, Rect rect, Color body, Color glass) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.width * 0.28),
    );
    canvas.drawRRect(rrect, Paint()..color = body);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Лобовое и заднее стёкла плюс крыша между ними — без них силуэт сверху
    // читается как просто скруглённый прямоугольник.
    final w = rect.width;
    final h = rect.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + w * 0.16,
          rect.top + h * 0.14,
          w * 0.68,
          h * 0.12,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + w * 0.16,
          rect.top + h * 0.68,
          w * 0.68,
          h * 0.12,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + w * 0.12,
          rect.top + h * 0.30,
          w * 0.76,
          h * 0.34,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0x22000000),
    );
  }

  @override
  bool shouldRepaint(covariant InfoScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme;
}
