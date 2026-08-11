import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/car_top_view.dart';
import 'package:saobracaj/test/animations/road_obstacle.dart';
import 'package:saobracaj/test/animations/trafic_cone.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Объезд препятствия с выездом на встречную полосу.
///
/// Правило, которое снимает путаницу: преимущества нет у того, в чьей полосе
/// препятствие — он пропускает **все** встречные ТС и только потом объезжает.
///
/// Подписи на сербском (термины из билетов), переводимых строк нет.
class ObilazenjePrepreke extends StatefulWidget {
  const ObilazenjePrepreke({super.key});

  @override
  State<ObilazenjePrepreke> createState() => _ObilazenjePreprekeState();
}

class _ObilazenjePreprekeState extends State<ObilazenjePrepreke>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 8 секунд: три фазы по 2–3 секунды плюс пауза в конце, иначе сцена
    // читается как дёрганая петля.
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
        height: 262,
        child: Column(
          children: [
            SizedBox(
              width: 400,
              height: 34,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Center(
                  child: Text(
                    _caption(_controller.value),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kAppFontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 400,
              height: 172,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: _ObilazenjePainter(scheme, _controller.value),
                      ),
                    ),
                  ),
                  // Препятствие неподвижно, поэтому оно вне AnimatedBuilder:
                  // готовые примитивы вместо своей ямы и своих конусов.
                  const Positioned(
                    left: 230,
                    top: 105,
                    child: RoadObstacleWidget(size: 44),
                  ),
                  const Positioned(
                    left: 214,
                    top: 101,
                    child: TrafficConeWidget(height: 26),
                  ),
                  const Positioned(
                    left: 276,
                    top: 101,
                    child: TrafficConeWidget(height: 26),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 376,
              height: 44,
              child: Text(
                'Возач у чијој се траци налази препрека нема првенство: прво '
                'пропушта возила из супротног смера, па обилази.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kAppFontFamily,
                  fontSize: 12,
                  height: 1.3,
                  color: scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _caption(double t) {
    if (t < 0.22) return 'Препрека у мојој траци — успоравам';
    if (t < 0.44) return 'Стајем и пропуштам сва возила из супротног смера';
    return 'Тек кад је слободно — обилазим преко супротне траке';
  }
}

const _asphalt = Color(0xFF424242);
const _marking = Colors.white;

// Геометрия сцены (холст 400×172): полосы и границы асфальта.
const _roadTop = 20.0;
const _roadBottom = 160.0;
const _centerLine = 90.0;
const _oncomingLane = 55.0;
const _myLane = 125.0;

class _ObilazenjePainter extends CustomPainter {
  final ColorScheme scheme;
  final double t;

  _ObilazenjePainter(this.scheme, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawRoad(canvas);

    final blinkOn = (t * 16).floor().isEven;

    // Встречное ТС проезжает, пока мы стоим: к моменту объезда полоса пуста.
    final oncomingX = _phase(t, 0.10, 0.40, 470, -70, Curves.linear);
    if (oncomingX > -60 && oncomingX < 460) {
      paintCarTopView(
        canvas,
        Rect.fromCenter(
          center: Offset(oncomingX, _oncomingLane),
          width: 96,
          height: 36,
        ),
        color: const Color(0xFF1E6FD9),
        facingLeft: true,
      );
      _pill(
        canvas,
        'има предност',
        Offset(oncomingX, _oncomingLane - 34),
        bg: scheme.tertiaryContainer,
        fg: scheme.onTertiaryContainer,
      );
    }

    // Наше ТС: подъезд → остановка перед препятствием → объезд. В конце цикла
    // машина не уезжает за кадр, а замирает за препятствием: иначе последние
    // две секунды петли зритель смотрит на пустую дорогу.
    final myX = t < 0.20
        ? _phase(t, 0.0, 0.20, -60, 170, Curves.easeOut)
        : (t < 0.44
              ? 170.0
              : _phase(t, 0.44, 0.86, 170, 352, Curves.easeInOut));
    final myY = t < 0.47
        ? _myLane
        : (t < 0.57
              ? _phase(t, 0.47, 0.57, _myLane, _oncomingLane, Curves.easeInOut)
              : (t < 0.74
                    ? _oncomingLane
                    : _phase(
                        t,
                        0.74,
                        0.86,
                        _oncomingLane,
                        _myLane,
                        Curves.easeInOut,
                      )));

    if (myX < 460) {
      paintCarTopView(
        canvas,
        Rect.fromCenter(center: Offset(myX, myY), width: 96, height: 36),
        color: const Color(0xFF2E7D32),
        lamps: t < 0.44
            ? CarLamps.none
            : (t < 0.72 ? CarLamps.turnUp : CarLamps.turnDown),
        blinkOn: blinkOn,
      );
      if (t >= 0.12 && t < 0.46) {
        _pill(
          canvas,
          'уступам',
          Offset(myX, myY + 34),
          bg: scheme.errorContainer,
          fg: scheme.onErrorContainer,
        );
      } else if (t >= 0.46 && t < 0.90) {
        _pill(
          canvas,
          'обилазим',
          Offset(myX, myY - 34),
          bg: scheme.primaryContainer,
          fg: scheme.onPrimaryContainer,
        );
      }
    }
  }

  void _drawRoad(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTRB(0, _roadTop, 400, _roadBottom),
      Paint()..color = _asphalt,
    );
    final edge = Paint()
      ..color = _marking
      ..strokeWidth = 2.5;
    canvas.drawLine(
      const Offset(0, _roadTop + 4),
      const Offset(400, _roadTop + 4),
      edge,
    );
    canvas.drawLine(
      const Offset(0, _roadBottom - 4),
      const Offset(400, _roadBottom - 4),
      edge,
    );
    final dash = Paint()
      ..color = _marking
      ..strokeWidth = 4;
    for (var x = 0.0; x < 400; x += 36) {
      canvas.drawLine(
        Offset(x, _centerLine),
        Offset((x + 20).clamp(0, 400), _centerLine),
        dash,
      );
    }
  }

  /// Подпись в «таблетке»: над асфальтом любой цвет темы читается плохо,
  /// а на своей подложке — одинаково хорошо в светлой и тёмной теме.
  void _pill(
    Canvas canvas,
    String text,
    Offset center, {
    required Color bg,
    required Color fg,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          fontFamily: kAppFontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: painter.width + 14,
        height: painter.height + 7,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(rect, Paint()..color = bg);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  double _phase(
    double t,
    double from,
    double to,
    double a,
    double b,
    Curve curve,
  ) {
    final raw = ((t - from) / (to - from)).clamp(0.0, 1.0);
    return a + (b - a) * curve.transform(raw);
  }

  @override
  bool shouldRepaint(covariant _ObilazenjePainter old) =>
      old.t != t || old.scheme != scheme;
}
