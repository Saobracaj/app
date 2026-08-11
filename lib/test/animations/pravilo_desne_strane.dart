import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/raskrsnica_common.dart';

/// Правило десне стране на перекрёстке без знаков и светофора.
///
/// Вопросы подкатегории 136 почти всегда сводятся к одному действию: найти,
/// кто у тебя справа. Статичная картинка это показывает плохо — на ней видно
/// расположение, но не видно **очерёдности**, а спрашивают именно её. Поэтому
/// сцена анимированная: сначала все трое стоят и у каждого нарисована стрелка
/// «кому уступаю», потом машины уезжают ровно в том порядке, который из этих
/// стрелок следует.
///
/// Три машины, а не две, — специально: с двумя правило выглядит как «уступи
/// встречному справа», и остаётся непонятным, почему кто-то едет первым.
/// Цепочка «у красного справа никого → едет первым» и есть ответ.
class PraviloDesneStrane extends StatefulWidget {
  const PraviloDesneStrane({super.key});

  @override
  State<PraviloDesneStrane> createState() => _PraviloDesneStraneState();
}

class _PraviloDesneStraneState extends State<PraviloDesneStrane>
    with SingleTickerProviderStateMixin {
  /// Восемь секунд на пять фаз: подъезд, три проезда и пауза с итогом.
  /// Быстрее — не успеть прочитать подпись, которая меняется вместе с фазой.
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

  /// Позиция в цикле, 0..1.
  final double t;

  static const _area = Rect.fromLTWH(0, 0, 400, 330);
  static const _center = Offset(200, 160);
  static const _armHalf = 52.0;

  /// Полосы: движение правостороннее, поэтому подъезжающий держится своей
  /// правой половины проезжей части.
  static const _blueLaneX = 226.0; // с юга на север
  static const _redLaneX = 174.0; // с севера на юг
  static const _greenLaneY = 134.0; // с востока на запад

  /// Где машина останавливается перед перекрёстком.
  static const _blueStopY = 242.0;
  static const _redStopY = 78.0;
  static const _greenStopX = 282.0;

  /// Границы фаз в долях цикла.
  static const _approach = 0.20;
  static const _redGo = 0.42;
  static const _greenGo = 0.64;
  static const _blueGo = 0.86;

  int get _phase {
    if (t < _approach) return 0;
    if (t < _redGo) return 1;
    if (t < _greenGo) return 2;
    if (t < _blueGo) return 3;
    return 4;
  }

  /// Прогресс внутри фазы: движение занимает первые 70 % отрезка, дальше
  /// пауза — без неё сцена выглядит как непрерывная карусель.
  double _progress(double from, double to) => Curves.easeInOut.transform(
        (((t - from) / (to - from)) / 0.7).clamp(0.0, 1.0),
      );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(_area);

    intersection(canvas, area: _area, center: _center, armHalf: _armHalf);

    final phase = _phase;

    // --- Позиции машин ---
    // Стартовые позиции — уже в кадре, и уезжают машины не за кадр, а на
    // другую сторону перекрёстка: и первый, и последний кадр цикла
    // пользователь видит как стоп-кадр, а пустая дорога ему ничего не
    // объясняет. В конце цикла на схеме видно всех троих с номерами очереди.
    final approach = _progress(0, _approach);
    final blueY = phase < 3
        ? _lerp(300, _blueStopY, approach)
        : _lerp(_blueStopY, 40, _progress(_greenGo, _blueGo));
    final redY = phase < 1
        ? _lerp(22, _redStopY, approach)
        : _lerp(_redStopY, 300, _progress(_approach, _redGo));
    final greenX = phase < 2
        ? _lerp(344, _greenStopX, approach)
        : _lerp(_greenStopX, 60, _progress(_redGo, _greenGo));

    final bluePos = Offset(_blueLaneX, blueY);
    final redPos = Offset(_redLaneX, redY);
    final greenPos = Offset(greenX, _greenLaneY);

    // Стоящая машина держит стоп-сигналы — так на стоп-кадре видно, кто ждёт.
    car(canvas, bluePos, kHeadingNorth, kCarBlue, brake: phase < 3);
    car(canvas, redPos, kHeadingSouth, kCarRed, brake: phase < 1);
    car(canvas, greenPos, kHeadingWest, kCarGreen, brake: phase < 2);

    _badge(canvas, '1', redPos + const Offset(-40, 0), kCarRed, redY);
    _badge(canvas, '2', greenPos + const Offset(40, 0), kCarGreen, greenX);
    _badge(canvas, '3', bluePos + const Offset(-40, 0), kCarBlue, blueY);

    if (phase == 0) _drawYieldArrows(canvas, approach);
    if (phase == 1) _highlight(canvas, redPos);
    if (phase == 2) _highlight(canvas, greenPos);
    if (phase == 3) _highlight(canvas, bluePos);

    canvas.restore();

    _drawCaptions(canvas, phase);
  }

  /// Кружок с номером очереди — только пока машина в кадре.
  void _badge(
      Canvas canvas, String value, Offset at, Color color, double along) {
    if (along < -20 || along > 350) return;
    orderBadge(canvas, at, value, color);
  }

  /// Дугообразные стрелки «кому уступаю»: от каждой машины к той, что у неё
  /// справа. У красного справа никого — его стрелка уходит в пустой рукав.
  void _drawYieldArrows(Canvas canvas, double approach) {
    if (approach < 1) return; // рисуем, когда все уже встали

    final ink = kMarking;
    // Плави → зелени (восток справа от того, кто едет на север).
    curvedArrow(canvas, const Offset(252, 232), const Offset(288, 162),
        const Offset(300, 232),
        color: ink, dashed: true);
    // Зелени → црвени (север справа от того, кто едет на запад).
    curvedArrow(canvas, const Offset(276, 112), const Offset(186, 56),
        const Offset(268, 46),
        color: ink, dashed: true);
    // Црвени → запад, там пусто.
    curvedArrow(canvas, const Offset(152, 88), const Offset(74, 176),
        const Offset(88, 96),
        color: kSignalGreen, dashed: true);

    roadLabel(canvas, 'десно', const Offset(328, 206), fontSize: 12);
    roadLabel(canvas, 'десно', const Offset(300, 30), fontSize: 12);
    roadLabel(canvas, 'здесна нико —\nцрвени иде први', const Offset(66, 218),
        fontSize: 12, maxWidth: 120);
  }

  /// Подсветка машины, которая едет прямо сейчас: пульсирующее кольцо.
  void _highlight(Canvas canvas, Offset at) {
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 24);
    canvas.drawCircle(
      at,
      38 + 4 * pulse,
      Paint()
        ..color = kSignalGreen.withValues(alpha: 0.6 + 0.35 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  void _drawCaptions(Canvas canvas, int phase) {
    const captions = [
      'Раскрсница без знакова и семафора: свако пропушта возило\n'
          'које му долази са ДЕСНЕ стране',
      '1 · црвени: са његове десне стране (запад) нема никога →\n'
          'пролази први',
      '2 · зелени: црвени му је био здесна и сада је прошао →\n'
          'зелени пролази други',
      '3 · плави: пропустио је зеленог са своје десне стране →\n'
          'пролази последњи',
      'Редослед проласка: 1 црвени → 2 зелени → 3 плави',
    ];
    calloutBox(
      canvas,
      captions[phase],
      const Rect.fromLTWH(6, 340, 388, 46),
      fill: phase == 4
          ? colorScheme.primaryContainer
          : colorScheme.secondaryContainer,
      ink: phase == 4
          ? colorScheme.onPrimaryContainer
          : colorScheme.onSecondaryContainer,
      isBold: phase == 4,
    );
    calloutBox(
      canvas,
      'Прво погледај десно: ако тамо има возила — ти чекаш',
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
