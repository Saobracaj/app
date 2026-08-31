import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/auto.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Общие рисовалки для сцен про претицање (`preticanje_sekvenca.dart`,
/// `preticanje_strane.dart`). Вынесены отдельно, потому что обе сцены должны
/// выглядеть как одна серия: одинаковый асфальт, одинаковые машины,
/// одинаковые выноски.
///
/// Все функции рисуют в системе координат холста сцены (см. style-guide:
/// фиксированный `SizedBox` внутри `FittedBox`), поэтому размеры здесь —
/// обычные числа, а не доли ширины экрана.

/// Асфальт. Литеральный цвет: серый асфальт — это содержание картинки, а не
/// оформление, и он одинаков в светлой и тёмной теме (как в `road.dart`).
const Color kAsphalt = Color(0xFF424242);

/// Разметка и подписи на асфальте — белым: на тёмно-сером читается в обеих
/// темах.
const Color kMarking = Colors.white;

/// Габариты легковой машины в координатах сцены.
const double kCarLength = 54;
const double kCarWidth = 26;

/// Габариты грузовика — того, кого обгоняют.
const double kTruckLength = 92;
const double kTruckWidth = 30;

/// Оранжевый показателя направления (жмигавац) — тоже смысловой цвет.
const Color kBlinker = Color(0xFFFFA000);

void drawAsphalt(Canvas canvas, Rect rect) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(6)),
    Paint()..color = kAsphalt,
  );
}

/// Сплошные краевые линии (ивичне линије) — по верхнему и нижнему краю полотна.
void drawEdgeLines(Canvas canvas, Rect rect) {
  final paint = Paint()
    ..color = kMarking.withValues(alpha: 0.75)
    ..strokeWidth = 2;
  canvas.drawLine(
    Offset(rect.left + 4, rect.top + 5),
    Offset(rect.right - 4, rect.top + 5),
    paint,
  );
  canvas.drawLine(
    Offset(rect.left + 4, rect.bottom - 5),
    Offset(rect.right - 4, rect.bottom - 5),
    paint,
  );
}

/// Прерывистая линия. [offset] сдвигает штрихи — так дорога «едет» под
/// неподвижной камерой.
void drawDashedLine(
  Canvas canvas,
  double y,
  double x0,
  double x1, {
  double offset = 0,
  double dash = 16,
  double gap = 14,
  double strokeWidth = 3,
  Color color = kMarking,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth;
  final period = dash + gap;
  final start = x0 - (offset % period);
  for (var x = start; x < x1; x += period) {
    final a = math.max(x, x0);
    final b = math.min(x + dash, x1);
    if (b > a) canvas.drawLine(Offset(a, y), Offset(b, y), paint);
  }
}

/// Легковая машина, вид сверху, носом вправо (или влево при [facingLeft]).
///
/// Поворотники: машина едет вправо, значит её левая сторона — верх экрана.
/// [blinkOn] моргает снаружи, чтобы все машины сцены мигали в такт.
void drawCar(
  Canvas canvas,
  Offset center, {
  required Color color,
  double length = kCarLength,
  double width = kCarWidth,
  bool facingLeft = false,
  bool leftBlinker = false,
  bool rightBlinker = false,
  bool blinkOn = true,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  if (facingLeft) canvas.scale(-1, 1);

  final l = length;
  final w = width;

  // Кузов — общая машинка из auto.dart (та же, что в «Мимоилажење» и
  // «Претицање»). Лампы показивача правца рисуем поверх сами: на общем
  // плане штатные лампочки машинки слишком мелкие.
  paintAutoTopView(
    canvas,
    Rect.fromCenter(center: Offset.zero, width: l, height: w),
    color: color,
  );

  // Показивачи правца: левый — сверху, правый — снизу. Лампы вынесены за
  // габарит кузова, иначе на общем плане их не разглядеть.
  void blinker(double sy) {
    final paint = Paint()
      ..color = blinkOn ? kBlinker : kBlinker.withValues(alpha: 0.25);
    canvas.drawCircle(Offset(l * 0.36, sy * (w / 2 + 2)), 4, paint);
    canvas.drawCircle(Offset(-l * 0.4, sy * (w / 2 + 2)), 4, paint);
  }

  if (leftBlinker) blinker(-1);
  if (rightBlinker) blinker(1);

  canvas.restore();
}

/// Грузовик: кабина + кузов. Тот, кого обгоняют.
void drawTruck(
  Canvas canvas,
  Offset center, {
  double length = kTruckLength,
  double width = kTruckWidth,
  Color color = const Color(0xFF8D6E63),
  bool facingLeft = false,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  if (facingLeft) canvas.scale(-1, 1);

  final l = length;
  final w = width;
  final wheelPaint = Paint()..color = Colors.black.withValues(alpha: 0.75);
  for (final sx in [-0.36, -0.2, 0.34]) {
    for (final sy in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(l * sx, sy * (w / 2 + 1)),
            width: l * 0.1,
            height: w * 0.2,
          ),
          const Radius.circular(2),
        ),
        wheelPaint,
      );
    }
  }

  // Кузов.
  final box = RRect.fromRectAndRadius(
    Rect.fromLTRB(-l / 2, -w / 2, l * 0.2, w / 2),
    const Radius.circular(3),
  );
  canvas.drawRRect(box, Paint()..color = const Color(0xFFECEFF1));
  canvas.drawRRect(
    box,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.black54,
  );

  // Кабина.
  final cab = RRect.fromRectAndRadius(
    Rect.fromLTRB(l * 0.22, -w / 2, l / 2, w / 2),
    Radius.circular(w * 0.25),
  );
  canvas.drawRRect(cab, Paint()..color = color);
  canvas.drawRRect(
    cab,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Color.lerp(color, Colors.black, 0.45)!,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(l * 0.36, -w * 0.32, l * 0.46, w * 0.32),
      const Radius.circular(2),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.8),
  );

  canvas.restore();
}

/// Трамвай на рельсах посреди проезжей части.
void drawTram(
  Canvas canvas,
  Offset center, {
  double length = 108,
  double width = 26,
}) {
  final l = length;
  final w = width;

  // Рельсы — чтобы было видно, что это трамвай, а не автобус.
  final rail = Paint()
    ..color = Colors.black.withValues(alpha: 0.45)
    ..strokeWidth = 2;
  for (final sy in [-0.3, 0.3]) {
    canvas.drawLine(
      Offset(center.dx - l * 0.9, center.dy + w * sy),
      Offset(center.dx + l * 0.9, center.dy + w * sy),
      rail,
    );
  }

  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: center, width: l, height: w),
    const Radius.circular(5),
  );
  canvas.drawRRect(body, Paint()..color = const Color(0xFFD32F2F));
  canvas.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.black54,
  );
  // Ряд окон секциями — вагон не спутать с фурой или автобусом-коробкой.
  final glass = Paint()..color = Colors.white.withValues(alpha: 0.8);
  const sections = 4;
  final sectionWidth = l * 0.78 / sections;
  for (var i = 0; i < sections; i++) {
    final left = center.dx - l * 0.39 + i * sectionWidth;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left + 2,
          center.dy - w * 0.2,
          sectionWidth - 4,
          w * 0.4,
        ),
        const Radius.circular(2),
      ),
      glass,
    );
  }
  // Токоприёмник — окончательно снимает вопрос «что это за красная коробка».
  final wire = Paint()
    ..color = Colors.black.withValues(alpha: 0.6)
    ..strokeWidth = 1.6;
  canvas.drawLine(
    Offset(center.dx - l * 0.1, center.dy - w / 2),
    Offset(center.dx - l * 0.1, center.dy + w / 2),
    wire,
  );
}

/// Стрелка (одно- или двусторонняя). Годится и как указатель направления
/// движения, и как размерная выноска.
void drawArrow(
  Canvas canvas,
  Offset from,
  Offset to, {
  required Color color,
  double strokeWidth = 2,
  bool doubleHead = false,
  double headSize = 6,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(from, to, paint);

  void head(Offset tip, Offset tail) {
    final angle = math.atan2(tip.dy - tail.dy, tip.dx - tail.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - headSize * math.cos(angle - 0.5),
        tip.dy - headSize * math.sin(angle - 0.5),
      )
      ..lineTo(
        tip.dx - headSize * math.cos(angle + 0.5),
        tip.dy - headSize * math.sin(angle + 0.5),
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  head(to, from);
  if (doubleHead) head(from, to);
}

/// Пунктирная траектория манёвра (куда поедет машина).
void drawDashedPath(
  Canvas canvas,
  Path path, {
  required Color color,
  double strokeWidth = 2,
  double dash = 7,
  double gap = 5,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final next = math.min(distance + dash, metric.length);
      canvas.drawPath(metric.extractPath(distance, next), paint);
      distance = next + gap;
    }
  }
}

/// Подпись. [anchor] задаёт, какой точкой текст цепляется за [at]
/// (`Alignment.topLeft` — левый верхний угол, `Alignment.topCenter` — середина
/// верхней стороны и так далее).
///
/// Шрифт всегда [kAppFontFamily]: иначе в тестовом рендере вместо букв
/// квадраты.
Size drawText(
  Canvas canvas,
  String text, {
  required Offset at,
  required Color color,
  double size = 12,
  bool bold = false,
  Alignment anchor = Alignment.topLeft,
  TextAlign align = TextAlign.left,
  double maxWidth = 400,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontFamily: kAppFontFamily,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        height: 1.25,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  final dx = at.dx - (anchor.x + 1) / 2 * painter.width;
  final dy = at.dy - (anchor.y + 1) / 2 * painter.height;
  painter.paint(canvas, Offset(dx, dy));
  return painter.size;
}

/// Подпись на асфальте — белым текстом на полупрозрачной тёмной плашке, иначе
/// буквы теряются на разметке и машинах.
void drawTagOnRoad(
  Canvas canvas,
  String text, {
  required Offset at,
  Alignment anchor = Alignment.topLeft,
  double size = 11,
  Color background = const Color(0xCC212121),
  Color color = kMarking,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontFamily: kAppFontFamily,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final dx = at.dx - (anchor.x + 1) / 2 * painter.width;
  final dy = at.dy - (anchor.y + 1) / 2 * painter.height;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(dx - 4, dy - 2, painter.width + 8, painter.height + 4),
      const Radius.circular(4),
    ),
    Paint()..color = background,
  );
  painter.paint(canvas, Offset(dx, dy));
}
