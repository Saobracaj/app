import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';

/// Силуэты ТС сбоку и спереди плюс размерные линии.
///
/// Темы «массы» и «габариты» рисуются тремя листами подряд, и во всех трёх
/// нужны один и тот же грузовик, один и тот же прицеп и одинаковые выноски с
/// размерами. Общая основа нужна ровно за этим: иначе на соседних картинках
/// колёса разного диаметра, а «2,55 m» подписано то сверху, то снизу.
///
/// Цвета кузова литеральные, а не из темы: с `onSurfaceVariant` кузов и шины
/// на тёмной теме сливаются в одно пятно (проверено на прошлых сценах).
const kVoziloBody = Color(0xFF7C8A99);
const kVoziloCab = Color(0xFF5A6875);
const kVoziloGlass = Color(0xFFC9E1F2);
const kVoziloTyre = Color(0xFF1E2126);
const kVoziloRim = Color(0xFFB9C0C7);
const kVoziloStroke = Color(0xFF2B3138);
const kTeret = Color(0xFFC08A3E);
const kKolovoz = Color(0xFF8C939B);

abstract class VoziloScenePainter extends InfoScenePainter {
  VoziloScenePainter(super.colorScheme);

  /// Коловоз: сплошная линия с короткой штриховкой под ней. Нужна, чтобы
  /// стрелки «осовинско оптерећење» было во что упереть.
  void kolovoz(Canvas canvas, double y, double left, double right) {
    canvas.drawLine(
      Offset(left, y),
      Offset(right, y),
      Paint()
        ..color = kKolovoz
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final hatch = Paint()
      ..color = kKolovoz.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    for (var x = left; x < right; x += 12) {
      canvas.drawLine(Offset(x, y + 1), Offset(x - 6, y + 8), hatch);
    }
  }

  void wheel(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = kVoziloTyre);
    canvas.drawCircle(center, radius * 0.45, Paint()..color = kVoziloRim);
  }

  /// Грузовик-бортовик сбоку, носом вправо. [r] — габарит от верха груза до
  /// низа колёс. Груз рисуется отдельным ящиком поверх платформы: в закрытом
  /// фургоне груза не видно, а вся картинка именно про него.
  ///
  /// [cargoSideExtra] и [cargoTopExtra] — свес груза за габарит кузова (для
  /// сцены «терет премашује димензије»). Возвращает центры осей.
  List<Offset> truckSide(
    Canvas canvas,
    Rect r, {
    bool loaded = true,
    double cargoSideExtra = 0,
    double cargoTopExtra = 0,
  }) {
    final w = r.width;
    final h = r.height;
    final wheelR = h * 0.17;
    final chassisY = r.bottom - wheelR;
    final cabW = w * 0.26;
    final cabLeft = r.right - cabW;
    final platformTop = chassisY - h * 0.14;

    final stroke = Paint()
      ..color = kVoziloStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Кабина: скошенное лобовое стекло сразу читается как «перёд».
    final cabTop = r.top + h * 0.30;
    final cabPath = Path()
      ..moveTo(cabLeft, cabTop)
      ..lineTo(r.right - w * 0.06, cabTop)
      ..lineTo(r.right, cabTop + h * 0.16)
      ..lineTo(r.right, chassisY)
      ..lineTo(cabLeft, chassisY)
      ..close();
    canvas.drawPath(cabPath, Paint()..color = kVoziloCab);
    canvas.drawPath(cabPath, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(cabLeft + w * 0.035, cabTop + h * 0.04)
        ..lineTo(r.right - w * 0.075, cabTop + h * 0.04)
        ..lineTo(r.right - w * 0.03, cabTop + h * 0.17)
        ..lineTo(cabLeft + w * 0.035, cabTop + h * 0.17)
        ..close(),
      Paint()..color = kVoziloGlass,
    );

    // Платформа и низкий борт.
    final platform = Rect.fromLTRB(r.left, platformTop, cabLeft - w * 0.01, chassisY);
    canvas.drawRect(platform, Paint()..color = kVoziloBody);
    canvas.drawRect(platform, stroke);

    if (loaded) {
      final cargo = Rect.fromLTRB(
        platform.left - cargoSideExtra,
        r.top - cargoTopExtra,
        platform.right + cargoSideExtra,
        platformTop,
      );
      canvas.drawRect(cargo, Paint()..color = kTeret);
      canvas.drawRect(cargo, stroke);
      // Пара досок, чтобы ящик не читался как просто оранжевый прямоугольник.
      final plank = Paint()
        ..color = kVoziloStroke.withValues(alpha: 0.35)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(cargo.left, cargo.top + cargo.height * 0.34),
        Offset(cargo.right, cargo.top + cargo.height * 0.34),
        plank,
      );
      canvas.drawLine(
        Offset(cargo.center.dx, cargo.top),
        Offset(cargo.center.dx, cargo.bottom),
        plank,
      );
    }

    final axles = [
      Offset(r.left + w * 0.16, chassisY + wheelR * 0.35),
      Offset(cabLeft + cabW * 0.42, chassisY + wheelR * 0.35),
    ];
    for (final axle in axles) {
      wheel(canvas, axle, wheelR);
    }
    return axles;
  }

  /// Легковой автомобиль сбоку, носом вправо.
  void carSide(Canvas canvas, Rect r, {Color body = kVoziloBody}) {
    final w = r.width;
    final h = r.height;
    final wheelR = h * 0.23;
    final bodyBottom = r.bottom - wheelR * 0.7;
    final beltLine = r.top + h * 0.46;

    final stroke = Paint()
      ..color = kVoziloStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final silhouette = Path()
      ..moveTo(r.left, bodyBottom)
      ..lineTo(r.left, beltLine)
      ..lineTo(r.left + w * 0.20, beltLine)
      ..quadraticBezierTo(r.left + w * 0.28, r.top, r.left + w * 0.42, r.top)
      ..lineTo(r.left + w * 0.62, r.top)
      ..quadraticBezierTo(r.left + w * 0.76, r.top + h * 0.06, r.left + w * 0.84,
          beltLine)
      ..lineTo(r.right, beltLine + h * 0.06)
      ..lineTo(r.right, bodyBottom)
      ..close();
    canvas.drawPath(silhouette, Paint()..color = body);
    canvas.drawPath(silhouette, stroke);

    canvas.drawPath(
      Path()
        ..moveTo(r.left + w * 0.24, beltLine - h * 0.04)
        ..quadraticBezierTo(r.left + w * 0.30, r.top + h * 0.06,
            r.left + w * 0.43, r.top + h * 0.06)
        ..lineTo(r.left + w * 0.61, r.top + h * 0.06)
        ..quadraticBezierTo(r.left + w * 0.72, r.top + h * 0.10,
            r.left + w * 0.78, beltLine - h * 0.04)
        ..close(),
      Paint()..color = kVoziloGlass,
    );

    wheel(canvas, Offset(r.left + w * 0.24, bodyBottom + wheelR * 0.35), wheelR);
    wheel(canvas, Offset(r.right - w * 0.20, bodyBottom + wheelR * 0.35), wheelR);
  }

  /// Прицеп сбоку: короб на одной оси и дышло к сцепке в точке [hitch].
  void trailerSide(Canvas canvas, Rect r, Offset hitch) {
    final h = r.height;
    final wheelR = h * 0.26;
    final bodyBottom = r.bottom - wheelR;
    final box = Rect.fromLTRB(r.left, r.top, r.right, bodyBottom);

    canvas.drawRect(box, Paint()..color = kVoziloBody);
    canvas.drawRect(
      box,
      Paint()
        ..color = kVoziloStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Дышло — светлое: тёмный штрих на тёмной теме сливается с фоном, и
    // прицеп выглядит просто стоящим рядом ящиком.
    canvas.drawLine(
      Offset(box.right, bodyBottom - h * 0.10),
      hitch,
      Paint()
        ..color = kVoziloRim
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    wheel(
      canvas,
      Offset(box.center.dx, bodyBottom + wheelR * 0.35),
      wheelR,
    );
  }

  /// Вид спереди — им подписываются ширина и высота. Пропорции [r] задаёт
  /// вызывающий: у «2,55 × 4,00 m» силуэт заметно выше, чем шире, и это часть
  /// содержания картинки.
  void voziloFront(Canvas canvas, Rect r) {
    final w = r.width;
    final h = r.height;
    final stroke = Paint()
      ..color = kVoziloStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final body = RRect.fromRectAndRadius(r, Radius.circular(w * 0.10));
    canvas.drawRRect(body, Paint()..color = kVoziloBody);
    canvas.drawRRect(body, stroke);

    final glass = Rect.fromLTWH(
      r.left + w * 0.12,
      r.top + h * 0.08,
      w * 0.76,
      h * 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glass, Radius.circular(w * 0.06)),
      Paint()..color = kVoziloGlass,
    );

    // Фары и решётка: без них прямоугольник не читается как «вид спереди».
    final lamp = Paint()..color = const Color(0xFFF3D98A);
    for (final dx in [0.20, 0.80]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(r.left + w * dx, r.bottom - h * 0.22),
            width: w * 0.20,
            height: h * 0.06,
          ),
          const Radius.circular(3),
        ),
        lamp,
      );
    }
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(r.center.dx, r.bottom - h * 0.22),
        width: w * 0.34,
        height: h * 0.05,
      ),
      Paint()..color = kVoziloCab,
    );
    // Колёса выглядывают снизу по краям.
    for (final dx in [0.16, 0.84]) {
      canvas.drawRect(
        Rect.fromLTWH(
          r.left + w * dx - w * 0.09,
          r.bottom - h * 0.06,
          w * 0.18,
          h * 0.06,
        ),
        Paint()..color = kVoziloTyre,
      );
    }
  }

  // --- Размерные линии ------------------------------------------------------

  /// Горизонтальный размер: засечки по краям, стрелки внутрь, подпись над или
  /// под линией.
  void dimH(
    Canvas canvas,
    double y,
    double from,
    double to,
    String label, {
    Color? ink,
    double fontSize = 12,
    bool labelAbove = true,
    double whisker = 7,
  }) {
    final color = ink ?? colorScheme.onSurface;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(from, y - whisker), Offset(from, y + whisker), paint);
    canvas.drawLine(Offset(to, y - whisker), Offset(to, y + whisker), paint);
    arrow(canvas, Offset((from + to) / 2, y), Offset(from, y),
        color: color, width: 1.4, head: 7);
    arrow(canvas, Offset((from + to) / 2, y), Offset(to, y),
        color: color, width: 1.4, head: 7);
    final size = measure(label, maxWidth: (to - from).abs() + 90,
        fontSize: fontSize, isBold: true);
    final center = Offset(
      (from + to) / 2,
      labelAbove ? y - whisker - 3 - size.height / 2 : y + whisker + 3 + size.height / 2,
    );
    // Подпись стоит на плашке цвета панели: иначе стрелка проходит сквозь
    // буквы, а плашка цвета surface выглядит на панели заплаткой.
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: size.width + 8,
        height: size.height + 2,
      ),
      Paint()..color = colorScheme.surfaceContainerHighest,
    );
    text(canvas, label, center, color,
        maxWidth: (to - from).abs() + 90, fontSize: fontSize, isBold: true);
  }

  /// Вертикальный размер; подпись — сбоку, а не повёрнутая: повёрнутый текст
  /// в такой мелочи читается заметно хуже.
  void dimV(
    Canvas canvas,
    double x,
    double from,
    double to,
    String label, {
    Color? ink,
    double fontSize = 12,
    bool labelLeft = true,
    double labelWidth = 74,
    double whisker = 7,
  }) {
    final color = ink ?? colorScheme.onSurface;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(x - whisker, from), Offset(x + whisker, from), paint);
    canvas.drawLine(Offset(x - whisker, to), Offset(x + whisker, to), paint);
    final mid = (from + to) / 2;
    arrow(canvas, Offset(x, mid), Offset(x, from),
        color: color, width: 1.4, head: 7);
    arrow(canvas, Offset(x, mid), Offset(x, to),
        color: color, width: 1.4, head: 7);
    final size = measure(label, maxWidth: labelWidth, fontSize: fontSize, isBold: true);
    final center = Offset(
      labelLeft ? x - whisker - 4 - size.width / 2 : x + whisker + 4 + size.width / 2,
      mid,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: size.width + 8,
        height: size.height + 2,
      ),
      Paint()..color = colorScheme.surfaceContainerHighest,
    );
    text(canvas, label, center, color,
        maxWidth: labelWidth, fontSize: fontSize, isBold: true);
  }

  /// Пунктирный габаритный бокс вокруг ТС с грузом.
  void dashedBox(Canvas canvas, Rect r, {Color? color, double dash = 6}) {
    final ink = color ?? colorScheme.outline;
    dashedLine(canvas, r.topLeft, r.topRight, dash: dash, color: ink);
    dashedLine(canvas, r.topRight, r.bottomRight, dash: dash, color: ink);
    dashedLine(canvas, r.bottomRight, r.bottomLeft, dash: dash, color: ink);
    dashedLine(canvas, r.bottomLeft, r.topLeft, dash: dash, color: ink);
  }

  /// Печать-штамп: плашка с текстом, при [crossed] перечёркнутая красным.
  void stamp(
    Canvas canvas,
    Rect r,
    String label, {
    required Color fill,
    required Color ink,
    required Color border,
    bool crossed = false,
    double fontSize = 11.5,
  }) {
    final rrect = RRect.fromRectAndRadius(r, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    text(canvas, label, r.center, ink,
        maxWidth: r.width - 10, fontSize: fontSize, isBold: true);
    if (crossed) {
      canvas.drawLine(
        Offset(r.left + 6, r.bottom - 6),
        Offset(r.right - 6, r.top + 6),
        Paint()
          ..color = kBanRed
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Регистрационная табличка. Красные таблички — сами по себе содержание
  /// вопроса, поэтому цвет литеральный.
  void plate(
    Canvas canvas,
    Rect r,
    String value, {
    Color fill = kBanRed,
    Color ink = Colors.white,
  }) {
    final rrect = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    text(canvas, value, r.center, ink,
        maxWidth: r.width - 8, fontSize: math.min(r.height * 0.5, 16), isBold: true);
  }
}
