import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/preticanje_common.dart';

/// Безопасная последовательность обгона: показивач → выезд на левую полосу →
/// опережение с боковым интервалом → возврат без «подрезания», и только потом
/// разъезд со встречным.
///
/// В отличие от старой сцены `obgon.dart` (там просто «машина объехала
/// машину») здесь важен именно порядок шагов, поэтому каждая фаза подписана
/// сверху и снабжена своей выноской — стоп-кадр читается сам по себе.
class PreticanjeSekvenca extends StatefulWidget {
  const PreticanjeSekvenca({super.key});

  @override
  State<PreticanjeSekvenca> createState() => _PreticanjeSekvencaState();
}

class _PreticanjeSekvencaState extends State<PreticanjeSekvenca>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 8 секунд: пять фаз, каждую надо успеть прочитать.
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 400,
        height: 240,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            painter: _SekvencaPainter(scheme, _controller.value),
          ),
        ),
      ),
    );
  }
}

/// Ключевой кадр: значение в момент [t] (доля цикла).
typedef _Key = (double t, double value);

double _track(List<_Key> keys, double t) {
  if (t <= keys.first.$1) return keys.first.$2;
  for (var i = 1; i < keys.length; i++) {
    if (t <= keys[i].$1) {
      final (t0, v0) = keys[i - 1];
      final (t1, v1) = keys[i];
      final k = (t - t0) / (t1 - t0);
      return v0 + (v1 - v0) * Curves.easeInOut.transform(k.clamp(0, 1));
    }
  }
  return keys.last.$2;
}

class _SekvencaPainter extends CustomPainter {
  _SekvencaPainter(this.scheme, this.t);

  final ColorScheme scheme;
  final double t;

  // Геометрия сцены (холст 400×240).
  static const double _roadTop = 38;
  static const double _roadBottom = 186;
  static const double _oncomingLaneY = 72; // встречная (левая) полоса
  static const double _ownLaneY = 140; // своя полоса
  static const double _axisY = 106;
  static const double _truckX = 158;

  static const _blueX = <_Key>[
    (0, 26),
    (0.22, 62),
    (0.38, 120),
    (0.62, 252),
    (0.82, 300),
    (1, 340),
  ];

  static const _blueY = <_Key>[
    (0, _ownLaneY),
    (0.24, _ownLaneY),
    (0.38, _oncomingLaneY),
    (0.66, _oncomingLaneY),
    (0.8, _ownLaneY),
    (1, _ownLaneY),
  ];

  // Встречный далеко и почти стоит, пока идёт обгон, и проезжает только после
  // того, как синий уже вернулся: в этом и смысл «оцени расстояние».
  static const _redX = <_Key>[
    (0, 372),
    (0.8, 344),
    (1, -70),
  ];

  static const _captions = <(double, String)>[
    (0.24, '1 · леви показивач правца + процена растојања'),
    (0.38, '2 · излазак на леву траку'),
    (0.66, '3 · претицање уз довољно бочно растојање'),
    (0.86, '4 · повратак у своју траку, десни показивач'),
    (1, '5 · мимоилажење тек кад си већ у својој траци'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final blueX = _track(_blueX, t);
    final blueY = _track(_blueY, t);
    final redX = _track(_redX, t);
    // Такт мигания ≈ 0,5 с — как у настоящего показивача.
    final blinkOn = (t * 16).floor().isEven;

    // Подпись фазы.
    final caption = _captions.firstWhere((it) => t <= it.$1).$2;
    drawText(
      canvas,
      caption,
      at: const Offset(0, 2),
      color: scheme.onSurface,
      size: 14,
      bold: true,
      maxWidth: 400,
    );

    // Полотно: две полосы, движение навстречу.
    final road = Rect.fromLTRB(0, _roadTop, size.width, _roadBottom);
    drawAsphalt(canvas, road);
    drawEdgeLines(canvas, road);
    // Штрихи едут влево — камера идёт вместе с обгоняемым грузовиком.
    drawDashedLine(canvas, _axisY, 4, size.width - 4, offset: t * 640);

    // Обгоняемый: подписи ему не даём — место под грузовиком нужно выноске
    // «одстојање», а роль ясна из фазовой подписи сверху.
    drawTruck(canvas, const Offset(_truckX, _ownLaneY));

    drawCar(
      canvas,
      Offset(redX, _oncomingLaneY),
      color: const Color(0xFFE53935),
      facingLeft: true,
    );

    drawCar(
      canvas,
      Offset(blueX, blueY),
      color: const Color(0xFF1E88E5),
      leftBlinker: t < 0.38,
      rightBlinker: t >= 0.62 && t < 0.86,
      blinkOn: blinkOn,
    );

    if (t < 0.24) {
      _drawOncomingDistance(canvas, blueX, redX);
    } else if (t >= 0.38 && t < 0.66) {
      _drawSideGap(canvas, blueX);
    } else if (t >= 0.66 && t < 0.86) {
      _drawFollowingGap(canvas, blueX);
    }

    drawText(
      canvas,
      'Претиче се само кад има довољно места. У своју траку се враћа '
      'без ометања претицаног — а не „чим се угледа возило из супротног смера“.',
      at: const Offset(0, 196),
      color: scheme.onSurfaceVariant,
      size: 12,
      maxWidth: 400,
    );
  }

  /// Фаза 1: расстояние до встречного — то, что оценивают до выезда.
  void _drawOncomingDistance(Canvas canvas, double blueX, double redX) {
    final from = Offset(blueX + kCarLength / 2 + 6, _axisY);
    final to = Offset(redX - kCarLength / 2 - 6, _axisY);
    drawArrow(canvas, from, to, color: kMarking, doubleHead: true);
    drawTagOnRoad(
      canvas,
      'процени растојање до возила из супротног смера',
      at: Offset((from.dx + to.dx) / 2, _axisY - 8),
      anchor: Alignment.bottomCenter,
    );
  }

  /// Фаза 3: боковой интервал до обгоняемого.
  void _drawSideGap(Canvas canvas, double blueX) {
    final x = blueX.clamp(60.0, 300.0);
    drawArrow(
      canvas,
      Offset(x, _oncomingLaneY + kCarWidth / 2 + 3),
      Offset(x, _ownLaneY - kTruckWidth / 2 - 3),
      color: kMarking,
      doubleHead: true,
      headSize: 5,
    );
    drawTagOnRoad(
      canvas,
      'бочно растојање',
      at: Offset(x + 8, _axisY),
      anchor: Alignment.centerLeft,
    );
  }

  /// Фаза 4: возврат — только с достаточным одстојањем, без «подрезания».
  void _drawFollowingGap(Canvas canvas, double blueX) {
    final rear = blueX - kCarLength / 2 - 6;
    final front = _truckX + kTruckLength / 2 + 6;
    if (rear - front < 12) return;
    drawArrow(
      canvas,
      Offset(front, _ownLaneY),
      Offset(rear, _ownLaneY),
      color: kMarking,
      doubleHead: true,
      headSize: 5,
    );
    drawTagOnRoad(
      canvas,
      'одстојање — без наглог упадања',
      at: Offset((front + rear) / 2, _ownLaneY + 12),
      anchor: Alignment.topCenter,
    );
  }

  @override
  bool shouldRepaint(covariant _SekvencaPainter old) =>
      old.t != t || old.scheme != scheme;
}
