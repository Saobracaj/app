// Полосность автострады: где ехать, где обгонять, где останавливаться и как
// въезжать/съезжать. Одна машина проходит весь путь по фазам, подпись сверху
// меняется вместе с фазой — стоп-кадр любой фазы читается сам по себе.
//
// Дорога (полосы, съезды, разметка) — общая с posebne_trake_autoput.dart,
// см. autoput_road.dart: обе картинки объясняют одни и те же полосы.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/autoput_road.dart';
import 'package:saobracaj/test/animations/interactive_animation.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Ширина холста: всё рисуется в этих координатах и целиком масштабируется.
const double _w = kAutoputRoadWidth;
const double _h = 262;

const double _carLength = 42;
const double _carWidth = 20;

class AutoputTrake extends StatelessWidget {
  const AutoputTrake({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      // 8 секунд на четыре фазы плюс пауза в конце: быстрее не успеть прочитать
      // подпись, медленнее — не дождаться второго круга.
      child: InteractiveAnimation(
        cycle: const Duration(seconds: 8),
        // Границы фаз — из _AutoputTrakePainter._phase.
        stepStarts: const [0, _tMergeEnd, _tRightEnd, _tReturnEnd],
        builder: (context, animation) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _w,
            height: _h,
            child: AnimatedBuilder(
              animation: animation,
              builder: (_, _) => CustomPaint(
                painter: _AutoputTrakePainter(
                  scheme: scheme,
                  progress: animation.value,
                ),
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

/// Хронометраж цикла (доли от 0 до 1). Границы подобраны так, чтобы наша
/// машина ни в одной фазе не наезжала на медленную: перед выездом на левую
/// полосу она ещё позади неё, при возврате — уже впереди с запасом.
const double _tRampInEnd = 0.18; // конец полосы для включения
const double _tMergeEnd = 0.25; // перестроились в правую полосу
const double _tRightEnd = 0.36; // подъехали к медленной машине
const double _tPullOutEnd = 0.43; // вышли на левую полосу
const double _tLeftEnd = 0.53; // прошли медленную
const double _tReturnEnd = 0.60; // вернулись в правую полосу
const double _tExitLaneEnd = 0.68; // перешли на полосу для исключения
const double _tRampOutEnd = 0.92; // уехали по съезду; дальше пауза

/// Ключевые x нашей машины на прямых участках.
const double _xMergeEnd = 142;
const double _xRightEnd = 177;
const double _xPullOutEnd = 211;
const double _xLeftEnd = 260;
const double _xReturnEnd = 295;

/// Точка съезда, в которой мы встаём на его ось после перестроения:
/// чуть дальше начала, где съезд ещё почти горизонтален.
const double _tRampOutJoin = 0.08;

class _AutoputTrakePainter extends CustomPainter {
  _AutoputTrakePainter({required this.scheme, required this.progress});

  final ColorScheme scheme;
  final double progress;

  static final AutoputRoad _road = AutoputRoad(top: 40);

  @override
  void paint(Canvas canvas, Size size) {
    // Съезды начинаются и заканчиваются за краем холста — обрезаем, чтобы
    // асфальт не вылезал за картинку.
    canvas.clipRect(Offset.zero & size);
    _road.paint(canvas);
    _drawLabels(canvas);
    _drawStoppedCar(canvas);
    _drawSlowCar(canvas);
    _drawMovingCar(canvas);
    _drawCaption(canvas);
  }

  // --- подписи ------------------------------------------------------------

  void _drawLabels(Canvas canvas) {
    // Подписи полос стоят в начале дороги: машины туда не заезжают, поэтому
    // ничего не перекрывают ни в одном кадре.
    drawSchemeChip(
      canvas,
      'лева трака\n(само претицање)',
      Offset(4, _road.yLeftLane),
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
      Offset(4, _road.yRightLane),
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
      const Offset(200, 178),
      scheme.errorContainer,
      scheme.onErrorContainer,
      maxWidth: 170,
      bold: true,
    );
    drawSchemeArrow(
      canvas,
      const Offset(215, 162),
      Offset(215, _road.bandBottom + 3),
      scheme.onSurface,
    );

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
    // Стрелки упираются в нижнюю кромку съездов.
    drawSchemeArrow(
      canvas,
      const Offset(60, 210),
      _road.rampIn.offsetAt(0.45, kAutoputAuxWidth / 2 + 3),
      scheme.onSurface,
    );
    drawSchemeArrow(
      canvas,
      const Offset(348, 210),
      _road.rampOut.offsetAt(0.55, kAutoputAuxWidth / 2 + 3),
      scheme.onSurface,
    );
  }

  // --- участники ----------------------------------------------------------

  /// Сломавшаяся машина: стоит на остановочной полосе с аварийкой.
  void _drawStoppedCar(Canvas canvas) {
    final blink = (progress * 16).floor().isEven;
    drawSchematicCarTopView(
      canvas,
      Rect.fromCenter(
        center: Offset(215, _road.yShoulder),
        width: _carLength,
        height: _carWidth,
      ),
      kCarRed,
      hazardOn: true,
      blinkOn: blink,
    );
  }

  /// Медленная машина в правой полосе — то, что мы обгоняем. Ползёт чуть
  /// вперёд, чтобы не выглядеть припаркованной, но так медленно, что за цикл
  /// почти не смещается — иначе не хватило бы дороги её объехать.
  double get _slowCarX => 234 + progress * 5;

  void _drawSlowCar(Canvas canvas) {
    drawSchematicCarTopView(
      canvas,
      Rect.fromCenter(
        center: Offset(_slowCarX, _road.yRightLane),
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
    drawSchematicCarTopView(
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
    final yRight = _road.yRightLane;
    final yLeft = _road.yLeftLane;
    final yAux = _road.yShoulder;

    if (t < _tRampInEnd) {
      // По полосе для включения — по кривой, машина повёрнута вдоль неё.
      final tc = _road.rampIn.tAtFraction(t / _tRampInEnd);
      return (_road.rampIn.pointAt(tc), _road.rampIn.angleAt(tc));
    }
    if (t < _tMergeEnd) {
      // Перестроение с полосы для включения в правую полосу.
      return _laneChange(
        Offset(AutoputRoad.rampInEnd, yAux),
        Offset(_xMergeEnd, yRight),
        _unit(t, _tRampInEnd, _tMergeEnd),
      );
    }
    if (t < _tRightEnd) {
      return (
        Offset(
          _lerp(_xMergeEnd, _xRightEnd, _unit(t, _tMergeEnd, _tRightEnd)),
          yRight,
        ),
        0,
      );
    }
    if (t < _tPullOutEnd) {
      // Выезд на левую полосу — только для обгона.
      return _laneChange(
        Offset(_xRightEnd, yRight),
        Offset(_xPullOutEnd, yLeft),
        _unit(t, _tRightEnd, _tPullOutEnd),
      );
    }
    if (t < _tLeftEnd) {
      return (
        Offset(
          _lerp(_xPullOutEnd, _xLeftEnd, _unit(t, _tPullOutEnd, _tLeftEnd)),
          yLeft,
        ),
        0,
      );
    }
    if (t < _tReturnEnd) {
      // Возврат в правую полосу: левая занимается только на время обгона.
      return _laneChange(
        Offset(_xLeftEnd, yLeft),
        Offset(_xReturnEnd, yRight),
        _unit(t, _tLeftEnd, _tReturnEnd),
      );
    }
    final rampOut = _road.rampOut;
    if (t < _tExitLaneEnd) {
      // Переход на полосу для исключения: в конце манёвра машина уже стоит
      // вдоль оси съезда, чтобы дальше ехать по нему без рывка.
      return _laneChange(
        Offset(_xReturnEnd, yRight),
        rampOut.pointAt(_tRampOutJoin),
        _unit(t, _tReturnEnd, _tExitLaneEnd),
        endAngle: rampOut.angleAt(_tRampOutJoin),
      );
    }
    if (t < _tRampOutEnd) {
      // Съезд по полосе для исключения.
      final from = rampOut.fractionAt(_tRampOutJoin);
      final s = _lerp(from, 1, _unit(t, _tExitLaneEnd, _tRampOutEnd));
      final tc = rampOut.tAtFraction(s);
      return (rampOut.pointAt(tc), rampOut.angleAt(tc));
    }
    // Пауза в конце цикла: без неё петля выглядит дёрганой.
    return (rampOut.pointAt(1), rampOut.angleAt(1));
  }

  _Phase get _phase {
    if (progress < _tMergeEnd) return _Phase.ukljucivanje;
    if (progress < _tRightEnd) return _Phase.desnaTraka;
    if (progress < _tReturnEnd) return _Phase.preticanje;
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

  /// Доля пройденного отрезка [from, to] для момента t.
  static double _unit(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  /// Перестроение по прямой из [from] в [to]: в середине манёвра машина
  /// наклонена сильнее всего, в начале стоит ровно, в конце — под [endAngle]
  /// (обычно 0, вдоль полосы).
  static (Offset, double) _laneChange(
    Offset from,
    Offset to,
    double s, {
    double endAngle = 0,
  }) {
    final delta = to - from;
    // 0.55 — иначе на коротком перестроении машина встаёт почти поперёк
    // полосы, чего в жизни не бывает.
    final tilt = math.atan2(delta.dy, delta.dx) * math.sin(s * math.pi) * 0.55;
    return (from + delta * s, tilt * (1 - s) + endAngle * s);
  }

  @override
  bool shouldRepaint(covariant _AutoputTrakePainter old) =>
      old.progress != progress || old.scheme != scheme;
}
