import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/raskrsnica_common.dart';

/// «Клинч» на нерегулируемом перекрёстке: четыре машины, и у каждой кто-то
/// справа.
///
/// Правило десне стране (см. `pravilo-desne-strane`) на четырёх участниках
/// замыкается в кольцо: формально уступить должен каждый, то есть не едет
/// никто. Статичная картинка показывает только затор; вопрос же спрашивает,
/// **как из него выйти** — поэтому сцена анимированная и её главная фаза не
/// клинч, а его разрешение: один водитель отказывается от своего первенства и
/// знаком руки пропускает того, кто иначе ждал бы его. Кольцо разрывается, и
/// дальше все едут по обычному правилу правой руки.
class KlincRaskrsnica extends StatefulWidget {
  const KlincRaskrsnica({super.key});

  @override
  State<KlincRaskrsnica> createState() => _KlincRaskrsnicaState();
}

class _KlincRaskrsnicaState extends State<KlincRaskrsnica>
    with SingleTickerProviderStateMixin {
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
          height: 420,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _ScenePainter(scheme, _controller.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenePainter extends RaskrsnicaPainter {
  _ScenePainter(super.colorScheme, this.t);

  final double t;

  static const _area = Rect.fromLTWH(0, 0, 400, 330);
  static const _center = Offset(200, 160);
  static const _armHalf = 52.0;

  static const _blueLaneX = 226.0; // с юга на север
  static const _redLaneX = 174.0; // с севера на юг
  static const _greenLaneY = 134.0; // с востока на запад
  static const _whiteLaneY = 186.0; // с запада на восток

  static const _blueStopY = 242.0;
  static const _redStopY = 78.0;
  static const _greenStopX = 282.0;
  static const _whiteStopX = 118.0;

  /// Границы фаз в долях цикла.
  static const _approach = 0.18;
  static const _deadlock = 0.40;
  static const _handSign = 0.64;
  static const _queue = 0.90;

  int get _phase {
    if (t < _approach) return 0;
    if (t < _deadlock) return 1;
    if (t < _handSign) return 2;
    if (t < _queue) return 3;
    return 4;
  }

  double _progress(double from, double to, {double move = 0.7}) =>
      Curves.easeInOut.transform(
        (((t - from) / (to - from)) / move).clamp(0.0, 1.0),
      );

  /// Белый трогается не сразу: сначала должен быть виден знак рукой, иначе
  /// кажется, что он поехал сам, а не потому, что его пропустили.
  double get _whiteGo => Curves.easeInOut.transform(
        ((((t - _deadlock) / (_handSign - _deadlock)) - 0.28) / 0.62)
            .clamp(0.0, 1.0),
      );

  /// Проезд «в очереди» третьей фазы: машины трогаются не разом, а через
  /// [delay] долей фазы друг за другом — это и есть очерёдность.
  double _staggered(double delay) {
    const span = 0.13; // сколько длится проезд одной машины
    final start = _handSign + delay;
    return Curves.easeInOut
        .transform(((t - start) / span).clamp(0.0, 1.0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(_area);

    intersection(canvas, area: _area, center: _center, armHalf: _armHalf);

    final phase = _phase;
    final approach = _progress(0, _approach);

    // Стартовые позиции — уже в кадре, и за кадр никто не улетает: проехавшая
    // машина останавливается сразу за перекрёстком. Любой кадр цикла
    // пользователь может увидеть как стоп-кадр, а пустая дорога ему ничего не
    // объясняет — в финальной паузе видны все четыре с номерами очереди.
    // Белый уезжает уже во второй фазе — его и пропустили.
    final whiteX = phase < 2
        ? _lerp(60, _whiteStopX, approach)
        : _lerp(_whiteStopX, 330, _whiteGo);
    final redY = phase < 3
        ? _lerp(22, _redStopY, approach)
        : _lerp(_redStopY, 300, _staggered(0));
    final greenX = phase < 3
        ? _lerp(344, _greenStopX, approach)
        : _lerp(_greenStopX, 60, _staggered(0.06));
    final blueY = phase < 3
        ? _lerp(300, _blueStopY, approach)
        : _lerp(_blueStopY, 40, _staggered(0.12));

    final bluePos = Offset(_blueLaneX, blueY);
    final redPos = Offset(_redLaneX, redY);
    final greenPos = Offset(greenX, _greenLaneY);
    final whitePos = Offset(whiteX, _whiteLaneY);

    car(canvas, bluePos, kHeadingNorth, kCarBlue, brake: phase < 3);
    car(canvas, redPos, kHeadingSouth, kCarRed, brake: phase < 3);
    car(canvas, greenPos, kHeadingWest, kCarGreen, brake: phase < 3);
    car(canvas, whitePos, kHeadingEast, kCarWhite, brake: phase < 2);

    if (phase == 1) _drawDeadlock(canvas);
    if (phase == 2) _drawHandSign(canvas, bluePos);
    if (phase >= 2) {
      // Номер белого появляется, когда он уже проехал: пока он пересекает
      // перекрёсток, кружок наезжает то на знак рукой, то на синего.
      if (whiteX > 300) {
        _badge(canvas, '1', whitePos + const Offset(0, 38), kCarWhite, whiteX,
            ink: const Color(0xFF1B1F24));
      }
      _badge(canvas, '2', redPos + const Offset(-40, 0), kCarRed, redY);
      _badge(canvas, '3', greenPos + const Offset(0, -38), kCarGreen, greenX);
      _badge(canvas, '4', bluePos + const Offset(-40, 0), kCarBlue, blueY);
    }

    canvas.restore();

    _drawCaptions(canvas, phase);
  }

  void _badge(Canvas canvas, String value, Offset at, Color color, double along,
      {Color? ink}) {
    if (along < -20 || along > 420) return;
    orderBadge(canvas, at, value, color, ink: ink);
  }

  /// Кольцо стрелок «уступи правому»: замкнулось — значит, не едет никто.
  void _drawDeadlock(Canvas canvas) {
    const ink = kForbidden;
    // Плави → зелени, зелени → црвени, црвени → бели, бели → плави.
    curvedArrow(canvas, const Offset(252, 232), const Offset(288, 162),
        const Offset(302, 232),
        color: ink, dashed: true);
    curvedArrow(canvas, const Offset(276, 112), const Offset(186, 54),
        const Offset(270, 44),
        color: ink, dashed: true);
    curvedArrow(canvas, const Offset(150, 88), const Offset(96, 166),
        const Offset(84, 92),
        color: ink, dashed: true);
    curvedArrow(canvas, const Offset(124, 210), const Offset(214, 272),
        const Offset(130, 278),
        color: ink, dashed: true);

    // Пульсация — чтобы затор не выглядел как обычная стоянка.
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 20);
    roadLabel(
      canvas,
      'КЛИНЧ\nнико не креће',
      _center,
      fontSize: 13,
      maxWidth: 120,
      background: kForbidden.withValues(alpha: 0.75 + 0.2 * pulse),
    );
  }

  /// Знак рукой из окна: плави отказывается от своего первенства.
  ///
  /// Стрелка целится не в саму белую машину, а в место, где она стояла: пока
  /// белый уезжает, стрелка тянулась бы за ним через весь кадр.
  void _drawHandSign(Canvas canvas, Offset bluePos) {
    handSign(canvas, bluePos + const Offset(-16, -6), kMarking, size: 15);
    curvedArrow(
      canvas,
      bluePos + const Offset(-26, -10),
      const Offset(_whiteStopX + 34, _whiteLaneY + 16),
      Offset(bluePos.dx - 74, bluePos.dy - 2),
      color: kSignalGreen,
      width: 3,
    );
    roadLabel(canvas, 'знак руком:\nизволи', const Offset(74, 256),
        fontSize: 12, maxWidth: 110);
  }

  void _drawCaptions(Canvas canvas, int phase) {
    const captions = [
      'Раскрсница без знакова: сва четири возила стижу истовремено',
      'Свако има возило са СВОЈЕ ДЕСНЕ стране — сви уступају,\n'
          'па нико не креће: то је клинч',
      'Излаз: визуелни контакт и знак руком — плави се одриче\n'
          'првенства и пропушта белог, који је иначе чекао њега',
      'Круг је прекинут — даље редом по правилу десне стране:\n'
          '2 црвени, 3 зелени, 4 плави',
      'Ко уступи — пролази последњи. Договор погледом и знаком,\n'
          'никако „ко је упорнији“',
    ];
    calloutBox(
      canvas,
      captions[phase],
      const Rect.fromLTWH(6, 340, 388, 46),
      fill: phase == 1
          ? colorScheme.errorContainer
          : (phase >= 3
              ? colorScheme.primaryContainer
              : colorScheme.secondaryContainer),
      ink: phase == 1
          ? colorScheme.onErrorContainer
          : (phase >= 3
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSecondaryContainer),
      isBold: phase == 2,
    );
    calloutBox(
      canvas,
      'Не гурај се на силу — прво се договори погледом',
      const Rect.fromLTWH(6, 392, 388, 26),
      fill: colorScheme.tertiaryContainer,
      ink: colorScheme.onTertiaryContainer,
      check: true,
      fontSize: 12,
    );
  }

  double _lerp(double from, double to, double p) => from + (to - from) * p;

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.colorScheme != colorScheme;
}
