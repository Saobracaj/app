import 'dart:math' as math;

// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Расшифровка маркировки шины 195/65 R 16 89 H на боковине.
///
/// Каждый код на боковине подсвечен своим цветом, и тем же цветом помечена
/// строка расшифровки внизу: выносок-линий шесть, они бы пересеклись между
/// собой (коды идут слева направо, а подписи — сверху вниз), поэтому связь
/// «код ↔ значение» держится на цвете, а не на линиях.
class OznakaPneumatika extends StatelessWidget {
  const OznakaPneumatika({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 616,
          child: CustomPaint(
            painter: _TirePainter(
              Theme.of(context).colorScheme,
              _tireLabels(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские пояснения к кодам. Сербские термины (*ширина пнеуматика*,
/// *брзинска ознака*) не переводятся и живут прямо в коде.
typedef _TireLabels = ({
  String width,
  String profile,
  String radial,
  String rim,
  String load,
  String speed,
  String winter,
  String wear,
});

/// Читаем строки через [BuildContext], чтобы виджет подписался на смену
/// локали: painter кэширует подписи и иначе остался бы на старом языке.
/// Запись (record) сравнивается по значению, поэтому [_TirePainter.shouldRepaint]
/// сам замечает смену языка.
_TireLabels _tireLabels(BuildContext context) => (
      width: context.tr(LocaleKeys.tireMarking_width),
      profile: context.tr(LocaleKeys.tireMarking_profile),
      radial: context.tr(LocaleKeys.tireMarking_radial),
      rim: context.tr(LocaleKeys.tireMarking_rim),
      load: context.tr(LocaleKeys.tireMarking_load),
      speed: context.tr(LocaleKeys.tireMarking_speed),
      winter: context.tr(LocaleKeys.tireMarking_winter),
      wear: context.tr(LocaleKeys.tireMarking_wear),
    );

/// Один код маркировки: как он написан на боковине, каким цветом подсвечен,
/// сербский термин и русское пояснение.
class _Code {
  const _Code(this.code, this.color, this.term, this.hint);

  final String code;
  final Color color;
  final String term;
  final String hint;
}

class _TirePainter extends CustomPainter {
  _TirePainter(this.scheme, this.labels);

  final ColorScheme scheme;
  final _TireLabels labels;

  // Резина чёрная в обеих темах — это её собственный цвет, а не цвет темы;
  // текст на ней всегда светлый, поэтому на тёмной теме ничего не пропадает.
  static const _rubber = Color(0xFF3C4046);
  static const _rubberDark = Color(0xFF26282C);
  static const _rim = Color(0xFF9AA0A6);
  static const _engraved = Color(0xFFE8EAED);
  static const _onChip = Color(0xFF1B1B1B);

  // Центр колеса лежит далеко ниже холста: видна только верхняя дуга шины —
  // так и выглядит крупный план боковины.
  static const _wheelCenter = Offset(200, 470);
  static const _rTreadOuter = 385.0;
  static const _rSidewall = 340.0;
  static const _rRimOuter = 250.0;

  static const _markingCenterY = 178.0;
  static const _legendTop = 268.0;
  static const _rowHeight = 40.0;

  List<_Code> get _codes => [
        _Code('195', const Color(0xFFFFD54F), 'ширина (mm)', labels.width),
        _Code('65', const Color(0xFF90CAF9), 'однос висине и ширине (%)',
            labels.profile),
        _Code('R', const Color(0xFFA5D6A7), 'радијална конструкција',
            labels.radial),
        _Code('16', const Color(0xFFFFAB91), 'пречник наплатка (цоли)',
            labels.rim),
        _Code('89', const Color(0xFFCE93D8), 'ознака носивости', labels.load),
        _Code('H', const Color(0xFF80CBC4), 'брзинска ознака', labels.speed),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final codes = _codes;
    _paintTire(canvas, codes);
    _paintLegend(canvas, codes);
    _paintExtraMarks(canvas);
  }

  // --- Боковина шины с маркировкой ---

  void _paintTire(Canvas canvas, List<_Code> codes) {
    // Крупный план: колесо целиком в холст не влезает, видна вырезанная
    // «фотография» его верхней части.
    const frame = Rect.fromLTRB(4, 76, 396, 252);
    final frameShape =
        RRect.fromRectAndRadius(frame, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(frameShape);

    canvas.drawPath(_ring(_rTreadOuter, _rSidewall), Paint()..color = _rubberDark);

    // Протектор: радиальные прорези по дуге — по ним шина и опознаётся.
    final groove = Paint()
      ..color = _rubber
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;
    for (var deg = -145.0; deg <= -35.0; deg += 7) {
      final a = deg * math.pi / 180;
      canvas.drawLine(
        _wheelCenter + Offset(math.cos(a), math.sin(a)) * (_rSidewall + 4),
        _wheelCenter + Offset(math.cos(a), math.sin(a)) * (_rTreadOuter - 4),
        groove,
      );
    }

    canvas.drawPath(_ring(_rSidewall, _rRimOuter), Paint()..color = _rubber);
    canvas.drawPath(
      _ring(_rSidewall, _rSidewall - 4),
      Paint()..color = _rubberDark,
    );
    canvas.drawPath(_ring(_rRimOuter, 210), Paint()..color = _rim);

    _paintMarking(canvas, codes);
    canvas.restore();

    // Рамка вокруг снимка: на тёмной теме чёрная резина иначе сливается с
    // фоном экрана.
    canvas.drawRRect(
      frameShape,
      Paint()
        ..color = scheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Кольцо между двумя радиусами — из него собираются протектор, боковина
  /// и обод.
  Path _ring(double outer, double inner) => Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: _wheelCenter, radius: outer)),
        Path()..addOval(Rect.fromCircle(center: _wheelCenter, radius: inner)),
      );

  /// Строка «195/65 R 16 89 H»: коды — цветными плашками, разделители —
  /// выдавленными в резине символами.
  void _paintMarking(Canvas canvas, List<_Code> codes) {
    const fontSize = 22.0;
    const chipPadding = 6.0;
    const gap = 7.0;
    const separatorWidth = 12.0;

    // Между 195 и 65 стоит косая черта, дальше — пробелы: сначала считаем
    // общую ширину, чтобы строка встала точно по центру боковины.
    double total = 0;
    for (var i = 0; i < codes.length; i++) {
      total += measureCanvasText(codes[i].code,
              fontSize: fontSize, fontWeight: FontWeight.bold) +
          chipPadding * 2;
      if (i == 0) {
        total += separatorWidth;
      } else if (i < codes.length - 1) {
        total += gap;
      }
    }

    var x = 200 - total / 2;
    for (var i = 0; i < codes.length; i++) {
      final code = codes[i];
      final textWidth = measureCanvasText(code.code,
          fontSize: fontSize, fontWeight: FontWeight.bold);
      final chipWidth = textWidth + chipPadding * 2;
      final rect = Rect.fromCenter(
        center: Offset(x + chipWidth / 2, _markingCenterY),
        width: chipWidth,
        height: 34,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = code.color,
      );
      drawCanvasText(
        canvas,
        code.code,
        rect.center,
        _onChip,
        maxWidth: chipWidth,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      );
      x += chipWidth;

      if (i == 0) {
        drawCanvasText(
          canvas,
          '/',
          Offset(x + separatorWidth / 2, _markingCenterY),
          _engraved,
          maxWidth: separatorWidth + 6,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        );
        x += separatorWidth;
      } else {
        x += gap;
      }
    }

    // M+S и TWI — тоже надписи на боковине, но не часть размера, поэтому
    // отдельной строкой и без плашек.
    drawCanvasText(canvas, 'M+S', const Offset(132, 216), _engraved,
        maxWidth: 80, fontSize: 15, fontWeight: FontWeight.bold);
    drawCanvasText(canvas, 'TWI', const Offset(268, 216), _engraved,
        maxWidth: 80, fontSize: 15, fontWeight: FontWeight.bold);
  }

  // --- Расшифровка кодов ---

  void _paintLegend(Canvas canvas, List<_Code> codes) {
    for (var i = 0; i < codes.length; i++) {
      final code = codes[i];
      final centerY = _legendTop + _rowHeight * i + _rowHeight / 2;

      final chip = Rect.fromCenter(
        center: Offset(38, centerY),
        width: 52,
        height: 26,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chip, const Radius.circular(6)),
        Paint()..color = code.color,
      );
      drawCanvasText(canvas, code.code, chip.center, _onChip,
          maxWidth: 52, fontSize: 15, fontWeight: FontWeight.bold);

      drawCanvasText(
        canvas,
        code.term,
        Offset(76, centerY - 9),
        scheme.onSurface,
        maxWidth: 316,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        textAlign: TextAlign.left,
        anchor: Alignment.centerLeft,
      );
      drawCanvasText(
        canvas,
        code.hint,
        Offset(76, centerY + 9),
        scheme.onSurfaceVariant,
        maxWidth: 316,
        fontSize: 11.5,
        textAlign: TextAlign.left,
        anchor: Alignment.centerLeft,
      );

      if (i < codes.length - 1) {
        canvas.drawLine(
          Offset(16, centerY + _rowHeight / 2),
          Offset(384, centerY + _rowHeight / 2),
          Paint()
            ..color = scheme.outlineVariant
            ..strokeWidth = 1,
        );
      }
    }
  }

  // --- M+S и TWI ---

  void _paintExtraMarks(Canvas canvas) {
    _paintMarkCard(canvas, const Rect.fromLTWH(8, 524, 186, 84), 'M+S',
        'зимски пнеуматик', labels.winter);
    _paintMarkCard(canvas, const Rect.fromLTWH(206, 524, 186, 84), 'TWI',
        'индикатор истрошености', labels.wear);
  }

  void _paintMarkCard(
    Canvas canvas,
    Rect rect,
    String mark,
    String term,
    String hint,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = scheme.surfaceContainerHighest,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..color = scheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Кусочек той же резины, что и на боковине: подпись читается как надпись
    // на шине, а не как ещё один термин из таблицы.
    final swatch = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + 22),
      width: 84,
      height: 28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(swatch, const Radius.circular(6)),
      Paint()..color = _rubber,
    );
    drawCanvasText(canvas, mark, swatch.center, _engraved,
        maxWidth: 84, fontSize: 16, fontWeight: FontWeight.bold);

    drawCanvasText(
      canvas,
      term,
      Offset(rect.center.dx, rect.top + 51),
      scheme.onSurface,
      maxWidth: rect.width - 16,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );
    drawCanvasText(
      canvas,
      hint,
      Offset(rect.center.dx, rect.top + 70),
      scheme.onSurfaceVariant,
      maxWidth: rect.width - 12,
      fontSize: 11.5,
    );
  }

  @override
  bool shouldRepaint(covariant _TirePainter oldDelegate) =>
      oldDelegate.scheme != scheme || oldDelegate.labels != labels;
}
