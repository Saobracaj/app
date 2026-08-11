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

  /// Сама наклейка: белый квадрат с чёрной буквой — так она выглядит на
  /// машине, поэтому цвета литеральные.
  void _plate(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(center: center, width: 30, height: 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = _plateFace,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = _plateInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    text(canvas, 'П', center, _plateInk, maxWidth: 26, fontSize: 19, isBold: true);
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
