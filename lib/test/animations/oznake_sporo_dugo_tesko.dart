import 'dart:math' as math;

// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Три задние таблички обозначения ТС: *спора / дуга / тешка возила*.
///
/// В трёх вопросах категории варианты ответа одинаковые, а отличается только
/// картинка, поэтому таблички стоят рядом: их надо различать не по смыслу,
/// а по форме и рисунку.
class OznakeSporoDugoTesko extends StatelessWidget {
  const OznakeSporoDugoTesko({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 212,
          child: CustomPaint(
            painter: _PlatesPainter(
              Theme.of(context).colorScheme,
              _plateLabels(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские пояснения под табличками. Сербские названия (*спора возила*
/// и т. д.) — термины из правил, они не переводятся.
typedef _PlateLabels = ({String slow, String long, String heavy});

_PlateLabels _plateLabels(BuildContext context) => (
      slow: context.tr(LocaleKeys.vehiclePlates_slow),
      long: context.tr(LocaleKeys.vehiclePlates_long),
      heavy: context.tr(LocaleKeys.vehiclePlates_heavy),
    );

class _PlatesPainter extends CustomPainter {
  _PlatesPainter(this.scheme, this.labels);

  final ColorScheme scheme;
  final _PlateLabels labels;

  // Цвета табличек — это и есть их содержание (красная светоотражающая кайма,
  // оранжевое/жёлтое флуоресцентное поле), поэтому они литеральные и
  // одинаковые в обеих темах.
  static const _red = Color(0xFFD32F2F);
  static const _orange = Color(0xFFF57C00);
  static const _yellow = Color(0xFFFDD835);

  static const _plateCenterY = 62.0;
  static const _columnCenters = [70.0, 200.0, 330.0];

  @override
  void paint(Canvas canvas, Size size) {
    _paintTriangle(canvas, Offset(_columnCenters[0], _plateCenterY));
    _paintLongPlate(canvas, Offset(_columnCenters[1], _plateCenterY));
    _paintHeavyPlate(canvas, Offset(_columnCenters[2], _plateCenterY));

    _paintCaption(canvas, _columnCenters[0], 'спора возила', labels.slow,
        'троугао');
    _paintCaption(canvas, _columnCenters[1], 'дуга возила', labels.long,
        'глатко жуто поље');
    _paintCaption(canvas, _columnCenters[2], 'тешка возила', labels.heavy,
        'косе пруге');
  }

  /// Табличка «спора возила»: равносторонний треугольник вершиной вверх со
  /// срезанными углами, красная кайма и оранжевая середина.
  void _paintTriangle(Canvas canvas, Offset center) {
    const width = 100.0;
    const height = 88.0;

    canvas.drawPath(
      _truncatedTriangle(center, width, height, 13),
      Paint()..color = _red,
    );
    // Внутреннее поле — тот же силуэт, уменьшенный к центру тяжести
    // треугольника (он ниже центра описанного прямоугольника на height/6):
    // только так кайма выходит одинаковой по всему периметру.
    const shrink = 0.66;
    canvas.drawPath(
      _truncatedTriangle(
        center.translate(0, height / 6 * (1 - shrink)),
        width * shrink,
        height * shrink,
        9,
      ),
      Paint()..color = _orange,
    );
    canvas.drawPath(
      _truncatedTriangle(center, width, height, 13),
      _outline(),
    );
  }

  Path _truncatedTriangle(
    Offset center,
    double width,
    double height,
    double cut,
  ) {
    final vertices = [
      Offset(center.dx, center.dy - height / 2),
      Offset(center.dx + width / 2, center.dy + height / 2),
      Offset(center.dx - width / 2, center.dy + height / 2),
    ];

    final path = Path();
    for (var i = 0; i < vertices.length; i++) {
      final prev = vertices[(i - 1 + vertices.length) % vertices.length];
      final current = vertices[i];
      final next = vertices[(i + 1) % vertices.length];

      final fromPrev = _pointTowards(current, prev, cut);
      final toNext = _pointTowards(current, next, cut);

      if (i == 0) {
        path.moveTo(fromPrev.dx, fromPrev.dy);
      } else {
        path.lineTo(fromPrev.dx, fromPrev.dy);
      }
      path.lineTo(toNext.dx, toNext.dy);
    }
    return path..close();
  }

  /// Точка на отрезке [from]→[to] на расстоянии [distance] от [from] —
  /// ею и срезается угол треугольника.
  Offset _pointTowards(Offset from, Offset to, double distance) {
    final delta = to - from;
    final length = delta.distance;
    return from + delta * (math.min(distance, length / 2) / length);
  }

  /// Табличка «дуга возила»: жёлтое поле с широкой красной каймой, без полос.
  void _paintLongPlate(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(center: center, width: 112, height: 58);
    canvas.drawRect(rect, Paint()..color = _red);
    canvas.drawRect(rect.deflate(11), Paint()..color = _yellow);
    canvas.drawRect(rect, _outline());
  }

  /// Табличка «тешка возила»: косые чередующиеся красные и жёлтые полосы.
  void _paintHeavyPlate(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(center: center, width: 112, height: 58);
    canvas.drawRect(rect, Paint()..color = _yellow);

    canvas.save();
    canvas.clipRect(rect);
    final stripe = Paint()
      ..color = _red
      ..strokeWidth = 13
      ..style = PaintingStyle.stroke;
    // Полосы под 45°: рисуем с запасом влево, чтобы наклонные концы
    // перекрывали углы прямоугольника.
    for (var x = rect.left - rect.height; x < rect.right + rect.height; x += 26) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        stripe,
      );
    }
    canvas.restore();
    canvas.drawRect(rect, _outline());
  }

  Paint _outline() => Paint()
    ..color = scheme.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  void _paintCaption(
    Canvas canvas,
    double centerX,
    String term,
    String hint,
    String shape,
  ) {
    drawCanvasText(
      canvas,
      shape,
      Offset(centerX, 122),
      scheme.onSurfaceVariant,
      maxWidth: 124,
      fontSize: 11.5,
    );
    drawCanvasText(
      canvas,
      term,
      Offset(centerX, 152),
      scheme.onSurface,
      maxWidth: 124,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    );
    drawCanvasText(
      canvas,
      hint,
      Offset(centerX, 186),
      scheme.onSurfaceVariant,
      maxWidth: 124,
      fontSize: 12,
    );
  }

  @override
  bool shouldRepaint(covariant _PlatesPainter oldDelegate) =>
      oldDelegate.scheme != scheme || oldDelegate.labels != labels;
}
