import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/car_top_view.dart';
import 'package:saobracaj/test/animations/emergency_triangle.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Обозначение вынужденно остановившегося ТС: сигурносни троугао, все
/// показатели поворота и светлоодбојни прслук, плюс расстояние до треугольника
/// и правило для колонны.
///
/// Подписи целиком на сербском (это термины из закона и билетов), поэтому
/// переводимых строк у схемы нет — при смене языка картинка не меняется.
class TrougaoIPrsluk extends StatelessWidget {
  const TrougaoIPrsluk({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 400,
        height: 470,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _TrougaoIPrslukPainter(scheme)),
            ),
            // Знак аварийной остановки — готовый примитив, а не своя копия.
            const Positioned(
              left: 84,
              top: 136,
              child: EmergencyTriangle(size: 28, rotationDegrees: 0),
            ),
            // Врезка «колона»: два треугольника вплотную друг к другу поперёк
            // полосы — это и есть «један поред другог».
            const Positioned(
              left: 131,
              top: 384,
              child: EmergencyTriangle(size: 18, rotationDegrees: 0),
            ),
            const Positioned(
              left: 131,
              top: 402,
              child: EmergencyTriangle(size: 18, rotationDegrees: 0),
            ),
          ],
        ),
      ),
    );
  }
}

/// Цвет асфальта взят такой же, как в `road.dart`, чтобы сцены выглядели
/// одинаково; на асфальте подписи всегда белые — он тёмный в обеих темах.
const _asphalt = Color(0xFF424242);
const _shoulder = Color(0xFF6D6154);
const _marking = Colors.white;

class _TrougaoIPrslukPainter extends CustomPainter {
  final ColorScheme scheme;

  _TrougaoIPrslukPainter(this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    _drawHeader(canvas);
    _drawMainScene(canvas);
    _drawDistance(canvas);
    _drawColumnInset(canvas);
  }

  void _drawHeader(Canvas canvas) {
    _text(
      canvas,
      'Обележавање заустављеног возила',
      const Offset(200, 14),
      color: scheme.onSurface,
      fontSize: 15,
      weight: FontWeight.w700,
      maxWidth: 396,
    );
    _text(
      canvas,
      'троугао + сви показивачи правца + прслук',
      const Offset(200, 38),
      color: scheme.onSurface.withValues(alpha: 0.75),
      fontSize: 11.5,
      maxWidth: 390,
    );
  }

  void _drawMainScene(Canvas canvas) {
    // Загородная дорога видом сверху: проезжая часть и обочина под ней.
    canvas.drawRect(
      const Rect.fromLTRB(0, 56, 400, 176),
      Paint()..color = _asphalt,
    );
    canvas.drawRect(
      const Rect.fromLTRB(0, 176, 400, 214),
      Paint()..color = _shoulder,
    );

    final line = Paint()
      ..color = _marking
      ..strokeWidth = 2.5;
    canvas.drawLine(const Offset(0, 60), const Offset(400, 60), line);
    canvas.drawLine(const Offset(0, 172), const Offset(400, 172), line);
    _dashedLine(canvas, y: 116, from: 0, to: 400, paint: Paint()
      ..color = _marking
      ..strokeWidth = 4);

    // Машина стоит на обочине с включённой аварийкой.
    paintCarTopView(
      canvas,
      const Rect.fromLTWH(248, 176, 110, 38),
      color: const Color(0xFF1E6FD9),
      lamps: CarLamps.hazard,
    );
    _text(
      canvas,
      'упаљени сви показивачи правца',
      const Offset(300, 228),
      color: scheme.onSurface,
      fontSize: 11.5,
      maxWidth: 200,
    );

    // Водитель вне ТС на коловозу — обязательно в жилете.
    _drawDriver(canvas, const Offset(245, 150));

    _text(
      canvas,
      'сигурносни троугао',
      const Offset(98, 86),
      color: _marking,
      fontSize: 11.5,
    );
    _leader(canvas, const Offset(98, 98), const Offset(98, 132));
    _text(
      canvas,
      'светлоодбојни прслук',
      const Offset(245, 86),
      color: _marking,
      fontSize: 11.5,
    );
    _leader(canvas, const Offset(245, 98), const Offset(245, 130));
  }

  /// Пиктограмма человека: голова, жёлтый жилет со светоотражающими полосами,
  /// руки и ноги. Смысл несёт жилет, поэтому он крупный и жёлтый.
  void _drawDriver(Canvas canvas, Offset center) {
    final skin = Paint()..color = const Color(0xFFE8B98C);
    final dark = Paint()..color = const Color(0xFF37474F);
    final vest = Paint()..color = const Color(0xFFFFEB3B);

    final x = center.dx;
    final top = center.dy - 17;

    // Ноги.
    canvas.drawLine(
      Offset(x - 3, top + 24),
      Offset(x - 5, top + 34),
      Paint()
        ..color = dark.color
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(x + 3, top + 24),
      Offset(x + 5, top + 34),
      Paint()
        ..color = dark.color
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    // Руки.
    canvas.drawLine(
      Offset(x - 6, top + 12),
      Offset(x - 10, top + 21),
      Paint()
        ..color = skin.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(x + 6, top + 12),
      Offset(x + 10, top + 21),
      Paint()
        ..color = skin.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    // Жилет.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 7, top + 9, 14, 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, vest);
    final stripe = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x - 7, top + 15), Offset(x + 7, top + 15), stripe);
    canvas.drawLine(Offset(x - 7, top + 20), Offset(x + 7, top + 20), stripe);
    // Голова.
    canvas.drawCircle(Offset(x, top + 4), 5, skin);
  }

  /// Размерная линия от ТС до треугольника с двумя нормами расстояния.
  void _drawDistance(Canvas canvas) {
    const y = 252.0;
    const left = 98.0;
    const right = 248.0;

    final thin = Paint()
      ..color = scheme.outline
      ..strokeWidth = 1;
    _dashedVertical(canvas, x: left, from: 170, to: y - 8, paint: thin);
    _dashedVertical(canvas, x: right, from: 214, to: y - 8, paint: thin);

    final arrow = Paint()
      ..color = scheme.onSurface
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(left, y), const Offset(right, y), arrow);
    _arrowHead(canvas, const Offset(left, y), pointingLeft: true, paint: arrow);
    _arrowHead(
      canvas,
      const Offset(right, y),
      pointingLeft: false,
      paint: arrow,
    );

    _text(
      canvas,
      'ван насеља ≥ 50 m',
      const Offset(173, 268),
      color: scheme.onSurface,
      fontSize: 13,
      weight: FontWeight.w700,
    );
    _text(
      canvas,
      'у насељу ≥ 10 m',
      const Offset(173, 288),
      color: scheme.onSurface,
      fontSize: 13,
      weight: FontWeight.w700,
    );
    _text(
      canvas,
      'растојање од возила\nдо троугла',
      const Offset(320, 278),
      color: scheme.onSurface.withValues(alpha: 0.75),
      fontSize: 11,
      maxWidth: 150,
    );
  }

  /// Врезка: колонна остановившихся ТС обозначается двумя треугольниками,
  /// поставленными рядом друг с другом.
  void _drawColumnInset(Canvas canvas) {
    final box = RRect.fromRectAndRadius(
      const Rect.fromLTRB(0, 306, 400, 462),
      const Radius.circular(12),
    );
    canvas.drawRRect(box, Paint()..color = scheme.surfaceContainerHighest);
    canvas.drawRRect(
      box,
      Paint()
        ..color = scheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _text(
      canvas,
      '✓ колона — два троугла један поред другог',
      const Offset(200, 322),
      color: scheme.onSurface,
      fontSize: 12.5,
      weight: FontWeight.w700,
      maxWidth: 380,
    );

    canvas.drawRect(
      const Rect.fromLTRB(12, 340, 388, 424),
      Paint()..color = _asphalt,
    );
    final line = Paint()
      ..color = _marking
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(12, 344), const Offset(388, 344), line);
    canvas.drawLine(const Offset(12, 420), const Offset(388, 420), line);
    _dashedLine(canvas, y: 382, from: 12, to: 388, paint: Paint()
      ..color = _marking
      ..strokeWidth = 3);

    // Колонна: три остановившихся ТС, у всех включена аварийка.
    for (final x in [176.0, 250.0, 324.0]) {
      paintCarTopView(
        canvas,
        Rect.fromLTWH(x, 389, 58, 24),
        color: const Color(0xFF1E6FD9),
        lamps: CarLamps.hazard,
      );
    }

    _text(
      canvas,
      '✗ погрешно: један троугао или два један иза другог',
      const Offset(200, 442),
      color: scheme.error,
      fontSize: 11.5,
      weight: FontWeight.w600,
      maxWidth: 380,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    required Color color,
    double fontSize = 11.5,
    FontWeight weight = FontWeight.w400,
    double maxWidth = 260,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          fontFamily: kAppFontFamily,
          height: 1.25,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  void _leader(Canvas canvas, Offset from, Offset to) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = _marking.withValues(alpha: 0.8)
        ..strokeWidth = 1.2,
    );
  }

  void _dashedLine(
    Canvas canvas, {
    required double y,
    required double from,
    required double to,
    required Paint paint,
  }) {
    for (var x = from; x < to; x += 34) {
      canvas.drawLine(Offset(x, y), Offset((x + 18).clamp(from, to), y), paint);
    }
  }

  void _dashedVertical(
    Canvas canvas, {
    required double x,
    required double from,
    required double to,
    required Paint paint,
  }) {
    for (var y = from; y < to; y += 10) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + 5).clamp(from, to)), paint);
    }
  }

  void _arrowHead(
    Canvas canvas,
    Offset tip, {
    required bool pointingLeft,
    required Paint paint,
  }) {
    final dx = pointingLeft ? 8.0 : -8.0;
    canvas.drawLine(tip, tip.translate(dx, -5), paint);
    canvas.drawLine(tip, tip.translate(dx, 5), paint);
  }

  @override
  bool shouldRepaint(covariant _TrougaoIPrslukPainter old) =>
      old.scheme != scheme;
}
