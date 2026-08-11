import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';

/// Что относится к *искључењу возача*, а что — к *искључењу возила*.
///
/// Шесть вопросов раздела (№8552, №8553, №8555–№8558) устроены одинаково: в
/// списке вариантов вперемешку лежат основания отстранить водителя, основания
/// отстранить машину и обычные нарушения правил. Схема разводит их по двум
/// колонкам и отдельно показывает третью кучу — то, что вообще не искључење, а
/// казна: скорость и проезд на красный.
class VozacVsVozilo extends StatelessWidget {
  const VozacVsVozilo({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 470,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

typedef _Icon = void Function(Canvas canvas, Offset center);

class _ScenePainter extends InfoScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  static const _driverPanel = Rect.fromLTRB(2, 2, 197, 336);
  static const _vehiclePanel = Rect.fromLTRB(203, 2, 398, 336);

  @override
  void paint(Canvas canvas, Size size) {
    _column(
      canvas,
      _driverPanel,
      title: 'ИСКЉУЧЕЊЕ ВОЗАЧА',
      subtitle: 'стање и папири${gloss(' — состояние и бумаги')}',
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      rows: [
        (_glassIcon, 'алкохол'),
        (_pillIcon, 'психоактивне супстанце'),
        (_breathalyzerIcon, 'одбија испитивање или преглед'),
        (_tubeIcon, 'тражи анализу крви / урина'),
        (_licenseCrossIcon, 'нема возачку за ту категорију'),
        (_licenseClockIcon, 'истекла возачка или пробна дозвола'),
        (_banIcon, 'траје заштитна мера или мера безбедности'),
        (_carBanIcon, 'вози иако је већ искључен'),
      ],
    );

    _column(
      canvas,
      _vehiclePanel,
      title: 'ИСКЉУЧЕЊЕ ВОЗИЛА',
      subtitle: 'гвожђе и терет${gloss(' — железо и груз')}',
      fill: colorScheme.tertiaryContainer,
      ink: colorScheme.onTertiaryContainer,
      rows: [
        (_wheelIcon, 'неисправно управљање или кочнице'),
        (_warningIcon, 'технички неисправно возило'),
        (_overloadIcon, 'претоварено преко носивости'),
        (_oversizeIcon, 'непрописан или вангабаритни терет'),
        (_plateIcon, 'регистрација или налепница није у реду'),
      ],
    );

    // Колонки одинаковой высоты, а оснований в правой меньше — свободное место
    // отдано напоминанию, ради которого схема и рисуется.
    panel(
      canvas,
      const Rect.fromLTRB(211, 240, 390, 328),
      fill: colorScheme.surfaceContainerHighest,
    );
    text(
      canvas,
      'Ово су разлози за возило.\nУ питању о искључењу возача\nсви су погрешни.'
      '${gloss('\n(вопрос №8558)')}',
      const Offset(300, 284),
      colorScheme.onSurface,
      maxWidth: 168,
      fontSize: 11.5,
    );

    _notAtAll(canvas);

    panel(
      canvas,
      const Rect.fromLTRB(2, 414, 398, 466),
      fill: colorScheme.primaryContainer,
    );
    text(
      canvas,
      'Стање и папири → ВОЗАЧ  ·  гвожђе и терет → ВОЗИЛО'
      '${gloss('\nводителя отстраняют за состояние и бумаги, машину — за железо и груз')}',
      const Offset(200, 440),
      colorScheme.onPrimaryContainer,
      maxWidth: 380,
      fontSize: 12,
      isBold: true,
    );
  }

  void _column(
    Canvas canvas,
    Rect rect, {
    required String title,
    required String subtitle,
    required Color fill,
    required Color ink,
    required List<(_Icon, String)> rows,
  }) {
    panel(canvas, rect);
    chip(
      canvas,
      title,
      Rect.fromLTRB(rect.left + 8, rect.top + 8, rect.right - 8, rect.top + 36),
      fill: fill,
      ink: ink,
      fontSize: 12.5,
    );
    text(canvas, subtitle, Offset(rect.center.dx, rect.top + 54),
        colorScheme.onSurfaceVariant,
        maxWidth: rect.width - 16, fontSize: 10.5);

    // Подзаголовок с русским пояснением занимает две строки, поэтому список
    // начинается заметно ниже шапки — иначе первая строка налезает на него.
    for (var i = 0; i < rows.length; i++) {
      final y = rect.top + 84 + i * 33.0;
      rows[i].$1(canvas, Offset(rect.left + 22, y));
      textLeft(
        canvas,
        rows[i].$2,
        Offset(rect.left + 40, y),
        colorScheme.onSurface,
        maxWidth: rect.width - 48,
        fontSize: 11,
      );
    }
  }

  /// Третья куча: то, что вообще не искључење. Полоса красная и лежит поперёк
  /// обеих колонок — именно эти варианты чаще всего и выбирают по ошибке.
  void _notAtAll(Canvas canvas) {
    const rect = Rect.fromLTRB(2, 344, 398, 406);
    panel(canvas, rect, fill: colorScheme.errorContainer);
    final ink = colorScheme.onErrorContainer;
    _speedometerIcon(canvas, const Offset(34, 375), ink);
    _trafficLightIcon(canvas, const Offset(74, 375), ink);
    banSlash(canvas, const Offset(54, 375), 30, width: 4.5);
    textLeft(
      canvas,
      'Брзина (51–70 km/h и више преко дозвољене) и пролазак на црвено:\n'
      'казна и казнени поени, НЕ искључење возача.',
      const Offset(102, 375),
      ink,
      maxWidth: 286,
      fontSize: 11.5,
      isBold: true,
    );
  }

  // --- Пиктограммы оснований ----------------------------------------------
  //
  // Все они рисуются в квадрате примерно 20×20 вокруг переданного центра:
  // строка списка выравнивается по этому центру.

  Paint get _stroke => Paint()
    ..color = colorScheme.onSurfaceVariant
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;

  Paint get _fill => Paint()..color = colorScheme.onSurfaceVariant;

  void _glassIcon(Canvas canvas, Offset c) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 7, c.dy - 9)
        ..lineTo(c.dx + 7, c.dy - 9)
        ..lineTo(c.dx + 2.5, c.dy + 1)
        ..lineTo(c.dx - 2.5, c.dy + 1)
        ..close(),
      _fill,
    );
    canvas.drawLine(c + const Offset(0, 1), c + const Offset(0, 7), _stroke);
    canvas.drawLine(
        c + const Offset(-5, 8), c + const Offset(5, 8), _stroke);
  }

  void _pillIcon(Canvas canvas, Offset c) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.7);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 20, height: 11),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, _stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-10, -5.5, 10, 11),
        const Radius.circular(6),
      ),
      _fill,
    );
    canvas.restore();
  }

  void _breathalyzerIcon(Canvas canvas, Offset c) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(1, 1), width: 13, height: 16),
        const Radius.circular(3),
      ),
      _stroke,
    );
    // Трубка, в которую дуют, — короткий отросток вверх слева.
    canvas.drawLine(
        c + const Offset(-5, -7), c + const Offset(-9, -10), _stroke);
    banSlash(canvas, c, 11, width: 2.6);
  }

  void _tubeIcon(Canvas canvas, Offset c) {
    final tube = RRect.fromRectAndCorners(
      Rect.fromCenter(center: c, width: 10, height: 20),
      bottomLeft: const Radius.circular(5),
      bottomRight: const Radius.circular(5),
    );
    canvas.drawRRect(tube, _stroke);
    canvas.save();
    canvas.clipRRect(tube);
    // Кровь — свой цвет: это содержание («анализа крви»), а не оформление.
    canvas.drawRect(
      Rect.fromLTRB(c.dx - 5, c.dy, c.dx + 5, c.dy + 10),
      Paint()..color = kBanRed,
    );
    canvas.restore();
  }

  void _card(Canvas canvas, Offset c) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 22, height: 15),
        const Radius.circular(2.5),
      ),
      _stroke,
    );
    canvas.drawLine(
        c + const Offset(-2, -2), c + const Offset(7, -2), _stroke);
    canvas.drawLine(c + const Offset(-2, 2), c + const Offset(7, 2), _stroke);
  }

  void _licenseCrossIcon(Canvas canvas, Offset c) {
    _card(canvas, c);
    drawCross(canvas, c + const Offset(-6, 0), 3.5, kBanRed, width: 2.4);
  }

  void _licenseClockIcon(Canvas canvas, Offset c) {
    _card(canvas, c);
    final clock = c + const Offset(-6, 0);
    canvas.drawCircle(
      clock,
      4.5,
      Paint()
        ..color = kBanRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      clock,
      clock + const Offset(0, -3),
      Paint()
        ..color = kBanRed
        ..strokeWidth = 1.4,
    );
  }

  void _banIcon(Canvas canvas, Offset c) {
    // Знак «забрана» — круг с горизонтальной перекладиной, не с косой чертой:
    // это про меру запрета, а не про перечёркнутую иконку.
    canvas.drawCircle(
      c,
      9,
      Paint()
        ..color = kBanRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawLine(
      c + const Offset(-5, 0),
      c + const Offset(5, 0),
      Paint()
        ..color = kBanRed
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _carBanIcon(Canvas canvas, Offset c) {
    _tinyCar(canvas, c, colorScheme.onSurfaceVariant);
    banSlash(canvas, c, 12, width: 2.6);
  }

  /// Машинка сбоку одним силуэтом: в списке она нужна только как значок.
  void _tinyCar(Canvas canvas, Offset c, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 1), width: 22, height: 8),
        const Radius.circular(2.5),
      ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 6, c.dy - 3)
        ..lineTo(c.dx - 3, c.dy - 8)
        ..lineTo(c.dx + 4, c.dy - 8)
        ..lineTo(c.dx + 7, c.dy - 3)
        ..close(),
      paint,
    );
    canvas.drawCircle(c + const Offset(-6, 6), 2.6, paint);
    canvas.drawCircle(c + const Offset(6, 6), 2.6, paint);
  }

  void _wheelIcon(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 9, _stroke);
    canvas.drawCircle(c, 2.6, _fill);
    for (final d in [
      const Offset(-9, 0),
      const Offset(9, 0),
      const Offset(0, 9),
    ]) {
      canvas.drawLine(c, c + d, _stroke);
    }
  }

  void _warningIcon(Canvas canvas, Offset c) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - 9)
        ..lineTo(c.dx + 10, c.dy + 8)
        ..lineTo(c.dx - 10, c.dy + 8)
        ..close(),
      Paint()
        ..color = kBanRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      c + const Offset(0, -3),
      c + const Offset(0, 3),
      Paint()
        ..color = kBanRed
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _overloadIcon(Canvas canvas, Offset c) {
    canvas.drawRect(
      Rect.fromLTRB(c.dx - 10, c.dy - 1, c.dx + 10, c.dy + 8),
      _stroke,
    );
    // Стрелки вниз над кузовом: перегруз давит на ось.
    for (final dx in [-5.0, 0.0, 5.0]) {
      arrow(
        canvas,
        Offset(c.dx + dx, c.dy - 10),
        Offset(c.dx + dx, c.dy - 3),
        color: colorScheme.onSurfaceVariant,
        width: 1.4,
        head: 4,
      );
    }
  }

  void _oversizeIcon(Canvas canvas, Offset c) {
    canvas.drawRect(
      Rect.fromLTRB(c.dx - 6, c.dy - 5, c.dx + 6, c.dy + 5),
      _stroke,
    );
    // Груз торчит за габарит — пунктирная рамка шире кузова.
    dashedLine(canvas, Offset(c.dx - 11, c.dy - 9), Offset(c.dx + 11, c.dy - 9),
        dash: 3, gap: 2, width: 1.4, color: kBanRed);
    dashedLine(canvas, Offset(c.dx - 11, c.dy + 9), Offset(c.dx + 11, c.dy + 9),
        dash: 3, gap: 2, width: 1.4, color: kBanRed);
  }

  void _plateIcon(Canvas canvas, Offset c) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 22, height: 12),
        const Radius.circular(2),
      ),
      _stroke,
    );
    text(canvas, 'RS', c, colorScheme.onSurfaceVariant,
        maxWidth: 20, fontSize: 8, isBold: true);
  }

  void _speedometerIcon(Canvas canvas, Offset c, Color ink) {
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: c, width: 26, height: 26),
      3.4,
      2.6,
      false,
      paint,
    );
    canvas.drawLine(c, c + const Offset(8, -6), paint);
  }

  void _trafficLightIcon(Canvas canvas, Offset c, Color ink) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 16, height: 28),
        const Radius.circular(4),
      ),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Горит красный — это и есть содержание значка.
    canvas.drawCircle(c + const Offset(0, -8), 4, Paint()..color = kBanRed);
    canvas.drawCircle(
      c + const Offset(0, 1),
      3.5,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      c + const Offset(0, 9),
      3.5,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.gloss != gloss;
}
