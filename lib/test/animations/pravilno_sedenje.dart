import 'dart:math' as math;
// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Правильная посадка: подголовник, ремень, детская корзина.
///
/// Схема из двух панелей: сверху — профиль водителя (верх подголовника на
/// уровне темени, ремень через плечо и таз), снизу — детская корзина против
/// хода движения на переднем сиденье при отключённой подушке безопасности.
///
/// Слаг в [animations_map.dart]: `pravilno-sedenje`.
class PravilnoSedenje extends StatelessWidget {
  const PravilnoSedenje({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labels = _SeatLabels.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 590,
          child: CustomPaint(painter: _SeatPainter(colorScheme, labels)),
        ),
      ),
    );
  }
}

/// Подписи схемы. Читаются в `build()` через [BuildContext], иначе Painter
/// закэширует их и при смене языка картинка останется на старом.
class _SeatLabels {
  const _SeatLabels({
    required this.driverTitle,
    required this.headrestTop,
    required this.headrestClose,
    required this.backUpright,
    required this.belt,
    required this.crown,
    required this.eyeLevel,
    required this.childTitle,
    required this.childRear,
    required this.airbagOff,
    required this.direction,
  });

  factory _SeatLabels.of(BuildContext context) => _SeatLabels(
        driverTitle: context.tr(LocaleKeys.pravilnoSedenje_driverTitle),
        headrestTop: context.tr(LocaleKeys.pravilnoSedenje_headrestTop),
        headrestClose: context.tr(LocaleKeys.pravilnoSedenje_headrestClose),
        backUpright: context.tr(LocaleKeys.pravilnoSedenje_backUpright),
        belt: context.tr(LocaleKeys.pravilnoSedenje_belt),
        crown: context.tr(LocaleKeys.pravilnoSedenje_crown),
        eyeLevel: context.tr(LocaleKeys.pravilnoSedenje_eyeLevel),
        childTitle: context.tr(LocaleKeys.pravilnoSedenje_childTitle),
        childRear: context.tr(LocaleKeys.pravilnoSedenje_childRear),
        airbagOff: context.tr(LocaleKeys.pravilnoSedenje_airbagOff),
        direction: context.tr(LocaleKeys.pravilnoSedenje_direction),
      );

  final String driverTitle;
  final String headrestTop;
  final String headrestClose;
  final String backUpright;
  final String belt;
  final String crown;
  final String eyeLevel;
  final String childTitle;
  final String childRear;
  final String airbagOff;
  final String direction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SeatLabels &&
          other.driverTitle == driverTitle &&
          other.headrestTop == headrestTop &&
          other.headrestClose == headrestClose &&
          other.backUpright == backUpright &&
          other.belt == belt &&
          other.crown == crown &&
          other.eyeLevel == eyeLevel &&
          other.childTitle == childTitle &&
          other.childRear == childRear &&
          other.airbagOff == airbagOff &&
          other.direction == direction;

  @override
  int get hashCode => Object.hash(
        driverTitle,
        headrestTop,
        headrestClose,
        backUpright,
        belt,
        crown,
        eyeLevel,
        childTitle,
        childRear,
        airbagOff,
        direction,
      );
}

class _SeatPainter extends CustomPainter {
  _SeatPainter(this.colorScheme, this.labels);

  final ColorScheme colorScheme;
  final _SeatLabels labels;

  // Человек нарисован справа, подписи — слева: так выноски не пересекают
  // силуэт, а голова и подголовник оказываются рядом со своими подписями.
  static const double _boxLeft = 12;
  static const double _boxRight = 184;

  @override
  void paint(Canvas canvas, Size size) {
    _paintDriverPanel(canvas);
    _paintChildPanel(canvas);
  }

  // ==================== ПАНЕЛЬ 1: ВОДИТЕЛЬ (y 8..306) ====================

  void _paintDriverPanel(Canvas canvas) {
    _panelFrame(canvas, const Rect.fromLTRB(8, 8, 392, 306));
    _text(canvas, labels.driverTitle, const Offset(200, 24), colorScheme.onSurface,
        maxWidth: 360, fontSize: 13, isBold: true);

    final seatFill = colorScheme.surfaceContainerHighest;
    final bodyColor = colorScheme.onSurfaceVariant;

    // Сиденье: подголовник, спинка, подушка.
    _seatPart(canvas, const Rect.fromLTRB(212, 50, 248, 108), seatFill);
    _seatPart(canvas, const Rect.fromLTRB(214, 112, 246, 250), seatFill);
    _seatPart(canvas, const Rect.fromLTRB(244, 250, 348, 272), seatFill);

    // Силуэт: спина вплотную к спинке (x = 246), поэтому торс начинается ровно
    // на её кромке — это и есть «леђа у потпуности належу».
    final body = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTRB(246, 114, 286, 248), const Radius.circular(14)),
      body,
    );
    // Бедро, голень, стопа — скруглённые линии одной толщины.
    final limb = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(272, 238), const Offset(338, 238),
        limb..strokeWidth = 24);
    canvas.drawLine(const Offset(338, 238), const Offset(350, 292),
        limb..strokeWidth = 20);
    canvas.drawLine(const Offset(350, 292), const Offset(368, 296),
        limb..strokeWidth = 12);
    canvas.drawLine(const Offset(278, 132), const Offset(322, 168),
        limb..strokeWidth = 14);
    canvas.drawLine(const Offset(272, 100), const Offset(270, 124),
        limb..strokeWidth = 16);
    // Голова: затылок в 2 px от подголовника — «што ближе потиљку».
    canvas.drawCircle(const Offset(274, 84), 24, body);
    canvas.drawCircle(const Offset(288, 76), 2.5,
        Paint()..color = colorScheme.surfaceContainerHighest);

    // Ремень: сначала подложка цветом фона — она отделяет ленту от силуэта
    // на тёмной теме, где и ремень, и тело светлые.
    _belt(canvas, const Offset(254, 122), const Offset(282, 232));
    _belt(canvas, const Offset(268, 242), const Offset(320, 240));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(280, 236), width: 16, height: 12),
          const Radius.circular(3)),
      Paint()..color = colorScheme.primary,
    );

    // Уровни темени и глаз: пунктир от подписи до головы. Верх подголовника
    // (y = 50) лежит выше линии темени (y = 60) — правило видно глазами.
    _dashedLine(canvas, const Offset(_boxRight, 60), const Offset(286, 60));
    _dashedLine(canvas, const Offset(_boxRight, 78), const Offset(250, 78));
    _text(canvas, labels.crown, const Offset(206, 52), colorScheme.onSurface,
        maxWidth: 44, fontSize: 11);
    _text(canvas, labels.eyeLevel, const Offset(206, 88), colorScheme.onSurface,
        maxWidth: 44, fontSize: 11);

    _calloutBox(canvas, labels.headrestTop, const Rect.fromLTRB(_boxLeft, 40, _boxRight, 96));
    _calloutBox(canvas, labels.headrestClose, const Rect.fromLTRB(_boxLeft, 104, _boxRight, 142));
    _arrow(canvas, const Offset(_boxRight, 123), const Offset(246, 100));
    _calloutBox(canvas, labels.backUpright, const Rect.fromLTRB(_boxLeft, 150, _boxRight, 196));
    _arrow(canvas, const Offset(_boxRight, 173), const Offset(212, 176));
    // Ремень подписан не выноской, а образцом цвета: любая стрелка отсюда
    // пересекала бы спинку сиденья.
    _calloutBox(canvas, labels.belt, const Rect.fromLTRB(_boxLeft, 204, _boxRight, 258),
        swatch: colorScheme.primary);
  }

  // ================== ПАНЕЛЬ 2: ДЕТСКАЯ КОРЗИНА (y 318..582) ==================

  void _paintChildPanel(Canvas canvas) {
    _panelFrame(canvas, const Rect.fromLTRB(8, 318, 392, 582));
    _text(canvas, labels.childTitle, const Offset(200, 334), colorScheme.onSurface,
        maxWidth: 360, fontSize: 13, isBold: true);

    final seatFill = colorScheme.surfaceContainerHighest;
    _seatPart(canvas, const Rect.fromLTRB(42, 356, 76, 386), seatFill);
    _seatPart(canvas, const Rect.fromLTRB(44, 390, 76, 500), seatFill);
    _seatPart(canvas, const Rect.fromLTRB(74, 500, 212, 522), seatFill);

    // Корзина наклонена: изголовье ниже и обращено к передку автомобиля
    // (вправо), ножной конец приподнят к спинке — так стоит корзина,
    // окончательно повёрнутая ПРОТИВ хода движения.
    canvas.save();
    canvas.translate(150, 456);
    canvas.rotate(0.26);
    final shell = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 120, height: 72),
        const Radius.circular(16));
    canvas.drawRRect(shell, Paint()..color = colorScheme.tertiaryContainer);
    canvas.drawRRect(
        shell,
        Paint()
          ..color = colorScheme.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // Ручка-дуга: без неё корзина читается просто как коробка.
    canvas.drawPath(
      Path()
        ..moveTo(-38, -36)
        ..quadraticBezierTo(0, -96, 38, -36),
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    final child = Paint()..color = colorScheme.onSurfaceVariant;
    canvas.drawLine(
      const Offset(12, 8),
      const Offset(-34, 16),
      Paint()
        ..color = colorScheme.onSurfaceVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(32, -6), 16, child);
    // Глаз ближе к «спине» корзины: ребёнок смотрит назад по ходу движения.
    canvas.drawCircle(const Offset(24, -12), 3,
        Paint()..color = colorScheme.tertiaryContainer);
    canvas.drawLine(
      const Offset(18, 6),
      const Offset(-10, 12),
      Paint()
        ..color = colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Куда обращена корзина — стрелка влево, ровно против стрелки хода
    // движения внизу панели.
    _arrow(canvas, const Offset(130, 494), const Offset(80, 486));

    _calloutBox(canvas, labels.childRear, const Rect.fromLTRB(232, 350, 388, 404),
        fill: colorScheme.tertiaryContainer,
        textColor: colorScheme.onTertiaryContainer,
        check: true);

    // Подушка безопасности: перечёркнутый круг = «искључен ваздушни јастук».
    // Внутри — та же пиктограмма, что на заводской наклейке: седок и
    // раскрывшаяся подушка перед ним. Слово внутри круга слишком мелкое,
    // поэтому текст вынесен в подпись под кругом.
    const airbag = Offset(272, 448);
    canvas.drawCircle(airbag, 36, Paint()..color = colorScheme.errorContainer);
    canvas.drawCircle(
        airbag,
        36,
        Paint()
          ..color = colorScheme.error
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    final pictogram = Paint()
      ..color = colorScheme.onErrorContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(252, 431), 7,
        Paint()..color = colorScheme.onErrorContainer);
    canvas.drawLine(const Offset(252, 441), const Offset(250, 464), pictogram);
    canvas.drawLine(const Offset(250, 464), const Offset(268, 468),
        pictogram..strokeWidth = 8);
    canvas.drawCircle(const Offset(274, 450), 15,
        Paint()..color = colorScheme.onErrorContainer);
    canvas.drawLine(
      const Offset(247, 423),
      const Offset(297, 473),
      Paint()
        ..color = colorScheme.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round,
    );
    _text(canvas, 'AIRBAG', const Offset(348, 448), colorScheme.onSurface,
        maxWidth: 76, fontSize: 12, isBold: true);
    _calloutBox(canvas, labels.airbagOff, const Rect.fromLTRB(232, 494, 388, 548),
        fill: colorScheme.errorContainer,
        textColor: colorScheme.onErrorContainer);

    // Ход движения — вправо; ребёнок и корзина смотрят в обратную сторону.
    _arrow(canvas, const Offset(40, 554), const Offset(140, 554), width: 3);
    _text(canvas, labels.direction, const Offset(214, 554), colorScheme.onSurface,
        maxWidth: 132, fontSize: 11);
  }

  // ============================ ПРИМИТИВЫ ============================

  void _panelFrame(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..color = colorScheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _seatPart(Canvas canvas, Rect rect, Color fill) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Лента ремня с подложкой цветом фона — контур, который отделяет её от
  /// силуэта в обеих темах.
  void _belt(Canvas canvas, Offset from, Offset to) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = colorScheme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
  }

  void _calloutBox(
    Canvas canvas,
    String text,
    Rect rect, {
    Color? fill,
    Color? textColor,
    Color? swatch,
    bool check = false,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(
        rrect, Paint()..color = fill ?? colorScheme.secondaryContainer);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    var textLeft = rect.left + 8;
    if (swatch != null) {
      canvas.drawLine(
        Offset(rect.left + 10, rect.center.dy),
        Offset(rect.left + 26, rect.center.dy),
        Paint()
          ..color = swatch
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      textLeft = rect.left + 34;
    }
    if (check) {
      // Галочку рисуем путём, а не глифом ✓: в шрифте его может не быть.
      canvas.drawPath(
        Path()
          ..moveTo(rect.left + 10, rect.center.dy)
          ..lineTo(rect.left + 16, rect.center.dy + 7)
          ..lineTo(rect.left + 26, rect.center.dy - 9),
        Paint()
          ..color = textColor ?? colorScheme.onSecondaryContainer
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      textLeft = rect.left + 34;
    }

    final width = rect.right - 8 - textLeft;
    _text(
      canvas,
      text,
      Offset(textLeft + width / 2, rect.center.dy),
      textColor ?? colorScheme.onSecondaryContainer,
      maxWidth: width,
      fontSize: 11,
    );
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to,
      {double dash = 6, double gap = 4}) {
    final paint = Paint()
      ..color = colorScheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final total = (to - from).distance;
    final step = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(from + step * travelled, from + step * end, paint);
      travelled = end + gap;
    }
  }

  void _arrow(Canvas canvas, Offset start, Offset end, {double width = 2}) {
    final paint = Paint()
      ..color = colorScheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawLine(start, end, paint);

    const arrowLen = 12.0;
    const arrowAngle = math.pi / 6;
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - arrowLen * math.cos(angle - arrowAngle),
            end.dy - arrowLen * math.sin(angle - arrowAngle))
        ..lineTo(end.dx - arrowLen * math.cos(angle + arrowAngle),
            end.dy - arrowLen * math.sin(angle + arrowAngle))
        ..close(),
      Paint()..color = colorScheme.outline,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    required double maxWidth,
    double fontSize = 12,
    bool isBold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: kAppFontFamily,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          height: 1.2,
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

  @override
  bool shouldRepaint(covariant _SeatPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.labels != labels;
}
