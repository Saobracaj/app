import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Какую полосу занять перед поворотом: направо — крайнюю правую, налево —
/// крайнюю левую.
///
/// Ошибка, которую снимает схема: кажется, что поворачивать можно «с той
/// полосы, с которой удобнее», пропустив тех, кто едет по крайней. Правило
/// обратное — полоса определена заранее, и выбирать её по удобству нельзя.
/// Поэтому оба поворота нарисованы на одной проезжей части: видно, что
/// машины стоят в разных полосах ещё до перекрёстка.
///
/// Второй сюжет — односторонняя дорога: там «крайняя левая» — это полоса у
/// левого края пути, а не у разделительной линии, которой просто нет.
class PozicijaPredSkretanje extends StatelessWidget {
  const PozicijaPredSkretanje({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 570,
          child: CustomPaint(
            painter: _PozicijaPainter(Theme.of(context).colorScheme),
          ),
        ),
      ),
    );
  }
}

/// Асфальт, разметка и цвета машин от темы не зависят: это их собственный
/// цвет, и по нему траектория связывается со своей машиной.
const _asphalt = Color(0xFF4E545B);
const _marking = Color(0xFFF2F2F2);
const _carGreen = Color(0xFF2E9E5B);
const _carBlue = Color(0xFF3D7BD6);

class _PozicijaPainter extends IllustrationPainter {
  _PozicijaPainter(super.colorScheme);

  // Двусторонняя дорога. Полосы считаются сверху вниз: встречная, наша левая
  // (у разделительной линии), наша правая (у правого края).
  static const _aRoadTop = 100.0;
  static const _aCenterLine = 138.0;
  static const _aLaneLine = 176.0;
  static const _aRoadBottom = 214.0;
  static const _aLeftLane = 157.0;
  static const _aRightLane = 195.0;

  // Поперечная дорога общая для обоих сюжетов: те же координаты по X, чтобы
  // траектории «налево» на двусторонней и на односторонней читались рядом.
  static const _crossLeft = 250.0;
  static const _crossRight = 342.0;
  static const _crossMiddle = 296.0;

  /// Половины поперечной дороги: вниз едут по левой (по ходу — правой),
  /// вверх — по правой. Траектория обязана попасть в свою половину, иначе
  /// схема учит выезжать на встречную.
  static const _downLane = 273.0;
  static const _upLane = 319.0;

  // Односторонняя дорога: две полосы в одну сторону, разделительной нет.
  static const _bRoadTop = 400.0;
  static const _bLaneLine = 438.0;
  static const _bRoadBottom = 476.0;
  static const _bLeftLane = 419.0;
  static const _bRightLane = 457.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _drawTwoWayPanel(canvas);
    _drawOneWayPanel(canvas);
    _drawFooter(canvas);
  }

  // ── Сюжет 1: двусторонняя дорога ──────────────────────────────────────

  void _drawTwoWayPanel(Canvas canvas) {
    text(
      canvas,
      'двосмерни пут: траку бираш пре раскрснице',
      const Offset(200, 22),
      colorScheme.onSurface,
      maxWidth: 380,
      fontSize: 12,
      isBold: true,
    );

    final asphalt = Paint()..color = _asphalt;
    canvas.drawRect(
      const Rect.fromLTRB(_crossLeft, 34, _crossRight, 252),
      asphalt,
    );
    canvas.drawRect(
      const Rect.fromLTRB(12, _aRoadTop, 388, _aRoadBottom),
      asphalt,
    );

    _mainRoadMarkings(
      canvas,
      top: _aRoadTop,
      bottom: _aRoadBottom,
      centerLine: _aCenterLine,
      laneLine: _aLaneLine,
    );
    _crossRoadMarkings(canvas, from: 34, to: 252, roadTop: _aRoadTop,
        roadBottom: _aRoadBottom);

    // Обе машины стоят на одной линии подъезда: разница только в полосе.
    drawCarTopView(
      canvas,
      this,
      const Rect.fromLTWH(64, _aLeftLane - 15, 62, 30),
      body: _carBlue,
    );
    drawCarTopView(
      canvas,
      this,
      const Rect.fromLTWH(64, _aRightLane - 15, 62, 30),
      body: _carGreen,
    );

    _turnArrow(
      canvas,
      const Offset(134, _aRightLane),
      const Offset(_downLane, _aRightLane),
      const Offset(_downLane, 244),
      _carGreen,
    );
    _turnArrow(
      canvas,
      const Offset(134, _aLeftLane),
      const Offset(_upLane, _aLeftLane),
      const Offset(_upLane, 44),
      _carBlue,
    );

    // Термины подписаны прямо на разметке: в вариантах ответа они звучат
    // именно так — «уз разделну линију», «уз десну ивицу коловоза».
    roadLabel(canvas, 'разделна линија', const Offset(190, _aCenterLine));
    _edgeLabel(canvas, 'десна ивица коловоза', const Offset(130, 234),
        _aRoadBottom);

    calloutBox(
      canvas,
      'удесно — крајњом десном траком, уз десну ивицу коловоза',
      const Rect.fromLTRB(12, 262, 388, 292),
      fill: colorScheme.tertiaryContainer,
      textColor: colorScheme.onTertiaryContainer,
      swatch: _carGreen,
    );
    calloutBox(
      canvas,
      'улево — крајњом левом траком, уз разделну линију',
      const Rect.fromLTRB(12, 296, 388, 326),
      fill: colorScheme.secondaryContainer,
      textColor: colorScheme.onSecondaryContainer,
      swatch: _carBlue,
    );
  }

  // ── Сюжет 2: односторонняя дорога ─────────────────────────────────────

  void _drawOneWayPanel(Canvas canvas) {
    text(
      canvas,
      'једносмерни пут',
      const Offset(120, 348),
      colorScheme.onSurface,
      maxWidth: 200,
      fontSize: 12,
      isBold: true,
    );

    final asphalt = Paint()..color = _asphalt;
    // Поперечная дорога подходит сверху: поворот налево — единственный, ради
    // которого сюжет нарисован, и лишний съезд вниз только отвлекает.
    canvas.drawRect(
      const Rect.fromLTRB(_crossLeft, 340, _crossRight, _bRoadTop),
      asphalt,
    );
    canvas.drawRect(
      const Rect.fromLTRB(12, _bRoadTop, 388, _bRoadBottom),
      asphalt,
    );

    _mainRoadMarkings(
      canvas,
      top: _bRoadTop,
      bottom: _bRoadBottom,
      laneLine: _bLaneLine,
    );
    // Поперечная дорога тут только сверху: её кромки и осевая рисуются до
    // главной дороги.
    final edge = Paint()
      ..color = _marking
      ..strokeWidth = 2.5;
    canvas.drawLine(const Offset(_crossLeft + 3, 340),
        const Offset(_crossLeft + 3, _bRoadTop), edge);
    canvas.drawLine(const Offset(_crossRight - 3, 340),
        const Offset(_crossRight - 3, _bRoadTop), edge);
    dashedLine(canvas, const Offset(_crossMiddle, 344),
        const Offset(_crossMiddle, _bRoadTop),
        color: _marking, dash: 12, gap: 8, width: 2.5);

    // Стрелки на асфальте: обе полосы в одну сторону — значит «крајња лева»
    // прижата к левому краю пути, а не к разделительной. В левой полосе
    // стрелка только до машины: дальше по ней идёт траектория поворота.
    arrow(canvas, const Offset(16, _bLeftLane), const Offset(52, _bLeftLane),
        color: _marking, width: 3);
    for (final x in [30.0, 150.0]) {
      arrow(canvas, Offset(x, _bRightLane), Offset(x + 48, _bRightLane),
          color: _marking, width: 3);
    }

    drawCarTopView(
      canvas,
      this,
      const Rect.fromLTWH(64, _bLeftLane - 15, 62, 30),
      body: _carBlue,
    );
    _turnArrow(
      canvas,
      const Offset(134, _bLeftLane),
      const Offset(_upLane, _bLeftLane),
      const Offset(_upLane, 350),
      _carBlue,
    );

    _edgeLabel(canvas, 'лева ивица пута', const Offset(150, 380), _bRoadTop);

    calloutBox(
      canvas,
      'улево — крајњом левом траком, уз леву ивицу пута',
      const Rect.fromLTRB(12, 486, 388, 516),
      fill: colorScheme.secondaryContainer,
      textColor: colorScheme.onSecondaryContainer,
      swatch: _carBlue,
    );
  }

  void _drawFooter(Canvas canvas) {
    const rect = Rect.fromLTRB(12, 524, 388, 566);
    panelFrame(canvas, rect, fill: colorScheme.primaryContainer);
    text(
      canvas,
      'траку заузми унапред, а не «оном којом је најлакше»',
      const Offset(200, 538),
      colorScheme.onPrimaryContainer,
      maxWidth: 356,
      fontSize: 12,
      isBold: true,
    );
    text(
      canvas,
      'ако саобраћајном сигнализацијом није друкчије одређено',
      const Offset(200, 555),
      colorScheme.onPrimaryContainer,
      maxWidth: 356,
      fontSize: 10,
      isItalic: true,
    );
  }

  // ── Общая отрисовка ───────────────────────────────────────────────────

  /// Подпись к кромке проезжей части: чип стоит за пределами асфальта, к
  /// линии от него идёт выноска. На самой кромке чип закрывал бы ровно ту
  /// линию, которую подписывает.
  void _edgeLabel(Canvas canvas, String value, Offset chip, double edgeY) {
    final dir = edgeY > chip.dy ? 1.0 : -1.0;
    canvas.drawLine(
      Offset(chip.dx, chip.dy + dir * 11),
      Offset(chip.dx, edgeY - dir * 1),
      Paint()
        ..color = colorScheme.onSurfaceVariant
        ..strokeWidth = 1.5,
    );
    roadLabel(canvas, value, chip, fontSize: 10);
  }

  /// Разметка горизонтальной дороги. В зоне перекрёстка линии прерываются —
  /// сплошная поперёк съезда читалась бы как «сюда нельзя».
  void _mainRoadMarkings(
    Canvas canvas, {
    required double top,
    required double bottom,
    double? centerLine,
    required double laneLine,
  }) {
    final edge = Paint()
      ..color = _marking
      ..strokeWidth = 2.5;
    // Кромочная линия сдвинута внутрь асфальта: ровно на границе белое по
    // белому фону светлой темы не видно вовсе.
    for (final y in [top + 3, bottom - 3]) {
      canvas.drawLine(Offset(12, y), Offset(_crossLeft, y), edge);
      canvas.drawLine(Offset(_crossRight, y), Offset(388, y), edge);
    }
    if (centerLine != null) {
      dashedLine(canvas, Offset(12, centerLine), Offset(_crossLeft, centerLine),
          color: _marking, dash: 14, gap: 10, width: 3);
      dashedLine(
          canvas, Offset(_crossRight, centerLine), Offset(388, centerLine),
          color: _marking, dash: 14, gap: 10, width: 3);
    }
    dashedLine(canvas, Offset(12, laneLine), Offset(_crossLeft, laneLine),
        color: _marking, dash: 10, gap: 12, width: 2);
    dashedLine(canvas, Offset(_crossRight, laneLine), Offset(388, laneLine),
        color: _marking, dash: 10, gap: 12, width: 2);
  }

  void _crossRoadMarkings(
    Canvas canvas, {
    required double from,
    required double to,
    required double roadTop,
    required double roadBottom,
  }) {
    final edge = Paint()
      ..color = _marking
      ..strokeWidth = 2.5;
    for (final x in [_crossLeft + 3, _crossRight - 3]) {
      canvas.drawLine(Offset(x, from), Offset(x, roadTop), edge);
      canvas.drawLine(Offset(x, roadBottom), Offset(x, to), edge);
    }
    dashedLine(canvas, Offset(_crossMiddle, from + 4), Offset(_crossMiddle, roadTop),
        color: _marking, dash: 12, gap: 8, width: 2.5);
    dashedLine(canvas, Offset(_crossMiddle, roadBottom), Offset(_crossMiddle, to - 4),
        color: _marking, dash: 12, gap: 8, width: 2.5);
  }

  /// Траектория поворота: прямой участок, скруглённый угол и стрелка на
  /// выходе. Скругление обязательно — угол в 90° читается как «занос».
  void _turnArrow(
    Canvas canvas,
    Offset start,
    Offset corner,
    Offset end,
    Color color,
  ) {
    const radius = 26.0;
    final inDir = (corner - start) / (corner - start).distance;
    final outDir = (end - corner) / (end - corner).distance;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(corner.dx - inDir.dx * radius, corner.dy - inDir.dy * radius)
      ..quadraticBezierTo(
        corner.dx,
        corner.dy,
        corner.dx + outDir.dx * radius,
        corner.dy + outDir.dy * radius,
      )
      ..lineTo(end.dx - outDir.dx * 12, end.dy - outDir.dy * 12);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Наконечник рисуем готовой стрелкой по короткому отрезку: так он точно
    // такой же, как во всех остальных схемах.
    arrow(canvas, end - outDir * 14, end, color: color, width: 4, head: 12);
  }

  @override
  bool shouldRepaint(covariant _PozicijaPainter old) =>
      old.colorScheme != colorScheme;
}
