import 'dart:math' as math;
// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/theme/app_theme.dart';

class ThemedCompactDecisionTree extends StatelessWidget {
  const ThemedCompactDecisionTree({super.key});

  @override
  Widget build(BuildContext context) {
    // Получаем текущую цветовую схему приложения (светлую или темную)
    final colorScheme = Theme.of(context).colorScheme;
    final labels = _TreeLabels.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 600,
          // Передаем цветовую схему и переведенные подписи внутрь Painter
          child: CustomPaint(
            painter: _ThemedTreePainter(colorScheme, labels),
          ),
        ),
      ),
    );
  }
}

/// Переведенные подписи дерева. Названия категорий транспорта
/// (лаки/тешки трицикл, лаки/тешки четвороцикл, путничко возило) — это
/// сербские термины из правил, они не переводятся.
class _TreeLabels {
  const _TreeLabels({
    required this.yes,
    required this.no,
    required this.fuelNote,
    required this.wheelsQuestion,
    required this.lightLimits,
    required this.withinLightLimits,
    required this.withinLightLimitsAndMass,
    required this.powerLimit,
    required this.seatsNote,
  });

  /// Читаем строки через [BuildContext], чтобы виджет подписался на смену
  /// локали: Painter кэширует подписи и без этого остался бы на старом языке.
  factory _TreeLabels.of(BuildContext context) => _TreeLabels(
        yes: context.tr(LocaleKeys.decisionTree_yes),
        no: context.tr(LocaleKeys.decisionTree_no),
        fuelNote: context.tr(LocaleKeys.decisionTree_fuelNote),
        wheelsQuestion: context.tr(LocaleKeys.decisionTree_wheelsQuestion),
        lightLimits: context.tr(LocaleKeys.decisionTree_lightLimits),
        withinLightLimits: context.tr(LocaleKeys.decisionTree_withinLightLimits),
        withinLightLimitsAndMass:
            context.tr(LocaleKeys.decisionTree_withinLightLimitsAndMass),
        powerLimit: context.tr(LocaleKeys.decisionTree_powerLimit),
        seatsNote: context.tr(LocaleKeys.decisionTree_seatsNote),
      );

  final String yes;
  final String no;
  final String fuelNote;
  final String wheelsQuestion;
  final String lightLimits;
  final String withinLightLimits;
  final String withinLightLimitsAndMass;
  final String powerLimit;
  final String seatsNote;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TreeLabels &&
          other.yes == yes &&
          other.no == no &&
          other.fuelNote == fuelNote &&
          other.wheelsQuestion == wheelsQuestion &&
          other.lightLimits == lightLimits &&
          other.withinLightLimits == withinLightLimits &&
          other.withinLightLimitsAndMass == withinLightLimitsAndMass &&
          other.powerLimit == powerLimit &&
          other.seatsNote == seatsNote;

  @override
  int get hashCode => Object.hash(
        yes,
        no,
        fuelNote,
        wheelsQuestion,
        lightLimits,
        withinLightLimits,
        withinLightLimitsAndMass,
        powerLimit,
        seatsNote,
      );
}

class _ThemedTreePainter extends CustomPainter {
  final ColorScheme colorScheme;
  final _TreeLabels labels;

  _ThemedTreePainter(this.colorScheme, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    // === КООРДИНАТЫ (СЕТКА 400x600) ===
    final noteCenter = const Offset(200, 40);
    final rootCenter = const Offset(200, 120);

    final diamond3Center = const Offset(60, 250);
    // Ромб сдвинут влево от 340: при ширине 130 его правая вершина иначе
    // вылезает за холст 400 и обрезается.
    final diamond4Center = const Offset(335, 250);

    // Сноска с лимитами уже и левее, чтобы не касаться правого ромба.
    final limitCenter = const Offset(193, 230);

    final laki3Center = const Offset(50, 380);
    final teski3Center = const Offset(150, 380);

    final laki4Center = const Offset(250, 380);
    final diamondPowCenter = const Offset(350, 380);

    final teski4Center = const Offset(250, 520);
    final autoCenter = const Offset(350, 520);

    // === ПАЛИТРА MATERIAL DESIGN ===
    // Вместо жестких цветов используем семантические цвета темы
    final noteColor = colorScheme.surfaceContainerHighest;
    final diamondColor = colorScheme.secondaryContainer;

    // Результаты
    final lakiColor = colorScheme.tertiaryContainer; // Мягкий акцентный (вместо зеленого)
    final teskiColor = colorScheme.errorContainer;   // Цвет ошибки/предупреждения (вместо красного)
    final autoColor = colorScheme.primaryContainer;  // Основной акцентный (вместо синего)

    final strokeColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;

    // === ОТРИСОВКА СТРЕЛОК ===
    _drawArrow(canvas, const Offset(160, 140), const Offset(60, 195), '3', strokeColor, textColor);
    _drawArrow(canvas, const Offset(240, 140), const Offset(340, 205), '4', strokeColor, textColor);

    _drawArrow(canvas, const Offset(50, 295), const Offset(50, 355), labels.yes, strokeColor, textColor, textOffset: const Offset(35, 310));
    _drawArrow(canvas, const Offset(90, 280), const Offset(150, 355), labels.no, strokeColor, textColor, textOffset: const Offset(135, 310));

    _drawArrow(canvas, const Offset(310, 275), const Offset(250, 355), labels.yes, strokeColor, textColor, textOffset: const Offset(260, 310));
    _drawArrow(canvas, const Offset(335, 275), const Offset(350, 335), labels.no, strokeColor, textColor, textOffset: const Offset(360, 310));

    _drawArrow(canvas, const Offset(325, 405), const Offset(250, 495), labels.yes, strokeColor, textColor, textOffset: const Offset(275, 440));
    _drawArrow(canvas, const Offset(350, 425), const Offset(350, 495), labels.no, strokeColor, textColor, textOffset: const Offset(365, 440));

    // === ОТРИСОВКА УЗЛОВ ===
    _drawBox(canvas, labels.fuelNote, noteCenter, noteColor, strokeColor, textColor, width: 380, height: 45, fontSize: 14);
    _drawBox(canvas, labels.wheelsQuestion, rootCenter, noteColor, strokeColor, textColor, width: 140, height: 40, fontSize: 14);
    _drawBox(canvas, labels.lightLimits, limitCenter, noteColor, strokeColor, textColor, width: 130, height: 80, fontSize: 14, dashed: true);



    _drawDiamond(canvas, labels.withinLightLimits, diamond3Center, diamondColor, strokeColor, colorScheme.onSecondaryContainer, width: 130, height: 110, fontSize: 11);
    // Ромб выше остальных: подпись в три строки, а у ромба к краям остаётся
    // всё меньше ширины — на высоте 100 нижняя строка вылезала за грани.
    _drawDiamond(canvas, labels.withinLightLimitsAndMass, diamond4Center, diamondColor, strokeColor, colorScheme.onSecondaryContainer, width: 130, height: 112, fontSize: 11);
    _drawDiamond(canvas, labels.powerLimit, diamondPowCenter, diamondColor, strokeColor, colorScheme.onSecondaryContainer, width: 90, height: 90, fontSize: 13);

    // Названия категорий — сербские термины из правил, не переводятся
    _drawBox(canvas, 'лаки\nтрицикл', laki3Center, lakiColor, strokeColor, colorScheme.onTertiaryContainer, width: 85, height: 50, fontSize: 13);
    _drawBox(canvas, 'тешки\nтрицикл', teski3Center, teskiColor, strokeColor, colorScheme.onErrorContainer, width: 85, height: 50, fontSize: 13);
    // Ширина 100, а не 90, как у трициклов: «четвороцикл» длиннее и при 90
    // переносится последней буквой на третью строку.
    _drawBox(canvas, 'лаки\nчетвороцикл', laki4Center, lakiColor, strokeColor, colorScheme.onTertiaryContainer, width: 100, height: 50, fontSize: 13);
    _drawBox(canvas, 'тешки\nчетвороцикл', teski4Center, teskiColor, strokeColor, colorScheme.onErrorContainer, width: 100, height: 50, fontSize: 13);
    _drawBox(canvas, 'путничко\nвозило\n${labels.seatsNote}', autoCenter, autoColor, strokeColor, colorScheme.onPrimaryContainer, width: 90, height: 55, fontSize: 13);
  }

  @override
  bool shouldRepaint(covariant _ThemedTreePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.labels != labels;

  // --- Вспомогательные методы с поддержкой тем ---

  void _drawBox(Canvas canvas, String text, Offset center, Color bgColor, Color strokeColor, Color textColor, {required double width, required double height, double fontSize = 12, bool dashed = false}) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    final paintFill = Paint()..color = bgColor..style = PaintingStyle.fill;
    final paintStroke = Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = 1.5;

    canvas.drawRRect(rRect, paintFill);
    if (dashed) {
      canvas.drawPath(_dashPath(Path()..addRRect(rRect)), paintStroke);
    } else {
      canvas.drawRRect(rRect, paintStroke);
    }

    _drawText(canvas, text, center, textColor, maxWidth: width - 8, fontSize: fontSize);
  }

  Path _dashPath(Path source, {double dashLength = 6, double gapLength = 4}) {
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

  void _drawDiamond(Canvas canvas, String text, Offset center, Color bgColor, Color strokeColor, Color textColor, {required double width, required double height, double fontSize = 12}) {
    final halfW = width / 2;
    final halfH = height / 2;
    final path = Path()
      ..moveTo(center.dx, center.dy - halfH)
      ..lineTo(center.dx + halfW, center.dy)
      ..lineTo(center.dx, center.dy + halfH)
      ..lineTo(center.dx - halfW, center.dy)
      ..close();

    final paintFill = Paint()..color = bgColor..style = PaintingStyle.fill;
    final paintStroke = Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = 1.5;

    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintStroke);

    _drawText(canvas, text, center, textColor, maxWidth: width * 0.75, fontSize: fontSize);
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, String label, Color strokeColor, Color textColor, {Offset? textOffset}) {
    final paintLine = Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawLine(start, end, paintLine);

    const arrowLen = 12.0;
    const arrowAngle = math.pi / 6;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx);

    final p1 = Offset(
      end.dx - arrowLen * math.cos(angle - arrowAngle),
      end.dy - arrowLen * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      end.dx - arrowLen * math.cos(angle + arrowAngle),
      end.dy - arrowLen * math.sin(angle + arrowAngle),
    );

    final path = Path()..moveTo(end.dx, end.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close();
    canvas.drawPath(path, Paint()..color = strokeColor);

    final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final finalOffset = textOffset ?? Offset(midPoint.dx, midPoint.dy - 15);
    _drawText(canvas, label, finalOffset, textColor, fontSize: 13, isBold: true, maxWidth: 40);
  }

  void _drawText(Canvas canvas, String text, Offset center, Color textColor, {required double maxWidth, double fontSize = 12, bool isBold = false}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor, // Используем цвет текста из темы
        // Без явного семейства TextPainter рисует системным шрифтом, а не
        // шрифтом приложения — метрики расходятся с теми, что проверяет
        // decision_tree_localization_test.
        fontFamily: kAppFontFamily,
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        height: 1.15,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: maxWidth);

    final offset = Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2);
    textPainter.paint(canvas, offset);
  }
}