import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/alkohol_common.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';

/// Порог задержания водителя — 1,20 mg/ml, на шкале.
///
/// Все четыре вопроса раздела (№8569, №8570, №8571, №8572) отличаются только
/// тем, по какую сторону от 1,20 стоит названная цифра, а варианты ответа во
/// всех одинаковые. Поэтому главное на картинке — граница и две подписи рядом
/// с ней: слева «може», справа «мора». Цифра из вопросов (1,00) отмечена прямо
/// на шкале, чтобы было видно, что она левее порога.
class AlkoholPragSkala extends StatelessWidget {
  const AlkoholPragSkala({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 384,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

class _ScenePainter extends AlkoholScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  static const _scale = PromileScale(left: 40, right: 362, axisY: 104, max: 2);
  static const _threshold = 1.20;

  @override
  void paint(Canvas canvas, Size size) {
    chip(
      canvas,
      'ЗАДРЖАВАЊЕ ВОЗАЧА · праг 1,20 mg/ml'
      '${gloss(' · задержание')}',
      const Rect.fromLTRB(2, 2, 398, 32),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 13.5,
    );

    _scaleBlock(canvas);
    _zones(canvas);
    _refusal(canvas);
  }

  void _scaleBlock(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 40, 398, 196));

    scaleBar(
      canvas,
      _scale,
      0,
      _threshold,
      fill: colorScheme.secondaryContainer,
      ink: colorScheme.onSecondaryContainer,
      label: 'МОЖЕ',
    );
    scaleBar(
      canvas,
      _scale,
      _threshold,
      2,
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      label: 'МОРА',
    );

    for (final value in [0.0, 0.5, 1.5, 2.0]) {
      scaleTick(canvas, _scale, value);
    }
    // 1,00 — та самая цифра из вопросов №8571 и №8572; она стоит слева от
    // порога, и именно это решает, какой вариант ответа правильный.
    scaleTick(
      canvas,
      _scale,
      1.0,
      color: colorScheme.onSurface,
      caption: 'пример из питања${gloss('\n(левее порога)')}',
    );
    canvas.drawCircle(
      Offset(_scale.x(1.0), _scale.axisY),
      6,
      Paint()..color = colorScheme.onSecondaryContainer,
    );
    canvas.drawCircle(
      Offset(_scale.x(1.0), _scale.axisY),
      6,
      Paint()
        ..color = colorScheme.secondaryContainer
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    _thresholdMark(canvas);
  }

  /// Граница: вертикаль через всю шкалу и плашка со значением над ней.
  void _thresholdMark(Canvas canvas) {
    final x = _scale.x(_threshold);
    canvas.drawLine(
      Offset(x, 68),
      Offset(x, _scale.axisY + AlkoholScenePainter.barHeight / 2 + 8),
      Paint()
        ..color = kBanRed
        ..strokeWidth = 2.5,
    );
    chip(
      canvas,
      '1,20 mg/ml',
      Rect.fromCenter(center: Offset(x, 56), width: 92, height: 24),
      fill: kBanRed,
      ink: Colors.white,
      fontSize: 12.5,
    );
  }

  void _zones(Canvas canvas) {
    _zone(
      canvas,
      const Rect.fromLTRB(2, 204, 197, 300),
      fill: colorScheme.secondaryContainer,
      ink: colorScheme.onSecondaryContainer,
      title: 'до 1,20 — МОЖЕ',
      body: 'задржан само ако изражава\nнамеру да настави вожњу\n'
          'након искључења из саобраћаја'
          '${gloss('\n(задержание необязательно)')}',
    );
    _zone(
      canvas,
      const Rect.fromLTRB(203, 204, 398, 300),
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      title: 'преко 1,20 — МОРА',
      body: 'задржан до отрежњења,\nа најдуже 12 сати'
          '${gloss('\n(задержание обязательно)')}',
    );
  }

  void _zone(
    Canvas canvas,
    Rect rect, {
    required Color fill,
    required Color ink,
    required String title,
    required String body,
  }) {
    panel(canvas, rect, fill: fill);
    text(
      canvas,
      title,
      Offset(rect.center.dx, rect.top + 18),
      ink,
      maxWidth: rect.width - 16,
      fontSize: 13,
      isBold: true,
    );
    text(
      canvas,
      body,
      Offset(rect.center.dx, rect.top + 60),
      ink,
      maxWidth: rect.width - 16,
      fontSize: 11,
    );
  }

  /// Отказ от проверки — отдельная карточка: он не про цифру вовсе, поэтому
  /// стоит вне шкалы.
  void _refusal(Canvas canvas) {
    const rect = Rect.fromLTRB(2, 308, 398, 382);
    panel(canvas, rect);
    _alcotest(canvas, const Offset(52, 351));
    textLeft(
      canvas,
      'одбијање испитивања\n= искључење + ОБАВЕЗНО задржавање'
      '${gloss('\n(отказ от проверки — задержание в любом случае)')}',
      const Offset(100, 345),
      colorScheme.onSurface,
      maxWidth: 288,
      fontSize: 11.5,
    );
  }

  /// Алкотестер: коробочка с экраном и трубкой-мундштуком.
  void _alcotest(Canvas canvas, Offset center) {
    final body = Rect.fromCenter(center: center, width: 32, height: 40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(6)),
      Paint()..color = colorScheme.onSurfaceVariant,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.left + 6, body.top + 7, body.width - 12, 14),
        const Radius.circular(2),
      ),
      Paint()..color = colorScheme.surfaceContainerHighest,
    );
    // Мундштук — трубка вверх: без неё коробочка читается телефоном.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 5, body.top - 14, 10, 16),
        const Radius.circular(3),
      ),
      Paint()..color = colorScheme.onSurfaceVariant,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 8, body.top - 18, 16, 7),
        const Radius.circular(3),
      ),
      Paint()..color = colorScheme.outline,
    );
    banRing(canvas, center, 30);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.gloss != gloss;
}
