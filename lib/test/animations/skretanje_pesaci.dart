import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Поворот на боковую дорогу, когда по её проезжей части идут пешеходы.
///
/// Ловушка вопросов в том, что у водителя «всё разрешено»: горит зелёный или
/// регулировщик даёт проезд. Разрешение относится к другим транспортным
/// потокам, а не к пешеходам, которые уже ступили на проезжую часть, — их
/// надо пропустить. Поэтому машина в сцене останавливается, не доехав до
/// перехода, и стоит ровно столько, сколько идут пешеходы: пауза здесь и
/// есть содержание.
class SkretanjePesaci extends StatefulWidget {
  const SkretanjePesaci({super.key});

  @override
  State<SkretanjePesaci> createState() => _SkretanjePesaciState();
}

class _SkretanjePesaciState extends State<SkretanjePesaci>
    with SingleTickerProviderStateMixin {
  /// Полный цикл: подъезд, начало поворота, остановка на время перехода,
  /// продолжение и пауза. Короче восьми секунд фаза ожидания перестаёт
  /// читаться как ожидание.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 8000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 442,
          child: Column(
            children: [
              SizedBox(
                width: 400,
                height: 272,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _ScenePainter(scheme, _controller.value),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 400,
                height: 160,
                child: CustomPaint(painter: _RulePainter(scheme)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Асфальт, разметка, сигнальные цвета и цвет машины от темы не зависят —
/// это их собственный цвет.
const _asphalt = Color(0xFF4E545B);
const _marking = Color(0xFFF2F2F2);
const _carBlue = Color(0xFF3D7BD6);
const _blinker = Color(0xFFFFA000);
const _greenLight = Color(0xFF2E9E5B);

class _ScenePainter extends IllustrationPainter {
  _ScenePainter(super.colorScheme, this.t);

  /// Позиция в цикле, 0..1.
  final double t;

  // Главная дорога: встречная полоса сверху, наша снизу.
  static const _roadTop = 44.0;
  static const _centerLine = 92.0;
  static const _roadBottom = 140.0;
  static const _ourLane = 116.0;

  // Боковая дорога уходит вниз; переход — сразу у въезда на неё.
  static const _sideLeft = 232.0;
  static const _sideRight = 320.0;
  static const _sideMiddle = 276.0;
  static const _zebraTop = 172.0;
  static const _zebraBottom = 204.0;

  /// Дуга поворота: машина входит в неё по своей полосе и выходит в правую
  /// (по ходу движения) половину боковой дороги.
  static const _turnCenter = Offset(200, 170);
  static const _turnRadius = 54.0;

  /// Угол, на котором машина замирает: передний бампер оказывается перед
  /// зеброй, а не на ней.
  static const _stopAngle = -40 * math.pi / 180;

  static double _ease(double x) => Curves.easeInOut.transform(x.clamp(0, 1));

  bool get _yielding => t >= 0.34 && t < 0.66;

  String get _caption {
    if (t < 0.22) return 'скрећеш на бочни пут';
    if (t < 0.34) return 'пешаци су већ ступили на коловоз';
    if (t < 0.66) return 'заустави возило и пропусти пешаке';
    return 'прелаз је слободан — настави скретање';
  }

  /// Положение и курс машины. Курс 0 — нос вправо, pi/2 — нос вниз.
  ({Offset position, double heading}) get _car {
    if (t < 0.22) {
      // Подъезд по своей полосе: машина въезжает из-за кадра.
      final x = -90 + _ease(t / 0.22) * (_turnCenter.dx + 90);
      return (position: Offset(x, _ourLane), heading: 0);
    }
    if (t < 0.34) {
      final angle = -math.pi / 2 +
          _ease((t - 0.22) / 0.12) * (_stopAngle + math.pi / 2);
      return _onArc(angle);
    }
    if (t < 0.66) return _onArc(_stopAngle);
    if (t < 0.76) {
      final angle = _stopAngle + _ease((t - 0.66) / 0.10) * -_stopAngle;
      return _onArc(angle);
    }
    // Съезд по боковой дороге вниз, за кадр.
    final y = _turnCenter.dy + _turnRadius + _ease((t - 0.76) / 0.18) * 120;
    return (
      position: Offset(_turnCenter.dx + _turnRadius, y),
      heading: math.pi / 2,
    );
  }

  ({Offset position, double heading}) _onArc(double angle) => (
        position: _turnCenter +
            Offset(math.cos(angle), math.sin(angle)) * _turnRadius,
        heading: angle + math.pi / 2,
      );

  /// Пешеходы идут слева направо: к началу цикла они уже на переходе — это и
  /// есть «већ ступили», а не «собираются перейти».
  double get _walkerX {
    if (t < 0.30) return 258 + (t / 0.30) * 16;
    if (t < 0.66) return 274 + _ease((t - 0.30) / 0.36) * 74;
    return 348 + ((t - 0.66) / 0.34) * 14;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Машина въезжает и выезжает за границы холста — без клипа она рисуется
    // поверх соседнего блока виджета.
    canvas.clipRect(Offset.zero & size);
    _drawCaption(canvas);
    _drawRoads(canvas);
    _drawIntendedPath(canvas);
    _drawTrafficLight(canvas);
    _drawZebra(canvas);
    _drawCar(canvas);
    _drawWalkers(canvas);
  }

  /// Задуманная траектория пунктиром. Нужна для стоп-кадра: без неё машина,
  /// замершая под углом, читается как «просто стоит наискось», а не как
  /// «начала скретање и остановилась перед прелазом».
  void _drawIntendedPath(Canvas canvas) {
    final path = Path()
      ..moveTo(40, _ourLane)
      ..lineTo(_turnCenter.dx, _ourLane)
      ..arcTo(
        Rect.fromCircle(center: _turnCenter, radius: _turnRadius),
        -math.pi / 2,
        math.pi / 2,
        false,
      )
      ..lineTo(_turnCenter.dx + _turnRadius, 262);

    // Цвет машины, а не белый: белым на дороге нарисована разметка, и ещё
    // одна белая пунктирная линия читалась бы как осевая.
    final paint = Paint()
      ..color = _carBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = math.min(start + 9, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start = end + 7;
      }
    }
  }

  void _drawCaption(Canvas canvas) {
    calloutBox(
      canvas,
      _caption,
      const Rect.fromLTRB(6, 4, 394, 34),
      fill: _yielding
          ? colorScheme.primaryContainer
          : colorScheme.secondaryContainer,
      textColor: _yielding
          ? colorScheme.onPrimaryContainer
          : colorScheme.onSecondaryContainer,
      fontSize: 12,
      isBold: true,
    );
  }

  void _drawRoads(Canvas canvas) {
    final asphalt = Paint()..color = _asphalt;
    canvas.drawRect(
      const Rect.fromLTRB(0, _roadTop, 400, _roadBottom),
      asphalt,
    );
    canvas.drawRect(
      const Rect.fromLTRB(_sideLeft, _roadBottom, _sideRight, 272),
      asphalt,
    );

    final edge = Paint()
      ..color = _marking
      ..strokeWidth = 2.5;
    // Кромочные линии сдвинуты внутрь асфальта: ровно на границе белое по
    // светлому фону темы не видно вовсе.
    canvas.drawLine(
        const Offset(0, _roadTop + 3), const Offset(400, _roadTop + 3), edge);
    // Нижняя кромка прерывается на въезде в боковую дорогу.
    canvas.drawLine(const Offset(0, _roadBottom - 3),
        const Offset(_sideLeft, _roadBottom - 3), edge);
    canvas.drawLine(const Offset(_sideRight, _roadBottom - 3),
        const Offset(400, _roadBottom - 3), edge);
    for (final x in [_sideLeft + 3, _sideRight - 3]) {
      canvas.drawLine(Offset(x, _roadBottom), Offset(x, 272), edge);
    }

    dashedLine(canvas, const Offset(0, _centerLine), const Offset(400, _centerLine),
        color: _marking, dash: 14, gap: 10, width: 3);
    // Осевая боковой дороги — только ниже перехода: на самом переходе
    // разметки нет.
    dashedLine(canvas, const Offset(_sideMiddle, _zebraBottom + 6),
        const Offset(_sideMiddle, 272),
        color: _marking, dash: 12, gap: 8, width: 2.5);
  }

  /// Светофор для нашего направления: горит зелёный. Он в сцене затем, чтобы
  /// «зелено светло» из вопроса было видно, а не подразумевалось. Стоит на
  /// обочине справа по ходу движения — то есть под дорогой, — а не на
  /// проезжей части.
  void _drawTrafficLight(Canvas canvas) {
    const body = Rect.fromLTWH(150, 150, 18, 44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      Paint()..color = const Color(0xFF23272B),
    );
    const lamps = [
      (Color(0xFF7A2E2A), 160.0),
      (Color(0xFF7A6A2A), 172.0),
      (_greenLight, 184.0),
    ];
    for (final lamp in lamps) {
      canvas.drawCircle(Offset(159, lamp.$2), 5, Paint()..color = lamp.$1);
    }
    // Свечение зелёного: без него на маленьком значке не видно, какой сигнал
    // включён.
    canvas.drawCircle(
      const Offset(159, 184),
      9,
      Paint()..color = _greenLight.withValues(alpha: 0.35),
    );
    roadLabel(canvas, 'зелено', const Offset(110, 184), fontSize: 10);
  }

  void _drawZebra(Canvas canvas) {
    final stripe = Paint()..color = _marking;
    for (var x = _sideLeft + 6; x < _sideRight - 6; x += 16) {
      canvas.drawRect(
        Rect.fromLTRB(x, _zebraTop, x + 8, _zebraBottom),
        stripe,
      );
    }
  }

  void _drawCar(Canvas canvas) {
    final car = _car;
    canvas.save();
    canvas.translate(car.position.dx, car.position.dy);
    canvas.rotate(car.heading);
    drawCarTopView(
      canvas,
      this,
      Rect.fromCenter(center: Offset.zero, width: 62, height: 30),
      body: _carBlue,
    );
    // Показыватель правца: мигает всё время манёвра. Правый борт машины,
    // нарисованной носом вправо, — нижний.
    final blinkOn = (t * 8000 / 450).floor().isEven;
    if (blinkOn && t < 0.80) {
      for (final dx in [26.0, -26.0]) {
        canvas.drawCircle(Offset(dx, 12), 3.6, Paint()..color = _blinker);
      }
    }
    canvas.restore();
  }

  /// Взрослый и ребёнок: в вопросах фигурирует и «пешак», и «дете», и
  /// пропустить надо любого.
  void _drawWalkers(Canvas canvas) {
    final ink = colorScheme.onSurface;
    drawPersonTopView(canvas, Offset(_walkerX, 182), 26, ink);
    drawPersonTopView(canvas, Offset(_walkerX - 24, 196), 19, ink);
    // Стрелка направления движения пешеходов — иначе на стоп-кадре они
    // выглядят стоящими на переходе.
    arrow(
      canvas,
      Offset(_walkerX + 22, 189),
      Offset(_walkerX + 46, 189),
      color: ink,
      width: 2,
      head: 8,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.t != t || old.colorScheme != colorScheme;
}

/// Памятка под сценой: два разрешения, которые не работают против пешеходов.
class _RulePainter extends IllustrationPainter {
  _RulePainter(super.colorScheme);

  @override
  void paint(Canvas canvas, Size size) {
    panelFrame(
      canvas,
      const Rect.fromLTRB(2, 2, 398, 158),
      fill: colorScheme.surfaceContainerHighest,
    );

    _drawTrafficLightIcon(canvas, const Offset(40, 32));
    _row(canvas, 'зелено светло за твој смер', 32);

    _drawOfficerIcon(canvas, const Offset(40, 76));
    _row(canvas, 'знак полицијског службеника', 76);

    canvas.drawLine(
      const Offset(20, 100),
      const Offset(380, 100),
      Paint()
        ..color = colorScheme.outlineVariant
        ..strokeWidth = 1.5,
    );

    text(
      canvas,
      'ни једно ни друго не даје предност над пешацима\nкоји су већ ступили на коловоз',
      const Offset(200, 120),
      colorScheme.onSurface,
      maxWidth: 360,
      fontSize: 12,
      isBold: true,
    );
    text(
      canvas,
      'важи и кад на улазу у бочни пут нема обележеног прелаза',
      const Offset(200, 147),
      colorScheme.onSurfaceVariant,
      maxWidth: 360,
      fontSize: 10,
      isItalic: true,
    );
  }

  /// Строка памятки: подпись начинается сразу за значком, а не по центру
  /// панели — иначе значок и его подпись читаются как две разные вещи.
  void _row(Canvas canvas, String value, double centerY) {
    const left = 72.0;
    final width = measure(value, maxWidth: 310, fontSize: 12).width;
    text(
      canvas,
      value,
      Offset(left + width / 2, centerY),
      colorScheme.onSurface,
      maxWidth: 310,
      fontSize: 12,
    );
  }

  void _drawTrafficLightIcon(Canvas canvas, Offset center) {
    final body = Rect.fromCenter(center: center, width: 20, height: 46);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(5)),
      Paint()..color = const Color(0xFF23272B),
    );
    final lamps = [
      (const Color(0xFF7A2E2A), center.dy - 14),
      (const Color(0xFF7A6A2A), center.dy),
      (_greenLight, center.dy + 14),
    ];
    for (final lamp in lamps) {
      canvas.drawCircle(
          Offset(center.dx, lamp.$2), 5.5, Paint()..color = lamp.$1);
    }
  }

  /// Регулировщик: силуэт с поднятой рукой и жезлом. Какой именно знак он
  /// подаёт, здесь не важно — важен сам факт, что проезд разрешён им.
  void _drawOfficerIcon(Canvas canvas, Offset center) {
    final ink = colorScheme.onSurface;
    final limb = Paint()
      ..color = ink
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(center.dx, center.dy - 16), 6, Paint()..color = ink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(center.dx - 7, center.dy - 9, center.dx + 7, center.dy + 11),
        const Radius.circular(4),
      ),
      Paint()..color = ink,
    );
    // Ноги и опущенная рука: без них силуэт читается как столбик.
    canvas.drawLine(
        Offset(center.dx - 4, center.dy + 10), Offset(center.dx - 5, center.dy + 21), limb);
    canvas.drawLine(
        Offset(center.dx + 4, center.dy + 10), Offset(center.dx + 5, center.dy + 21), limb);
    canvas.drawLine(
        Offset(center.dx - 6, center.dy - 6), Offset(center.dx - 13, center.dy + 5), limb);
    // Поднятая рука с жезлом — по ней силуэт и опознаётся как регулировщик.
    canvas.drawLine(
        Offset(center.dx + 6, center.dy - 6), Offset(center.dx + 15, center.dy - 17), limb);
    canvas.drawLine(
      Offset(center.dx + 15, center.dy - 17),
      Offset(center.dx + 21, center.dy - 28),
      Paint()
        ..color = const Color(0xFFE8402A)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RulePainter old) =>
      old.colorScheme != colorScheme;
}
