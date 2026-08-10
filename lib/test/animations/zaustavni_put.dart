import 'dart:math' as math;

// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Зауставни пут = пут реакције + пут кочења.
///
/// Линейка остановочного пути для 50/90/130 km/h: видно, что путь реакции
/// растёт пропорционально скорости, а путь торможения — как её квадрат.
/// Именно поэтому «успею затормозить» на 130 km/h — не то же самое, что на 50.
class ZaustavniPut extends StatelessWidget {
  const ZaustavniPut({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labels = _StoppingLabels.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 320,
          child: CustomPaint(
            painter: _ZaustavniPutPainter(colorScheme, labels),
          ),
        ),
      ),
    );
  }
}

/// Русские пояснения — переводимые. Сербские термины
/// (`зауставни пут`, `пут реакције`, `пут кочења`) в заголовке схемы
/// не переводятся: это экзаменационная лексика.
class _StoppingLabels {
  const _StoppingLabels({
    required this.reactionLegend,
    required this.brakingLegend,
    required this.growthNote,
    required this.conditionsNote,
  });

  /// Читаем строки через [BuildContext], чтобы виджет подписался на смену
  /// локали: Painter кэширует подписи и без этого остался бы на старом языке.
  factory _StoppingLabels.of(BuildContext context) => _StoppingLabels(
        reactionLegend: context.tr(LocaleKeys.stoppingDistance_reactionLegend),
        brakingLegend: context.tr(LocaleKeys.stoppingDistance_brakingLegend),
        growthNote: context.tr(LocaleKeys.stoppingDistance_growthNote),
        conditionsNote: context.tr(LocaleKeys.stoppingDistance_conditionsNote),
      );

  final String reactionLegend;
  final String brakingLegend;
  final String growthNote;
  final String conditionsNote;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _StoppingLabels &&
          other.reactionLegend == reactionLegend &&
          other.brakingLegend == brakingLegend &&
          other.growthNote == growthNote &&
          other.conditionsNote == conditionsNote;

  @override
  int get hashCode => Object.hash(
        reactionLegend,
        brakingLegend,
        growthNote,
        conditionsNote,
      );
}

class _ZaustavniPutPainter extends CustomPainter {
  _ZaustavniPutPainter(this.colorScheme, this.labels);

  final ColorScheme colorScheme;
  final _StoppingLabels labels;

  // Исходные данные расчёта. Время реакции 1 с — то самое «постоянное время»
  // из учебников; замедление 6,5 м/с² — сухой асфальт, исправные тормоза.
  static const double _reactionSeconds = 1.0;
  static const double _deceleration = 6.5;
  static const List<int> _speedsKmh = [50, 90, 130];

  // === СЕТКА 400x320 ===
  static const double _barLeft = 66; // левее — подпись скорости
  static const double _barHeight = 30;
  static const double _rowStep = 46;
  static const double _firstRowTop = 68;
  // 2 px на метр: 136 м самого длинного пути укладываются в 273 px,
  // справа остаётся место под подпись суммы.
  static const double _pxPerMeter = 2.0;

  double _reactionMeters(int kmh) => kmh / 3.6 * _reactionSeconds;

  double _brakingMeters(int kmh) =>
      math.pow(kmh / 3.6, 2) / (2 * _deceleration);

  @override
  void paint(Canvas canvas, Size size) {
    final reactionColor = colorScheme.secondaryContainer;
    final onReaction = colorScheme.onSecondaryContainer;
    // Путь торможения — та часть, которую водитель недооценивает; красим её
    // в «тревожный» контейнер, но смысл держится и на подписи в легенде.
    final brakingColor = colorScheme.errorContainer;
    final onBraking = colorScheme.onErrorContainer;
    final strokeColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;

    // Заголовок — сербская формула целиком, её и надо запомнить.
    _drawText(
      canvas,
      'Зауставни пут = пут реакције + пут кочења',
      const Offset(200, 16),
      textColor,
      maxWidth: 392,
      fontSize: 15,
      isBold: true,
    );

    _drawLegend(canvas, reactionColor, brakingColor, strokeColor, textColor);

    final rowsBottom = _firstRowTop + _rowStep * (_speedsKmh.length - 1) + _barHeight;
    _drawScale(canvas, rowsBottom, strokeColor, textColor);

    for (var i = 0; i < _speedsKmh.length; i++) {
      final kmh = _speedsKmh[i];
      final top = _firstRowTop + _rowStep * i;
      final reaction = _reactionMeters(kmh);
      final braking = _brakingMeters(kmh);

      _drawText(
        canvas,
        '$kmh km/h',
        Offset(31, top + _barHeight / 2),
        textColor,
        maxWidth: 62,
        fontSize: 12,
        isBold: true,
      );

      final reactionWidth = reaction * _pxPerMeter;
      final brakingWidth = braking * _pxPerMeter;

      _drawSegment(
        canvas,
        Rect.fromLTWH(_barLeft, top, reactionWidth, _barHeight),
        reactionColor,
        strokeColor,
        onReaction,
        '${reaction.round()}',
      );
      _drawSegment(
        canvas,
        Rect.fromLTWH(_barLeft + reactionWidth, top, brakingWidth, _barHeight),
        brakingColor,
        strokeColor,
        onBraking,
        '${braking.round()}',
      );

      // Сумма — справа от полосы: её и сравнивают между строками.
      _drawText(
        canvas,
        '${(reaction + braking).round()} m',
        Offset(_barLeft + reactionWidth + brakingWidth + 28, top + _barHeight / 2),
        textColor,
        maxWidth: 56,
        fontSize: 12,
        isBold: true,
      );
    }

    _drawNotes(canvas, textColor);
  }

  @override
  bool shouldRepaint(covariant _ZaustavniPutPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.labels != labels;

  // --- Вспомогательные методы ---

  void _drawLegend(
    Canvas canvas,
    Color reactionColor,
    Color brakingColor,
    Color strokeColor,
    Color textColor,
  ) {
    void swatch(double x, Color color, String text, double maxWidth) {
      final rect = Rect.fromLTWH(x, 38, 14, 14);
      final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rRect, Paint()..color = color);
      canvas.drawRRect(
        rRect,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      _drawTextLeft(
        canvas,
        text,
        Offset(x + 20, 45),
        textColor,
        maxWidth: maxWidth,
        fontSize: 11.5,
      );
    }

    swatch(8, reactionColor, labels.reactionLegend, 170);
    swatch(206, brakingColor, labels.brakingLegend, 166);
  }

  /// Линейка в метрах под полосами: без неё длины сравниваются «на глаз».
  void _drawScale(
    Canvas canvas,
    double rowsBottom,
    Color strokeColor,
    Color textColor,
  ) {
    final gridPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final meters in const [0, 50, 100]) {
      final x = _barLeft + meters * _pxPerMeter;
      canvas.drawPath(
        _dashPath(
          Path()
            ..moveTo(x, _firstRowTop - 6)
            ..lineTo(x, rowsBottom + 6),
        ),
        gridPaint,
      );
      _drawText(
        canvas,
        meters == 0 ? '0' : '$meters m',
        Offset(x, rowsBottom + 18),
        textColor,
        maxWidth: 46,
        fontSize: 11,
      );
    }
  }

  void _drawSegment(
    Canvas canvas,
    Rect rect,
    Color fill,
    Color strokeColor,
    Color textColor,
    String value,
  ) {
    canvas.drawRect(rect, Paint()..color = fill);
    canvas.drawRect(
      rect,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // В узкий сегмент число не влезет — тогда оно есть в сумме справа.
    if (rect.width >= 26) {
      _drawText(
        canvas,
        value,
        rect.center,
        textColor,
        maxWidth: rect.width - 4,
        fontSize: 11.5,
        isBold: true,
      );
    }
  }

  void _drawNotes(Canvas canvas, Color textColor) {
    final text = '${labels.growthNote}\n${labels.conditionsNote}';
    final painter = _textPainter(
      text,
      colorScheme.onSecondaryContainer,
      fontSize: 11.5,
    )..layout(maxWidth: 368);

    final rect = Rect.fromLTWH(8, 226, 384, painter.height + 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = colorScheme.secondaryContainer,
    );
    painter.paint(
      canvas,
      Offset(rect.center.dx - painter.width / 2, rect.top + 9),
    );
  }

  Path _dashPath(Path source, {double dashLength = 4, double gapLength = 4}) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gapLength;
      }
    }
    return dashed;
  }

  TextPainter _textPainter(
    String text,
    Color color, {
    required double fontSize,
    bool isBold = false,
    TextAlign align = TextAlign.center,
  }) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: kAppFontFamily,
            color: color,
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            height: 1.2,
          ),
        ),
        textAlign: align,
        textDirection: TextDirection.ltr,
      );

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    required double maxWidth,
    double fontSize = 12,
    bool isBold = false,
  }) {
    final painter = _textPainter(text, color, fontSize: fontSize, isBold: isBold)
      ..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  /// Текст, прижатый левым краем к [left] и отцентрованный по вертикали.
  void _drawTextLeft(
    Canvas canvas,
    String text,
    Offset left,
    Color color, {
    required double maxWidth,
    double fontSize = 12,
  }) {
    final painter = _textPainter(
      text,
      color,
      fontSize: fontSize,
      align: TextAlign.left,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, Offset(left.dx, left.dy - painter.height / 2));
  }
}
