import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/parkiranje_common.dart';
import 'package:saobracaj/test/animations/road_sign.dart';

/// Девять допунских табличек парковки одной сеткой.
///
/// В билетах это девять почти одинаковых вопросов «Допунска табла приказана
/// на слици означава…», и все ловушки — перестановка двух признаков:
/// **где** стоит машина относительно бордюра и **под каким углом** к
/// продольной оси. Поэтому таблички разложены матрицей: столбец даёт первую
/// половину ответа, строка — вторую, и формулировка собирается чтением по
/// координатам, а не запоминанием девяти картинок.
class DopunskeTableParkiranje extends StatelessWidget {
  const DopunskeTableParkiranje({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: RoadSignScope(
        signs: ['III-30', for (final row in _panels) ...row],
        builder: (context, signs) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 400,
            height: 452,
            child: TappableSigns(
              signs: signs,
              child: CustomPaint(painter: _ScenePainter(scheme, signs)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Официальные таблички IV-10…IV-18 по клеткам сетки: строка — положение
/// относительно продольной оси (паралелно / под углом / управно), столбец —
/// где стоит машина (на коловозу / на тротоару / на тротоару и коловозу).
/// На табличке взгляд направлен вдоль оси коловоза, поэтому «паралелно» —
/// машина сзади, «управно» — сбоку, «под углом» — в три четверти.
const _panels = [
  ['IV-17', 'IV-11', 'IV-14'],
  ['IV-16', 'IV-10', 'IV-13'],
  ['IV-18', 'IV-12', 'IV-15'],
];

class _ScenePainter extends ParkingScenePainter {
  _ScenePainter(super.colorScheme, this.signs);

  final RoadSigns signs;

  static const _columns = [131.0, 239.0, 347.0];
  static const _rows = [124.0, 224.0, 324.0];

  @override
  void paint(Canvas canvas, Size size) {
    // Знак «Паркиралиште» (III-30), к которому относятся таблички.
    signs.paint(canvas, 'III-30', const Rect.fromLTWH(4, 6, 34, 34));
    text(
      canvas,
      'Допунска табла уз знак „Паркиралиште“:\n'
      'где возило стоји и под којим углом',
      const Offset(222, 23),
      colorScheme.onSurface,
      maxWidth: 340,
      fontSize: 12.5,
      isBold: true,
    );

    const columnTitles = ['на коловозу', 'на тротоару', 'на тротоару\nи коловозу'];
    const rowTitles = ['паралелно', 'под углом', 'управно'];

    for (var c = 0; c < 3; c++) {
      text(canvas, columnTitles[c], Offset(_columns[c], 60),
          colorScheme.onSurface,
          maxWidth: 104, fontSize: 12, isBold: true);
    }
    for (var r = 0; r < 3; r++) {
      text(canvas, rowTitles[r], Offset(40, _rows[r]), colorScheme.onSurface,
          maxWidth: 74, fontSize: 12, isBold: true);
    }

    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        signs.paint(
          canvas,
          _panels[r][c],
          Rect.fromCenter(
            center: Offset(_columns[c], _rows[r]),
            width: 100,
            height: 74,
          ),
        );
      }
    }

    calloutBox(
      canvas,
      '1 · где возило стоји: на коловозу · на тротоару · на тротоару и коловозу',
      const Rect.fromLTRB(2, 378, 398, 410),
      fill: colorScheme.secondaryContainer,
      ink: colorScheme.onSecondaryContainer,
      fontSize: 11.5,
    );
    calloutBox(
      canvas,
      '2 · како стоји у односу на подужну осу коловоза:\n'
      'паралелно · под углом · управно',
      const Rect.fromLTRB(2, 414, 398, 450),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 11.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.signs != signs;
}
