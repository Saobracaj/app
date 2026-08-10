import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Таблички-«лестницы» перед железнодорожным переездом: сколько косых полос —
/// столько раз по 80 метров до пруге.
///
/// На экзамене показывают одну табличку крупным планом, и выбрать надо цифру.
/// Поэтому все три таблички стоят рядом в порядке приближения к переезду:
/// правило «3 → 240, 2 → 160, 1 → 80» видно как ряд, а не как три отдельных
/// факта. Треугольные знаки сверху — второй вопрос тех же билетов: они
/// говорят, обезбеђен ли переезд браницима, к расстоянию отношения не имеют.
class TrakePredPrugom extends StatelessWidget {
  const TrakePredPrugom({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 420,
          child: CustomPaint(
            painter: _TrakePainter(Theme.of(context).colorScheme),
          ),
        ),
      ),
    );
  }
}

/// Цвета знака — его собственные, от темы не зависят: белое поле таблички,
/// оранжево-красная полоса и чёрная пиктограмма внутри треугольника.
const _signRed = Color(0xFFE8402A);
const _signWhite = Color(0xFFF7F7F7);
const _pictogram = Color(0xFF1A1A1A);
const _pole = Color(0xFF9AA0A6);

/// Одна табличка ряда: сколько полос и что под ней подписано.
class _Board {
  const _Board(this.centerX, this.stripes, this.stripesLabel, this.distance);

  final double centerX;
  final int stripes;
  final String stripesLabel;
  final String distance;
}

const _boards = [
  _Board(70, 3, '3 траке', '240 m'),
  _Board(175, 2, '2 траке', '160 m'),
  _Board(280, 1, '1 трака', '80 m'),
];

class _TrakePainter extends IllustrationPainter {
  _TrakePainter(super.colorScheme);

  static const _boardTop = 144.0;
  static const _boardBottom = 294.0;
  static const _boardWidth = 46.0;
  static const _groundY = 318.0;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSigns(canvas);

    // Стрелка от знаков к ряду табличек: знак и табличка стоят на одном
    // столбе, но спрашивают о них порознь.
    arrow(canvas, const Offset(175, 108), const Offset(175, 138),
        color: colorScheme.outline);

    canvas.drawLine(
      const Offset(20, _groundY),
      const Offset(396, _groundY),
      Paint()
        ..color = colorScheme.outlineVariant
        ..strokeWidth = 2,
    );

    for (final board in _boards) {
      _drawBoard(canvas, board);
    }
    _drawRails(canvas);
    _drawFooter(canvas);
  }

  void _drawSigns(Canvas canvas) {
    _dangerTriangle(canvas, const Offset(140, 48), 76, fence: true);
    _dangerTriangle(canvas, const Offset(262, 48), 76, fence: false);
    text(
      canvas,
      'обезбеђен браницима\nили полубраницима',
      const Offset(140, 88),
      colorScheme.onSurface,
      maxWidth: 120,
      fontSize: 10,
    );
    text(
      canvas,
      'није обезбеђен\nбраницима',
      const Offset(262, 88),
      colorScheme.onSurface,
      maxWidth: 120,
      fontSize: 10,
    );
  }

  void _drawBoard(Canvas canvas, _Board board) {
    final rect = Rect.fromLTRB(
      board.centerX - _boardWidth / 2,
      _boardTop,
      board.centerX + _boardWidth / 2,
      _boardBottom,
    );

    // Столб рисуется первым — иначе он лезет поверх нижнего края таблички.
    canvas.drawRect(
      Rect.fromLTRB(board.centerX - 3, _boardBottom - 6, board.centerX + 3,
          _groundY),
      Paint()..color = _pole,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rrect, Paint()..color = _signWhite);

    // Полосы идут снизу вверх слева направо и упираются в края таблички:
    // без клипа они торчали бы наружу.
    canvas.save();
    canvas.clipRRect(rrect);
    final rise = _boardWidth * 0.85;
    final stripe = Paint()
      ..color = _signRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.height * 0.075;
    // Считаем от нижней полосы вверх: у всех трёх табличек нижняя полоса
    // стоит одинаково, различается только их количество.
    for (var i = 0; i < board.stripes; i++) {
      final y = rect.top + rect.height * (0.845 - i * 0.155);
      canvas.drawLine(
        Offset(rect.left - 6, y + rise / 2),
        Offset(rect.right + 6, y - rise / 2),
        stripe,
      );
    }
    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    text(
      canvas,
      board.stripesLabel,
      Offset(board.centerX, 334),
      colorScheme.onSurfaceVariant,
      maxWidth: 100,
      fontSize: 11,
    );
    text(
      canvas,
      board.distance,
      Offset(board.centerX, 356),
      colorScheme.primary,
      maxWidth: 100,
      fontSize: 16,
      isBold: true,
    );
  }

  /// Пруга у правого края: ряд табличек читается как приближение к ней,
  /// а не как три независимые картинки.
  void _drawRails(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTRB(346, _groundY - 4, 398, _groundY + 5),
      Paint()..color = colorScheme.outlineVariant,
    );
    final rail = Paint()..color = colorScheme.onSurfaceVariant;
    for (final x in [360.0, 384.0]) {
      canvas.drawRect(
        Rect.fromLTRB(x - 3, _groundY - 12, x + 3, _groundY),
        rail,
      );
    }
    text(
      canvas,
      'пруга',
      const Offset(372, 334),
      colorScheme.onSurfaceVariant,
      maxWidth: 70,
      fontSize: 11,
      isBold: true,
    );
  }

  void _drawFooter(Canvas canvas) {
    const rect = Rect.fromLTRB(24, 372, 376, 414);
    panelFrame(canvas, rect, fill: colorScheme.primaryContainer);
    text(
      canvas,
      'број трака = удаљеност до пруге',
      const Offset(200, 386),
      colorScheme.onPrimaryContainer,
      maxWidth: 330,
      fontSize: 13,
      isBold: true,
    );
    text(
      canvas,
      'знак изнад табле каже само: са браницима или без њих',
      const Offset(200, 403),
      colorScheme.onPrimaryContainer,
      maxWidth: 330,
      fontSize: 10,
      isItalic: true,
    );
  }

  /// Знак опасности: равносторонний треугольник вершиной вверх, красная кайма,
  /// белое поле. Скруглённые углы даёт обводка тем же цветом с круглым стыком —
  /// заливка сама углы не скругляет.
  void _dangerTriangle(
    Canvas canvas,
    Offset center,
    double side, {
    required bool fence,
  }) {
    final height = side * 0.866;
    final path = Path()
      ..moveTo(center.dx, center.dy - height * 2 / 3)
      ..lineTo(center.dx + side / 2, center.dy + height / 3)
      ..lineTo(center.dx - side / 2, center.dy + height / 3)
      ..close();
    final red = Paint()..color = _signRed;
    canvas.drawPath(path, red);
    canvas.drawPath(
      path,
      Paint()
        ..color = _signRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round,
    );

    final innerSide = side * 0.62;
    final innerHeight = innerSide * 0.866;
    // Внутренний треугольник смещён вниз: у равностороннего знака кайма по
    // низу уже, чем у вершины.
    final innerCenter = Offset(center.dx, center.dy + side * 0.045);
    final inner = Path()
      ..moveTo(innerCenter.dx, innerCenter.dy - innerHeight * 2 / 3)
      ..lineTo(innerCenter.dx + innerSide / 2, innerCenter.dy + innerHeight / 3)
      ..lineTo(innerCenter.dx - innerSide / 2, innerCenter.dy + innerHeight / 3)
      ..close();
    canvas.drawPath(inner, Paint()..color = _signWhite);
    canvas.drawPath(
      inner,
      Paint()
        ..color = _signWhite
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );

    final pictogramCenter = Offset(center.dx, center.dy + side * 0.09);
    if (fence) {
      _fencePictogram(canvas, pictogramCenter, side * 0.34);
    } else {
      _locomotivePictogram(canvas, pictogramCenter, side * 0.38);
    }
  }

  /// Штакетник: переезд с браницима. Пять кольев и две перекладины — меньше
  /// уже не читается как забор.
  void _fencePictogram(Canvas canvas, Offset center, double size) {
    final paint = Paint()..color = _pictogram;
    final left = center.dx - size / 2;
    final top = center.dy - size * 0.5;
    final bottom = center.dy + size * 0.5;
    for (var i = 0; i < 5; i++) {
      final x = left + size * i / 4;
      canvas.drawRect(Rect.fromLTRB(x - 1.4, top, x + 1.4, bottom), paint);
    }
    for (final y in [center.dy - size * 0.22, center.dy + size * 0.16]) {
      canvas.drawRect(
        Rect.fromLTRB(left - 1.4, y - 1.4, left + size + 1.4, y + 1.4),
        paint,
      );
    }
  }

  /// Паровозик: переезд без браника. Силуэт условный — котёл, будка, труба,
  /// дым и два колеса; узнаётся именно по трубе с дымом.
  void _locomotivePictogram(Canvas canvas, Offset center, double size) {
    final paint = Paint()..color = _pictogram;
    final bodyTop = center.dy - size * 0.16;
    final bodyBottom = center.dy + size * 0.24;
    canvas.drawRect(
      Rect.fromLTRB(
          center.dx - size * 0.5, bodyTop, center.dx + size * 0.32, bodyBottom),
      paint,
    );
    // Будка машиниста — сзади и выше котла.
    canvas.drawRect(
      Rect.fromLTRB(center.dx - size * 0.5, center.dy - size * 0.42,
          center.dx - size * 0.16, bodyTop),
      paint,
    );
    // Труба и дым.
    canvas.drawRect(
      Rect.fromLTRB(center.dx + size * 0.06, center.dy - size * 0.44,
          center.dx + size * 0.24, bodyTop),
      paint,
    );
    canvas.drawCircle(
        Offset(center.dx + size * 0.15, center.dy - size * 0.58),
        size * 0.15,
        paint);
    for (final wheel in [
      [center.dx - size * 0.3, size * 0.14],
      [center.dx + size * 0.1, size * 0.14],
    ]) {
      canvas.drawCircle(
          Offset(wheel[0], bodyBottom + size * 0.06), wheel[1], paint);
    }
    // Буфер спереди — иначе паровоз читается как автобус.
    canvas.drawRect(
      Rect.fromLTRB(center.dx + size * 0.32, center.dy + size * 0.02,
          center.dx + size * 0.5, bodyBottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrakePainter old) =>
      old.colorScheme != colorScheme;
}
