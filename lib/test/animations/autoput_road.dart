// Общий участок аутопута для схем про полосы: две ходовые полосы, полоса
// для включения слева, зауставна трака посередине и полоса для исключения
// справа. Одна геометрия на все картинки — дорога должна выглядеть одинаково
// в autoput_trake.dart и posebne_trake_autoput.dart.
//
// Как устроены съезды: полоса для включения подходит снизу слева и вливается
// в коловоз *по касательной* — так, как это выглядит на настоящем узле, а не
// упирается в него под углом. Между съездом и краем коловоза остаётся
// «нос» (разделительный островок), после носа край коловоза становится
// прерывистым — это и есть полоса для включения; дальше линия снова сплошная
// (зауставна трака), потом снова прерывистая (полоса для исключения), и
// съезд так же плавно уходит вниз направо.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Ширина холста, на который рассчитана геометрия дороги.
const double kAutoputRoadWidth = 400;

/// Ширина ходовой полосы и вспомогательной (зауставна/включение/исключение).
const double kAutoputLaneWidth = 36;
const double kAutoputAuxWidth = 30;

/// Границы участков вспомогательной полосы по x: где кончается прерывистая
/// разметка полосы для включения, где начинается полоса для исключения.
const double kAutoputAccelLaneEnd = 165;
const double kAutoputDecelLaneStart = 262;

/// Кубическая кривая Безье с выборкой по длине дуги: машина по съезду должна
/// ехать с постоянной скоростью, а параметр t у Безье неравномерный.
class CubicCurve {
  CubicCurve(this.p0, this.p1, this.p2, this.p3) {
    var length = 0.0;
    var previous = p0;
    _lengths[0] = 0;
    for (var i = 1; i <= _samples; i++) {
      final point = pointAt(i / _samples);
      length += (point - previous).distance;
      _lengths[i] = length;
      previous = point;
    }
  }

  final Offset p0;
  final Offset p1;
  final Offset p2;
  final Offset p3;

  static const int _samples = 64;
  final List<double> _lengths = List.filled(_samples + 1, 0);

  double get length => _lengths[_samples];

  Offset pointAt(double t) {
    final u = 1 - t;
    return Offset(
      u * u * u * p0.dx +
          3 * u * u * t * p1.dx +
          3 * u * t * t * p2.dx +
          t * t * t * p3.dx,
      u * u * u * p0.dy +
          3 * u * u * t * p1.dy +
          3 * u * t * t * p2.dy +
          t * t * t * p3.dy,
    );
  }

  /// Направление движения по кривой в точке t.
  Offset tangentAt(double t) {
    final u = 1 - t;
    final d = Offset(
      3 * u * u * (p1.dx - p0.dx) +
          6 * u * t * (p2.dx - p1.dx) +
          3 * t * t * (p3.dx - p2.dx),
      3 * u * u * (p1.dy - p0.dy) +
          6 * u * t * (p2.dy - p1.dy) +
          3 * t * t * (p3.dy - p2.dy),
    );
    return d / d.distance;
  }

  double angleAt(double t) {
    final d = tangentAt(t);
    return math.atan2(d.dy, d.dx);
  }

  /// Точка на кривой, сдвинутая на [offset] по нормали: положительный сдвиг —
  /// вправо по ходу движения (в экранных координатах — «ниже» кривой,
  /// идущей слева направо).
  Offset offsetAt(double t, double offset) {
    final d = tangentAt(t);
    return pointAt(t) + Offset(-d.dy, d.dx) * offset;
  }

  /// Параметр t для доли пройденного пути [s] ∈ [0, 1] (по длине дуги).
  double tAtFraction(double s) {
    final target = s.clamp(0.0, 1.0) * length;
    var low = 0;
    var high = _samples;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_lengths[mid] < target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low == 0) return 0;
    final before = _lengths[low - 1];
    final after = _lengths[low];
    final k = after == before ? 0.0 : (target - before) / (after - before);
    return (low - 1 + k) / _samples;
  }

  /// Обратное к [tAtFraction]: какая доля длины пройдена к параметру t.
  double fractionAt(double t) {
    final position = t.clamp(0.0, 1.0) * _samples;
    final index = position.floor().clamp(0, _samples - 1);
    final k = position - index;
    final at = _lengths[index] + (_lengths[index + 1] - _lengths[index]) * k;
    return at / length;
  }

  /// Полоса шириной 2·[halfWidth] вокруг кривой — замкнутый контур для
  /// заливки асфальтом.
  Path bandPath(double halfWidth) {
    const steps = 32;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final point = offsetAt(i / steps, -halfWidth);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    for (var i = steps; i >= 0; i--) {
      final point = offsetAt(i / steps, halfWidth);
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  /// Ломаная вдоль кривой со сдвигом по нормали — так рисуются края съезда
  /// (у сдвинутой Безье нет точной формулы, ломаной из 32 точек хватает).
  Path offsetPath(double offset, {double from = 0, double to = 1}) {
    const steps = 32;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = from + (to - from) * i / steps;
      final point = offsetAt(t, offset);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }
}

/// Геометрия участка аутопута: всё считается от верхнего края коловоза [top].
class AutoputRoad {
  AutoputRoad({required this.top})
    : rampIn = CubicCurve(
        Offset(-26, top + 172),
        Offset(40, top + 168),
        Offset(60, top + 87),
        Offset(rampInEnd, top + 87),
      ),
      rampOut = CubicCurve(
        Offset(rampOutStart, top + 87),
        Offset(360, top + 87),
        Offset(378, top + 122),
        Offset(420, top + 196),
      );

  final double top;

  /// Осевые линии съездов (по ним едет машина). Оба заканчиваются/начинаются
  /// горизонтально — на уровне вспомогательной полосы.
  final CubicCurve rampIn;
  final CubicCurve rampOut;

  /// Где полоса для включения полностью влилась в коловоз и где полоса для
  /// исключения начинает уходить в сторону.
  static const double rampInEnd = 110;
  static const double rampOutStart = 322;

  /// «Носы» — точки, где край съезда сходится с краем коловоза. До носа край
  /// коловоза сплошной, после — прерывистый.
  static const double _noseIn = 112;
  static const double _noseOut = 336;

  /// Насколько краевая линия утоплена внутрь асфальта (половина её ширины).
  static const double _edgeInset = 1.25;

  double get laneDivider => top + kAutoputLaneWidth;
  double get bandTop => top + 2 * kAutoputLaneWidth;
  double get bandBottom => bandTop + kAutoputAuxWidth;

  /// Оси полос.
  double get yLeftLane => top + kAutoputLaneWidth / 2;
  double get yRightLane => top + kAutoputLaneWidth * 1.5;
  double get yShoulder => bandTop + kAutoputAuxWidth / 2;

  /// Асфальт и разметка. Порядок: съезды → вспомогательная полоса → коловоз,
  /// чтобы ничего не вылезало поверх соседа, потом линии.
  void paint(Canvas canvas) {
    _drawSurface(canvas);
    _drawMarkings(canvas);
  }

  void _drawSurface(Canvas canvas) {
    final aux = Paint()..color = kAsphaltShoulder;
    const half = kAutoputAuxWidth / 2;
    for (final ramp in [rampIn, rampOut]) {
      canvas.drawPath(ramp.bandPath(half), aux);
    }
    // Прямой участок чуть заходит на концы съездов (там они уже
    // горизонтальны), иначе на стыке остаётся волосяной шов от сглаживания.
    canvas.drawRect(
      Rect.fromLTRB(rampInEnd - 4, bandTop, rampOutStart + 4, bandBottom),
      aux,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, top, kAutoputRoadWidth, bandTop),
      Paint()..color = kAsphalt,
    );
  }

  void _drawMarkings(Canvas canvas) {
    final solid = Paint()
      ..color = kLineWhite
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    // Краевые линии лежат целиком на асфальте: на светлой теме белая линия
    // ровно по кромке сливается с фоном и её не видно.
    const half = kAutoputAuxWidth / 2 - _edgeInset;

    // Верхний край коловоза и прерывистая между ходовыми полосами.
    canvas.drawLine(
      Offset(0, top + _edgeInset),
      Offset(kAutoputRoadWidth, top + _edgeInset),
      solid,
    );
    drawDashedLine(
      canvas,
      Offset(0, laneDivider),
      Offset(kAutoputRoadWidth, laneDivider),
      kLineWhite,
      strokeWidth: 2.5,
    );

    // Правый край коловоза: сплошной до носа съезда, прерывистый вдоль полос
    // для включения/исключения (там перестраиваются), сплошной вдоль
    // зауставной траке (на неё просто так заезжать нельзя).
    final y = bandTop;
    canvas.drawLine(Offset(0, y), Offset(_noseIn, y), solid);
    drawDashedLine(
      canvas,
      Offset(_noseIn, y),
      Offset(kAutoputAccelLaneEnd, y),
      kLineWhite,
      strokeWidth: 2.5,
    );
    canvas.drawLine(
      Offset(kAutoputAccelLaneEnd, y),
      Offset(kAutoputDecelLaneStart, y),
      solid,
    );
    drawDashedLine(
      canvas,
      Offset(kAutoputDecelLaneStart, y),
      Offset(_noseOut, y),
      kLineWhite,
      strokeWidth: 2.5,
    );
    canvas.drawLine(Offset(_noseOut, y), Offset(kAutoputRoadWidth, y), solid);

    // Внешний край: нижняя кромка съезда для включения → низ вспомогательной
    // полосы → нижняя кромка съезда для исключения, одной линией.
    final outer = rampIn.offsetPath(half)
      ..lineTo(rampOutStart, bandBottom - _edgeInset)
      ..addPath(rampOut.offsetPath(half), Offset.zero);
    canvas.drawPath(outer, solid);

    // Внутренние кромки съездов — до носа, где они сходятся с краем коловоза.
    canvas.drawPath(rampIn.offsetPath(-half, to: 0.9), solid);
    canvas.drawPath(rampOut.offsetPath(-half, from: 0.12), solid);
  }
}
