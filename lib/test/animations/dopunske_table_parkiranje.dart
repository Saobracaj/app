import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/parkiranje_common.dart';

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
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 452,
          child: CustomPaint(painter: _ScenePainter(scheme)),
        ),
      ),
    );
  }
}

/// Где машина стоит относительно бордюра — первая половина ответа.
enum _Where { roadway, sidewalk, both }

/// Как машина повёрнута к продольной оси — вторая половина ответа.
enum _How { parallel, angled, perpendicular }

class _ScenePainter extends ParkingScenePainter {
  _ScenePainter(super.colorScheme);

  /// Табличка — дорожный знак, поэтому её собственные цвета (белое поле,
  /// чёрный символ, синий «Паркиралиште») не зависят от темы приложения.
  static const _plate = Color(0xFFF7F7F5);
  static const _ink = Color(0xFF1B1B1B);
  static const _walk = Color(0xFFD2D5D8);
  static const _signBlue = Color(0xFF1B57A5);

  static const _columns = [131.0, 239.0, 347.0];
  static const _rows = [124.0, 224.0, 324.0];

  @override
  void paint(Canvas canvas, Size size) {
    _parkingSign(canvas, const Rect.fromLTWH(4, 6, 34, 34));
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

    const where = [_Where.roadway, _Where.sidewalk, _Where.both];
    const how = [_How.parallel, _How.angled, _How.perpendicular];
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
        _plateCell(
          canvas,
          Rect.fromCenter(
            center: Offset(_columns[c], _rows[r]),
            width: 96,
            height: 74,
          ),
          where[c],
          how[r],
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

  /// Знак «Паркиралиште», под которым висит табличка: без него сетка выглядит
  /// как девять абстрактных пиктограмм.
  void _parkingSign(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = _signBlue);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    text(canvas, 'P', rect.center, Colors.white,
        maxWidth: rect.width, fontSize: 22, isBold: true);
  }

  /// Одна табличка: бордюрная линия посередине, тротуар сверху, проезжая
  /// часть снизу и машина в нужном положении.
  void _plateCell(Canvas canvas, Rect rect, _Where where, _How how) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = _plate);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Бордюр по центру таблички: у всех девяти он на одном уровне, поэтому
    // положение машины сравнивается по картинкам без чтения подписей.
    final curbY = rect.center.dy;
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.top, rect.right, curbY),
      Paint()..color = _walk,
    );
    canvas.drawLine(
      Offset(rect.left, curbY),
      Offset(rect.right, curbY),
      Paint()
        ..color = _ink
        ..strokeWidth = 2.5,
    );

    final dy = switch (where) {
      _Where.roadway => 17.0,
      _Where.sidewalk => -17.0,
      _Where.both => 0.0,
    };
    final heading = switch (how) {
      _How.parallel => 0.0,
      _How.angled => -math.pi / 4,
      _How.perpendicular => -math.pi / 2,
    };
    // Ось проезжей части: без неё нижняя половина таблички выглядит просто
    // пустым белым полем, а она и есть «коловоз».
    dashedLine(
      canvas,
      Offset(rect.left + 8, rect.bottom - 8),
      Offset(rect.right - 8, rect.bottom - 8),
      dash: 6,
      gap: 5,
      width: 1.5,
      color: _ink.withValues(alpha: 0.35),
    );
    _plateCar(canvas, Offset(rect.center.dx, curbY + dy), heading);
    canvas.restore();
  }

  /// Машина на табличке — чёрный силуэт с прорезями стёкол цвета поля знака.
  /// Общая `car()` здесь не годится: её стёкла тёмные, и на чёрном силуэте
  /// пиктограмма превращается в таблетку без формы.
  void _plateCar(Canvas canvas, Offset center, double heading) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-18, -9, 18, 9),
        const Radius.circular(4),
      ),
      Paint()..color = _ink,
    );
    // Салон одним светлым пятном с перемычкой посередине: две отдельные
    // прорези читались как домино, а не как машина.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-9, -6, 8, 6),
        const Radius.circular(2),
      ),
      Paint()..color = _plate,
    );
    canvas.drawLine(
      const Offset(-0.5, -6),
      const Offset(-0.5, 6),
      Paint()
        ..color = _ink
        ..strokeWidth = 2.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme;
}
