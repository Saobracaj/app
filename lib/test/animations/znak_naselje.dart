// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';
import 'package:saobracaj/test/animations/road_sign.dart';

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
      child: RoadSignScope(
        signs: const ['III-23.1', 'III-24.1'],
        builder: (context, signs) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 400,
            height: 306,
            child: TappableSigns(
              signs: signs,
              child: CustomPaint(
                painter: _NaseljePainter(
                  Theme.of(context).colorScheme,
                  _naseljeLabels(context),
                  signs,
                ),
              ),
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
  _NaseljePainter(this.scheme, this.labels, this.signs);

  final ColorScheme scheme;
  final _NaseljeLabels labels;
  final RoadSigns signs;

  // Цвета таблички-приманки — как у настоящего знака: белое поле, чёрная
  // рамка. Одинаковые в обеих темах.
  static const _plateFill = Color(0xFFFAFAFA);
  static const _plateInk = Color(0xFF1B1B1B);

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

  /// Знак *насеље* (III-23.1). С [crossed] — знак *завршетак насеља*
  /// (III-24.1): та же табличка, перечёркнутая красной диагональю.
  void _paintSign(Canvas canvas, Offset topLeft, {required bool crossed}) {
    final rect = Rect.fromLTWH(
        topLeft.dx, topLeft.dy, _signSize.width, _signSize.height);
    signs.paint(canvas, crossed ? 'III-24.1' : 'III-23.1', rect);
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
      oldDelegate.scheme != scheme ||
      oldDelegate.labels != labels ||
      oldDelegate.signs != signs;
}
