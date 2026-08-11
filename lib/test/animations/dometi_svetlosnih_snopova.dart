import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';
import 'package:saobracaj/test/animations/vozilo_bocno.dart';

/// Три числа, которые спрашивают чаще всего в теме фар: сколько метров дороги
/// освещает каждый пучок.
///
/// №8724 (кратко светло — најмање 40 и највише 80 m), №8726 (дуго — најмање
/// 100 m), №8729 (светло за маглу — највише 35 m). Ловушки построены на
/// направлении ограничения: «најмање 35» для противотуманного и «најмање 40»
/// без верхней границы для ближнего. Поэтому картинка показывает не три
/// абстрактных числа, а три пучка на одной шкале: видно, что противотуманный
/// упирается в потолок 35 m, ближний живёт в вилке 40–80, а дальний уходит за
/// 100 и вправо не ограничен.
///
/// Сцена ночная (тёмная подложка литеральная): жёлтый свет на светлом фоне
/// просто не читается, а «ночь» здесь и есть содержание.
class DometiSvetlosnihSnopova extends StatelessWidget {
  const DometiSvetlosnihSnopova({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 392,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

/// Ночное небо и асфальт — литеральные: на светлой теме белый фон убил бы
/// свечение пучков, а вся картинка держится именно на нём.
const _kNoc = Color(0xFF11161F);
const _kAsfalt = Color(0xFF2A2F38);
const _kNocInk = Color(0xFFE8ECF3);
const _kDugo = Color(0xFFFFF6D6);
const _kKratko = Color(0xFFFFD766);
const _kMagla = Color(0xFFFFA726);

class _ScenePainter extends VoziloScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  // Геометрия шкалы: 0 m — у фары, дальше линейно до 120 m у правого края.
  static const double _x0 = 116;
  static const double _xMax = 388;
  static const double _mMax = 120;
  static const double _road = 208; // уровень коловоза внутри ночной панели

  double _x(double metres) => _x0 + (_xMax - _x0) * metres / _mMax;

  @override
  void paint(Canvas canvas, Size size) {
    chip(
      canvas,
      'ДОМЕТИ СВЕТЛОСНИХ СНОПОВА${gloss(' · дальность пучков')}',
      const Rect.fromLTRB(2, 2, 398, 32),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 12.5,
    );

    _night(canvas);
    _ruler(canvas);
    _legend(canvas);

    chip(
      canvas,
      'кратко: најмање 40 — највише 80\n'
      'дуго: најмање 100   ·   магла: највише 35',
      const Rect.fromLTRB(2, 354, 398, 390),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 11.5,
    );
  }

  /// Ночная сцена: машина сбоку и три вложенных пучка от одной фары.
  void _night(Canvas canvas) {
    const scene = Rect.fromLTRB(2, 40, 398, 236);
    final rrect = RRect.fromRectAndRadius(scene, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(scene, Paint()..color = _kNoc);
    canvas.drawRect(
      Rect.fromLTRB(scene.left, _road, scene.right, scene.bottom),
      Paint()..color = _kAsfalt,
    );

    // Пучки рисуются от самого длинного к самому короткому: наложение
    // светлеет к фаре, как у настоящего света.
    _beam(canvas, top: 148, bottom: 196, to: _x(_mMax), color: _kDugo, alpha: 0.26);
    _beam(canvas, top: 172, bottom: 202, to: _x(80), color: _kKratko, alpha: 0.34);
    _beam(canvas, top: 188, bottom: 206, to: _x(35), color: _kMagla, alpha: 0.46);

    carSide(canvas, const Rect.fromLTRB(14, 150, 118, 204));
    // Светящаяся фара — точка, из которой выходят все три пучка.
    canvas.drawCircle(
      const Offset(_x0, 182),
      7,
      Paint()..color = _kDugo.withValues(alpha: 0.55),
    );
    canvas.drawCircle(const Offset(_x0, 182), 3.5, Paint()..color = _kDugo);

    canvas.drawLine(
      const Offset(2, _road),
      const Offset(398, _road),
      Paint()
        ..color = _kNocInk.withValues(alpha: 0.35)
        ..strokeWidth = 1.2,
    );

    // Границы дальностей: где кончается каждый пучок и где начинается вилка.
    // 35 и 40 стоят почти вплотную, поэтому подписи разведены в стороны от
    // своих линий — иначе они наезжают друг на друга.
    const marks = [(35.0, -17.0), (40.0, 17.0), (80.0, 0.0), (100.0, 0.0)];
    for (final (m, shift) in marks) {
      dashedLine(
        canvas,
        Offset(_x(m), 60),
        Offset(_x(m), 232),
        dash: 5,
        gap: 4,
        width: 1.2,
        color: _kNocInk.withValues(alpha: 0.5),
      );
      text(
        canvas,
        '${m.toInt()} m',
        Offset(_x(m) + shift, 50),
        _kNocInk,
        maxWidth: 46,
        fontSize: 11,
        isBold: true,
      );
    }

    // Подписи прямо в пучках: так не нужно сверять цвет с легендой.
    text(canvas, 'дуго светло', const Offset(300, 132), _kDugo,
        maxWidth: 120, fontSize: 11.5, isBold: true);
    text(canvas, 'кратко светло', const Offset(252, 216), _kKratko,
        maxWidth: 120, fontSize: 11.5, isBold: true);
    text(canvas, 'светло за маглу', const Offset(136, 228), _kMagla,
        maxWidth: 120, fontSize: 11, isBold: true);

    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Клин света: у фары почти точка, к концу расходится по вертикали.
  void _beam(
    Canvas canvas, {
    required double top,
    required double bottom,
    required double to,
    required Color color,
    required double alpha,
  }) {
    final path = Path()
      ..moveTo(_x0, 178)
      ..lineTo(to, top)
      ..lineTo(to, bottom)
      ..lineTo(_x0, 186)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: alpha + 0.18),
            color.withValues(alpha: alpha * 0.45),
          ],
        ).createShader(Rect.fromLTRB(_x0, top, to, bottom)),
    );
  }

  /// Шкала под сценой: отрезок каждого пучка со своими границами.
  void _ruler(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 244, 398, 286));

    _span(canvas, y: 256, from: 0, to: 35, color: _kMagla, label: '≤ 35 m');
    _span(canvas, y: 272, from: 40, to: 80, color: _kKratko, label: '40 — 80 m');
    _span(canvas, y: 264, from: 100, to: _mMax, color: _kDugo, label: '≥ 100 m',
        openEnd: true);
  }

  void _span(
    Canvas canvas, {
    required double y,
    required double from,
    required double to,
    required Color color,
    required String label,
    bool openEnd = false,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(_x(from), y), Offset(_x(to), y), paint);
    if (openEnd) {
      arrow(canvas, Offset(_x(to) - 12, y), Offset(_x(to) + 6, y),
          color: color, width: 3, head: 8);
    }
    text(
      canvas,
      label,
      Offset((_x(from) + _x(to)) / 2, y - 9),
      colorScheme.onSurface,
      maxWidth: 120,
      fontSize: 10.5,
      isBold: true,
    );
  }

  /// Легенда: цвет пучка → сербский термин и направление ограничения.
  void _legend(Canvas canvas) {
    const rows = [
      ('светло за маглу', 'највише 35 m', 'противотуманный', _kMagla),
      ('кратко светло', 'најмање 40, највише 80 m', 'ближний', _kKratko),
      ('дуго светло', 'најмање 100 m', 'дальний', _kDugo),
    ];
    var y = 302.0;
    for (final row in rows) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, y - 5, 22, 10),
          const Radius.circular(5),
        ),
        Paint()..color = row.$4,
      );
      final gloss = this.gloss('   ·   ${row.$3}');
      textLeft(
        canvas,
        '${row.$1} — ${row.$2}$gloss',
        Offset(38, y),
        colorScheme.onSurface,
        maxWidth: 352,
        fontSize: 11,
      );
      y += 18;
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.gloss != gloss;
}
