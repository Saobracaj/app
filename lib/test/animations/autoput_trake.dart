// Полосность автострады: где ехать, где обгонять, где останавливаться и как
// въезжать/съезжать. Одна машина проходит весь путь по фазам, подпись сверху
// меняется вместе с фазой — стоп-кадр любой фазы читается сам по себе.
//
// Геометрия дороги (полосы, порядок полос, положение съездов) намеренно та же,
// что в posebne_trake_autoput.dart: обе картинки объясняют одни и те же полосы.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Ширина холста: всё рисуется в этих координатах и целиком масштабируется.
const double _w = 400;
const double _h = 262;

/// Оси полос по вертикали.
const double _yLeftLane = 58; // лева трака — за претицање
const double _yRightLane = 94; // десна трака — обычная езда
const double _yShoulder = 127; // зауставна трака / съезды

/// Кривая полосы для въезда: снизу слева до края коловоза.
const Offset _rampInStart = Offset(-14, 188);
const Offset _rampInControl = Offset(60, 182);
const Offset _rampInEnd = Offset(140, _yShoulder);

/// Кривая полосы для съезда: отделяется от коловоза и уводит вниз направо.
const Offset _rampOutStart = Offset(296, _yShoulder);
const Offset _rampOutControl = Offset(360, 142);
const Offset _rampOutEnd = Offset(416, 192);

/// Траектория съезда для машины: из правой полосы через остановочную на
/// полосу торможения.
const Offset _exitStart = Offset(300, _yRightLane);
const Offset _exitControl = Offset(360, 130);
const Offset _exitEnd = Offset(416, 190);

const double _carLength = 42;
const double _carWidth = 20;

class AutoputTrake extends StatefulWidget {
  const AutoputTrake({super.key});

  @override
  State<AutoputTrake> createState() => _AutoputTrakeState();
}

class _AutoputTrakeState extends State<AutoputTrake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 8 секунд на четыре фазы плюс пауза в конце: быстрее не успеть прочитать
    // подпись, медленнее — не дождаться второго круга.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
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
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _w,
          height: _h,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => CustomPaint(
              painter: _AutoputTrakePainter(
                scheme: scheme,
                progress: _controller.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Фаза сцены: подпись сверху плюс положение машины.
enum _Phase {
  ukljucivanje('1. Укључујем се преко траке за укључивање'),
  desnaTraka('2. Возим крајњом десном траком'),
  preticanje('3. Претичем — лева трака служи само за претицање'),
  iskljucivanje('4. Искључујем се преко траке за искључивање');

  const _Phase(this.caption);

  final String caption;
}

class _AutoputTrakePainter extends CustomPainter {
  _AutoputTrakePainter({required this.scheme, required this.progress});

  final ColorScheme scheme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Съезды начинаются и заканчиваются за краем холста — обрезаем, чтобы
    // асфальт не вылезал за картинку.
    canvas.clipRect(Offset.zero & size);
    _drawRoadSurface(canvas);
    _drawRamps(canvas);
    _drawMarkings(canvas);
    _drawLaneLabels(canvas);
    _drawStoppedCar(canvas);
    _drawSlowCar(canvas);
    _drawMovingCar(canvas);
    _drawCaption(canvas);
  }

  // --- дорога -------------------------------------------------------------

  void _drawRoadSurface(Canvas canvas) {
    // Ходовые полосы и остановочная — разным тоном асфальта: остановочная
    // отличается от ходовых даже до того, как прочитана подпись.
    canvas.drawRect(
      const Rect.fromLTRB(0, 40, _w, _yShoulder - 15),
      Paint()..color = kAsphalt,
    );
    canvas.drawRect(
      const Rect.fromLTRB(0, _yShoulder - 15, _w, _yShoulder + 15),
      Paint()..color = kAsphaltShoulder,
    );
  }

  void _drawMarkings(Canvas canvas) {
    final solid = Paint()
      ..color = kLineWhite
      ..strokeWidth = 2.5;
    // Внешние края коловоза. Нижний край рисуется только между съездами —
    // там, где съезд примыкает, края у коловоза нет.
    canvas.drawLine(const Offset(0, 40), const Offset(_w, 40), solid);
    canvas.drawLine(
      const Offset(150, _yShoulder + 15),
      const Offset(292, _yShoulder + 15),
      solid,
    );
    // Прерывистая между ходовыми полосами — её пересекать можно.
    drawDashedLine(
      canvas,
      const Offset(0, 76),
      const Offset(_w, 76),
      kLineWhite,
      strokeWidth: 2.5,
    );
    // Сплошная перед остановочной полосой: заезжать на неё просто так нельзя.
    // На длине полос разгона и торможения она прерывистая — там перестроение
    // как раз и происходит.
    drawDashedLine(
      canvas,
      const Offset(0, _yShoulder - 15),
      const Offset(150, _yShoulder - 15),
      kLineWhite,
      strokeWidth: 2.5,
    );
    canvas.drawLine(
      const Offset(150, _yShoulder - 15),
      const Offset(285, _yShoulder - 15),
      solid,
    );
    drawDashedLine(
      canvas,
      const Offset(285, _yShoulder - 15),
      const Offset(_w, _yShoulder - 15),
      kLineWhite,
      strokeWidth: 2.5,
    );
  }

  void _drawRamps(Canvas canvas) {
    for (final ramp in [
      (_rampInStart, _rampInControl, _rampInEnd),
      (_rampOutStart, _rampOutControl, _rampOutEnd),
    ]) {
      final path = Path()
        ..moveTo(ramp.$1.dx, ramp.$1.dy)
        ..quadraticBezierTo(
          ramp.$2.dx,
          ramp.$2.dy,
          ramp.$3.dx,
          ramp.$3.dy,
        );
      // Белая подложка чуть шире асфальта — так у съезда появляются края
      // разметки, и он не сливается с остановочной полосой.
      canvas.drawPath(
        path,
        Paint()
          ..color = kLineWhite
          ..strokeWidth = 34
          ..style = PaintingStyle.stroke,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = kAsphaltShoulder
          ..strokeWidth = 30
          ..style = PaintingStyle.stroke,
      );
    }

    drawSchemeChip(
      canvas,
      'трака за укључивање',
      const Offset(4, 228),
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
      align: const Alignment(-1, 0),
      maxWidth: 120,
      bold: true,
    );
    drawSchemeChip(
      canvas,
      'трака за искључивање',
      const Offset(_w - 4, 228),
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
      align: const Alignment(1, 0),
      maxWidth: 120,
      bold: true,
    );
    drawSchemeArrow(
      canvas,
      const Offset(66, 212),
      const Offset(84, 190),
      scheme.onSurface,
    );
    drawSchemeArrow(
      canvas,
      const Offset(330, 212),
      const Offset(350, 190),
      scheme.onSurface,
    );
  }

  void _drawLaneLabels(Canvas canvas) {
    // Подписи полос стоят в начале дороги: машины туда не заезжают, поэтому
    // ничего не перекрывают ни в одном кадре.
    drawSchemeChip(
      canvas,
      'лева трака\n(само претицање)',
      const Offset(4, _yLeftLane),
      scheme.surface,
      scheme.onSurface,
      align: const Alignment(-1, 0),
      maxWidth: 110,
      fontSize: 10,
      bold: true,
    );
    drawSchemeChip(
      canvas,
      'десна трака\n(вожња)',
      const Offset(4, _yRightLane),
      scheme.surface,
      scheme.onSurface,
      align: const Alignment(-1, 0),
      maxWidth: 110,
      fontSize: 10,
      bold: true,
    );
    drawSchemeChip(
      canvas,
      'зауставна трака —\nсамо за принудно заустављање',
      const Offset(196, 178),
      scheme.errorContainer,
      scheme.onErrorContainer,
      maxWidth: 170,
      bold: true,
    );
    drawSchemeArrow(
      canvas,
      const Offset(215, 162),
      const Offset(215, 145),
      scheme.onSurface,
    );
  }

  // --- участники ----------------------------------------------------------

  /// Сломавшаяся машина: стоит на остановочной полосе с аварийкой.
  void _drawStoppedCar(Canvas canvas) {
    final blink = (progress * 16).floor().isEven;
    drawCarTopView(
      canvas,
      Rect.fromCenter(
        center: const Offset(215, _yShoulder),
        width: _carLength,
        height: _carWidth,
      ),
      kCarRed,
      hazardOn: true,
      blinkOn: blink,
    );
  }

  /// Медленная машина в правой полосе — то, что мы обгоняем.
  void _drawSlowCar(Canvas canvas) {
    // Едет медленнее нашей: к началу обгона она впереди, к концу — позади.
    final x = 200 + progress * 55;
    drawCarTopView(
      canvas,
      Rect.fromCenter(
        center: Offset(x, _yRightLane),
        width: _carLength,
        height: _carWidth,
      ),
      kCarGreen,
    );
  }

  void _drawMovingCar(Canvas canvas) {
    final (center, angle) = _carPose();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    drawCarTopView(
      canvas,
      Rect.fromCenter(
        center: Offset.zero,
        width: _carLength,
        height: _carWidth,
      ),
      kCarBlue,
    );
    canvas.restore();
  }

  /// Положение и поворот нашей машины по фазам.
  (Offset, double) _carPose() {
    final t = progress;
    if (t < 0.20) {
      // Разгон по полосе включения — едем по кривой, машина повёрнута по ней.
      final s = t / 0.20;
      return (
        _quad(_rampInStart, _rampInControl, _rampInEnd, s),
        _quadAngle(_rampInStart, _rampInControl, _rampInEnd, s),
      );
    }
    if (t < 0.28) {
      // Перестроение с полосы включения в правую полосу.
      final s = (t - 0.20) / 0.08;
      return (
        Offset(_lerp(140, 180, s), _lerp(_yShoulder, _yRightLane, s)),
        _slopeAngle(180 - 140, _yRightLane - _yShoulder, s),
      );
    }
    if (t < 0.36) {
      final s = (t - 0.28) / 0.08;
      return (Offset(_lerp(180, 205, s), _yRightLane), 0);
    }
    if (t < 0.44) {
      // Выезд на левую полосу — только для обгона.
      final s = (t - 0.36) / 0.08;
      return (
        Offset(_lerp(205, 235, s), _lerp(_yRightLane, _yLeftLane, s)),
        _slopeAngle(235 - 205, _yLeftLane - _yRightLane, s),
      );
    }
    if (t < 0.54) {
      final s = (t - 0.44) / 0.10;
      return (Offset(_lerp(235, 275, s), _yLeftLane), 0);
    }
    if (t < 0.62) {
      // Возврат в правую полосу: левая занимается только на время обгона.
      final s = (t - 0.54) / 0.08;
      return (
        Offset(_lerp(275, 305, s), _lerp(_yLeftLane, _yRightLane, s)),
        _slopeAngle(305 - 275, _yRightLane - _yLeftLane, s),
      );
    }
    if (t < 0.85) {
      // Съезд по полосе торможения.
      final s = (t - 0.62) / 0.23;
      return (
        _quad(_exitStart, _exitControl, _exitEnd, s),
        _quadAngle(_exitStart, _exitControl, _exitEnd, s),
      );
    }
    // Пауза в конце цикла: без неё петля выглядит дёрганой.
    return (_exitEnd, _quadAngle(_exitStart, _exitControl, _exitEnd, 1));
  }

  _Phase get _phase {
    if (progress < 0.20) return _Phase.ukljucivanje;
    if (progress < 0.36) return _Phase.desnaTraka;
    if (progress < 0.62) return _Phase.preticanje;
    return _Phase.iskljucivanje;
  }

  void _drawCaption(Canvas canvas) {
    drawSchemeChip(
      canvas,
      _phase.caption,
      const Offset(_w / 2, 16),
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
      fontSize: 13,
      bold: true,
      maxWidth: 360,
    );
    drawSchemeText(
      canvas,
      'смер вожње →',
      const Offset(_w / 2, 252),
      scheme.onSurface,
      align: const Alignment(0, 1),
      maxWidth: 120,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static Offset _quad(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

  static double _quadAngle(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    final dx = 2 * u * (p1.dx - p0.dx) + 2 * t * (p2.dx - p1.dx);
    final dy = 2 * u * (p1.dy - p0.dy) + 2 * t * (p2.dy - p1.dy);
    return math.atan2(dy, dx);
  }

  /// Наклон машины при перестроении: в середине манёвра он максимальный,
  /// в начале и в конце машина стоит ровно вдоль полосы.
  static double _slopeAngle(double dx, double dy, double s) {
    // 0.55 — иначе на коротком перестроении машина встаёт почти поперёк
    // полосы, чего в жизни не бывает.
    final k = math.sin(s * math.pi);
    return math.atan2(dy, dx) * k * 0.55;
  }

  @override
  bool shouldRepaint(covariant _AutoputTrakePainter old) =>
      old.progress != progress || old.scheme != scheme;
}
