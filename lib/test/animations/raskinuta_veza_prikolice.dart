import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/prikolica_common.dart';

/// Обрыв сцепки: страховочные цепи не дают дышлу упасть на дорогу.
///
/// Вопрос №8706 спрашивает, зачем лёгкому прицепу (*до 1.500 kg*, без тормоза,
/// срабатывающего автоматически при обрыве) *додатна веза* — цепь или стальной
/// трос. Словами это звучит абстрактно, поэтому здесь показано само событие:
/// сцепная головка сходит с шара, дышло (*руда*) начинает падать, но повисает
/// на перекрещённых цепях, и прицеп катится прямо, а не уходит в сторону.
///
/// Ключевой кадр — третий: дышло висит над асфальтом, не касаясь его. По нему
/// правило читается и на стоп-кадре, если пользователь пролистнёт мимо.
class RaskinutaVezaPrikolice extends StatefulWidget {
  const RaskinutaVezaPrikolice({super.key});

  @override
  State<RaskinutaVezaPrikolice> createState() => _RaskinutaVezaPrikoliceState();
}

class _RaskinutaVezaPrikoliceState extends State<RaskinutaVezaPrikolice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Семь секунд на четыре фазы: быстрее не успеть прочитать подпись фазы,
    // медленнее — пользователь не дождётся второго круга.
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gloss = Gloss.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 336,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _ScenePainter(scheme, gloss, _controller.value),
            ),
          ),
        ),
      ),
    );
  }
}

/// Стальной цвет цепи: она рисуется светлой поверх тёмного ореола, поэтому
/// читается и на светлой, и на тёмной теме.
const _kChain = Color(0xFFCBD1D8);
const _kChainShadow = Color(0xCC1B1F24);

/// Приглушённый красный для «призрака» упавшего дышла: на асфальте он должен
/// читаться как предупреждение, но не спорить с самой сценой.
const kReflectorRedDim = Color(0xFFE05A4E);

class _ScenePainter extends TrailerScenePainter {
  _ScenePainter(super.colorScheme, this.gloss, this.t);

  final Gloss gloss;

  /// Позиция в цикле, 0…1.
  final double t;

  static const _scene = Rect.fromLTRB(2, 32, 398, 218);
  static const _roadY = 182.0;

  /// Сцепной шар на тягаче и точка, вокруг которой поворачивается дышло
  /// (нос прицепа). Дышло — жёсткая рама, поэтому падает не отвесно, а
  /// поворотом вокруг кузова.
  static const _ball = Offset(188, 158);
  static const _nose = Offset(300, 154);

  /// Насколько дышло опустилось (0 — на шаре, 1 — висит на цепях).
  double get _drop => Curves.easeIn.transform(_seg(0.22, 0.42));

  /// Разрыв: прицеп отстаёт от уходящего вперёд тягача.
  double get _gap => 22 * Curves.easeOut.transform(_seg(0.22, 0.60));

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  double _seg(double from, double to) => _clamp01((t - from) / (to - from));

  @override
  void paint(Canvas canvas, Size size) {
    _phaseCaption(canvas);

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(_scene, const Radius.circular(12)),
    );
    panel(canvas, _scene);
    _road(canvas);

    // Тягач уезжает вперёд (влево), поэтому его нос за кадром: сцена — крупный
    // план сцепного узла, а не общий вид состава.
    carSide(canvas, const Rect.fromLTRB(6, 118, 170, _roadY));
    towBall(canvas, const Offset(166, 150), _ball);

    final head = _headOffset();
    final nose = _nose + Offset(_gap, 0);
    trailerSide(canvas, Rect.fromLTRB(300 + _gap, 118, 404 + _gap, _roadY));

    // Порядок важен: цепи и «призрак» уходят под дышло, иначе сцепной узел —
    // главное в кадре — теряется под ними.
    _ghostDrawbar(canvas);
    _chains(canvas, head);
    drawbar(canvas, head, nose, spread: 8, width: 5);
    couplingHead(canvas, head, angle: _drawbarAngle());
    _labels(canvas, head);
    canvas.restore();

    _rule(canvas);
  }

  /// Точка сцепной головки: пока связь цела — на шаре, дальше поворачивается
  /// вокруг носа прицепа вниз, пока цепи не натянутся.
  Offset _headOffset() {
    final nose = _nose + Offset(_gap, 0);
    final radius = (_ball - _nose).distance;
    final angle = _drawbarAngle();
    return nose + Offset(-radius * math.cos(angle), radius * math.sin(angle));
  }

  /// Угол дышла к горизонту. Максимум подобран так, чтобы головка повисла над
  /// асфальтом с зазором — это и есть содержание правила.
  double _drawbarAngle() => 0.13 * _drop;

  void _road(Canvas canvas) {
    asphalt(canvas, const Rect.fromLTRB(2, _roadY, 398, 218));
    // Штрихи на асфальте едут вправо — тягач движется влево. Когда сцена
    // останавливается, останавливаются и они.
    final shift = _travel() % 36;
    for (var x = -36.0; x < 420; x += 36) {
      canvas.drawRect(
        Rect.fromLTWH(x + shift, 202, 18, 3),
        Paint()..color = kMarking.withValues(alpha: 0.7),
      );
    }
  }

  /// Пройденный «путь» камеры: полный ход до 0.55, затем плавное торможение
  /// до нуля к 0.75 и остановка до конца цикла.
  double _travel() {
    const speedEnd = 0.75;
    const brakeStart = 0.55;
    const k = 900.0;
    if (t <= brakeStart) return k * t;
    final x = _clamp01((t - brakeStart) / (speedEnd - brakeStart));
    return k * brakeStart + k * (speedEnd - brakeStart) * (x - x * x / 2);
  }

  /// Две перекрещённые цепи. Пока сцепка цела, они провисают — по провису
  /// видно, что это страховка, а не тяга; после обрыва натягиваются.
  void _chains(Canvas canvas, Offset head) {
    final angle = _drawbarAngle();
    final along = Offset(math.cos(angle), math.sin(angle));
    final across = Offset(-math.sin(angle), math.cos(angle));
    final upper = head + along * 44 - across * 11;
    final lower = head + along * 44 + across * 11;
    final sag = 11 * (1 - _drop) + 2;

    _chain(canvas, const Offset(164, 148), lower, sag);
    _chain(canvas, const Offset(164, 166), upper, sag);
  }

  void _chain(Canvas canvas, Offset from, Offset to, double sag) {
    final control = Offset.lerp(from, to, 0.5)! + Offset(0, sag);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = _kChainShadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    // Звенья точками: сплошная линия читается как трос, а в вопросе связь —
    // именно ланац или челично уже.
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d <= metric.length; d += 7) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent == null) continue;
        canvas.drawCircle(tangent.position, 1.9, Paint()..color = _kChain);
      }
    }
  }

  void _labels(Canvas canvas, Offset head) {
    roadLabel(
      canvas,
      'руда${gloss('  ·  дышло')}',
      const Offset(324, 76),
      fontSize: 11.5,
    );
    arrow(canvas, const Offset(312, 88), const Offset(268, 148),
        color: kMarking, width: 2, head: 7);

    roadLabel(
      canvas,
      'додатне везе — ланци, челично уже'
      '${gloss('\nдополнительные связи — цепи, стальной трос')}',
      const Offset(140, 58),
      fontSize: 11,
    );
    arrow(canvas, const Offset(146, 78), const Offset(196, 140),
        color: kMarking, width: 2, head: 7);

  }

  /// Пунктирный «призрак»: куда руда упала бы без додатне везе. Сам зазор над
  /// асфальтом мал, поэтому правило показано сравнением двух положений, а не
  /// размерной линией в несколько пикселей.
  void _ghostDrawbar(Canvas canvas) {
    final show = Curves.easeOut.transform(_seg(0.34, 0.50));
    if (show <= 0.01) return;
    final ink = kReflectorRedDim.withValues(alpha: 0.85 * show);

    final nose = _nose + Offset(_gap, 0);
    final radius = (_ball - _nose).distance;
    // Угол подобран так, чтобы головка легла на сам асфальт.
    const fallen = 0.245;
    final ghostHead = nose +
        Offset(-radius * math.cos(fallen), radius * math.sin(fallen));

    drawbar(canvas, ghostHead, nose, spread: 8, color: ink, width: 3.5);
    couplingHead(canvas, ghostHead, angle: fallen, color: ink);
    text(
      canvas,
      'без додатне везе',
      Offset(ghostHead.dx + 34, ghostHead.dy + 16),
      kMarking.withValues(alpha: show),
      maxWidth: 140,
      fontSize: 10,
      isBold: true,
    );
  }

  void _phaseCaption(Canvas canvas) {
    final String phase;
    if (t < 0.22) {
      phase = '1. Спојено: приколица иде за возилом';
    } else if (t < 0.42) {
      phase = '2. Веза се раскинула — руда пада';
    } else if (t < 0.62) {
      phase = '3. Ланци задржавају руду изнад коловоза';
    } else {
      phase = '4. Приколица иде право и зауставља се';
    }
    calloutBox(
      canvas,
      phase,
      const Rect.fromLTRB(2, 0, 398, 26),
      fill: colorScheme.secondaryContainer,
      ink: colorScheme.onSecondaryContainer,
      fontSize: 12,
      isBold: true,
    );
  }

  void _rule(Canvas canvas) {
    calloutBox(
      canvas,
      'Приколица до 1.500 kg која нема кочницу што делује аутоматски при '
      'раскидању везе мора имати додатну везу — ланац или челично уже: руда не '
      'сме пасти на коловоз.'
      '${gloss('\nПрицеп до 1.500 kg без автоматического тормоза при обрыве — '
          'цепь или стальной трос обязательны.')}',
      const Rect.fromLTRB(2, 226, 398, 330),
      fill: colorScheme.surfaceContainerHighest,
      ink: colorScheme.onSurface,
      fontSize: 11.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.t != t || old.colorScheme != colorScheme || old.gloss != gloss;
}
