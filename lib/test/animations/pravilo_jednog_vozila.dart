import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/car_top_view.dart';
import 'package:saobracaj/test/animations/trafic_cone.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Правило «молнии»: если соседняя полоса закрыта, впустить нужно **ровно
/// одно** ТС.
///
/// Ловушки этих вопросов — «пропустить все» и «пропустить два»; и обратная
/// ситуация: если соседняя полоса не закрыта, обязанности впускать нет
/// вообще. Поэтому в сцене два кадра: закрытая полоса и свободная.
///
/// Подписи целиком на сербском (термины из билетов), переводимых строк нет.
class PraviloJednogVozila extends StatefulWidget {
  const PraviloJednogVozila({super.key});

  @override
  State<PraviloJednogVozila> createState() => _PraviloJednogVozilaState();
}

class _PraviloJednogVozilaState extends State<PraviloJednogVozila>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 8 секунд: подъезд — пропуск — проезд — пауза.
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
        height: 458,
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
              height: 196,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: _ZipperPainter(scheme, _controller.value),
                      ),
                    ),
                  ),
                  // Дорожные работы неподвижны, поэтому лежат вне
                  // AnimatedBuilder — и собраны из готовых примитивов. Конусы
                  // стоят «лесенкой» от разделительной линии к правому краю:
                  // так видно, что полоса сужается и закрывается.
                  const Positioned(
                    left: 300,
                    top: 100,
                    child: TrafficConeWidget(height: 24),
                  ),
                  const Positioned(
                    left: 320,
                    top: 122,
                    child: TrafficConeWidget(height: 24),
                  ),
                  const Positioned(
                    left: 340,
                    top: 144,
                    child: TrafficConeWidget(height: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 376,
              height: 34,
              child: Text(
                'Кад је суседна трака затворена, обавезно је пропустити '
                'ЈЕДНО возило — не сва и не два.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kAppFontFamily,
                  fontSize: 11.5,
                  height: 1.3,
                  color: scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 400,
              height: 22,
              child: Text(
                'Ако суседна трака НИЈЕ затворена — нема обавезе',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kAppFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            SizedBox(
              width: 400,
              height: 120,
              child: CustomPaint(painter: _FreeLanePainter(scheme)),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 376,
              height: 32,
              child: Text(
                'Нема обавезе да га пропустиш, али пропусти ради безбедности '
                '— саобраћај не сме да буде угрожен.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kAppFontFamily,
                  fontSize: 11.5,
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
    if (t < 0.20) return 'Десна трака је затворена због радова';
    if (t < 0.52) return 'Успоравам и пропуштам ТАЧНО ЈЕДНО возило';
    return 'Друго и треће возило чекају следећа возила';
  }
}

const _asphalt = Color(0xFF424242);
const _marking = Colors.white;
const _blue = Color(0xFF1E6FD9);
const _green = Color(0xFF2E7D32);
const _brown = Color(0xFF6D4C41);
const _slate = Color(0xFF546E7A);

// Геометрия главной сцены (холст 400×196): две полосы одного направления.
const _roadTop = 26.0;
const _roadBottom = 172.0;
const _divider = 99.0;
const _leftLane = 62.0; // свободная полоса — на схеме верхняя
const _rightLane = 136.0; // закрытая полоса — нижняя
const _worksFrom = 296.0;

class _ZipperPainter extends CustomPainter {
  final ColorScheme scheme;
  final double t;

  _ZipperPainter(this.scheme, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawRoad(canvas);

    final blinkOn = (t * 16).floor().isEven;

    // Синий по свободной полосе: подъезжает, стоит, пока первый встраивается,
    // и уезжает уже за ним.
    final blueX = t < 0.20
        ? _phase(t, 0, 0.20, -50, 150, Curves.easeOut)
        : (t < 0.52
              ? 150.0
              : _phase(t, 0.52, 0.80, 150, 230, Curves.easeInOut));
    // Первое возило из закрытой полосы: только оно и въезжает.
    final firstX = t < 0.32
        ? 250.0
        : (t < 0.52
              ? _phase(t, 0.32, 0.52, 250, 262, Curves.easeInOut)
              : _phase(t, 0.52, 0.80, 262, 340, Curves.easeInOut));
    final firstY = t < 0.32
        ? _rightLane
        : (t < 0.52
              ? _phase(t, 0.32, 0.52, _rightLane, _leftLane, Curves.easeInOut)
              : _leftLane);

    // Второе и третье остаются на месте: они ждут следующие ТС, а не «свою
    // очередь в этой же щели».
    for (final x in [160.0, 70.0]) {
      paintCarTopView(
        canvas,
        Rect.fromCenter(center: Offset(x, _rightLane), width: 78, height: 32),
        color: x > 100 ? _brown : _slate,
      );
      _pill(
        canvas,
        'чека',
        Offset(x, _rightLane + 30),
        bg: scheme.secondaryContainer,
        fg: scheme.onSecondaryContainer,
      );
    }

    paintCarTopView(
      canvas,
      Rect.fromCenter(center: Offset(firstX, firstY), width: 78, height: 32),
      color: _green,
      // Показатель поворота в сторону свободной полосы горит до самого
      // завершения перестроения.
      lamps: t >= 0.24 && t < 0.56 ? CarLamps.turnUp : CarLamps.none,
      blinkOn: blinkOn,
    );
    _pill(
      canvas,
      t < 0.52 ? 'прво — улази' : 'ушао',
      Offset(firstX, firstY + (firstY > _divider ? 30 : -30)),
      bg: scheme.tertiaryContainer,
      fg: scheme.onTertiaryContainer,
    );

    paintCarTopView(
      canvas,
      Rect.fromCenter(center: Offset(blueX, _leftLane), width: 78, height: 32),
      color: _blue,
    );
    if (blueX > 20) {
      _pill(
        canvas,
        'пропуштам једно',
        Offset(blueX, _leftLane - 30),
        bg: scheme.primaryContainer,
        fg: scheme.onPrimaryContainer,
      );
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
        Offset(x, _divider),
        Offset((x + 20).clamp(0, 400), _divider),
        dash,
      );
    }

    // Обе полосы — одного направления: шевроны у левого края.
    final chevron = Paint()
      ..color = _marking.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final y in [_leftLane, _rightLane]) {
      canvas.drawPath(
        Path()
          ..moveTo(8, y - 9)
          ..lineTo(20, y)
          ..lineTo(8, y + 9),
        chevron,
      );
    }

    // Зона работ: закрытая часть правой полосы в оранжевую штриховку.
    final zone = Rect.fromLTRB(_worksFrom, _divider, 400, _roadBottom - 8);
    canvas.save();
    canvas.clipRect(zone);
    canvas.drawRect(zone, Paint()..color = const Color(0xFF8D6E00));
    final stripe = Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 6;
    for (var x = _worksFrom - 60; x < 420; x += 18) {
      canvas.drawLine(Offset(x, _roadBottom), Offset(x + 60, _divider), stripe);
    }
    canvas.restore();
    _pill(
      canvas,
      'радови',
      const Offset(366, 110),
      bg: scheme.errorContainer,
      fg: scheme.onErrorContainer,
    );
  }

  void _pill(
    Canvas canvas,
    String text,
    Offset center, {
    required Color bg,
    required Color fg,
  }) {
    _paintPill(canvas, text, center, bg: bg, fg: fg);
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
  bool shouldRepaint(covariant _ZipperPainter old) =>
      old.t != t || old.scheme != scheme;
}

/// Второй кадр: обе полосы свободны, соседнее ТС просит впустить.
class _FreeLanePainter extends CustomPainter {
  final ColorScheme scheme;

  _FreeLanePainter(this.scheme);

  static const _top = 20.0;
  static const _bottom = 108.0;
  static const _mid = 64.0;
  static const _upper = 42.0;
  static const _lower = 86.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      const Rect.fromLTRB(0, _top, 400, _bottom),
      Paint()..color = _asphalt,
    );
    final edge = Paint()
      ..color = _marking
      ..strokeWidth = 2.5;
    canvas.drawLine(const Offset(0, _top + 4), const Offset(400, _top + 4), edge);
    canvas.drawLine(
      const Offset(0, _bottom - 4),
      const Offset(400, _bottom - 4),
      edge,
    );
    final dash = Paint()
      ..color = _marking
      ..strokeWidth = 4;
    for (var x = 0.0; x < 400; x += 36) {
      canvas.drawLine(
        Offset(x, _mid),
        Offset((x + 20).clamp(0, 400), _mid),
        dash,
      );
    }

    paintCarTopView(
      canvas,
      Rect.fromCenter(center: const Offset(170, _lower), width: 74, height: 30),
      color: _green,
      lamps: CarLamps.turnUp,
    );
    paintCarTopView(
      canvas,
      Rect.fromCenter(center: const Offset(84, _upper), width: 74, height: 30),
      color: _blue,
    );

    _paintPill(
      canvas,
      'молим да уђем',
      const Offset(190, _lower + 26),
      bg: scheme.secondaryContainer,
      fg: scheme.onSecondaryContainer,
    );
    _paintPill(
      canvas,
      'нема обавезе',
      const Offset(84, _upper - 26),
      bg: scheme.primaryContainer,
      fg: scheme.onPrimaryContainer,
    );
    _paintPill(
      canvas,
      'трака је слободна',
      const Offset(330, _lower),
      bg: scheme.tertiaryContainer,
      fg: scheme.onTertiaryContainer,
    );
  }

  @override
  bool shouldRepaint(covariant _FreeLanePainter old) => old.scheme != scheme;
}

/// Подпись в «таблетке»: над асфальтом цвета темы читаются плохо, а на своей
/// подложке — одинаково в светлой и тёмной теме. Центр прижимается к краям
/// холста, чтобы движущаяся подпись не уехала за кадр.
void _paintPill(
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
  final width = painter.width + 14;
  final height = painter.height + 7;
  final dx = center.dx.clamp(4 + width / 2, 396 - width / 2);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(dx, center.dy),
        width: width,
        height: height,
      ),
      const Radius.circular(9),
    ),
    Paint()..color = bg,
  );
  painter.paint(
    canvas,
    Offset(dx - painter.width / 2, center.dy - painter.height / 2),
  );
}
