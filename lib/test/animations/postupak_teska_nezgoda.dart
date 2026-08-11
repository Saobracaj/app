import 'dart:math' as math;

// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/dve_vrste_nezgode.dart'
    show kAsphalt, kMarking, kCarBlue, kSignalRed;
import 'package:saobracaj/test/animations/painters.dart'
    // Палитра этих сцен берётся из dve_vrste_nezgode.dart выше:
    // одноимённые цвета из painters.dart относятся к схемам автомагистрали.
    hide kAsphalt, kCarBlue;

/// Шесть шагов на месте тяжёлого ДТП — ровно в том порядке, в каком они
/// перечислены в вопросе №8534: *заустави возило → искључи мотор → укључи све
/// показиваче правца → постави сигурносни троугао → обавести полицију и хитну
/// помоћ → остани на месту*.
///
/// Кадры сменяются сами, но каждый читается и как стоп-кадр: наверху крупный
/// номер шага и сербская формулировка, внизу — сколько шагов всего и на каком
/// мы сейчас. То, что уже сделано, со сцены не исчезает (аварийка горит с
/// третьего шага, треугольник стоит с четвёртого): порядок действий виден
/// накоплением, а не мельканием.
///
/// Слаг в `animations_map.dart`: `postupak-teska-nezgoda`.
class PostupakTeskaNezgoda extends StatefulWidget {
  const PostupakTeskaNezgoda({super.key});

  @override
  State<PostupakTeskaNezgoda> createState() => _PostupakTeskaNezgodaState();
}

class _PostupakTeskaNezgodaState extends State<PostupakTeskaNezgoda>
    with SingleTickerProviderStateMixin {
  /// Шесть шагов по 1,25 с: быстрее — не успеть прочитать сербскую
  /// формулировку, медленнее — не дождаться второго круга.
  static const Duration _cycle = Duration(milliseconds: 7500);

  late final AnimationController _controller = AnimationController(
    duration: _cycle,
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labels = _Labels.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 290,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _PostupakPainter(
                colorScheme,
                labels,
                _controller.value,
                _cycle.inMilliseconds,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские подписи к шагам. Сербские формулировки — дословно из вопроса, они
/// и есть правильный вариант ответа, поэтому не переводятся.
class _Labels {
  const _Labels({required this.title, required this.steps});

  factory _Labels.of(BuildContext context) => _Labels(
        title: context.tr(LocaleKeys.postupakTeskaNezgoda_title),
        steps: [
          context.tr(LocaleKeys.postupakTeskaNezgoda_step1),
          context.tr(LocaleKeys.postupakTeskaNezgoda_step2),
          context.tr(LocaleKeys.postupakTeskaNezgoda_step3),
          context.tr(LocaleKeys.postupakTeskaNezgoda_step4),
          context.tr(LocaleKeys.postupakTeskaNezgoda_step5),
          context.tr(LocaleKeys.postupakTeskaNezgoda_step6),
        ],
      );

  final String title;
  final List<String> steps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Labels &&
          other.title == title &&
          _sameSteps(other.steps, steps);

  static bool _sameSteps(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(title, Object.hashAll(steps));
}

class _PostupakPainter extends IllustrationPainter {
  _PostupakPainter(super.colorScheme, this.labels, this.t, this.cycleMs);

  final _Labels labels;

  /// Положение внутри цикла, 0…1.
  final double t;
  final int cycleMs;

  static const List<String> _serbian = [
    'заустави возило',
    'искључи мотор',
    'укључи све показиваче правца',
    'постави сигурносни троугао',
    'обавести полицију и хитну помоћ',
    'остани на месту до завршетка увиђаја',
  ];

  static const Rect _road = Rect.fromLTRB(0, 88, 400, 248);
  static const Rect _car = Rect.fromLTWH(200, 96, 100, 40);
  static const Offset _trianglePlace = Offset(58, 116);

  int get _step => (t * _serbian.length).floor().clamp(0, _serbian.length - 1);

  /// Прогресс внутри шага, 0…1.
  double get _local => (t * _serbian.length) - _step;

  @override
  void paint(Canvas canvas, Size size) {
    final step = _step;

    text(
      canvas,
      labels.title,
      const Offset(200, 12),
      colorScheme.onSurface,
      maxWidth: 396,
      fontSize: 12,
      isBold: true,
    );
    _stepBadge(canvas, const Offset(28, 54), step + 1);
    text(
      canvas,
      _serbian[step],
      const Offset(226, 44),
      colorScheme.primary,
      maxWidth: 330,
      fontSize: 14,
      isBold: true,
    );
    text(
      canvas,
      labels.steps[step],
      const Offset(226, 70),
      colorScheme.onSurface,
      maxWidth: 330,
      fontSize: 11,
    );

    canvas.save();
    canvas.clipRect(_road);
    _scene(canvas, step);
    canvas.restore();

    _pips(canvas, step);
  }

  @override
  bool shouldRepaint(covariant _PostupakPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.labels != labels;

  // ======================== СЦЕНА ========================

  void _scene(Canvas canvas, int step) {
    canvas.drawRect(_road, Paint()..color = kAsphalt);
    final dash = Paint()
      ..color = kMarking
      ..strokeWidth = 3;
    for (var x = 8.0; x < _road.right - 8; x += 34) {
      canvas.drawLine(
        Offset(x, _road.center.dy),
        Offset(x + 18, _road.center.dy),
        dash,
      );
    }

    // Шаг 1: машина ещё докатывается до места и тормозит. Дальше она стоит.
    final approach = step == 0 ? Curves.easeOut.transform(math.min(_local / 0.55, 1)) : 1.0;
    final carRect = _car.translate(-70 * (1 - approach), 0);

    if (step == 0) {
      _skidMarks(canvas, carRect, approach);
    }

    // Треугольник выставлен на четвёртом шаге и дальше стоит на дороге.
    final trianglePlaced = step > 3 || (step == 3 && _local >= 0.62);
    if (trianglePlaced) {
      _triangle(canvas, _trianglePlace, 15);
      // Размерную линию показываем только на шаге про сам треугольник: дальше
      // её место занимают телефон и подъезжающая полиция.
      if (step == 3) _safeDistance(canvas, carRect);
    }

    // Аварийка включена с третьего шага; моргание считаем от общего времени,
    // чтобы фаза не сбрасывалась на границе шагов.
    final blinkOn = ((t * cycleMs) / 380).floor().isEven;
    drawCarTopView(
      canvas,
      this,
      carRect,
      body: kCarBlue,
      damagedFront: true,
      hazardOn: step >= 2 && blinkOn,
    );

    switch (step) {
      case 1:
        // Иконку рисуем под машиной: сцена обрезана по асфальту, и всё, что
        // выше дороги, до картинки не доезжает.
        _engineOff(canvas, Offset(carRect.center.dx, carRect.bottom + 52), _local);
      case 2:
        _hazardButton(canvas, const Offset(120, 190), blinkOn);
      case 3:
        _driverWithTriangle(canvas, carRect, _local);
      case 4:
        _callServices(canvas, _local);
        drawPersonTopView(canvas, Offset(carRect.left - 22, carRect.center.dy), 22,
            const Color(0xFF2B2B2B));
      case 5:
        _policeArriving(canvas, _local);
        drawPersonTopView(canvas, Offset(carRect.left - 22, carRect.center.dy), 22,
            const Color(0xFF2B2B2B));
    }
  }

  /// Тормозной след: по нему видно, что машина именно остановилась здесь, а не
  /// была тут всегда.
  void _skidMarks(Canvas canvas, Rect car, double progress) {
    final paint = Paint()
      ..color = const Color(0xFF2E3238)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final length = 46 * progress;
    for (final y in [car.top + 6, car.bottom - 6]) {
      canvas.drawLine(
        Offset(car.left + 14 - length, y),
        Offset(car.left + 14, y),
        paint,
      );
    }
  }

  /// Кнопка «Stop/Start» гаснет: сначала горит, к концу шага серая и
  /// перечёркнута — мотор выключен.
  void _engineOff(Canvas canvas, Offset center, double progress) {
    final off = math.min(progress / 0.6, 1.0);
    final live = Color.lerp(const Color(0xFFE53935), const Color(0xFF7A7F87), off)!;
    canvas.drawCircle(center, 18, Paint()..color = colorScheme.surface);
    canvas.drawCircle(
      center,
      18,
      Paint()
        ..color = live
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Символ питания: дуга с разрывом сверху и вертикальная черта.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 9),
      -math.pi / 2 + 0.6,
      math.pi * 2 - 1.2,
      false,
      Paint()
        ..color = live
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      center + const Offset(0, -11),
      center + const Offset(0, -1),
      Paint()
        ..color = live
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    if (off >= 1) {
      canvas.drawLine(
        center + Offset.fromDirection(2.36, 18),
        center + Offset.fromDirection(-0.78, 18),
        Paint()
          ..color = const Color(0xFF7A7F87)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    roadLabel(canvas, 'мотор', Offset(center.dx, center.dy - 32));
  }

  /// Кнопка аварийки на панели: красный треугольник в рамке, моргает в такт с
  /// указателями поворота на машине.
  void _hazardButton(Canvas canvas, Offset center, bool on) {
    final rect = Rect.fromCenter(center: center, width: 44, height: 40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = colorScheme.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final ink = on ? kSignalRed : colorScheme.outlineVariant;
    for (final scale in [1.0, 0.55]) {
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - 13 * scale)
          ..lineTo(center.dx + 12 * scale, center.dy + 9 * scale)
          ..lineTo(center.dx - 12 * scale, center.dy + 9 * scale)
          ..close(),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    roadLabel(canvas, 'све четири', Offset(center.dx, center.dy + 32));
  }

  /// Водитель уносит треугольник назад по дороге — навстречу тем, кто
  /// подъезжает.
  void _driverWithTriangle(Canvas canvas, Rect car, double progress) {
    final walk = math.min(progress / 0.62, 1.0);
    final x = car.left - 14 - (car.left - 14 - _trianglePlace.dx) * walk;
    drawPersonTopView(canvas, Offset(x, 150), 22, const Color(0xFF2B2B2B));
    if (walk < 1) {
      _triangle(canvas, Offset(x, 124), 13);
    }
  }

  /// Размерная линия «на безбедном растојању»: конкретных метров в вопросе
  /// нет, поэтому подписью служит сама формулировка закона.
  void _safeDistance(Canvas canvas, Rect car) {
    const y = 224.0;
    dimensionLine(
      canvas,
      Offset(_trianglePlace.dx, y),
      Offset(car.left, y),
      color: kMarking,
    );
    roadLabel(
      canvas,
      'на безбедном растојању',
      Offset((_trianglePlace.dx + car.left) / 2, y - 15),
    );
  }

  /// Телефон и два номера: 192 — *полиција*, 194 — *хитна помоћ*. Волны от
  /// трубки нарастают, пока идёт шаг: звонок уже сделан, а не «собирается».
  void _callServices(Canvas canvas, double progress) {
    // Телефон ниже треугольника: иначе волны звонка накрывают знак.
    const phone = Rect.fromLTWH(70, 150, 34, 56);
    canvas.drawRRect(
      RRect.fromRectAndRadius(phone, const Radius.circular(6)),
      Paint()..color = colorScheme.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(phone.deflate(4), const Radius.circular(3)),
      Paint()..color = colorScheme.primaryContainer,
    );
    for (var i = 0; i < 3; i++) {
      final wave = (progress * 3 - i).clamp(0.0, 1.0);
      if (wave <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: phone.topCenter, radius: 12.0 + i * 9),
        -1.25,
        1.1,
        false,
        Paint()
          ..color = kMarking.withValues(alpha: 0.35 + 0.45 * wave)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }

    _serviceBadge(canvas, const Rect.fromLTRB(118, 150, 300, 178), '192',
        'полиција', const Color(0xFF1E63D0), Colors.white);
    _serviceBadge(canvas, const Rect.fromLTRB(118, 182, 300, 210), '194',
        'хитна помоћ', const Color(0xFFF1F1F1), const Color(0xFF23272B));
  }

  void _serviceBadge(
    Canvas canvas,
    Rect rect,
    String number,
    String caption,
    Color fill,
    Color ink,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = fill,
    );
    text(canvas, number, Offset(rect.left + 26, rect.center.dy), ink,
        maxWidth: 44, fontSize: 14, isBold: true);
    text(canvas, caption, Offset(rect.left + 96, rect.center.dy), ink,
        maxWidth: 106, fontSize: 12);
  }

  /// Полиция приезжает, водитель остаётся: последний кадр отвечает на ловушку
  /// «сообщил и уехал».
  void _policeArriving(Canvas canvas, double progress) {
    final drive = Curves.easeOut.transform(math.min(progress / 0.7, 1.0));
    final x = -100 + 150 * drive;
    drawCarTopView(
      canvas,
      this,
      Rect.fromLTWH(x, 186, 92, 38),
      body: colorScheme.surfaceContainerHighest,
      beacon: true,
    );
    roadLabel(canvas, 'полиција', Offset(x + 46, 236));
    roadLabel(canvas, 'увиђај', const Offset(250, 205), fontSize: 12);
  }

  void _triangle(Canvas canvas, Offset center, double size) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * 0.9, center.dy + size * 0.7)
      ..lineTo(center.dx - size * 0.9, center.dy + size * 0.7)
      ..close();
    canvas.drawPath(path, Paint()..color = kSignalRed);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - size * 0.45)
        ..lineTo(center.dx + size * 0.42, center.dy + size * 0.42)
        ..lineTo(center.dx - size * 0.42, center.dy + size * 0.42)
        ..close(),
      Paint()..color = const Color(0xFFF6F1E7),
    );
  }

  // ==================== ШАПКА И ШКАЛА ====================

  void _stepBadge(Canvas canvas, Offset center, int number) {
    canvas.drawCircle(center, 20, Paint()..color = colorScheme.primary);
    text(canvas, '$number', center, colorScheme.onPrimary,
        maxWidth: 40, fontSize: 20, isBold: true);
  }

  /// Шкала шагов: видно, сколько всего действий и на каком мы сейчас — иначе
  /// анимация читается как одно бесконечное «что-то происходит».
  void _pips(Canvas canvas, int step) {
    const y = 268.0;
    for (var i = 0; i < _serbian.length; i++) {
      final x = 130.0 + i * 28;
      final current = i == step;
      canvas.drawCircle(
        Offset(x, y),
        current ? 10 : 7,
        Paint()
          ..color = current
              ? colorScheme.primary
              : (i < step
                  ? colorScheme.primary.withValues(alpha: 0.35)
                  : colorScheme.outlineVariant),
      );
      if (current) {
        text(canvas, '${i + 1}', Offset(x, y), colorScheme.onPrimary,
            maxWidth: 20, fontSize: 11, isBold: true);
      }
    }
  }
}
