// Общие рисовалки для схем «вид сверху»: асфальт, разметка, стрелки, подписи
// и пиктограммы транспорта.
//
// Вынесено сюда, потому что одни и те же куски нужны сразу нескольким сценам
// (autoput_trake, posebne_trake_autoput, autoput_vs_motoput): дорога и машины
// во всём приложении должны выглядеть одинаково, а копия рисовалки в каждом
// файле неизбежно разъезжается.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/theme/app_theme.dart';

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
void drawCarTopView(
  Canvas canvas,
  Rect rect,
  Color body, {
  bool hazardOn = false,
  bool blinkOn = true,
}) {
  final radius = Radius.circular(rect.height * 0.32);
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

  final glass = Paint()..color = Colors.black.withValues(alpha: 0.42);
  // Лобовое — ближе к носу (правому краю), заднее — к корме.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + rect.width * 0.62,
        rect.top + rect.height * 0.18,
        rect.width * 0.16,
        rect.height * 0.64,
      ),
      const Radius.circular(2),
    ),
    glass,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + rect.width * 0.18,
        rect.top + rect.height * 0.2,
        rect.width * 0.12,
        rect.height * 0.6,
      ),
      const Radius.circular(2),
    ),
    glass,
  );
  // Крыша — светлый блик, чтобы силуэт не выглядел плоским пятном.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + rect.width * 0.33,
        rect.top + rect.height * 0.16,
        rect.width * 0.26,
        rect.height * 0.68,
      ),
      const Radius.circular(2),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.16),
  );

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
