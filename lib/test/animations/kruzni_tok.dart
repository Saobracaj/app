import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Претицање и раскрсница са кружним током.
///
/// Ловушка вопросов не в самом кольце, а в границе: «непосредно испред
/// раскрснице» и «на раскрсници» — это два разных места с противоположными
/// правилами. По чл. 57 ст. 1 обгон запрещён перед любым перекрёстком и на
/// перекрёстке, который **не** является кольцевым; значит на самом кольце он
/// разрешён. На статике эту границу не показать — приходится провезти машины
/// через неё, поэтому сцена анимированная: первая половина цикла — подъезд
/// (перечёркнуто), вторая — то же самое уже на кольце (разрешено).
///
/// Третье правило (чл. 57 ст. 2 — путь с преимуществом проезда) в сцену не
/// влезает: оно не про кольцо. Оно вынесено в памятку под сценой, потому что
/// один из вопросов, к которому подключается эта картинка, именно про него.
class KruzniTok extends StatefulWidget {
  const KruzniTok({super.key});

  @override
  State<KruzniTok> createState() => _KruzniTokState();
}

class _KruzniTokState extends State<KruzniTok>
    with SingleTickerProviderStateMixin {
  /// Восемь секунд — по четыре на фазу: примерно 2,5 с движение и 1,5 с
  /// пауза. Короче — не успеть прочитать подпись и понять, что изменилось.
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
          height: 530,
          child: Column(
            children: [
              SizedBox(
                width: 400,
                height: 380,
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
                height: 140,
                child: CustomPaint(painter: _RulePainter(scheme)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Асфальт, разметка, трава острова и цвета машин от темы не зависят — это
/// их собственный цвет.
const _asphalt = Color(0xFF4E545B);
const _marking = Color(0xFFF2F2F2);
const _island = Color(0xFF56794B);
const _carBlue = Color(0xFF3D7BD6);
const _carGreen = Color(0xFF3E9B57);
const _forbidden = Color(0xFFD32F2F);

double _rad(double degrees) => degrees * math.pi / 180;

class _ScenePainter extends IllustrationPainter {
  _ScenePainter(super.colorScheme, this.t);

  /// Позиция в цикле, 0..1.
  final double t;

  /// Кольцо сдвинуто вверх: на подход снизу нужно больше места, чем на
  /// остальные три — весь обгон первой фазы происходит именно там.
  static const _center = Offset(200, 168);
  static const _outerR = 92.0;
  static const _islandR = 32.0;

  /// Кольцо в две полосы. Внешняя — правая (по ней едут), внутренняя — левая
  /// (по ней обгоняют): кольцо объезжается против часовой стрелки, поэтому
  /// «слева» — это со стороны острова.
  static const _laneLineR = 62.0;
  static const _innerLaneR = 52.0;
  static const _outerLaneR = 76.0;

  /// Половина ширины подхода; полоса одного направления — 32.
  static const _armHalf = 32.0;
  static const _rightLaneX = 216.0;
  static const _leftLaneX = 186.0;
  static const _bottom = 380.0;

  /// Где подход стыкуется с окружностью кольца — до этой точки кромочные
  /// линии не рисуются, иначе они лезут на кольцевую проезжую часть.
  static final _armJoin = math.sqrt(_outerR * _outerR - _armHalf * _armHalf);

  bool get _onRing => t >= 0.5;

  /// Прогресс внутри фазы: 0..1 за первые 55 % фазы, дальше пауза на чтение.
  double get _progress => (((_onRing ? t - 0.5 : t) / 0.5) / 0.55).clamp(0, 1);

  double get _eased => Curves.easeInOut.transform(_progress);

  String get _caption => _onRing
      ? 'на раскрсници са кружним током — претицање је дозвољено'
      : 'непосредно испред раскрснице — претицање је забрањено';

  @override
  void paint(Canvas canvas, Size size) {
    // Машины выезжают из-за нижнего края: без клипа они рисуются поверх
    // памятки под сценой.
    canvas.clipRect(Offset.zero & size);
    _drawCaption(canvas);
    _drawRoads(canvas);
    if (_onRing) {
      _drawRingScene(canvas);
    } else {
      _drawApproachScene(canvas);
    }
  }

  void _drawCaption(Canvas canvas) {
    calloutBox(
      canvas,
      _caption,
      const Rect.fromLTRB(6, 4, 394, 36),
      fill: _onRing
          ? colorScheme.tertiaryContainer
          : colorScheme.errorContainer,
      textColor: _onRing
          ? colorScheme.onTertiaryContainer
          : colorScheme.onErrorContainer,
      check: _onRing,
      cross: !_onRing,
      fontSize: 12,
      isBold: true,
    );
  }

  void _drawRoads(Canvas canvas) {
    final asphalt = Paint()..color = _asphalt;
    // Подходы доводятся до центра и перекрываются кругом — так стык выходит
    // без швов, без вычисления касательных.
    for (final arm in const [
      Rect.fromLTRB(168, 168, 232, _bottom), // юг
      Rect.fromLTRB(168, 40, 232, 168), // север
      Rect.fromLTRB(200, 136, 400, 200), // восток
      Rect.fromLTRB(0, 136, 200, 200), // запад
    ]) {
      canvas.drawRect(arm, asphalt);
    }
    canvas.drawCircle(_center, _outerR, asphalt);

    _drawMarkings(canvas);
    _drawIsland(canvas);
    _drawRingArrows(canvas);
    _drawYieldLine(canvas);
  }

  void _drawMarkings(Canvas canvas) {
    final edge = Paint()
      ..color = _marking
      ..strokeWidth = 2.5;

    // Кромочные линии подходов. Сдвинуты внутрь асфальта: ровно на границе
    // белое по светлому фону темы не видно вовсе.
    final joinY = _center.dy + _armJoin;
    for (final x in [171.0, 229.0]) {
      canvas.drawLine(Offset(x, joinY), Offset(x, _bottom), edge);
      canvas.drawLine(Offset(x, 40), Offset(x, _center.dy - _armJoin), edge);
    }
    final joinX = _center.dx + _armJoin;
    for (final y in [139.0, 197.0]) {
      canvas.drawLine(Offset(joinX, y), Offset(400, y), edge);
      canvas.drawLine(Offset(0, y), Offset(_center.dx - _armJoin, y), edge);
    }

    // Внешняя кромка кольца — четырьмя дугами между подходами.
    final ringEdge = Paint()
      ..color = _marking
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (var quadrant = 0; quadrant < 4; quadrant++) {
      canvas.drawArc(
        Rect.fromCircle(center: _center, radius: _outerR),
        _rad(quadrant * 90 + 20),
        _rad(50),
        false,
        ringEdge,
      );
    }

    // Осевые подходов: разделяют встречные направления.
    dashedLine(canvas, const Offset(200, 276), const Offset(200, _bottom),
        color: _marking, dash: 12, gap: 9, width: 2.5);
    dashedLine(canvas, const Offset(200, 40), const Offset(200, 70),
        color: _marking, dash: 12, gap: 9, width: 2.5);
    dashedLine(canvas, const Offset(300, 168), const Offset(400, 168),
        color: _marking, dash: 12, gap: 9, width: 2.5);
    dashedLine(canvas, const Offset(0, 168), const Offset(100, 168),
        color: _marking, dash: 12, gap: 9, width: 2.5);

    // Разделительная линия полос самого кольца: по ней и видно, что полос
    // две и что обгон на кольце — это переход на внутреннюю.
    _dashedCircle(canvas, _laneLineR);
  }

  void _dashedCircle(Canvas canvas, double radius) {
    final paint = Paint()
      ..color = _marking
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // Шаг в градусах подобран так, чтобы штрих на этом радиусе был примерно
    // такой же длины, как штрихи осевой на подходах.
    const step = 14.0;
    for (var angle = 0.0; angle < 360; angle += step) {
      canvas.drawArc(
        Rect.fromCircle(center: _center, radius: radius),
        _rad(angle),
        _rad(step * 0.55),
        false,
        paint,
      );
    }
  }

  void _drawIsland(Canvas canvas) {
    canvas.drawCircle(_center, _islandR, Paint()..color = _island);
    canvas.drawCircle(
      _center,
      _islandR,
      Paint()
        ..color = _marking
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  /// Стрелки направления объезда. Стоят в верхних четвертях — там, где по
  /// сцене не проезжают машины, иначе они бы читались как разметка под ними.
  void _drawRingArrows(Canvas canvas) {
    for (final angle in [225.0, 315.0]) {
      // Движение против часовой стрелки — угол убывает, поэтому стрелка
      // смотрит из большего угла в меньший.
      final from = _pointAt(angle + 9, _laneLineR);
      final to = _pointAt(angle - 9, _laneLineR);
      arrow(canvas, from, to, color: _marking, width: 3, head: 11);
    }
  }

  /// «Уступи првенство» на въезде: треугольники поперёк въездной полосы. Тот,
  /// кто уже на кольце, имеет преимущество — это отдельное правило, но без
  /// него схема кольца выглядит недорисованной.
  void _drawYieldLine(Canvas canvas) {
    final paint = Paint()..color = _marking;
    for (var x = 204.0; x < 230; x += 11) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 271)
          ..lineTo(x + 8, 271)
          ..lineTo(x + 4, 262)
          ..close(),
        paint,
      );
    }
    // Граница «испред раскрснице / на раскрсници» проходит ровно здесь, и
    // весь вопрос — по какую сторону от неё машина. Без подписи её на схеме
    // просто не видно.
    roadLabel(canvas, 'улаз у раскрсницу', const Offset(92, 266), fontSize: 11);
  }

  /// Фаза 1: обе машины ещё на подходе. Синяя выходит на встречную полосу,
  /// чтобы обогнать зелёную, — и именно это перечёркнуто.
  void _drawApproachScene(Canvas canvas) {
    // Обе машины видны с первого кадра фазы и никуда не уезжают за край:
    // движется, по сути, только манёвр обгона, а не поток.
    final greenY = lerpDouble(320, 296, _eased);
    final blueY = lerpDouble(372, 312, _eased);
    // Перестроение — в середине разгона: сначала догнал, потом вышел влево.
    final blueX = lerpDouble(
      _rightLaneX,
      _leftLaneX,
      Curves.easeInOut.transform(((_progress - 0.3) / 0.5).clamp(0, 1)),
    );

    _drawCar(canvas, Offset(_rightLaneX, greenY), -math.pi / 2, _carGreen);
    _drawCar(canvas, Offset(blueX, blueY), -math.pi / 2, _carBlue);

    // Крест появляется вместе с выездом на встречную: пока синяя едет в своей
    // полосе, запрещать нечего. Полупрозрачный — под ним должно остаться
    // видно, что именно запрещено.
    if (_progress > 0.4) {
      crossOutRect(
        canvas,
        const Rect.fromLTRB(162, 276, 240, 344),
        _forbidden.withValues(alpha: 0.85),
        width: 6,
      );
    }
  }

  /// Фаза 2: те же машины уже на кольце. Синяя обгоняет по внутренней полосе
  /// — на кольцевом перекрёстке это разрешено.
  void _drawRingScene(Canvas canvas) {
    final greenAngle = lerpDouble(105, 35, _eased);
    final blueAngle = lerpDouble(155, 5, _eased);

    _drawOvertakePath(canvas);
    _drawCar(
      canvas,
      _pointAt(greenAngle, _outerLaneR),
      _rad(greenAngle) - math.pi / 2,
      _carGreen,
    );
    _drawCar(
      canvas,
      _pointAt(blueAngle, _innerLaneR),
      _rad(blueAngle) - math.pi / 2,
      _carBlue,
    );
  }

  /// Траектория обгона пунктиром. Нужна для стоп-кадра: без неё две машины на
  /// кольце читаются как «просто едут», а не как «одна обгоняет другую».
  void _drawOvertakePath(Canvas canvas) {
    final path = Path()
      ..addArc(
        Rect.fromCircle(center: _center, radius: _innerLaneR),
        _rad(5),
        _rad(150),
      );
    // Цветом машины, а не белым: белым на дороге нарисована разметка.
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

  void _drawCar(Canvas canvas, Offset position, double heading, Color color) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(heading);
    drawCarTopView(
      canvas,
      this,
      Rect.fromCenter(center: Offset.zero, width: 46, height: 22),
      body: color,
    );
    canvas.restore();
  }

  Offset _pointAt(double degrees, double radius) =>
      _center +
      Offset(math.cos(_rad(degrees)), math.sin(_rad(degrees))) * radius;

  static double lerpDouble(double a, double b, double x) => a + (b - a) * x;

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.t != t || old.colorScheme != colorScheme;
}

/// Памятка под сценой: три места, где вопросы спрашивают про обгон, и ответ
/// для каждого. Третья строка — единственное место, где живёт правило про
/// путь с преимуществом проезда.
class _RulePainter extends IllustrationPainter {
  _RulePainter(super.colorScheme);

  @override
  void paint(Canvas canvas, Size size) {
    calloutBox(
      canvas,
      'испред раскрснице и на раскрсници\nкоја није са кружним током',
      const Rect.fromLTRB(4, 2, 396, 38),
      fill: colorScheme.errorContainer,
      textColor: colorScheme.onErrorContainer,
      cross: true,
    );
    calloutBox(
      canvas,
      'на раскрсници са кружним током саобраћаја',
      const Rect.fromLTRB(4, 44, 396, 80),
      fill: colorScheme.tertiaryContainer,
      textColor: colorScheme.onTertiaryContainer,
      check: true,
    );
    calloutBox(
      canvas,
      'на путу са првенством пролаза — и непосредно\nиспред раскрснице, и на самој раскрсници',
      const Rect.fromLTRB(4, 86, 396, 122),
      fill: colorScheme.tertiaryContainer,
      textColor: colorScheme.onTertiaryContainer,
      check: true,
    );
    text(
      canvas,
      'члан 57. Закона о безбедности саобраћаја на путевима',
      const Offset(200, 133),
      colorScheme.onSurfaceVariant,
      maxWidth: 380,
      fontSize: 10,
      isItalic: true,
    );
  }

  @override
  bool shouldRepaint(covariant _RulePainter old) =>
      old.colorScheme != colorScheme;
}
