// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';
import 'package:saobracaj/test/animations/road_sign.dart';

/// Три вида знаков рядом: треугольник опасности, круги изричите наредбе и
/// синий квадрат обавештења.
///
/// Схема снимает главную путаницу категории 32: пешеход нарисован во всех
/// трёх оболочках (I-14, II-17/II-41, III-6), и правильный ответ
/// определяется **формой и каймой**, а не картинкой внутри. Поэтому под каждым
/// знаком стоит не только его вид, но и слова, с которых начинается верный
/// вариант: *приближавање/наилазак*, *забрањено/мора*, *место/близина*.
class TriVrsteZnakova extends StatelessWidget {
  const TriVrsteZnakova({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: RoadSignScope(
        signs: const ['I-14', 'II-17', 'II-41', 'III-6'],
        builder: (context, signs) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 400,
            height: 322,
            child: CustomPaint(
              painter: _TriVrsteZnakovaPainter(
                Theme.of(context).colorScheme,
                _SignLabels.of(context),
                signs,
              ),
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

class _TriVrsteZnakovaPainter extends IllustrationPainter {
  _TriVrsteZnakovaPainter(super.colorScheme, this.labels, this.signs);

  final _SignLabels labels;
  final RoadSigns signs;

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
    // I-14 «наилазак на место на коме је обележен пешачки прелаз».
    signs.paint(
      canvas,
      'I-14',
      Rect.fromCenter(center: Offset(cx, 58), width: 96, height: 88),
    );
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
    // Два круга рядом: красный запрещает (II-17 «забрана саобраћаја за
    // пешаке»), синий приказывает (II-41 «пешачка стаза»). Оба — «изричита
    // наредба», поэтому стоят в одной колонке.
    signs.paint(canvas,
        'II-17', Rect.fromCircle(center: Offset(cx - 30, 58), radius: 27));
    signs.paint(canvas,
        'II-41', Rect.fromCircle(center: Offset(cx + 30, 58), radius: 27));
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
    // III-6 «обележени пешачки прелаз».
    signs.paint(
      canvas,
      'III-6',
      Rect.fromCenter(center: Offset(cx, 58), width: 78, height: 78),
    );
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

  @override
  bool shouldRepaint(covariant _TriVrsteZnakovaPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.labels != labels ||
      oldDelegate.signs != signs;
}
