import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';

/// Ограничения пробной возачке дозволе одним листом.
///
/// Шесть вопросов раздела (№8524, №8525, №10696, №10697, №8527, №8470) — это
/// шесть разных ограничений одного режима, и путаются они именно потому, что
/// каждый вопрос показывает одно из них по отдельности. Лист собирает их
/// вместе: наклейка «П» на обоих концах машины, телефон, ночь, мощность,
/// пассажиры и порог казнених поена.
///
/// Числа стоят прямо в подписях, потому что ловушки в вариантах отличаются
/// именно числом или припиской «само …» — сравнивать их читателю придётся
/// глазами.
class ProbnaOgranicenja extends StatelessWidget {
  const ProbnaOgranicenja({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 558,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

/// Кузов и стекло — свой цвет, а не роль в схеме.
const _carBody = Color(0xFF3D7BD6);
const _carGlass = Color(0x99101418);
const _plateFace = Color(0xFFF7F7F7);
const _plateInk = Color(0xFF17191C);
const _plateRed = Color(0xFFD8232A);
const _plateBlue = Color(0xFF3585C5);

class _ScenePainter extends InfoScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  static const _carPanel = Rect.fromLTRB(2, 38, 398, 252);
  static const _car = Rect.fromLTRB(163, 56, 237, 212);

  @override
  void paint(Canvas canvas, Size size) {
    chip(
      canvas,
      'ПРОБНА ВОЗАЧКА ДОЗВОЛА${gloss(' · пробные права')}',
      const Rect.fromLTRB(2, 2, 398, 32),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 13.5,
    );

    _carWithPlates(canvas);
    _cards(canvas);

    // Порог поенов — не ограничение поведения, а последствие, поэтому он
    // вынесен из сетки карточек в отдельную полосу внизу.
    panel(
      canvas,
      const Rect.fromLTRB(2, 510, 398, 552),
      fill: colorScheme.errorContainer,
    );
    text(
      canvas,
      'Праг за „несавесног возача“: 9 казнених поена'
      '${gloss('\n(вдвое строже обычных 18)')}',
      const Offset(200, 531),
      colorScheme.onErrorContainer,
      maxWidth: 380,
      fontSize: 12.5,
      isBold: true,
    );
  }

  /// Машина сверху с двумя наклейками «П». Вид сверху выбран ради того, чтобы
  /// обе наклейки — передняя и задняя — были видны на одной картинке: сбоку
  /// одна из них всегда оказывается с обратной стороны.
  void _carWithPlates(Canvas canvas) {
    panel(canvas, _carPanel);
    carTop(canvas, _car, _carBody, _carGlass);

    _plate(canvas, const Offset(200, 74));
    _plate(canvas, const Offset(200, 194));

    arrow(canvas, const Offset(128, 74), const Offset(180, 74),
        color: colorScheme.onSurface, width: 2, head: 7);
    text(canvas, 'предња страна', const Offset(66, 74), colorScheme.onSurface,
        maxWidth: 118, fontSize: 12, isBold: true);

    arrow(canvas, const Offset(272, 194), const Offset(220, 194),
        color: colorScheme.onSurface, width: 2, head: 7);
    text(canvas, 'задња страна', const Offset(334, 194), colorScheme.onSurface,
        maxWidth: 118, fontSize: 12, isBold: true);

    text(
      canvas,
      'Налепница „П“ — обавезно и напред и назад${gloss(' (не только сзади)')}',
      const Offset(200, 235),
      colorScheme.onSurface,
      maxWidth: 380,
      fontSize: 12,
    );
  }

  /// Сама наклейка — уменьшенная копия настоящей: белый квадрат, в нём
  /// красный пятиугольник вершиной вверх, поверх него синий вершиной вниз,
  /// на синем — белая курсивная «П» с засечками. Цвета литеральные: это
  /// цвета самой наклейки, а не роли темы.
  void _plate(Canvas canvas, Offset center) {
    const side = 34.0;
    final rect = Rect.fromCenter(center: center, width: side, height: side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = _plateFace,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = _plateInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Координаты ниже — в долях эталонной наклейки 100×100.
    final u = side / 100;
    final pc = center.translate(0, -2 * u);
    // Красный повёрнут относительно синего, поэтому его углы выглядывают
    // между сторонами синего — как на настоящей наклейке.
    canvas.drawPath(
      _pentagon(pc, 42 * u, pointUp: true, tiltDeg: 8),
      Paint()..color = _plateRed,
    );
    canvas.drawPath(
      _pentagon(pc, 37 * u, pointUp: false),
      Paint()..color = _plateBlue,
    );
    _serifP(canvas, pc.translate(0, 2 * u), 26 * u, 31 * u);
  }

  Path _pentagon(Offset c, double r,
      {required bool pointUp, double tiltDeg = 0}) {
    final start = (pointUp ? -90 : 90) + tiltDeg;
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = (start + 72 * i) * math.pi / 180;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// «П» рисуется контуром, а не шрифтом: у шрифта приложения нет засечек,
  /// а на наклейке буква именно засечная и наклонная.
  void _serifP(Canvas canvas, Offset center, double w, double h) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.skew(-0.18, 0);
    final st = 0.26 * w; // толщина стебля
    final bt = 0.22 * h; // толщина перекладины
    final ft = 0.10 * h; // высота засечки-подошвы
    final fe = 0.10 * w; // вынос засечки в сторону
    final letter = Path()
      ..addRect(Rect.fromLTRB(-w / 2 - fe, -h / 2, w / 2 + fe, -h / 2 + bt))
      ..addRect(Rect.fromLTRB(-w / 2, -h / 2, -w / 2 + st, h / 2))
      ..addRect(Rect.fromLTRB(w / 2 - st, -h / 2, w / 2, h / 2))
      ..addRect(
          Rect.fromLTRB(-w / 2 - fe, h / 2 - ft, -w / 2 + st + fe, h / 2))
      ..addRect(Rect.fromLTRB(w / 2 - st - fe, h / 2 - ft, w / 2 + fe, h / 2));
    canvas.drawPath(letter, Paint()..color = Colors.white);
    canvas.restore();
  }

  // --- Четыре ограничения -------------------------------------------------

  void _cards(Canvas canvas) {
    const cards = [
      Rect.fromLTRB(2, 258, 197, 378),
      Rect.fromLTRB(203, 258, 398, 378),
      Rect.fromLTRB(2, 384, 197, 504),
      Rect.fromLTRB(203, 384, 398, 504),
    ];

    _card(
      canvas,
      cards[0],
      title: 'Телефон: никако',
      body: 'ни „без ангажовања руку“,\nни у одређеном делу дана'
          '${gloss('\n(hands-free тоже нельзя)')}',
      icon: _phoneIcon,
    );
    _card(
      canvas,
      cards[1],
      title: 'Ноћна вожња 23–06',
      body: 'забрањена свима са пробном,\nбез обзира на године'
          '${gloss('\nловушка: 22–05')}',
      icon: _moonIcon,
    );
    _card(
      canvas,
      cards[2],
      title: 'Јачина преко 80 kW',
      body: 'само уз члана породице\nса возачком B ≥ 5 година'
          '${gloss('\n(единственное исключение)')}',
      icon: _powerIcon,
    );
    _card(
      canvas,
      cards[3],
      title: 'До 18 година',
      body: 'највише 3 лица у возилу,\nукључујући и надзор'
          '${gloss('\nне «сколько есть мест»')}',
      icon: _passengersIcon,
    );
  }

  void _card(
    Canvas canvas,
    Rect rect, {
    required String title,
    required String body,
    required void Function(Canvas, Offset) icon,
  }) {
    panel(canvas, rect);
    icon(canvas, Offset(rect.center.dx, rect.top + 34));
    text(canvas, title, Offset(rect.center.dx, rect.top + 70),
        colorScheme.onSurface,
        maxWidth: rect.width - 16, fontSize: 12.5, isBold: true);
    text(canvas, body, Offset(rect.center.dx, rect.top + 98),
        colorScheme.onSurfaceVariant,
        maxWidth: rect.width - 16, fontSize: 11);
  }

  void _phoneIcon(Canvas canvas, Offset center) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 22, height: 38),
      const Radius.circular(4),
    );
    canvas.drawRRect(body, Paint()..color = colorScheme.onSurfaceVariant);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 17, height: 27),
        const Radius.circular(2),
      ),
      Paint()..color = colorScheme.surfaceContainerHighest,
    );
    banRing(canvas, center, 24);
  }

  /// Ночь рисуется месяцем, а не часами: две стрелки на маленьком циферблате в
  /// превью сливаются в пятно, а месяц читается сразу.
  void _moonIcon(Canvas canvas, Offset center) {
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: 16)),
      Path()
        ..addOval(
          Rect.fromCircle(center: center + const Offset(7, -5), radius: 14),
        ),
    );
    canvas.drawPath(moon, Paint()..color = colorScheme.onSurfaceVariant);
    banRing(canvas, center, 24);
  }

  void _powerIcon(Canvas canvas, Offset center) {
    chip(
      canvas,
      '80 kW',
      Rect.fromCenter(center: center, width: 84, height: 34),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      fontSize: 13,
    );
  }

  void _passengersIcon(Canvas canvas, Offset center) {
    // Надзорный выделен цветом: в вопросе №10697 ловушка ровно в том, считать
    // ли его четвёртым человеком.
    personIcon(canvas, center + const Offset(-30, 0), 34, colorScheme.primary);
    personIcon(canvas, center, 34, colorScheme.onSurfaceVariant);
    personIcon(canvas, center + const Offset(30, 0), 34,
        colorScheme.onSurfaceVariant);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.gloss != gloss;
}
