import 'dart:math' as math;

// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/interactive_animation.dart';
import 'package:saobracaj/test/animations/dve_vrste_nezgode.dart'
    show kAsphalt, kMarking, kCarBlue, kSignalRed;
import 'package:saobracaj/test/animations/painters.dart'
    // Палитра этих сцен берётся из dve_vrste_nezgode.dart выше:
    // одноимённые цвета из painters.dart относятся к схемам автомагистрали.
    hide kAsphalt, kCarBlue;

/// Порядок эвакуации непрописно паркираног возила по шагам.
///
/// Сцена наверху не меняется — это та самая машина на тротуаре, из-за которой
/// всё и происходит. Меняется нижняя половина: сначала развилка «возач
/// присутан?», потом вариант с камерой, потом сама эвакуация и, наконец,
/// ветка «водитель успел». Числа, которые спрашивают в вопросах (*одмах* без
/// срока и *најмање 1 минут*), стоят прямо в кадре — в ответах их подменяют то
/// 15 минутами, то 3 и 10 минутами.
///
/// Карточка внизу не участвует в анимации: это отдельное основание для
/// эвакуации (*видно запуштено и није регистровано*), и оно должно быть видно
/// на любом кадре.
///
/// Слаг в `animations_map.dart`: `uklanjanje-tok`.
class UklanjanjeTok extends StatelessWidget {
  const UklanjanjeTok({super.key});

  /// Четыре шага по 1,7 с: на кадре есть что прочитать, но круг всё ещё
  /// укладывается в семь секунд.
  static const Duration _cycle = Duration(milliseconds: 6800);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labels = _Labels.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InteractiveAnimation(
        cycle: _cycle,
        stepStarts: [for (var i = 0; i < 4; i++) i / 4],
        builder: (context, animation) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 400,
            height: 482,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) => CustomPaint(
                painter: _UklanjanjePainter(colorScheme, labels, animation.value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские подписи. Сербские формулировки решения (*одмах*, *најмање 1
/// минут*, *о трошку возача*) не переводятся — их и спрашивают.
class _Labels {
  const _Labels({
    required this.title,
    required this.steps,
    required this.abandoned,
    required this.timerCaption,
  });

  factory _Labels.of(BuildContext context) => _Labels(
        title: context.tr(LocaleKeys.uklanjanjeTok_title),
        steps: [
          context.tr(LocaleKeys.uklanjanjeTok_step1),
          context.tr(LocaleKeys.uklanjanjeTok_step2),
          context.tr(LocaleKeys.uklanjanjeTok_step3),
          context.tr(LocaleKeys.uklanjanjeTok_step4),
        ],
        abandoned: context.tr(LocaleKeys.uklanjanjeTok_abandoned),
        timerCaption: context.tr(LocaleKeys.uklanjanjeTok_timerCaption),
      );

  final String title;
  final List<String> steps;
  final String abandoned;
  final String timerCaption;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Labels &&
          other.title == title &&
          other.abandoned == abandoned &&
          other.timerCaption == timerCaption &&
          _sameSteps(other.steps, steps);

  static bool _sameSteps(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(title, abandoned, timerCaption, Object.hashAll(steps));
}

class _UklanjanjePainter extends IllustrationPainter {
  _UklanjanjePainter(super.colorScheme, this.labels, this.t);

  final _Labels labels;

  /// Положение внутри цикла, 0…1.
  final double t;

  static const List<String> _serbian = [
    'возач присутан?',
    'прекршај снимљен камером',
    'уклањање о трошку возача',
    'возач стигне за време уклањања',
  ];

  static const Rect _road = Rect.fromLTRB(6, 86, 394, 134);
  static const Rect _sidewalk = Rect.fromLTRB(6, 134, 394, 206);
  static const Rect _story = Rect.fromLTRB(6, 214, 394, 372);

  int get _step => (t * _serbian.length).floor().clamp(0, _serbian.length - 1);

  double get _local => (t * _serbian.length) - _step;

  @override
  void paint(Canvas canvas, Size size) {
    final step = _step;

    text(canvas, labels.title, const Offset(200, 10), colorScheme.onSurface,
        maxWidth: 396, fontSize: 12, isBold: true);
    _stepBadge(canvas, const Offset(26, 48), step + 1);
    text(canvas, _serbian[step], const Offset(224, 36), colorScheme.primary,
        maxWidth: 330, fontSize: 13, isBold: true);
    text(canvas, labels.steps[step], const Offset(224, 62), colorScheme.onSurface,
        maxWidth: 330, fontSize: 10.5);

    _parkedScene(canvas, step);

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(_story, const Radius.circular(12)),
    );
    canvas.drawRect(_story, Paint()..color = colorScheme.surfaceContainerHighest);
    switch (step) {
      case 0:
        _forkStep(canvas);
      case 1:
        _cameraStep(canvas, _local);
      case 2:
        _towingStep(canvas, _local);
      case 3:
        _driverReturnsStep(canvas, _local);
    }
    canvas.restore();
    panelFrame(canvas, _story);

    _abandonedCard(canvas, const Rect.fromLTRB(6, 386, 394, 476));
  }

  @override
  bool shouldRepaint(covariant _UklanjanjePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.labels != labels;

  // ============== ПОСТОЯННАЯ СЦЕНА: МАШИНА НА ТРОТУАРЕ ==============

  void _parkedScene(Canvas canvas, int step) {
    canvas.drawRect(_road, Paint()..color = kAsphalt);
    canvas.drawRect(_sidewalk, Paint()..color = const Color(0xFFBFC4C9));
    // Ивичњак: по нему видно, что машина стоит уже не на коловозу.
    canvas.drawLine(
      Offset(_sidewalk.left, _sidewalk.top + 2),
      Offset(_sidewalk.right, _sidewalk.top + 2),
      Paint()
        ..color = const Color(0xFFE8EAEC)
        ..strokeWidth = 4,
    );
    final tile = Paint()
      ..color = const Color(0xFF9AA0A6)
      ..strokeWidth = 1;
    for (var x = _sidewalk.left + 24; x < _sidewalk.right; x += 34) {
      canvas.drawLine(
        Offset(x, _sidewalk.top + 4),
        Offset(x, _sidewalk.bottom),
        tile,
      );
    }
    _dashes(canvas, _road.top + 12, _road.left + 8, _road.right - 8);

    // Машина стоит поперёк тротуара — та самая ситуация из вопросов.
    drawCarTopView(
      canvas,
      this,
      const Rect.fromLTWH(36, 140, 140, 46),
      body: kCarBlue,
    );
    // На третьем шаге на стекле уже лежит бумага, на втором — уведомление.
    if (step >= 1) {
      _paperOnGlass(canvas, const Offset(148, 152));
    }

    drawPersonTopView(canvas, const Offset(210, 172), 24, const Color(0xFF1E63D0));
    text(canvas, 'полицијски службеник', const Offset(300, 172),
        const Color(0xFF23272B), maxWidth: 176, fontSize: 10.5);
    roadLabel(canvas, 'непрописно паркирано возило', const Offset(240, 120),
        fontSize: 11.5, maxWidth: 300);
  }

  /// Лист решения (или уведомления) на лобовом стекле.
  void _paperOnGlass(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(center: center, width: 22, height: 16);
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF7F5EF));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF23272B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final line = Paint()
      ..color = const Color(0xFF9AA0A6)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = rect.top + 4 + i * 4;
      canvas.drawLine(Offset(rect.left + 3, y), Offset(rect.right - 3, y), line);
    }
  }

  // ==================== ШАГ 1: РАЗВИЛКА ====================

  void _forkStep(Canvas canvas) {
    _diamond(canvas, const Offset(200, 238), 210, 42, 'возач присутан?');

    // Ветки идут строками во всю ширину: в двух узких колонках сербская
    // формулировка ломается на четыре строки и перестаёт читаться.
    // Сверху — устное распоряжение без срока, снизу — письменное решение со
    // сроком. Обе ловушки вопросов («15 минута», «одмах уручује решење»)
    // снимаются именно этой парой.
    _branchRow(
      canvas,
      const Rect.fromLTRB(14, 266, 386, 312),
      chip: 'ДА',
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      title: 'уклони возило одмах',
      note: 'усмено, под претњом принудног извршења — рока нема',
      badge: (c, center) => _clock(c, center, 15, hands: false),
    );
    _branchRow(
      canvas,
      const Rect.fromLTRB(14, 318, 386, 364),
      chip: 'НЕ',
      fill: colorScheme.secondaryContainer,
      ink: colorScheme.onSecondaryContainer,
      title: 'решење на ветробран возила',
      note: 'рок у решењу не може бити краћи од 1 минута',
      badge: (c, center) => _clock(c, center, 15, hands: true),
    );
  }

  void _branchRow(
    Canvas canvas,
    Rect rect, {
    required String chip,
    required Color fill,
    required Color ink,
    required String title,
    required String note,
    required void Function(Canvas canvas, Offset center) badge,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final chipRect = Rect.fromCenter(
      center: Offset(rect.left + 28, rect.center.dy),
      width: 36,
      height: 24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(12)),
      Paint()..color = colorScheme.surface,
    );
    text(canvas, chip, chipRect.center, ink,
        maxWidth: 36, fontSize: 13, isBold: true);
    badge(canvas, Offset(rect.left + 76, rect.center.dy));

    // Подписи раскладываем по измеренной высоте: иначе вторая строка
    // заголовка наезжает на пояснение.
    final left = rect.left + 102;
    final width = rect.right - 10 - left;
    final titleSize = measure(title, maxWidth: width, fontSize: 12, isBold: true);
    final noteSize = measure(note, maxWidth: width, fontSize: 10.5);
    final top = rect.center.dy - (titleSize.height + 3 + noteSize.height) / 2;
    text(canvas, title, Offset(left + width / 2, top + titleSize.height / 2), ink,
        maxWidth: width, fontSize: 12, isBold: true);
    text(
      canvas,
      note,
      Offset(left + width / 2,
          top + titleSize.height + 3 + noteSize.height / 2),
      ink,
      maxWidth: width,
      fontSize: 10.5,
    );
  }

  // ==================== ШАГ 2: КАМЕРА ====================

  void _cameraStep(Canvas canvas, double progress) {
    _camera(canvas, const Offset(56, 262));
    // Луч камеры «снимает» машину со сцены выше — поэтому смотрит вверх.
    final shot = math.min(progress / 0.35, 1.0);
    canvas.drawPath(
      Path()
        ..moveTo(56, 248)
        ..lineTo(20, 226)
        ..lineTo(96, 226)
        ..close(),
      Paint()..color = colorScheme.primary.withValues(alpha: 0.15 + 0.35 * shot),
    );

    final screen = const Rect.fromLTRB(112, 238, 262, 304);
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(6)),
      Paint()..color = colorScheme.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(6)),
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final typed = math.min(math.max(progress - 0.25, 0) / 0.4, 1.0);
    text(
      canvas,
      'решење у\nелектронској форми',
      Offset(screen.center.dx, screen.center.dy),
      colorScheme.onSurface.withValues(alpha: 0.3 + 0.7 * typed),
      maxWidth: screen.width - 12,
      fontSize: 11.5,
      isBold: true,
    );

    _timerBadge(
      canvas,
      const Rect.fromLTRB(272, 232, 386, 310),
      'најмање\n1 минут',
    );

    // Уведомление на стекло кладёт полицейский, а не тот, кто увозит машину —
    // это отдельная ловушка вопроса №10668.
    arrow(canvas, const Offset(200, 234), const Offset(160, 210),
        color: colorScheme.primary);
    text(
      canvas,
      'обавештење о решењу на возило оставља полицијски службеник',
      const Offset(200, 336),
      colorScheme.onSurface,
      maxWidth: 372,
      fontSize: 11.5,
      isBold: true,
    );
  }

  void _camera(Canvas canvas, Offset center) {
    final body = Rect.fromCenter(center: center, width: 46, height: 22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(5)),
      Paint()..color = colorScheme.onSurface,
    );
    canvas.drawPath(
      Path()
        ..moveTo(body.left, body.top)
        ..lineTo(body.left - 12, body.top - 8)
        ..lineTo(body.left - 12, body.bottom - 2)
        ..lineTo(body.left, body.bottom)
        ..close(),
      Paint()..color = colorScheme.onSurface,
    );
    canvas.drawLine(
      Offset(center.dx + 6, body.bottom),
      Offset(center.dx + 6, body.bottom + 16),
      Paint()
        ..color = colorScheme.onSurface
        ..strokeWidth = 3,
    );
    text(canvas, 'видео-надзор', Offset(center.dx, body.bottom + 26),
        colorScheme.onSurface, maxWidth: 110, fontSize: 10.5);
  }

  // ==================== ШАГ 3: ЭВАКУАТОР ====================

  void _towingStep(Canvas canvas, double progress) {
    // Таймер истёк — и только теперь машину увозят.
    _timerBadge(canvas, const Rect.fromLTRB(14, 236, 116, 302), 'рок\nистекао',
        expired: true);

    const lane = Rect.fromLTRB(126, 236, 388, 302);
    canvas.drawRect(lane, Paint()..color = kAsphalt);
    final drive = Curves.easeIn.transform(math.min(progress / 0.85, 1.0));
    final x = 190 + 150 * drive;
    _towTruck(canvas, Offset(x, lane.center.dy + 4));

    _plate(
      canvas,
      const Rect.fromLTRB(14, 314, 386, 360),
      'о трошку возача, власника односно корисника возила',
      colorScheme.primaryContainer,
      colorScheme.onPrimaryContainer,
    );
  }

  /// Эвакуатор: платформа с уже погруженной машиной. [center] — середина
  /// платформы.
  void _towTruck(Canvas canvas, Offset center) {
    final platform = Rect.fromCenter(center: center, width: 150, height: 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(platform, const Radius.circular(4)),
      Paint()..color = const Color(0xFFE0A100),
    );
    // Погруженная машина — она уже не своя на дороге, а груз.
    drawCarTopView(
      canvas,
      this,
      Rect.fromLTWH(platform.left + 6, platform.top - 26, 92, 30),
      body: kCarBlue,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(platform.right - 34, platform.top - 22, 34, 22),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFE0A100),
    );
    text(canvas, 'паук', Offset(platform.center.dx, platform.center.dy + 2),
        const Color(0xFF23272B), maxWidth: 80, fontSize: 11, isBold: true);
  }

  // ============ ШАГ 4: ВОДИТЕЛЬ УСПЕЛ ============

  void _driverReturnsStep(Canvas canvas, double progress) {
    const lane = Rect.fromLTRB(14, 236, 386, 302);
    canvas.drawRect(lane, Paint()..color = kAsphalt);

    // Эвакуатор уже не едет: он останавливается, как только водитель добежал.
    final run = math.min(progress / 0.5, 1.0);
    _towTruck(canvas, const Offset(180, 280));
    final personX = 356 - 56 * run;
    drawPersonTopView(
        canvas, Offset(personX, 276), 26, const Color(0xFFF1F1F1));
    roadLabel(canvas, 'возач', Offset(personX, 297), fontSize: 10.5);

    if (run >= 1) {
      // Крест поверх платформы: уклањање се прекида. Подпись стоит слева от
      // сцены, а не поверх неё — иначе её не прочитать через крест.
      crossOutRect(
        canvas,
        const Rect.fromLTRB(112, 250, 248, 296),
        kSignalRed,
        width: 5,
      );
      final chip = const Rect.fromLTRB(20, 252, 100, 294);
      canvas.drawRRect(
        RRect.fromRectAndRadius(chip, const Radius.circular(8)),
        Paint()..color = kSignalRed,
      );
      text(canvas, 'прекида\nсе', chip.center, Colors.white,
          maxWidth: chip.width - 8, fontSize: 12, isBold: true);
    }

    _plate(
      canvas,
      const Rect.fromLTRB(14, 314, 386, 360),
      'али сноси трошкове већ предузетих радњи',
      colorScheme.tertiaryContainer,
      colorScheme.onTertiaryContainer,
    );
  }

  // ==================== ОБЩИЕ КУСКИ ====================

  void _dashes(Canvas canvas, double y, double from, double to) {
    final paint = Paint()
      ..color = kMarking
      ..strokeWidth = 3;
    for (var x = from; x < to; x += 34) {
      canvas.drawLine(Offset(x, y), Offset(x + 18, y), paint);
    }
  }

  void _diamond(Canvas canvas, Offset center, double w, double h, String label) {
    final path = Path()
      ..moveTo(center.dx, center.dy - h / 2)
      ..lineTo(center.dx + w / 2, center.dy)
      ..lineTo(center.dx, center.dy + h / 2)
      ..lineTo(center.dx - w / 2, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = colorScheme.secondaryContainer);
    canvas.drawPath(
      path,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    text(canvas, label, center, colorScheme.onSecondaryContainer,
        maxWidth: w * 0.7, fontSize: 12, isBold: true);
  }

  /// Часы: со стрелками — когда срок считают, без стрелок — когда срока нет
  /// вовсе и убрать надо *одмах*.
  void _clock(Canvas canvas, Offset center, double radius, {bool hands = true}) {
    canvas.drawCircle(center, radius, Paint()..color = colorScheme.surface);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = colorScheme.onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (hands) {
      final hand = Paint()
        ..color = colorScheme.onSurface
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, center + Offset(0, -radius * 0.6), hand);
      canvas.drawLine(center, center + Offset(radius * 0.5, 0), hand);
    } else {
      // Циферблат без стрелок: срока нет вовсе, убрать надо *одмах*.
      final tick = Paint()
        ..color = colorScheme.onSurface
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 4; i++) {
        final dir = Offset.fromDirection(i * math.pi / 2);
        canvas.drawLine(center + dir * (radius * 0.55),
            center + dir * (radius * 0.8), tick);
      }
    }
  }

  /// Плашка со сроком. Главное число вопроса — «1 минут»; в ответах его
  /// подменяют тремя и десятью минутами.
  void _timerBadge(Canvas canvas, Rect rect, String value,
      {bool expired = false}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = expired
            ? colorScheme.errorContainer
            : colorScheme.tertiaryContainer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final ink = expired
        ? colorScheme.onErrorContainer
        : colorScheme.onTertiaryContainer;

    // Часы сверху, подписи под ними: в строку они не помещаются — сербский
    // текст сроков длинный, и часы наезжают на первую букву. Высоты меряем,
    // иначе вторая строка значения садится на русское пояснение.
    const clockR = 14.0;
    final width = rect.width - 12;
    final valueSize = measure(value, maxWidth: width, fontSize: 12, isBold: true);
    final captionSize = expired
        ? Size.zero
        : measure(labels.timerCaption, maxWidth: width, fontSize: 9.5);
    final total = clockR * 2 +
        4 +
        valueSize.height +
        (expired ? 0 : 3 + captionSize.height);
    final top = rect.center.dy - total / 2;

    _clock(canvas, Offset(rect.center.dx, top + clockR), clockR);
    if (expired) {
      drawCross(canvas, Offset(rect.center.dx, top + clockR), 12, kSignalRed,
          width: 3);
    }
    text(
      canvas,
      value,
      Offset(rect.center.dx, top + clockR * 2 + 4 + valueSize.height / 2),
      ink,
      maxWidth: width,
      fontSize: 12,
      isBold: true,
    );
    if (!expired) {
      text(
        canvas,
        labels.timerCaption,
        Offset(rect.center.dx,
            top + clockR * 2 + 7 + valueSize.height + captionSize.height / 2),
        ink,
        maxWidth: width,
        fontSize: 9.5,
      );
    }
  }

  void _plate(Canvas canvas, Rect rect, String value, Color fill, Color ink) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = fill,
    );
    text(canvas, value, rect.center, ink,
        maxWidth: rect.width - 16, fontSize: 11.5, isBold: true);
  }

  void _stepBadge(Canvas canvas, Offset center, int number) {
    canvas.drawCircle(center, 18, Paint()..color = colorScheme.primary);
    text(canvas, '$number', center, colorScheme.onPrimary,
        maxWidth: 36, fontSize: 18, isBold: true);
  }


  /// Отдельное основание для эвакуации: машина стоит правильно, но брошена и
  /// без номеров. В анимации не участвует — иначе её примут за очередной шаг.
  void _abandonedCard(Canvas canvas, Rect rect) {
    panelFrame(canvas, rect, fill: colorScheme.surfaceContainerHighest);
    final car = drawCarProfile(
      canvas,
      this,
      Rect.fromLTRB(rect.left + 12, rect.top + 22, rect.left + 132, rect.bottom - 12),
    );
    // Пыль: точки по кузову — «видно запуштено».
    final dust = Paint()..color = const Color(0xFF8D8271);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(
        Offset(
          car.rearEdge + 12 + (i * 37) % 96,
          car.cabin.top + 6 + (i * 23) % 34,
        ),
        1.8,
        dust,
      );
    }
    // Пустое место под регистрационный знак, перечёркнутое: није регистровано.
    final plate = Rect.fromLTWH(car.frontBumper - 18, car.groundY - 32, 16, 10);
    canvas.drawRect(plate, Paint()..color = colorScheme.surface);
    canvas.drawRect(
      plate,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    drawCross(canvas, plate.center, 6, kSignalRed, width: 2.5);

    text(
      canvas,
      'видно запуштено и није регистровано',
      Offset(rect.left + 268, rect.top + 30),
      colorScheme.onSurface,
      maxWidth: 234,
      fontSize: 11.5,
      isBold: true,
    );
    text(
      canvas,
      labels.abandoned,
      Offset(rect.left + 268, rect.top + 62),
      colorScheme.onSurface,
      maxWidth: 234,
      fontSize: 10.5,
    );
  }
}
