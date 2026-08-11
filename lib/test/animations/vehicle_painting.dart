import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Общие рисовалки для сцен про спецтранспорт: машина вид сверху,
/// проблесковые маячки, «волны» сирены, текст на холсте.
///
/// Вынесено в отдельный файл, потому что статичная схема `posebni-signali`
/// и анимация `propustanje-vozila-s-prvenstvom` рисуют одни и те же ТС:
/// если рисовать их дважды, машины в двух картинках разъедутся по виду.

/// Один проблесковый маячок на крыше.
///
/// [intensity] — насколько он сейчас «горит» (0 — тёмный корпус, 1 — вспышка
/// с ореолом). Через неё делается попеременное мигание красного и синего.
class Beacon {
  const Beacon(this.color, {this.intensity = 1});

  final Color color;
  final double intensity;
}

/// Легковой автомобиль вид сверху, **носом вправо**, вписанный в [rect]
/// (ширина прямоугольника — длина машины, высота — её ширина).
///
/// Все размеры считаются в долях от [rect], поэтому машину можно рисовать
/// любого масштаба: в схеме она крупная, в дорожной сцене — мелкая.
void paintTopViewCar(
  Canvas canvas,
  Rect rect, {
  required Color body,
  required Color outline,
  Color? roofStripe,
  List<Beacon> beacons = const [],
  bool brakeLights = false,
  bool hazardOn = false,
  double hazardIntensity = 1,
  bool facingLeft = false,
}) {
  // Встречная машина — та же самая, только зеркально: рисовать её вторым
  // набором координат значит держать две геометрии вместо одной.
  if (facingLeft) {
    canvas.save();
    canvas.translate(rect.center.dx * 2, 0);
    canvas.scale(-1, 1);
  }

  final w = rect.width;
  final h = rect.height;
  double x(double t) => rect.left + w * t;
  double y(double t) => rect.top + h * t;

  final glass = Color.lerp(body, Colors.black, 0.55)!;
  final darker = Color.lerp(body, Colors.black, 0.3)!;

  // Колёса выступают за корпус — так вид сверху читается как машина,
  // а не как прямоугольник.
  final wheel = Paint()..color = const Color(0xFF1A1A1A);
  for (final wx in const [0.18, 0.66]) {
    for (final wy in const [-1.0, 1.0]) {
      final r = Rect.fromLTWH(
        x(wx),
        wy < 0 ? y(0) - h * 0.09 : y(1) - h * 0.05,
        w * 0.17,
        h * 0.14,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(h * 0.05)),
        wheel,
      );
    }
  }

  final bodyRect = RRect.fromRectAndRadius(rect, Radius.circular(h * 0.26));
  canvas.drawRRect(bodyRect, Paint()..color = body);
  canvas.drawRRect(
    bodyRect,
    Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, h * 0.03),
  );

  // Лобовое и заднее стёкла + крыша между ними.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(x(0.56), y(0.16), x(0.72), y(0.84)),
      Radius.circular(h * 0.12),
    ),
    Paint()..color = glass,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(x(0.2), y(0.18), x(0.31), y(0.82)),
      Radius.circular(h * 0.12),
    ),
    Paint()..color = glass,
  );
  canvas.drawRect(
    Rect.fromLTRB(x(0.31), y(0.13), x(0.56), y(0.87)),
    Paint()..color = darker,
  );

  // Полоса ливреи вдоль машины: по ней спецтранспорт узнаётся даже на
  // мелком масштабе, где маячок — две точки.
  if (roofStripe != null) {
    canvas.drawRect(
      Rect.fromLTRB(x(0.08), y(0.42), x(0.92), y(0.58)),
      Paint()..color = roofStripe,
    );
  }

  // Стоп-сигналы — по ним видно, что ТС останавливается, а не просто стоит.
  if (brakeLights) {
    final stop = Paint()..color = const Color(0xFFE53935);
    for (final ly in const [0.16, 0.66]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x(0.01), y(ly), x(0.06), y(ly + 0.18)),
          Radius.circular(h * 0.06),
        ),
        stop,
      );
    }
  }

  // Аварийка: все четыре угла жёлтым.
  if (hazardOn) {
    final blink = Paint()
      ..color = const Color(0xFFFFC107)
          .withValues(alpha: 0.25 + 0.75 * hazardIntensity);
    for (final cx in const [0.04, 0.94]) {
      for (final cy in const [0.14, 0.72]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x(cx), y(cy), w * 0.04, h * 0.16),
            Radius.circular(h * 0.05),
          ),
          blink,
        );
      }
    }
  }

  _paintBeacons(canvas, rect, beacons);

  if (facingLeft) canvas.restore();
}

/// Маячки в ряд поперёк крыши, ближе к её переднему краю.
void _paintBeacons(Canvas canvas, Rect rect, List<Beacon> beacons) {
  if (beacons.isEmpty) return;

  final h = rect.height;
  final barWidth = rect.width * 0.12;
  final barLeft = rect.left + rect.width * 0.42;
  final slot = h * 0.8 / beacons.length;
  final top = rect.top + h * 0.1;

  for (var i = 0; i < beacons.length; i++) {
    final beacon = beacons[i];
    final r = Rect.fromLTWH(
      barLeft,
      top + slot * i + slot * 0.12,
      barWidth,
      slot * 0.76,
    );
    // Ореол вспышки: без него на маленьком масштабе маячок теряется.
    // Радиус считается от ширины маячка, а не от его высоты, иначе у
    // одиночного маячка ореол расползается на пол-картинки.
    if (beacon.intensity > 0.05) {
      canvas.drawCircle(
        r.center,
        barWidth * (0.8 + 0.5 * beacon.intensity),
        Paint()
          ..color = beacon.color.withValues(alpha: 0.35 * beacon.intensity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.09),
      );
    }
    final rrect = RRect.fromRectAndRadius(r, Radius.circular(h * 0.07));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Color.lerp(
          Color.lerp(beacon.color, Colors.black, 0.55)!,
          beacon.color,
          beacon.intensity,
        )!,
    );
    // Тёмный кант: жёлтый маячок на жёлтой машине без него не виден.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF212121)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, h * 0.025),
    );
  }
}

/// «Волны» сирены — три дуги, расходящиеся от [origin] в сторону [toRight].
void paintSirenWaves(
  Canvas canvas,
  Offset origin, {
  required Color color,
  double size = 18,
  bool toRight = true,
}) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.11
    ..strokeCap = StrokeCap.round;
  for (var i = 1; i <= 3; i++) {
    final r = size * i / 3;
    canvas.drawArc(
      Rect.fromCircle(center: origin, radius: r),
      toRight ? -math.pi / 4 : math.pi * 3 / 4,
      math.pi / 2,
      false,
      paint..color = color.withValues(alpha: 1 - (i - 1) * 0.22),
    );
  }
}

/// Текст на холсте шрифтом приложения.
///
/// [alignment] говорит, как текстовый блок стоит относительно точки [anchor]:
/// `Alignment.topLeft` — anchor это левый верхний угол, `Alignment.center` —
/// центр, и так далее.
Size paintCanvasText(
  Canvas canvas,
  String text,
  Offset anchor, {
  required Color color,
  double fontSize = 12,
  FontWeight weight = FontWeight.normal,
  double maxWidth = 240,
  TextAlign align = TextAlign.left,
  Alignment alignment = Alignment.topLeft,
  double height = 1.25,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        height: height,
        fontFamily: kAppFontFamily,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  final offset = Offset(
    anchor.dx - painter.width * (alignment.x + 1) / 2,
    anchor.dy - painter.height * (alignment.y + 1) / 2,
  );
  painter.paint(canvas, offset);
  return painter.size;
}

/// Стрелка с наконечником — общая выноска для дорожных сцен.
void paintArrow(
  Canvas canvas,
  Offset from,
  Offset to, {
  required Color color,
  double strokeWidth = 2.5,
  double headSize = 9,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(from, to, paint);

  final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
  const spread = math.pi / 7;
  final path = Path()
    ..moveTo(to.dx, to.dy)
    ..lineTo(
      to.dx - headSize * math.cos(angle - spread),
      to.dy - headSize * math.sin(angle - spread),
    )
    ..lineTo(
      to.dx - headSize * math.cos(angle + spread),
      to.dy - headSize * math.sin(angle + spread),
    )
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

/// Красный крест «нельзя» в круге.
void paintForbiddenMark(
  Canvas canvas,
  Offset center, {
  required double radius,
  Color color = const Color(0xFFD32F2F),
}) {
  canvas.drawCircle(center, radius, Paint()..color = Colors.white);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.28,
  );
  final arm = radius * 0.45;
  final stroke = Paint()
    ..color = color
    ..strokeWidth = radius * 0.28
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    center + Offset(-arm, -arm),
    center + Offset(arm, arm),
    stroke,
  );
  canvas.drawLine(
    center + Offset(arm, -arm),
    center + Offset(-arm, arm),
    stroke,
  );
}
