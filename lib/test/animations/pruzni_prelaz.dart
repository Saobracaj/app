import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/painters.dart';
import 'package:saobracaj/test/animations/road_sign.dart';

/// Прелаз пута преко железничке пруге: приближение, опускающийся полубраник,
/// остановка перед ним — и отдельная памятка на случай, когда машина встала
/// на путях.
///
/// Сцена собрана вокруг одной ошибки: «места под браником хватает, проскочу».
/// Поэтому запрет показан не словом, а кадром — та же машина под опущенным
/// брaником, перечёркнутая. Памятка внизу статичная: её читают, а не смотрят.
class PruzniPrelaz extends StatefulWidget {
  const PruzniPrelaz({super.key});

  @override
  State<PruzniPrelaz> createState() => _PruzniPrelazState();
}

class _PruzniPrelazState extends State<PruzniPrelaz>
    with SingleTickerProviderStateMixin {
  /// Полный цикл: подъезд, опускание, остановка, запрет и пауза на запрете.
  /// Короче семи секунд последний кадр не успевают прочитать.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7500),
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
          height: 428,
          child: Column(
            children: [
              SizedBox(
                width: 400,
                height: 250,
                child: RoadSignScope(
                  signs: const ['I-34'],
                  builder: (context, signs) => AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CustomPaint(
                      painter:
                          _CrossingPainter(scheme, _controller.value, signs),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 400,
                height: 168,
                child: CustomPaint(painter: _StalledPainter(scheme)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Асфальт, разметка и сигнальные цвета от темы не зависят — это их
/// собственный цвет.
const _asphalt = Color(0xFF4E545B);
const _marking = Color(0xFFF2F2F2);
const _barrierRed = Color(0xFFD32F2F);
const _barrierWhite = Color(0xFFF5F5F5);
const _hazard = Color(0xFFFFA000);
const _railSteel = Color(0xFF9AA0A6);
const _sleeper = Color(0xFF6D5B4B);

/// Ключевые координаты сцены. Держим их в одном месте: машина, браник и
/// пруга обязаны стоять друг относительно друга ровно так, как в правиле —
/// сначала уређај, потом рельсы.
const _roadY = 206.0;
const _hinge = Offset(273, 156);
const _armLength = 110.0;
const _railLeft = 300.0;
const _railRight = 322.0;

class _CrossingPainter extends IllustrationPainter {
  _CrossingPainter(super.colorScheme, this.t, this.signs);

  /// Позиция в цикле, 0..1.
  final double t;

  final RoadSigns signs;

  /// Насколько опущен полубраник: 0 — поднят, 1 — лежит поперёк пути.
  double get _lowered {
    if (t < 0.30) return 0;
    if (t < 0.46) return _ease((t - 0.30) / 0.16) * 0.55;
    if (t < 0.60) return 0.55 + _ease((t - 0.46) / 0.14) * 0.45;
    return 1;
  }

  /// Левый край машины. Останавливается на 58 — передний бампер оказывается
  /// перед брaником, а не под ним.
  double get _carLeft {
    if (t < 0.30) return -120 + (t / 0.30) * 130;
    if (t < 0.46) return 10 + _ease((t - 0.30) / 0.16) * 48;
    return 58;
  }

  bool get _forbiddenFrame => t >= 0.74;

  String get _caption {
    if (t < 0.30) return 'прилагоди брзину: мораш моћи да станеш пре пруге';
    if (t < 0.46) return 'уређај за затварање саобраћаја почео је да се спушта';
    if (t < 0.74) return 'дужан си да се зауставиш испред уређаја';
    return 'забрањено: провлачење испод или поред браника';
  }

  Color get _captionFill => _forbiddenFrame
      ? colorScheme.errorContainer
      : colorScheme.secondaryContainer;

  Color get _captionInk => _forbiddenFrame
      ? colorScheme.onErrorContainer
      : colorScheme.onSecondaryContainer;

  static double _ease(double x) => Curves.easeInOut.transform(x.clamp(0, 1));

  @override
  void paint(Canvas canvas, Size size) {
    // Машина въезжает из-за кадра — без клипа она рисуется поверх соседних
    // блоков виджета.
    canvas.clipRect(Offset.zero & size);
    _drawCaption(canvas);
    _drawRoad(canvas);
    _drawCrossSign(canvas);

    if (_forbiddenFrame) _drawForbiddenCar(canvas);

    drawCarProfile(
      canvas,
      this,
      Rect.fromLTWH(_carLeft, _roadY - 46, 92, 46),
      palette: VehiclePalette(
        body: const Color(0xFF3D7BD6),
        outline: colorScheme.outline,
        glass: colorScheme.surface,
        tire: const Color(0xFF23272B),
      ),
    );

    _drawBarrier(canvas);
    _drawTerms(canvas);
  }

  /// Термины из вопросов подписаны прямо на сцене: в вариантах ответа они
  /// звучат как «уређај за затварање саобраћаја», и связать их с картинкой
  /// надо один раз.
  void _drawTerms(Canvas canvas) {
    // Выноска ведёт к стреле, а не к фонарям: подписан именно уређај.
    text(canvas, 'браник /\nполубраник', const Offset(200, 120),
        colorScheme.onSurfaceVariant,
        maxWidth: 110, fontSize: 10, isBold: true);
    dashedLine(canvas, const Offset(200, 136), const Offset(206, 150),
        color: colorScheme.outline);

    text(canvas, 'пруга', const Offset(311, 172), colorScheme.onSurfaceVariant,
        maxWidth: 70, fontSize: 10, isBold: true);
  }

  void _drawCaption(Canvas canvas) {
    const rect = Rect.fromLTRB(6, 6, 394, 40);
    panelFrame(canvas, rect, fill: _captionFill);
    text(canvas, _caption, const Offset(200, 23), _captionInk,
        maxWidth: 366, fontSize: 12, isBold: true);
  }

  void _drawRoad(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTRB(0, _roadY, 400, 240),
      Paint()..color = _asphalt,
    );

    // Насыпь со шпалами: по ней видно, что рельсы лежат в дороге, а не
    // нарисованы поверх неё.
    canvas.drawRect(
      const Rect.fromLTRB(282, _roadY, 342, 240),
      Paint()
        ..color = Color.alphaBlend(_sleeper.withValues(alpha: 0.5), _asphalt),
    );
    // Рельсы смотрят торцом: поперёк дороги они уходят от зрителя, поэтому
    // видны как две головки, выступающие над полотном.
    for (final x in [_railLeft, _railRight]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - 4, _roadY - 11, x + 4, _roadY + 3),
          const Radius.circular(2),
        ),
        Paint()..color = _railSteel,
      );
    }

    // Линия остановки — та самая «испред уређаја».
    canvas.drawRect(
      const Rect.fromLTRB(154, _roadY, 160, 222),
      Paint()..color = _marking,
    );
  }

  /// Андреевский крест (I-34) у самой пруге: без него сцена читается как
  /// обычный шлагбаум на въезде во двор.
  void _drawCrossSign(Canvas canvas) {
    const base = Offset(358, _roadY);
    canvas.drawRect(
      Rect.fromLTRB(base.dx - 2.5, 138, base.dx + 2.5, base.dy),
      Paint()..color = _railSteel,
    );
    signs.paint(canvas, 'I-34',
        Rect.fromCenter(center: const Offset(358, 128), width: 56, height: 24));
  }

  void _drawBarrier(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTRB(_hinge.dx - 5, _hinge.dy - 6, _hinge.dx + 5, _roadY),
      Paint()..color = _railSteel,
    );

    // Красные фонари начинают мигать вместе с опусканием — сигнал звучит
    // раньше, чем стрела перекроет дорогу.
    final blinkOn = ((t * 7500) ~/ 380).isEven;
    for (var i = 0; i < 2; i++) {
      final on = _lowered > 0 && (i == 0 ? blinkOn : !blinkOn);
      canvas.drawCircle(
        Offset(_hinge.dx - 12 + i * 24, _hinge.dy - 18),
        5,
        Paint()
          ..color = on ? _barrierRed : _barrierRed.withValues(alpha: 0.25),
      );
    }

    // Стрела: 0 — вертикально вверх, 1 — горизонтально влево, поперёк дороги.
    final angle = _lowered * math.pi / 2;
    final end = _hinge +
        Offset(-math.sin(angle) * _armLength, -math.cos(angle) * _armLength);
    final direction = (end - _hinge) / _armLength;
    const segments = 5;
    for (var i = 0; i < segments; i++) {
      canvas.drawLine(
        _hinge + direction * (_armLength * i / segments),
        _hinge + direction * (_armLength * (i + 1) / segments),
        Paint()
          ..color = i.isEven ? _barrierRed : _barrierWhite
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9,
      );
    }
    canvas.drawCircle(_hinge, 6, Paint()..color = _railSteel);
  }

  /// Полупрозрачная машина под опущенной стрелой: показываем именно то, что
  /// в вопросе предлагают как «правильный» ответ, и перечёркиваем.
  void _drawForbiddenCar(Canvas canvas) {
    final rect = Rect.fromLTWH(170, _roadY - 46, 92, 46);
    canvas.saveLayer(rect.inflate(12), Paint()..color = Colors.white54);
    drawCarProfile(
      canvas,
      this,
      rect,
      palette: VehiclePalette(
        body: colorScheme.surfaceContainerHighest,
        outline: colorScheme.outline,
        glass: colorScheme.surface,
        tire: const Color(0xFF23272B),
      ),
    );
    canvas.restore();
    crossOutRect(canvas, rect.deflate(4), colorScheme.error);
  }

  @override
  bool shouldRepaint(covariant _CrossingPainter old) =>
      old.t != t || old.colorScheme != colorScheme || old.signs != signs;
}

/// Памятка: что делать, если возило заглохло на путях. Статичная — это текст
/// закона, его читают, а не смотрят.
class _StalledPainter extends IllustrationPainter {
  _StalledPainter(super.colorScheme);

  @override
  void paint(Canvas canvas, Size size) {
    panelFrame(canvas, const Rect.fromLTRB(2, 2, 398, 166),
        fill: colorScheme.surfaceContainerHighest);
    text(
      canvas,
      'Ако се возило зауставило на прузи',
      const Offset(200, 20),
      colorScheme.onSurface,
      maxWidth: 370,
      fontSize: 12,
      isBold: true,
    );

    _drawStalledScene(canvas);

    calloutBox(
      canvas,
      '1. одмах уклони возило са шина',
      const Rect.fromLTRB(176, 34, 388, 70),
      fill: colorScheme.tertiaryContainer,
      textColor: colorScheme.onTertiaryContainer,
      check: true,
    );
    calloutBox(
      canvas,
      '2. ако то није могуће — упозори\nвозаче шинског возила на опасност',
      const Rect.fromLTRB(176, 76, 388, 120),
      fill: colorScheme.tertiaryContainer,
      textColor: colorScheme.onTertiaryContainer,
      check: true,
      fontSize: 10,
    );

    const footer = Rect.fromLTRB(14, 126, 386, 158);
    panelFrame(canvas, footer, fill: colorScheme.primaryContainer);
    text(
      canvas,
      'шинско возило увек има првенство пролаза',
      footer.center,
      colorScheme.onPrimaryContainer,
      maxWidth: 350,
      fontSize: 12,
      isBold: true,
    );
  }

  /// Мини-сцена слева: машина стоит на рельсах с включённой аварийкой,
  /// стрелка показывает, куда её убирать.
  void _drawStalledScene(Canvas canvas) {
    const surfaceY = 104.0;
    canvas.drawRect(
      const Rect.fromLTRB(14, surfaceY, 170, 116),
      Paint()..color = _asphalt,
    );
    for (final x in [96.0, 118.0]) {
      canvas.drawRect(
        Rect.fromLTRB(x - 3, surfaceY - 9, x + 3, surfaceY + 3),
        Paint()..color = _railSteel,
      );
    }

    final rect = Rect.fromLTWH(68, surfaceY - 32, 78, 32);
    drawCarProfile(
      canvas,
      this,
      rect,
      palette: VehiclePalette(
        body: const Color(0xFF3D7BD6),
        outline: colorScheme.outline,
        glass: colorScheme.surface,
        tire: const Color(0xFF23272B),
      ),
    );
    // Аварийка: машина стоит вынужденно, а не просто припаркована.
    for (final x in [rect.left + 4, rect.right - 4]) {
      canvas.drawCircle(
          Offset(x, rect.top + 20), 3.5, Paint()..color = _hazard);
    }

    arrow(canvas, const Offset(62, 88), const Offset(24, 88),
        color: colorScheme.tertiary, width: 3);
  }

  @override
  bool shouldRepaint(covariant _StalledPainter old) =>
      old.colorScheme != colorScheme;
}
