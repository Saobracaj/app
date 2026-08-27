import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/car_top_view.dart';
import 'package:saobracaj/test/animations/road_sign.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Разъезд на узкой дороге с уклоном: кто сдаёт назад.
///
/// Сцена снимает главную путаницу этих вопросов: люди думают, что назад
/// всегда сдаёт тот, кто едет вниз. Уклон решает **только** между ТС одного
/// вида, а между разными видами работает иерархия: назад сдаёт тот, кто
/// ниже в списке. Поэтому легковой отъезжает перед автобусом, хотя автобус
/// едет вверх.
///
/// Подписи целиком на сербском (термины из закона и билетов), переводимых
/// строк у сцены нет.
class MimoilazenjeNagib extends StatefulWidget {
  const MimoilazenjeNagib({super.key});

  @override
  State<MimoilazenjeNagib> createState() => _MimoilazenjeNagibState();
}

class _MimoilazenjeNagibState extends State<MimoilazenjeNagib>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 8 секунд: четыре фазы по 1,5–2,5 секунды плюс пауза в конце, иначе
    // сцена читается как дёрганая петля.
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
        height: 498,
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
              height: 240,
              child: RoadSignScope(
                signs: const ['I-4'],
                builder: (context, signs) => AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _NagibPainter(scheme, _controller.value, signs),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 376,
              height: 48,
              child: Text(
                'Прво важи хијерархија врста возила, а не нагиб: пред возилом '
                'са приколицом назад иде свако возило, а теретно возило иде '
                'назад пред аутобусом.',
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
                'Иста врста возила: назад иде онај који иде низ нагиб',
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
              height: 100,
              child: CustomPaint(painter: _SameKindPainter(scheme)),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 376,
              height: 34,
              child: Text(
                'Изузетак: ако је возилу које се креће уз нагиб очигледно '
                'лакше да се врати (проширење је непосредно испред њега).',
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
    if (t < 0.16) return 'Узак пут: возила не могу да се мимоиђу';
    if (t < 0.26) return 'Ко иде назад? Одлучује врста возила, а не нагиб';
    if (t < 0.50) return 'Путничко возило иде назад до проширења';
    return 'Аутобус пролази: он је више у хијерархији';
  }
}

const _asphalt = Color(0xFF424242);
const _marking = Colors.white;
const _carColor = Color(0xFF1E6FD9);
const _busColor = Color(0xFFF9A825);

// Геометрия наклонной дороги в холсте 400×240. Сцена занимает левые 250 px,
// справа — шкала-иерархия. Дорога поднимается направо: сверху справа спуск
// (низбрдица), снизу слева подъём (успон).
const _slopeAngle = -0.36;
const _slopeOrigin = Offset(4, 200);
const _roadHalf = 22.0;
const _sceneRight = 246.0;

/// Продольные координаты вдоль дороги: 0 — низ склона, 250 — верх.
const _roadFrom = -14.0;
const _roadTo = 258.0;
const _pocketFrom = 168.0;
const _pocketTo = 246.0;
const _pocketDepth = -54.0;

class _NagibPainter extends CustomPainter {
  final ColorScheme scheme;
  final double t;

  _NagibPainter(this.scheme, this.t, this.signs);

  final RoadSigns signs;

  /// Точка дорожной системы координат (s — вдоль дороги, y — поперёк,
  /// отрицательное y — в сторону проширења) в координатах холста.
  Offset _p(double s, [double y = 0]) => Offset(
    _slopeOrigin.dx + s * math.cos(_slopeAngle) - y * math.sin(_slopeAngle),
    _slopeOrigin.dy + s * math.sin(_slopeAngle) + y * math.cos(_slopeAngle),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final busS = t < 0.16
        ? _phase(t, 0, 0.16, -46, 95, Curves.easeOut)
        : (t < 0.50 ? 95.0 : _phase(t, 0.50, 0.78, 95, 208, Curves.easeInOut));
    final carS = t < 0.16
        ? _phase(t, 0, 0.16, 252, 174, Curves.easeOut)
        : (t < 0.26
              ? 174.0
              : (t < 0.46
                    ? _phase(t, 0.26, 0.46, 174, 192, Curves.easeInOut)
                    : 192.0));
    // Легковой уходит в проширење не сразу, а уже сдавая назад: сначала
    // отъезжает, потом смещается поперёк дороги.
    final carY = t < 0.30
        ? 0.0
        : (t < 0.46 ? _phase(t, 0.30, 0.46, 0, -38, Curves.easeInOut) : -38.0);
    final reversing = t >= 0.26 && t < 0.50;

    _drawRoad(canvas);
    _drawVehicles(canvas, busS: busS, carS: carS, carY: carY);
    _drawVehicleLabels(canvas, busS: busS, carS: carS, carY: carY, reversing: reversing);
    _drawSignBadge(canvas);
    _drawHierarchy(canvas);
  }

  void _drawRoad(Canvas canvas) {
    canvas.save();
    canvas.translate(_slopeOrigin.dx, _slopeOrigin.dy);
    canvas.rotate(_slopeAngle);

    // Контур асфальта вместе с карманом-проширењем: одна фигура, поэтому
    // краевая линия сама обходит карман.
    final road = Path()
      ..moveTo(_roadFrom, _roadHalf)
      ..lineTo(_roadTo, _roadHalf)
      ..lineTo(_roadTo, -_roadHalf)
      ..lineTo(_pocketTo, -_roadHalf)
      ..lineTo(_pocketTo - 8, _pocketDepth)
      ..lineTo(_pocketFrom + 12, _pocketDepth)
      ..lineTo(_pocketFrom, -_roadHalf)
      ..lineTo(_roadFrom, -_roadHalf)
      ..close();
    canvas.drawPath(road, Paint()..color = _asphalt);
    canvas.drawPath(
      road,
      Paint()
        ..color = _marking
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.restore();
  }

  void _drawVehicles(
    Canvas canvas, {
    required double busS,
    required double carS,
    required double carY,
  }) {
    canvas.save();
    canvas.translate(_slopeOrigin.dx, _slopeOrigin.dy);
    canvas.rotate(_slopeAngle);

    _paintBusTopView(
      canvas,
      Rect.fromCenter(center: Offset(busS, 0), width: 86, height: 27),
      color: _busColor,
    );
    paintCarTopView(
      canvas,
      Rect.fromCenter(center: Offset(carS, carY), width: 54, height: 22),
      color: _carColor,
      facingLeft: true,
      // Аварийка на время маневра: так видно, что легковой не просто стоит,
      // а сдаёт назад.
      lamps: (t >= 0.26 && t < 0.50) ? CarLamps.hazard : CarLamps.none,
      blinkOn: (t * 16).floor().isEven,
    );
    canvas.restore();
  }

  void _drawVehicleLabels(
    Canvas canvas, {
    required double busS,
    required double carS,
    required double carY,
    required bool reversing,
  }) {
    _pill(
      canvas,
      'аутобус\nуз нагиб',
      _p(busS, 44),
      bg: scheme.tertiaryContainer,
      fg: scheme.onTertiaryContainer,
    );
    final carLabel = reversing
        ? 'путничко возило\nиде назад'
        : (t >= 0.50
              ? 'путничко возило\nчека у проширењу'
              : 'путничко возило\nниз нагиб');
    _pill(
      canvas,
      carLabel,
      _p(carS, carY - 38),
      bg: reversing || t >= 0.50
          ? scheme.errorContainer
          : scheme.secondaryContainer,
      fg: reversing || t >= 0.50
          ? scheme.onErrorContainer
          : scheme.onSecondaryContainer,
    );
  }

  /// Знак «опасна низбрдица» вынесен в угол как значок ситуации: на самой
  /// дороге для него нет свободного места, а у обочины он налез бы на
  /// подписи участников.
  void _drawSignBadge(Canvas canvas) {
    // I-4 «опасна низбрдица».
    signs.paint(canvas, 'I-4',
        Rect.fromCenter(center: const Offset(34, 28), width: 40, height: 36));
    _text(
      canvas,
      'опасна\nнизбрдица',
      const Offset(96, 28),
      color: scheme.onSurface,
      fontSize: 11,
      weight: FontWeight.w600,
      maxWidth: 90,
    );
  }

  /// Вертикальная шкала-иерархия справа от сцены: назад сдаёт тот, кто ниже.
  void _drawHierarchy(Canvas canvas) {
    _text(
      canvas,
      'Хијерархија врста\n(ниже → иде назад)',
      const Offset(330, 22),
      color: scheme.onSurface,
      fontSize: 11.5,
      weight: FontWeight.w700,
      maxWidth: 148,
    );

    const rows = [
      ('скуп возила', false, false),
      ('аутобус — пролази', true, false),
      ('теретно возило', false, false),
      ('радна машина', false, false),
      ('трактор', false, false),
      ('путничко возило — назад', false, true),
      ('мотоцикл, мопед, трицикл, четвороцикл', false, false),
    ];

    var y = 44.0;
    for (final (label, passes, reverses) in rows) {
      final painter = _textPainter(
        label,
        color: passes
            ? scheme.onTertiaryContainer
            : (reverses ? scheme.onErrorContainer : scheme.onSecondaryContainer),
        fontSize: 11,
        weight: passes || reverses ? FontWeight.w700 : FontWeight.w500,
        maxWidth: 118,
      );
      final height = painter.height + 6;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(268, y, 130, height),
        const Radius.circular(7),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = passes
              ? scheme.tertiaryContainer
              : (reverses ? scheme.errorContainer : scheme.secondaryContainer),
      );
      painter.paint(canvas, Offset(274, y + 3));
      y += height + 2.5;
    }

    // Стрелка «вниз по списку» — смысл шкалы не должен держаться только на
    // порядке строк.
    final arrow = Paint()
      ..color = scheme.outline
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(259, 46), Offset(259, y - 6), arrow);
    canvas.drawPath(
      Path()
        ..moveTo(259, y + 1)
        ..lineTo(254, y - 8)
        ..lineTo(264, y - 8)
        ..close(),
      Paint()..color = scheme.outline,
    );
  }

  /// Подпись в «таблетке»: над асфальтом цвета темы читаются плохо, а на
  /// своей подложке — одинаково в светлой и тёмной теме. Центр прижимается к
  /// границам сцены, чтобы подпись не уехала на шкалу или за холст.
  void _pill(
    Canvas canvas,
    String text,
    Offset center, {
    required Color bg,
    required Color fg,
  }) {
    final painter = _textPainter(
      text,
      color: fg,
      fontSize: 11,
      weight: FontWeight.w600,
      maxWidth: 140,
    );
    final width = painter.width + 14;
    final height = painter.height + 7;
    final dx = center.dx.clamp(8 + width / 2, _sceneRight - width / 2);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(dx, center.dy), width: width, height: height),
      const Radius.circular(9),
    );
    canvas.drawRRect(rect, Paint()..color = bg);
    painter.paint(
      canvas,
      Offset(dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    required Color color,
    required double fontSize,
    required double maxWidth,
    FontWeight weight = FontWeight.w500,
  }) {
    final painter = _textPainter(
      text,
      color: color,
      fontSize: fontSize,
      weight: weight,
      maxWidth: maxWidth,
    );
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
  bool shouldRepaint(covariant _NagibPainter old) =>
      old.t != t || old.scheme != scheme || old.signs != signs;
}

/// Второй кадр: два одинаковых легковых. Здесь иерархия не помогает, поэтому
/// решает уклон — назад едет тот, кто спускается.
class _SameKindPainter extends CustomPainter {
  final ColorScheme scheme;

  _SameKindPainter(this.scheme);

  static const _angle = -0.20;
  static const _origin = Offset(12, 82);
  static const _half = 17.0;

  Offset _p(double s, [double y = 0]) => Offset(
    _origin.dx + s * math.cos(_angle) - y * math.sin(_angle),
    _origin.dy + s * math.sin(_angle) + y * math.cos(_angle),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(_origin.dx, _origin.dy);
    canvas.rotate(_angle);

    final road = Rect.fromLTRB(-12, -_half, 300, _half);
    canvas.drawRect(road, Paint()..color = _asphalt);
    final edge = Paint()
      ..color = _marking
      ..strokeWidth = 2.2;
    canvas.drawLine(Offset(-12, -_half + 3), Offset(300, -_half + 3), edge);
    canvas.drawLine(Offset(-12, _half - 3), Offset(300, _half - 3), edge);

    // Оба ТС одного вида — одинаковый цвет и размер, иначе зритель начнёт
    // искать разницу в машинах, а разница только в направлении.
    paintCarTopView(
      canvas,
      Rect.fromCenter(center: const Offset(195, 0), width: 56, height: 22),
      color: _carColor,
      facingLeft: true,
    );
    paintCarTopView(
      canvas,
      Rect.fromCenter(center: const Offset(80, 0), width: 56, height: 22),
      color: _carColor,
    );
    canvas.restore();

    _pill(
      canvas,
      'низ нагиб → назад',
      _p(195, -32),
      bg: scheme.errorContainer,
      fg: scheme.onErrorContainer,
    );
    _pill(
      canvas,
      'уз нагиб → пролази',
      _p(80, 26),
      bg: scheme.tertiaryContainer,
      fg: scheme.onTertiaryContainer,
    );
  }

  void _pill(
    Canvas canvas,
    String text,
    Offset center, {
    required Color bg,
    required Color fg,
  }) {
    final painter = _textPainter(
      text,
      color: fg,
      fontSize: 11,
      weight: FontWeight.w600,
      maxWidth: 160,
    );
    final width = painter.width + 14;
    final height = painter.height + 7;
    final dx = center.dx.clamp(4 + width / 2, 396 - width / 2);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(dx, center.dy), width: width, height: height),
      const Radius.circular(9),
    );
    canvas.drawRRect(rect, Paint()..color = bg);
    painter.paint(
      canvas,
      Offset(dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SameKindPainter old) => old.scheme != scheme;
}

TextPainter _textPainter(
  String text, {
  required Color color,
  required double fontSize,
  required double maxWidth,
  FontWeight weight = FontWeight.w500,
}) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        height: 1.25,
        fontFamily: kAppFontFamily,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
}

/// Автобус видом сверху. Отдельная функция, а не примитив на весь проект:
/// сцене нужен только силуэт «длинный, боксообразный, с рядом окон», по
/// которому автобус отличается от легкового с первого взгляда.
void _paintBusTopView(
  Canvas canvas,
  Rect rect, {
  required Color color,
  bool facingLeft = false,
}) {
  canvas.save();
  if (facingLeft) {
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(-1, 1);
    canvas.translate(-rect.center.dx, -rect.center.dy);
  }

  final w = rect.width;
  final h = rect.height;
  final body = RRect.fromRectAndRadius(rect, Radius.circular(h * 0.16));
  canvas.drawRRect(body, Paint()..color = color);
  canvas.drawRRect(
    body,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.05,
  );

  final glass = Paint()..color = Colors.black.withValues(alpha: 0.45);
  // Крыша светлее кузова — по ней автобус читается объёмным.
  canvas.drawRect(
    Rect.fromLTWH(rect.left + w * 0.10, rect.top + h * 0.18, w * 0.78, h * 0.64),
    Paint()..color = Colors.white.withValues(alpha: 0.14),
  );
  // Лобовое и заднее стекло.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.right - w * 0.09, rect.top + h * 0.10, w * 0.05, h * 0.80),
      Radius.circular(h * 0.08),
    ),
    glass,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left + w * 0.04, rect.top + h * 0.14, w * 0.04, h * 0.72),
      Radius.circular(h * 0.08),
    ),
    glass,
  );
  // Ряды боковых окон.
  for (final top in [h * 0.06, h * 0.82]) {
    canvas.drawRect(
      Rect.fromLTWH(rect.left + w * 0.16, rect.top + top, w * 0.64, h * 0.12),
      glass,
    );
  }
  // Фары спереди, фонари сзади: по ним видно, куда автобус смотрит.
  for (final dy in [0.16, 0.68]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.right - w * 0.035, rect.top + h * dy, w * 0.025, h * 0.16),
        Radius.circular(h * 0.05),
      ),
      Paint()..color = const Color(0xFFFFF3B0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + w * 0.012, rect.top + h * dy, w * 0.025, h * 0.16),
        Radius.circular(h * 0.05),
      ),
      Paint()..color = const Color(0xFFD32F2F),
    );
  }

  canvas.restore();
}
