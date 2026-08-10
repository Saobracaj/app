// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Три вида знаков рядом: треугольник опасности, круги изричите наредбе и
/// синий квадрат обавештења.
///
/// Схема снимает главную путаницу категории 32: одна и та же пиктограмма
/// (пешеход на зебре) стоит во всех трёх оболочках, и правильный ответ
/// определяется **формой и каймой**, а не картинкой внутри. Поэтому под каждым
/// знаком стоит не только его вид, но и слова, с которых начинается верный
/// вариант: *приближавање/наилазак*, *забрањено/мора*, *место/близина*.
class TriVrsteZnakova extends StatelessWidget {
  const TriVrsteZnakova({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 322,
          child: CustomPaint(
            painter: _TriVrsteZnakovaPainter(
              Theme.of(context).colorScheme,
              _SignLabels.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские пояснения. Сербские термины (*опасност*, *изричита наредба*,
/// *обавештење*, названия знаков) не переводятся и живут прямо в painter'е.
class _SignLabels {
  const _SignLabels({
    required this.danger,
    required this.order,
    required this.info,
    required this.note,
  });

  factory _SignLabels.of(BuildContext context) => _SignLabels(
        danger: context.tr(LocaleKeys.triVrsteZnakova_danger),
        order: context.tr(LocaleKeys.triVrsteZnakova_order),
        info: context.tr(LocaleKeys.triVrsteZnakova_info),
        note: context.tr(LocaleKeys.triVrsteZnakova_note),
      );

  final String danger;
  final String order;
  final String info;
  final String note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SignLabels &&
          other.danger == danger &&
          other.order == order &&
          other.info == info &&
          other.note == note;

  @override
  int get hashCode => Object.hash(danger, order, info, note);
}

/// Цвета знаков — литеральные: красная кайма и синий фон это и есть
/// содержание, в тёмной теме знак остаётся таким же, как на дороге.
const _signRed = Color(0xFFD32F2F);
const _signBlue = Color(0xFF1565C0);
const _signWhite = Color(0xFFF5F5F5);
const _signInk = Color(0xFF1B1B1B);

class _TriVrsteZnakovaPainter extends IllustrationPainter {
  _TriVrsteZnakovaPainter(super.colorScheme, this.labels);

  final _SignLabels labels;

  @override
  void paint(Canvas canvas, Size size) {
    const panelTop = 4.0;
    const panelBottom = 252.0;
    const centers = [68.0, 200.0, 332.0];

    for (final cx in centers) {
      panelFrame(
        canvas,
        Rect.fromLTRB(cx - 64, panelTop, cx + 64, panelBottom),
        fill: colorScheme.surfaceContainerHighest,
      );
    }

    _drawDangerColumn(canvas, centers[0]);
    _drawOrderColumn(canvas, centers[1]);
    _drawInfoColumn(canvas, centers[2]);

    calloutBox(
      canvas,
      labels.note,
      const Rect.fromLTRB(4, 262, 396, 318),
      fill: colorScheme.secondaryContainer,
      textColor: colorScheme.onSecondaryContainer,
      fontSize: 11,
    );
  }

  // --- Колонки ---

  void _drawDangerColumn(Canvas canvas, double cx) {
    _triangleSign(canvas, Offset(cx, 58), 92);
    _column(
      canvas,
      cx,
      title: 'знак опасности',
      keywords: 'приближавање\nнаилазак',
      keywordsFill: colorScheme.tertiaryContainer,
      keywordsInk: colorScheme.onTertiaryContainer,
      example: 'наилазак на место\nна коме је обележен\nпешачки прелаз',
      gloss: labels.danger,
    );
  }

  void _drawOrderColumn(Canvas canvas, double cx) {
    // Два круга рядом: красный запрещает, синий приказывает. Оба — «изричита
    // наредба», поэтому стоят в одной колонке.
    _prohibitionSign(canvas, Offset(cx - 30, 58), 27);
    _mandatorySign(canvas, Offset(cx + 30, 58), 27);
    _column(
      canvas,
      cx,
      title: 'изричита наредба',
      keywords: 'забрањено\nмора',
      keywordsFill: colorScheme.errorContainer,
      keywordsInk: colorScheme.onErrorContainer,
      example: 'забрањен саобраћај\nза пешаке · пешачка стаза',
      gloss: labels.order,
    );
  }

  void _drawInfoColumn(Canvas canvas, double cx) {
    _informationSign(canvas, Offset(cx, 58), 78);
    _column(
      canvas,
      cx,
      title: 'обавештење',
      keywords: 'место\nблизина',
      keywordsFill: colorScheme.primaryContainer,
      keywordsInk: colorScheme.onPrimaryContainer,
      example: 'место на коме се\nналази пешачки прелаз',
      gloss: labels.info,
    );
  }

  /// Общая нижняя часть колонки: название вида, ключевые слова ответа,
  /// пример конкретного знака и русское пояснение.
  void _column(
    Canvas canvas,
    double cx, {
    required String title,
    required String keywords,
    required Color keywordsFill,
    required Color keywordsInk,
    required String example,
    required String gloss,
  }) {
    text(
      canvas,
      title,
      Offset(cx, 118),
      colorScheme.onSurface,
      maxWidth: 122,
      fontSize: 13,
      isBold: true,
    );
    calloutBox(
      canvas,
      keywords,
      Rect.fromCenter(center: Offset(cx, 152), width: 114, height: 38),
      fill: keywordsFill,
      textColor: keywordsInk,
      fontSize: 12,
      isBold: true,
    );
    text(
      canvas,
      example,
      Offset(cx, 192),
      colorScheme.onSurfaceVariant,
      maxWidth: 122,
      fontSize: 10,
      isItalic: true,
    );
    text(
      canvas,
      gloss,
      Offset(cx, 228),
      colorScheme.onSurface,
      maxWidth: 122,
      fontSize: 11,
    );
  }

  // --- Сами знаки ---

  /// Треугольник опасности: красная кайма, белое поле, пиктограмма внутри.
  void _triangleSign(Canvas canvas, Offset center, double side) {
    final height = side * 0.866;
    Path triangle(double scale) {
      final s = side * scale;
      final h = height * scale;
      return Path()
        ..moveTo(center.dx, center.dy - h * 0.62)
        ..lineTo(center.dx + s / 2, center.dy + h * 0.38)
        ..lineTo(center.dx - s / 2, center.dy + h * 0.38)
        ..close();
    }

    canvas.drawPath(triangle(1), Paint()..color = _signRed);
    canvas.drawPath(triangle(0.74), Paint()..color = _signWhite);
    _crossingPictogram(
      canvas,
      Rect.fromCenter(center: center + const Offset(0, 8), width: 44, height: 34),
      _signInk,
    );
  }

  /// Круг с красной каймой и красной чертой — забрана.
  void _prohibitionSign(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(center, r, Paint()..color = _signRed);
    canvas.drawCircle(center, r * 0.76, Paint()..color = _signWhite);
    _pedestrian(canvas, center + Offset(0, r * 0.5), r * 1.05, _signInk);
    canvas.drawLine(
      center + Offset(-r * 0.62, -r * 0.62),
      center + Offset(r * 0.62, r * 0.62),
      Paint()
        ..color = _signRed
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Сплошной синий круг — наредба «мора» (пешачка стаза).
  void _mandatorySign(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(center, r, Paint()..color = _signBlue);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = _signWhite
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _pedestrian(canvas, center + Offset(0, r * 0.5), r * 1.05, _signWhite);
  }

  /// Синий квадрат — обавештење.
  void _informationSign(Canvas canvas, Offset center, double side) {
    final rect = Rect.fromCenter(center: center, width: side, height: side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = _signBlue,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = _signWhite
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _crossingPictogram(
      canvas,
      Rect.fromCenter(center: center, width: 50, height: 40),
      _signWhite,
    );
  }

  /// Пешеход, идущий по зебре: полосы снизу, силуэт сверху. Одна и та же
  /// пиктограмма во всех трёх знаках — в этом весь смысл схемы.
  void _crossingPictogram(Canvas canvas, Rect area, Color color) {
    final stripeTop = area.bottom - 9;
    final paint = Paint()..color = color;
    for (var i = 0; i < 4; i++) {
      final left = area.left + i * (area.width / 4);
      canvas.drawRect(
        Rect.fromLTWH(left, stripeTop, area.width / 4 * 0.55, 9),
        paint,
      );
    }
    _pedestrian(canvas, Offset(area.center.dx, stripeTop - 1),
        area.height * 0.78, color);
  }

  /// Идущий человек: [person] из painters.dart даёт силуэт «голова + туловище»,
  /// а на знаке пешеход должен читаться именно как **идущий** — иначе в
  /// маленьком круге он выглядит замочной скважиной.
  void _pedestrian(Canvas canvas, Offset feet, double h, Color color) {
    final limb = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.11
      ..strokeCap = StrokeCap.round;
    final torso = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.17
      ..strokeCap = StrokeCap.round;

    final hip = Offset(feet.dx, feet.dy - h * 0.4);
    final shoulder = Offset(feet.dx, feet.dy - h * 0.68);
    // Ноги в шаге и рука вперёд: по ним фигура читается как движение.
    canvas.drawLine(hip, Offset(feet.dx - h * 0.19, feet.dy), limb);
    canvas.drawLine(hip, Offset(feet.dx + h * 0.21, feet.dy), limb);
    canvas.drawLine(hip, shoulder, torso);
    canvas.drawLine(shoulder, Offset(feet.dx + h * 0.17, feet.dy - h * 0.46),
        limb);
    canvas.drawLine(shoulder, Offset(feet.dx - h * 0.15, feet.dy - h * 0.42),
        limb);
    canvas.drawCircle(
      Offset(feet.dx, feet.dy - h * 0.83),
      h * 0.13,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TriVrsteZnakovaPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.labels != labels;
}
