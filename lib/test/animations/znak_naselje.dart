// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Знаки начала и конца *насеља*.
///
/// В двух вопросах подкатегории показан один и тот же знак, отличается только
/// красная диагональ, а варианты ответа одинаковые. Поэтому оба знака стоят
/// рядом, а под ними — табличка с названием (*насељено место*), самая частая
/// приманка: её легко принять за знак *насеље*.
class ZnakNaselje extends StatelessWidget {
  const ZnakNaselje({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 306,
          child: CustomPaint(
            painter: _NaseljePainter(
              Theme.of(context).colorScheme,
              _naseljeLabels(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские пояснения. Сербские термины (*насеље*, *насељено место*) — из
/// правил и не переводятся.
typedef _NaseljeLabels = ({
  String starts,
  String ends,
  String notConfuse,
  String wrongAnswer,
});

_NaseljeLabels _naseljeLabels(BuildContext context) => (
      starts: context.tr(LocaleKeys.znakNaselje_starts),
      ends: context.tr(LocaleKeys.znakNaselje_ends),
      notConfuse: context.tr(LocaleKeys.znakNaselje_notConfuse),
      wrongAnswer: context.tr(LocaleKeys.znakNaselje_wrongAnswer),
    );

class _NaseljePainter extends CustomPainter {
  _NaseljePainter(this.scheme, this.labels);

  final ColorScheme scheme;
  final _NaseljeLabels labels;

  // Цвета знака — это его содержание: белое поле, чёрный силуэт, красная
  // диагональ. Одинаковые в обеих темах.
  static const _plateFill = Color(0xFFFAFAFA);
  static const _plateInk = Color(0xFF1B1B1B);
  static const _crossRed = Color(0xFFD32F2F);

  static const _signSize = Size(150, 96);
  static const _leftSign = Offset(30, 22);
  static const _rightSign = Offset(220, 22);

  @override
  void paint(Canvas canvas, Size size) {
    _paintSign(canvas, _leftSign, crossed: false);
    _paintSign(canvas, _rightSign, crossed: true);

    _paintCaption(canvas, 105, 'насеље почиње', labels.starts);
    _paintCaption(canvas, 295, 'насеље престаје', labels.ends);

    _paintSpeedBand(canvas);
    _paintDecoyPlate(canvas);
  }

  /// Знак *насеље*: белая табличка с чёрным силуэтом города. С [crossed] —
  /// та же табличка, перечёркнутая красной диагональю: конец *насеља*.
  void _paintSign(Canvas canvas, Offset topLeft, {required bool crossed}) {
    final rect = Rect.fromLTWH(
        topLeft.dx, topLeft.dy, _signSize.width, _signSize.height);
    canvas.drawRect(rect, Paint()..color = _plateFill);
    canvas.drawRect(rect, _stroke(_plateInk, 2.5));

    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(topLeft.dx, topLeft.dy);
    _paintSkyline(canvas);
    canvas.restore();

    if (crossed) {
      canvas.drawLine(
        rect.topLeft + const Offset(4, 4),
        rect.bottomRight + const Offset(-4, -4),
        _stroke(_crossRed, 9),
      );
    }
  }

  /// Силуэт города в локальных координатах таблички (150×96): высотки и дома
  /// на общей линии земли.
  void _paintSkyline(Canvas canvas) {
    const groundY = 82.0;
    // (левый край, правый край, высота крыши)
    const buildings = [
      (16.0, 40.0, 54.0),
      (42.0, 62.0, 36.0),
      (64.0, 92.0, 24.0),
      (94.0, 116.0, 44.0),
      (118.0, 136.0, 62.0),
    ];
    final ink = Paint()..color = _plateInk;
    for (final (left, right, top) in buildings) {
      canvas.drawRect(Rect.fromLTRB(left, top, right, groundY), ink);
    }
    // Скатная крыша у крайнего левого дома — чтобы силуэт читался как «город
    // с домами», а не как столбиковая диаграмма.
    canvas.drawPath(
      Path()
        ..moveTo(14, 54)
        ..lineTo(28, 42)
        ..lineTo(42, 54)
        ..close(),
      ink,
    );
    canvas.drawRect(const Rect.fromLTRB(14, groundY, 138, 86), ink);

    // Окна вырезаем цветом таблички: сплошной чёрный блок читается хуже.
    final window = Paint()..color = _plateFill;
    for (final (left, top) in const [
      (68.0, 32.0),
      (80.0, 32.0),
      (68.0, 46.0),
      (80.0, 46.0),
      (98.0, 52.0),
      (108.0, 52.0),
      (122.0, 70.0),
    ]) {
      canvas.drawRect(Rect.fromLTWH(left, top, 6, 8), window);
    }
  }

  void _paintCaption(Canvas canvas, double centerX, String term, String hint) {
    drawCanvasText(canvas, term, Offset(centerX, 136), scheme.onSurface,
        maxWidth: 180, fontSize: 15, fontWeight: FontWeight.bold);
    drawCanvasText(canvas, hint, Offset(centerX, 164), scheme.onSurfaceVariant,
        maxWidth: 180, fontSize: 11.5);
  }

  /// Практический вывод, который пригодится в других категориях.
  void _paintSpeedBand(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTRB(14, 186, 386, 214),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = scheme.primaryContainer);
    drawCanvasText(
      canvas,
      'од знака „насеље” важи ограничење 50 km/h',
      const Offset(200, 200),
      scheme.onPrimaryContainer,
      maxWidth: 360,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );
  }

  /// Табличка названия населённого пункта — приманка *насељено место*.
  void _paintDecoyPlate(Canvas canvas) {
    const rect = Rect.fromLTRB(258, 236, 386, 276);
    canvas.drawRect(rect, Paint()..color = _plateFill);
    canvas.drawRect(rect, _stroke(_plateInk, 2));
    drawCanvasText(canvas, 'НОВИ САД', rect.center, _plateInk,
        maxWidth: 120, fontSize: 15, fontWeight: FontWeight.bold);
    drawCanvasText(canvas, '≠ насеље', const Offset(322, 292), scheme.error,
        maxWidth: 128, fontSize: 12, fontWeight: FontWeight.bold);

    drawCanvasText(canvas, 'насељено место', const Offset(14, 240),
        scheme.onSurface,
        maxWidth: 230,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.left,
        anchor: Alignment.centerLeft);
    drawCanvasText(canvas, labels.notConfuse, const Offset(14, 266),
        scheme.onSurfaceVariant,
        maxWidth: 230,
        fontSize: 11,
        textAlign: TextAlign.left,
        anchor: Alignment.centerLeft);
    drawCanvasText(canvas, labels.wrongAnswer, const Offset(14, 292),
        scheme.onSurfaceVariant,
        maxWidth: 230,
        fontSize: 11,
        textAlign: TextAlign.left,
        anchor: Alignment.centerLeft);
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  @override
  bool shouldRepaint(covariant _NaseljePainter oldDelegate) =>
      oldDelegate.scheme != scheme || oldDelegate.labels != labels;
}
