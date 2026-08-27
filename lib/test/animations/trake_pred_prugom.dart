import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/painters.dart';
import 'package:saobracaj/test/animations/road_sign.dart';

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
      child: RoadSignScope(
        signs: const ['I-32', 'I-33', 'I-35-t1', 'I-35-t2', 'I-35-t3'],
        builder: (context, signs) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 400,
            height: 420,
            child: CustomPaint(
              painter: _TrakePainter(Theme.of(context).colorScheme, signs),
            ),
          ),
        ),
      ),
    );
  }
}

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
  _TrakePainter(super.colorScheme, this.signs);

  final RoadSigns signs;

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
    // I-32 «близина пружног прелаза са браницима» и I-33 «… без браника».
    signs.paint(canvas, 'I-32',
        Rect.fromCenter(center: const Offset(140, 38), width: 76, height: 67));
    signs.paint(canvas, 'I-33',
        Rect.fromCenter(center: const Offset(262, 38), width: 76, height: 67));
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

    // Табличка — вырезка из официального знака I-35: у всех трёх нижняя
    // полоса стоит одинаково, различается только их количество.
    signs.paint(canvas, 'I-35-t${board.stripes}', rect);

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

  @override
  bool shouldRepaint(covariant _TrakePainter old) =>
      old.colorScheme != colorScheme || old.signs != signs;
}
