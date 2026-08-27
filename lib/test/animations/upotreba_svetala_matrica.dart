import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';
import 'package:saobracaj/test/animations/road_sign.dart';

/// Какие огни включены в какой ситуации — одна таблица вместо пяти статей.
///
/// №10210 (дању — кратка, односно дневна), №10211 (ноћу — дуга), №10539 (када
/// уместо дугих иду кратка) и №10543 (магла — кратка и/или светла за маглу)
/// спрашивают по одной клетке этой таблицы каждый, и путаются они именно между
/// собой: «дневна» подставляют в туман, «дуга» — в разъезд. Поэтому картинка
/// показывает не отдельное правило, а всю сетку сразу — видно, что у каждой
/// ситуации свой столбец и что дуго светло дважды перечёркнуто.
///
/// Приборы стоят строками, а ситуации столбцами (а не наоборот): длинные тут
/// названия приборов, и только так «светла за маглу» помещается в одну строку.
///
/// Стоянка в этих четырёх вопросах не встречается, но без неё матрица врёт:
/// позициона светла — единственное, что горит на стоящем ТС.
class UpotrebaSvetalaMatrica extends StatelessWidget {
  const UpotrebaSvetalaMatrica({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: RoadSignScope(
        signs: const ['III-30'],
        builder: (context, signs) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 400,
            height: 452,
            child: CustomPaint(
                painter: _ScenePainter(scheme, Gloss.of(context), signs)),
          ),
        ),
      ),
    );
  }
}

/// Что стоит в клетке.
enum _Mark { must, banned, optional }

enum _Icon { sun, moon, cars, fog, parking }

/// Столбец — ситуация: пиктограмма и короткая сербская подпись.
class _Situation {
  const _Situation(this.icon, this.title, this.gloss);

  final _Icon icon;
  final String title;
  final String gloss;
}

/// Строка — прибор: сербское название, русский перевод и колонка отметок.
class _Lamp {
  const _Lamp(this.title, this.gloss, this.marks, {this.beam});

  final String title;
  final String gloss;
  final List<_Mark> marks;

  /// true — короткий пучок (ближний), false — длинный (дальний).
  final bool? beam;
}

/// Зелёный «мора» и красный «не сме» — содержание, а не оформление, но на
/// тёмной теме тёмно-зелёный проваливается в фон, поэтому он там светлее.
const _kMustGreenLight = Color(0xFF2E7D32);
const _kMustGreenDark = Color(0xFF66BB6A);

class _ScenePainter extends InfoScenePainter {
  _ScenePainter(super.colorScheme, this.gloss, this.signs);

  final Gloss gloss;
  final RoadSigns signs;

  static const double _left = 6;
  static const double _split = 140;
  static const double _right = 394;
  static const double _colWidth = (_right - _split) / 5;
  static const double _headTop = 46;
  static const double _headBottom = 116;
  static const double _rowHeight = 44;

  static const _situations = [
    _Situation(_Icon.sun, 'ДАЊУ', 'днём'),
    _Situation(_Icon.moon, 'НОЋУ', 'ночью'),
    _Situation(_Icon.cars, '< 200 m', 'разъезд'),
    _Situation(_Icon.fog, 'МАГЛА', 'туман'),
    _Situation(_Icon.parking, 'ПАРКИРАНО', 'стоянка'),
  ];

  static const _lamps = [
    _Lamp('дневна светла', 'ДХО',
        [_Mark.must, _Mark.optional, _Mark.optional, _Mark.banned, _Mark.optional]),
    _Lamp('кратка светла', 'ближний',
        [_Mark.must, _Mark.optional, _Mark.must, _Mark.must, _Mark.optional],
        beam: true),
    _Lamp('дуга светла', 'дальний',
        [_Mark.optional, _Mark.must, _Mark.banned, _Mark.banned, _Mark.optional],
        beam: false),
    _Lamp('светла за маглу', 'туманные',
        [_Mark.optional, _Mark.optional, _Mark.optional, _Mark.must, _Mark.optional]),
    _Lamp('позициона светла', 'габаритные',
        [_Mark.must, _Mark.must, _Mark.must, _Mark.must, _Mark.must]),
  ];

  double _colCenter(int index) => _split + _colWidth * (index + 0.5);

  @override
  void paint(Canvas canvas, Size size) {
    chip(
      canvas,
      'УПОТРЕБА СВЕТАЛА${gloss(' · что включено когда')}',
      const Rect.fromLTRB(2, 2, 398, 32),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 12.5,
    );

    final tableBottom = _headBottom + _rowHeight * _lamps.length;
    panel(canvas, Rect.fromLTRB(2, 40, 398, tableBottom + 6));

    _header(canvas, tableBottom);
    for (var i = 0; i < _lamps.length; i++) {
      _row(canvas, _lamps[i], _headBottom + _rowHeight * i);
    }

    _legend(canvas, tableBottom + 16);

    chip(
      canvas,
      'дању: кратка ИЛИ дневна   ·   магла: кратка И/ИЛИ за маглу\n'
      'позициона горе увек кад је укључено дуго, кратко или светло за маглу',
      Rect.fromLTRB(2, tableBottom + 48, 398, tableBottom + 100),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 11,
    );
  }

  /// Шапка: столбец = ситуация, узнаваемая по пиктограмме раньше, чем по
  /// подписи.
  void _header(Canvas canvas, double tableBottom) {
    for (var i = 0; i < _situations.length; i++) {
      final x = _colCenter(i);
      _icon(canvas, _situations[i].icon, Offset(x, _headTop + 22));
      final glossText = gloss(_situations[i].gloss);
      text(
        canvas,
        glossText.isEmpty
            ? _situations[i].title
            : '${_situations[i].title}\n$glossText',
        Offset(x, _headBottom - 20),
        colorScheme.onSurface,
        // Заметно шире клетки: «ПАРКИРАНО» иначе рвётся посреди слова, а
        // соседние подписи короткие — наезжать не на что.
        maxWidth: _colWidth + 18,
        fontSize: 9.5,
        isBold: true,
      );
      if (i != 0) {
        canvas.drawLine(
          Offset(_split + _colWidth * i, _headTop),
          Offset(_split + _colWidth * i, tableBottom),
          Paint()
            ..color = colorScheme.outline.withValues(alpha: 0.4)
            ..strokeWidth = 1,
        );
      }
    }
    canvas.drawLine(
      const Offset(_left, _headBottom - 2),
      const Offset(_right, _headBottom - 2),
      Paint()
        ..color = colorScheme.outline
        ..strokeWidth = 1.4,
    );
    canvas.drawLine(
      const Offset(_split, _headTop),
      Offset(_split, tableBottom),
      Paint()
        ..color = colorScheme.outline
        ..strokeWidth = 1.4,
    );
  }

  void _row(Canvas canvas, _Lamp lamp, double top) {
    final bottom = top + _rowHeight;
    canvas.drawLine(
      Offset(_left, bottom),
      Offset(_right, bottom),
      Paint()
        ..color = colorScheme.outline.withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );

    final centerY = top + _rowHeight / 2;
    final glossText = gloss(lamp.gloss);
    textLeft(
      canvas,
      glossText.isEmpty ? lamp.title : '${lamp.title}\n$glossText',
      Offset(_left + 6, centerY),
      colorScheme.onSurface,
      maxWidth: 100,
      fontSize: 10.5,
      isBold: true,
    );
    if (lamp.beam != null) {
      _beamGlyph(canvas, Offset(106, centerY), short: lamp.beam!);
    }

    for (var i = 0; i < lamp.marks.length; i++) {
      _mark(canvas, lamp.marks[i], Offset(_colCenter(i), centerY));
    }
  }

  /// Пучок света у названия фары: у ближнего короткий и наклонённый вниз, у
  /// дальнего длинный и плоский. Отличие ровно то же, что и в жизни.
  void _beamGlyph(Canvas canvas, Offset lamp, {required bool short}) {
    const lampR = 3.0;
    canvas.drawCircle(lamp, lampR, Paint()..color = colorScheme.onSurface);
    final length = short ? 16.0 : 28.0;
    final drop = short ? 6.0 : 0.0;
    canvas.drawPath(
      Path()
        ..moveTo(lamp.dx, lamp.dy - lampR)
        ..lineTo(lamp.dx + length, lamp.dy - lampR + drop - 4)
        ..lineTo(lamp.dx + length, lamp.dy + lampR + drop + 4)
        ..lineTo(lamp.dx, lamp.dy + lampR)
        ..close(),
      Paint()..color = const Color(0xFFFFC107).withValues(alpha: 0.85),
    );
  }

  void _mark(Canvas canvas, _Mark mark, Offset center) {
    switch (mark) {
      case _Mark.must:
        drawCheck(
          canvas,
          center,
          8,
          colorScheme.brightness == Brightness.dark
              ? _kMustGreenDark
              : _kMustGreenLight,
        );
      case _Mark.banned:
        drawCross(canvas, center, 8, kBanRed, width: 3.5);
      case _Mark.optional:
        canvas.drawLine(
          center + const Offset(-7, 0),
          center + const Offset(7, 0),
          Paint()
            ..color = colorScheme.onSurface.withValues(alpha: 0.35)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  /// Пиктограмма ситуации: солнце, месяц, две встречные машины, туман, «P».
  void _icon(Canvas canvas, _Icon icon, Offset center) {
    final ink = colorScheme.onSurface;
    switch (icon) {
      case _Icon.sun:
        canvas.drawCircle(center, 6, Paint()..color = const Color(0xFFF9A825));
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            center + Offset(math.cos(a) * 8, math.sin(a) * 8),
            center + Offset(math.cos(a) * 11, math.sin(a) * 11),
            Paint()
              ..color = const Color(0xFFF9A825)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
      case _Icon.moon:
        // Месяц — разность двух кругов: полумесяц узнаётся мгновенно, а слово
        // «ночь» в узкой колонке уже не помещается.
        canvas.saveLayer(Rect.fromCircle(center: center, radius: 18), Paint());
        canvas.drawCircle(center, 10, Paint()..color = const Color(0xFF5C7FB8));
        canvas.drawCircle(
          center + const Offset(6, -4),
          9,
          Paint()..blendMode = BlendMode.clear,
        );
        canvas.restore();
      case _Icon.cars:
        // Две встречные машины: синяя идёт на нас, серая — от нас.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: center + const Offset(-6, 0), width: 10, height: 18),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFF4E7CC7),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: center + const Offset(6, 0), width: 10, height: 18),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFF8A98A6),
        );
      case _Icon.fog:
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            center + Offset(-12, -7 + i * 7.0),
            center + Offset(12, -7 + i * 7.0),
            Paint()
              ..color = ink.withValues(alpha: 0.55)
              ..strokeWidth = 3.5
              ..strokeCap = StrokeCap.round,
          );
        }
      case _Icon.parking:
        // Знак «паркиралиште» (III-30) вместо рукописной пиктограммы.
        signs.paint(canvas, 'III-30',
            Rect.fromCenter(center: center, width: 22, height: 22));
    }
  }

  /// Расшифровка знаков — без неё «–» читается как «запрещено».
  void _legend(Canvas canvas, double top) {
    final centerY = top + 10;
    var x = 16.0;

    void item(_Mark mark, String label) {
      _mark(canvas, mark, Offset(x, centerY));
      final size = measure(label, maxWidth: 200, fontSize: 10.5);
      textLeft(canvas, label, Offset(x + 12, centerY), colorScheme.onSurface,
          maxWidth: 200, fontSize: 10.5);
      x += 26 + size.width;
    }

    item(_Mark.must, 'мора${gloss(' — обязательно')}');
    item(_Mark.banned, 'не сме${gloss(' — нельзя')}');
    item(_Mark.optional, 'није обавезно');
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.gloss != gloss ||
      oldDelegate.signs != signs;
}
