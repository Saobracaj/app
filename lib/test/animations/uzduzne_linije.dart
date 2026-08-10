import 'dart:math' as math;

// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Продольная разметка: как выглядит и как называется каждая линия.
///
/// Верхняя часть — вид сверху на дорогу с нумерацией **ровно такой, какая
/// почти всегда стоит в экзаменационных картинках** (1 и 2 — ивичне, 3 —
/// неиспрекидана разделна, 4 — линија упозорења): половина вопросов раздела
/// сводится к «покажи номер». Внизу — два случая, которые в поток дороги не
/// вставить: линија водиља внутри перекрёстка и комбинована линија, где
/// решает, с чьей стороны прерывистая.
class UzduzneLinije extends StatelessWidget {
  const UzduzneLinije({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 500,
          child: CustomPaint(
            painter: _UzduzneLinijePainter(
              Theme.of(context).colorScheme,
              _LineLabels.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские пояснения к сербским названиям линий.
class _LineLabels {
  const _LineLabels({
    required this.edge,
    required this.doubleSolid,
    required this.warning,
    required this.guide,
    required this.combined,
    required this.numbers,
  });

  factory _LineLabels.of(BuildContext context) => _LineLabels(
        edge: context.tr(LocaleKeys.uzduzneLinije_edge),
        doubleSolid: context.tr(LocaleKeys.uzduzneLinije_doubleSolid),
        warning: context.tr(LocaleKeys.uzduzneLinije_warning),
        guide: context.tr(LocaleKeys.uzduzneLinije_guide),
        combined: context.tr(LocaleKeys.uzduzneLinije_combined),
        numbers: context.tr(LocaleKeys.uzduzneLinije_numbers),
      );

  final String edge;
  final String doubleSolid;
  final String warning;
  final String guide;
  final String combined;
  final String numbers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LineLabels &&
          other.edge == edge &&
          other.doubleSolid == doubleSolid &&
          other.warning == warning &&
          other.guide == guide &&
          other.combined == combined &&
          other.numbers == numbers;

  @override
  int get hashCode =>
      Object.hash(edge, doubleSolid, warning, guide, combined, numbers);
}

/// Асфальт и разметка — литеральные цвета: белая линия на сером покрытии это
/// и есть содержание схемы, в тёмной теме она выглядит так же.
const _asphalt = Color(0xFF4E4E4E);
const _marking = Color(0xFFF2F2F2);

/// Выноски идут поверх асфальта и поверх фона схемы, поэтому их цвет не берём
/// из темы: серединный серый одинаково виден и на светлом, и на тёмном.
const _leader = Color(0xFF9E9E9E);

const _allowed = Color(0xFF43A047);
const _forbidden = Color(0xFFE53935);

class _UzduzneLinijePainter extends IllustrationPainter {
  _UzduzneLinijePainter(super.colorScheme, this.labels);

  final _LineLabels labels;

  // Дорога вида сверху: одна полоса вниз, две вверх — так на одной картинке
  // помещаются и удвојена неиспрекидана посередине, и линија упозорења.
  static const _road = Rect.fromLTRB(110, 8, 300, 244);
  static const _edgeLeftX = 118.0;
  static const _solidLeftX = 186.0;
  static const _solidRightX = 194.0;
  static const _warningX = 246.0;
  static const _edgeRightX = 292.0;

  @override
  void paint(Canvas canvas, Size size) {
    _drawRoad(canvas);
    _drawRoadLabels(canvas);

    calloutBox(
      canvas,
      labels.numbers,
      const Rect.fromLTRB(4, 252, 396, 286),
      fill: colorScheme.secondaryContainer,
      textColor: colorScheme.onSecondaryContainer,
      fontSize: 11,
    );

    _drawGuideLinePanel(canvas, const Rect.fromLTRB(4, 294, 196, 496));
    _drawCombinedLinePanel(canvas, const Rect.fromLTRB(204, 294, 396, 496));
  }

  // --- Верхняя панель: дорога с четырьмя линиями ---

  void _drawRoad(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(_road, const Radius.circular(4)),
      Paint()..color = _asphalt,
    );

    _solid(canvas, _edgeLeftX, _road.top + 4, _road.bottom - 4);
    _solid(canvas, _solidLeftX, _road.top + 4, _road.bottom - 4);
    _solid(canvas, _solidRightX, _road.top + 4, _road.bottom - 4);
    _solid(canvas, _edgeRightX, _road.top + 4, _road.bottom - 4);
    // Линија упозорења: штрих длинный, промежуток короткий — именно этим она
    // отличается от обычной испрекидане.
    dashedLine(
      canvas,
      Offset(_warningX, _road.top + 6),
      Offset(_warningX, _road.bottom - 6),
      dash: 26,
      gap: 10,
      width: 4,
      color: _marking,
    );

    // Направления движения: без них не видно, что удвојена неиспрекидана
    // делит встречные потоки.
    _directionArrow(canvas, 152, 70, down: true);
    _directionArrow(canvas, 220, 200, down: false);
    _directionArrow(canvas, 269, 130, down: false);
  }

  void _solid(Canvas canvas, double x, double top, double bottom) {
    canvas.drawLine(
      Offset(x, top),
      Offset(x, bottom),
      Paint()
        ..color = _marking
        ..strokeWidth = 4,
    );
  }

  void _directionArrow(Canvas canvas, double x, double y, {required bool down}) {
    final from = Offset(x, down ? y - 22 : y + 22);
    final to = Offset(x, down ? y + 22 : y - 22);
    arrow(canvas, from, to, color: _marking.withValues(alpha: 0.65), head: 9);
  }

  void _drawRoadLabels(Canvas canvas) {
    _lineCallout(
      canvas,
      number: '1',
      badge: const Offset(_edgeLeftX, 56),
      anchor: const Offset(54, 56),
      onLeft: true,
      title: 'ивична линија',
      gloss: labels.edge,
    );
    _lineCallout(
      canvas,
      number: '3',
      badge: const Offset(190, 156),
      anchor: const Offset(54, 156),
      onLeft: true,
      title: 'разделна удвојена\nнеиспрекидана',
      gloss: labels.doubleSolid,
    );
    _lineCallout(
      canvas,
      number: '4',
      badge: const Offset(_warningX, 84),
      anchor: const Offset(350, 84),
      onLeft: false,
      title: 'разделна линија\nупозорења',
      gloss: labels.warning,
    );
    _lineCallout(
      canvas,
      number: '2',
      badge: const Offset(_edgeRightX, 196),
      anchor: const Offset(350, 196),
      onLeft: false,
      title: 'ивична линија',
      gloss: labels.edge,
    );
  }

  /// Выноска: кружок с номером прямо на линии, линия-указка и подпись сбоку —
  /// сербское название сверху, русское пояснение под ним.
  void _lineCallout(
    Canvas canvas, {
    required String number,
    required Offset badge,
    required Offset anchor,
    required bool onLeft,
    required String title,
    required String gloss,
  }) {
    const maxWidth = 96.0;
    canvas.drawLine(
      Offset(onLeft ? anchor.dx + maxWidth / 2 - 2 : anchor.dx - maxWidth / 2 + 2,
          badge.dy),
      Offset(badge.dx + (onLeft ? -10 : 10), badge.dy),
      Paint()
        ..color = _leader
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(badge, 9, Paint()..color = _marking);
    canvas.drawCircle(
      badge,
      9,
      Paint()
        ..color = _asphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    text(canvas, number, badge, _asphalt,
        maxWidth: 18, fontSize: 12, isBold: true);

    final titleSize = measure(title, maxWidth: maxWidth, fontSize: 11.5, isBold: true);
    final glossSize = measure(gloss, maxWidth: maxWidth, fontSize: 10);
    final totalHeight = titleSize.height + 3 + glossSize.height;
    final titleCenter =
        Offset(anchor.dx, anchor.dy - totalHeight / 2 + titleSize.height / 2);
    text(canvas, title, titleCenter, colorScheme.onSurface,
        maxWidth: maxWidth, fontSize: 11.5, isBold: true);
    text(
      canvas,
      gloss,
      Offset(anchor.dx, anchor.dy + totalHeight / 2 - glossSize.height / 2),
      colorScheme.onSurfaceVariant,
      maxWidth: maxWidth,
      fontSize: 10,
    );
  }

  // --- Нижняя левая панель: линија водиља ---

  void _drawGuideLinePanel(Canvas canvas, Rect panel) {
    panelFrame(canvas, panel, fill: colorScheme.surfaceContainerHighest);

    final vertical = Rect.fromLTRB(panel.left + 56, panel.top + 8,
        panel.left + 136, panel.top + 146);
    final horizontal = Rect.fromLTRB(panel.left + 8, panel.top + 38,
        panel.right - 8, panel.top + 112);
    canvas.drawRect(vertical, Paint()..color = _asphalt);
    canvas.drawRect(horizontal, Paint()..color = _asphalt);

    // Осевые обеих дорог обрываются на въезде в перекрёсток — внутри него
    // разметки нет, кроме линије водиље.
    _dashedSegment(canvas, Offset(vertical.center.dx, vertical.top + 4),
        Offset(vertical.center.dx, horizontal.top - 4));
    _dashedSegment(canvas, Offset(vertical.center.dx, horizontal.bottom + 4),
        Offset(vertical.center.dx, vertical.bottom - 4));
    _dashedSegment(canvas, Offset(horizontal.left + 4, horizontal.center.dy),
        Offset(vertical.left - 4, horizontal.center.dy));
    _dashedSegment(canvas, Offset(vertical.right + 4, horizontal.center.dy),
        Offset(horizontal.right - 4, horizontal.center.dy));

    // Сама водиља: частые короткие штрихи по траектории левого поворота.
    final path = Path()
      ..moveTo(vertical.center.dx + 20, horizontal.bottom)
      ..quadraticBezierTo(
        vertical.center.dx + 20,
        horizontal.center.dy - 12,
        vertical.left - 2,
        horizontal.center.dy - 12,
      );
    canvas.drawPath(
      // Штрихи вдвое короче и чаще, чем у обычной испрекидане на въезде —
      // именно по этому водиља и узнаётся на картинке вопроса.
      _dashPath(path, dash: 5, gap: 4),
      Paint()
        ..color = _marking
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    _panelCaption(
      canvas,
      panel,
      title: 'линија водиља',
      gloss: labels.guide,
      top: panel.top + 154,
    );
  }

  /// Обычная разделна испрекидана линија на подходе к перекрёстку.
  void _dashedSegment(Canvas canvas, Offset from, Offset to) {
    dashedLine(canvas, from, to, dash: 10, gap: 8, width: 3, color: _marking);
  }

  // --- Нижняя правая панель: комбинована линија ---

  void _drawCombinedLinePanel(Canvas canvas, Rect panel) {
    panelFrame(canvas, panel, fill: colorScheme.surfaceContainerHighest);

    final road = Rect.fromLTRB(
        panel.left + 16, panel.top + 8, panel.right - 16, panel.top + 146);
    canvas.drawRect(road, Paint()..color = _asphalt);

    final solidX = road.center.dx - 4;
    final dashedX = road.center.dx + 4;
    canvas.drawLine(
      Offset(solidX, road.top + 4),
      Offset(solidX, road.bottom - 4),
      Paint()
        ..color = _marking
        ..strokeWidth = 3.5,
    );
    dashedLine(
      canvas,
      Offset(dashedX, road.top + 4),
      Offset(dashedX, road.bottom - 4),
      dash: 14,
      gap: 12,
      width: 3.5,
      color: _marking,
    );

    // Справа прерывистая ближе — оттуда пересекать можно; слева ближе
    // сплошная, и тот же манёвр запрещён.
    final rightLaneX = (dashedX + road.right) / 2;
    final leftLaneX = (road.left + solidX) / 2;

    arrow(
      canvas,
      Offset(rightLaneX, road.bottom - 16),
      Offset(leftLaneX, road.bottom - 62),
      color: _allowed,
      width: 3,
      head: 11,
    );
    drawCheck(canvas, Offset(rightLaneX + 12, road.bottom - 24), 7, _allowed);

    arrow(
      canvas,
      Offset(leftLaneX, road.top + 62),
      Offset(rightLaneX, road.top + 20),
      color: _forbidden,
      width: 3,
      head: 11,
    );
    drawCross(canvas, Offset(road.center.dx, road.top + 41), 8, _forbidden,
        width: 3.5);

    _panelCaption(
      canvas,
      panel,
      title: 'разделна комбинована',
      gloss: labels.combined,
      top: panel.top + 154,
    );
  }

  // --- Общее ---

  void _panelCaption(
    Canvas canvas,
    Rect panel, {
    required String title,
    required String gloss,
    required double top,
  }) {
    final width = panel.width - 16;
    final titleSize = measure(title, maxWidth: width, fontSize: 12, isBold: true);
    text(canvas, title, Offset(panel.center.dx, top + titleSize.height / 2),
        colorScheme.onSurface,
        maxWidth: width, fontSize: 12, isBold: true);
    final glossSize = measure(gloss, maxWidth: width, fontSize: 10.5);
    text(
      canvas,
      gloss,
      Offset(panel.center.dx, top + titleSize.height + 4 + glossSize.height / 2),
      colorScheme.onSurfaceVariant,
      maxWidth: width,
      fontSize: 10.5,
    );
  }

  /// Пунктир вдоль произвольного пути (у [dashedLine] из painters.dart он
  /// только прямой, а водиља идёт по дуге).
  Path _dashPath(Path source, {required double dash, required double gap}) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        result.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gap;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _UzduzneLinijePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.labels != labels;
}
