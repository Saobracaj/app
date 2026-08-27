// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';
import 'package:saobracaj/test/animations/road_sign.dart';
import 'package:saobracaj/test/animations/police_officer.dart';

/// Пирамида старшинства сигнализации: пять ступеней от жестов уполномоченного
/// лица до общего правила движения.
///
/// Схема отвечает на самый частый вопрос категории 30 — «*поступање возача
/// регулисано је…*». Ступени специально и пронумерованы, и разной ширины: на
/// экзаменационной картинке видно сразу несколько источников (например, знак и
/// разметку), и выбрать нужно тот, что стоит выше.
class HijerarhijaPiramida extends StatelessWidget {
  const HijerarhijaPiramida({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: RoadSignScope(
        signs: const ['I-25'],
        builder: (context, signs) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 400,
            height: 440,
            child: CustomPaint(
              painter: _PiramidaPainter(
                Theme.of(context).colorScheme,
                _PiramidaLabels.of(context),
                signs,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские пояснения. Названия ступеней — сербские термины из правил
/// (*знаци овлашћеног лица*, *ознака на коловозу*), они не переводятся и
/// живут прямо в painter'е.
class _PiramidaLabels {
  const _PiramidaLabels({
    required this.stronger,
    required this.weaker,
    required this.note,
  });

  /// Читаем подписи через [BuildContext], иначе при смене языка painter
  /// останется на закэшированных строках.
  factory _PiramidaLabels.of(BuildContext context) => _PiramidaLabels(
        stronger: context.tr(LocaleKeys.hijerarhijaPiramida_stronger),
        weaker: context.tr(LocaleKeys.hijerarhijaPiramida_weaker),
        note: context.tr(LocaleKeys.hijerarhijaPiramida_note),
      );

  final String stronger;
  final String weaker;
  final String note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PiramidaLabels &&
          other.stronger == stronger &&
          other.weaker == weaker &&
          other.note == note;

  @override
  int get hashCode => Object.hash(stronger, weaker, note);
}

/// Цвета сигналов светофора, разметки и асфальта — литеральные: это их
/// собственный цвет, от темы он не зависит.
const _lightRed = Color(0xFFE53935);
const _lightAmber = Color(0xFFFDD835);
const _lightGreen = Color(0xFF43A047);
const _asphalt = Color(0xFF4E545B);
const _markingWhite = Color(0xFFF2F2F2);

class _PiramidaPainter extends IllustrationPainter {
  _PiramidaPainter(super.colorScheme, this.labels, this.signs);

  final _PiramidaLabels labels;
  final RoadSigns signs;

  /// Ступени сверху вниз. Ширина растёт к низу — форма пирамиды сама говорит,
  /// что сверху «уже и главнее».
  static const _steps = <String>[
    'знаци овлашћеног лица',
    'светлосни саобраћајни знак',
    'саобраћајни знак',
    'ознака на коловозу',
    'правило саобраћаја',
  ];

  static const _rowHeight = 60.0;
  static const _rowGap = 8.0;
  static const _firstRowTop = 26.0;
  static const _centerX = 175.0;

  Rect _rowRect(int i) => Rect.fromCenter(
        center: Offset(_centerX, _firstRowTop + _rowHeight / 2 + i * (_rowHeight + _rowGap)),
        width: 214 + i * 32,
        height: _rowHeight,
      );

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _steps.length; i++) {
      final rect = _rowRect(i);
      // Верхние ступени заливаем акцентным контейнером, нижние — нейтральным:
      // смысл держится на номере и на форме, цвет только помогает.
      final fill = switch (i) {
        0 => colorScheme.primaryContainer,
        1 => colorScheme.secondaryContainer,
        2 => colorScheme.secondaryContainer,
        _ => colorScheme.surfaceContainerHighest,
      };
      final ink = switch (i) {
        0 => colorScheme.onPrimaryContainer,
        1 || 2 => colorScheme.onSecondaryContainer,
        _ => colorScheme.onSurface,
      };
      panelFrame(canvas, rect, fill: fill);

      _rankBadge(canvas, Offset(rect.left + 24, rect.center.dy), '${i + 1}', ink);

      final iconCenter = Offset(rect.left + 74, rect.center.dy);
      switch (i) {
        case 0:
          drawPoliceOfficer(
            canvas,
            colorScheme,
            Offset(iconCenter.dx, iconCenter.dy + 22),
            44,
            pose: OfficerPose.stop,
          );
        case 1:
          _trafficLight(canvas, iconCenter);
        case 2:
          _roadSign(canvas, iconCenter);
        case 3:
          _pavementMarking(canvas, iconCenter);
        case 4:
          _bareCrossroad(canvas, iconCenter);
      }

      final textLeft = rect.left + 104;
      text(
        canvas,
        _steps[i],
        Offset((textLeft + rect.right - 10) / 2, rect.center.dy),
        ink,
        maxWidth: rect.right - 10 - textLeft,
        fontSize: 13,
        isBold: i == 0,
      );
    }

    _strengthArrow(canvas);

    calloutBox(
      canvas,
      labels.note,
      const Rect.fromLTRB(6, 376, 394, 432),
      fill: colorScheme.surfaceContainerHighest,
      textColor: colorScheme.onSurface,
      fontSize: 11,
    );
  }

  /// Номер ступени в кружке: без него порядок пришлось бы читать по ширине
  /// плашек, а на узком экране разница в 22 px почти не видна.
  void _rankBadge(Canvas canvas, Offset center, String value, Color ink) {
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    text(canvas, value, center, ink, maxWidth: 26, fontSize: 14, isBold: true);
  }

  /// Стрелка «сильнее → слабее» вдоль всей пирамиды. Подпись повёрнута: в
  /// столбик она нечитаема, а места под горизонтальную справа нет.
  void _strengthArrow(Canvas canvas) {
    final top = _rowRect(0).top;
    final bottom = _rowRect(_steps.length - 1).bottom;
    arrow(
      canvas,
      Offset(362, top),
      Offset(362, bottom),
      color: colorScheme.primary,
      width: 2.5,
    );
    canvas.save();
    canvas.translate(386, (top + bottom) / 2);
    canvas.rotate(1.5707963267948966); // pi/2 — читается сверху вниз
    text(
      canvas,
      '${labels.stronger} → ${labels.weaker}',
      Offset.zero,
      colorScheme.primary,
      maxWidth: bottom - top,
      fontSize: 12,
      isBold: true,
    );
    canvas.restore();
  }

  /// Обводка тёмных фигур: на тёмной теме асфальт почти сливается с заливкой
  /// ступени, и без контура иконка пропадает.
  Paint get _iconOutline => Paint()
    ..color = colorScheme.outlineVariant
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  void _trafficLight(Canvas canvas, Offset center) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 22, height: 46),
      const Radius.circular(5),
    );
    canvas.drawRRect(body, Paint()..color = _asphalt);
    canvas.drawRRect(body, _iconOutline);
    for (final (i, color) in [_lightRed, _lightAmber, _lightGreen].indexed) {
      canvas.drawCircle(
        Offset(center.dx, center.dy - 14 + i * 14),
        5.5,
        Paint()..color = color,
      );
    }
  }

  void _roadSign(Canvas canvas, Offset center) {
    canvas.drawLine(
      Offset(center.dx, center.dy + 4),
      Offset(center.dx, center.dy + 24),
      Paint()
        ..color = colorScheme.outline
        ..strokeWidth = 3,
    );
    // I-25 «опасност на путу»: самый общий знак на столбе.
    signs.paint(
      canvas,
      'I-25',
      Rect.fromCenter(
          center: center.translate(0, -8), width: 44, height: 39),
    );
  }

  void _pavementMarking(Canvas canvas, Offset center) {
    final asphalt = Rect.fromCenter(center: center, width: 46, height: 46);
    final box = RRect.fromRectAndRadius(asphalt, const Radius.circular(4));
    canvas.drawRRect(box, Paint()..color = _asphalt);
    canvas.drawRRect(box, _iconOutline);
    // Стрелка направления на асфальте — самая частая «ознака на коловозу».
    arrow(
      canvas,
      Offset(center.dx, center.dy + 16),
      Offset(center.dx, center.dy - 14),
      color: _markingWhite,
      width: 4,
      head: 11,
    );
  }

  void _bareCrossroad(Canvas canvas, Offset center) {
    // Крест из двух дорог рисуем одним путём: у пересечения не должно быть
    // внутренних линий, иначе вместо перекрёстка получается плюс из брусков.
    final path = Path.combine(
      PathOperation.union,
      Path()..addRect(Rect.fromCenter(center: center, width: 46, height: 20)),
      Path()..addRect(Rect.fromCenter(center: center, width: 20, height: 46)),
    );
    canvas.drawPath(path, Paint()..color = _asphalt);
    canvas.drawPath(path, _iconOutline);
    // Ни знака, ни разметки — только две дороги: это и есть пятая ступень.
    dashedLine(
      canvas,
      Offset(center.dx - 23, center.dy),
      Offset(center.dx - 11, center.dy),
      color: _markingWhite,
      dash: 4,
      gap: 3,
      width: 1.6,
    );
    dashedLine(
      canvas,
      Offset(center.dx + 11, center.dy),
      Offset(center.dx + 23, center.dy),
      color: _markingWhite,
      dash: 4,
      gap: 3,
      width: 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _PiramidaPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.labels != labels ||
      oldDelegate.signs != signs;
}
