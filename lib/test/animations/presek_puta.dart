import 'dart:math' as math;

// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/auto.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Дорога сверху с подписями-скобками.
///
/// Вопросы этой подкатегории — фото дороги с жёлтыми стрелками разной длины, и
/// отвечать на них надо именно по длине стрелки. Поэтому схема построена вокруг
/// вложенности: *пут* ⊃ *коловоз* ⊃ *коловозна трака* ⊃ *саобраћајна трака*.
/// Сверху — вид дороги с высоты (машины, тротуар, банкина, разметка), а под
/// ним каждый уровень — своя скобка своего цвета под тем участком, который он
/// покрывает; вертикальные направляющие связывают края скобок с краями
/// участков, чтобы «длину стрелки» было видно глазами.
class PresekPuta extends StatelessWidget {
  const PresekPuta({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 426,
          child: CustomPaint(
            painter: _PresekPainter(
              Theme.of(context).colorScheme,
              _presekLabels(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские пояснения под сербскими терминами. Сами термины (*коловоз*,
/// *саобраћајна трака*, *банкина*) — из правил и не переводятся.
typedef _PresekLabels = ({
  String sidewalk,
  String shoulder,
  String lane,
  String laneHalf,
  String roadway,
  String road,
});

_PresekLabels _presekLabels(BuildContext context) => (
      sidewalk: context.tr(LocaleKeys.presekPuta_sidewalk),
      shoulder: context.tr(LocaleKeys.presekPuta_shoulder),
      lane: context.tr(LocaleKeys.presekPuta_lane),
      laneHalf: context.tr(LocaleKeys.presekPuta_laneHalf),
      roadway: context.tr(LocaleKeys.presekPuta_roadway),
      road: context.tr(LocaleKeys.presekPuta_road),
    );

class _PresekPainter extends CustomPainter {
  _PresekPainter(this.scheme, this.labels);

  final ColorScheme scheme;
  final _PresekLabels labels;

  // === Горизонтальная разметка (сетка 400 в ширину) ===
  // Скобки внизу привязаны к этим же краям, поэтому вся вложенность понятий
  // задана одним набором координат: пут ⊃ коловоз ⊃ траке.
  static const _roadLeft = 14.0; // край пута слева
  static const _roadRight = 386.0;
  static const _sidewalkLeft = 44.0; // между банкином и тротоаром
  static const _sidewalkRight = 356.0;
  static const _kolovozLeft = 80.0; // край асфальта для транспорта
  static const _kolovozRight = 320.0;
  static const _axis = 200.0; // осевая: делит коловоз на две коловозне траке
  // Границы четырёх саобраћајних трака.
  static const _laneEdges = [80.0, 140.0, 200.0, 260.0, 320.0];

  // === Вертикальная разметка ===
  // Дорога идёт сверху вниз: левая половина едет «на нас» (вниз), правая —
  // «от нас» (вверх), как при правостороннем движении.
  static const _sceneTop = 76.0;
  static const _sceneBottom = 190.0;

  // Уровни скобок: чем шире понятие, тем ниже его скобка.
  static const _laneRow = 206.0;
  static const _halfRow = 262.0;
  static const _kolovozRow = 318.0;
  static const _roadRow = 374.0;

  // Размер легковушки в сцене: полоса 60 в ширину, машина занимает ~треть.
  static const _carLength = 46.0;
  static const _carWidth = 22.0;

  // Покрытия — цвет и есть содержание, поэтому литеральные и одинаковые в
  // обеих темах (как в road.dart). Брать их из темы нельзя: в тёмной схеме
  // surfaceContainerHighest, outlineVariant и асфальт попадают в один
  // узкий диапазон серого, и дорога превращается в однородную полосу.
  static const _asphalt = Color(0xFF3C3C3C);
  static const _sidewalk = Color(0xFFBFBFBF); // бетонная плита тротоара
  static const _shoulder = Color(0xFF8C8474); // грунт/щебень банкине
  static const _grass = Color(0xFF7C9B69); // земля за пределами пута
  static const _marking = Color(0xFFF5F5F5);
  static const _carBlue = Color(0xFF1E88E5);
  static const _carGreen = Color(0xFF43A047);
  static const _carRed = Color(0xFFE53935);

  @override
  void paint(Canvas canvas, Size size) {
    _paintTopView(canvas);
    _paintGuides(canvas);

    // Саобраћајна трака — своя скобка над каждой отдельной полосой.
    for (var i = 0; i < _laneEdges.length - 1; i++) {
      _bracket(canvas, _laneEdges[i], _laneEdges[i + 1], _laneRow,
          scheme.primary);
    }
    _rowCaption(canvas, _laneRow, 'САОБРАЋАЈНА ТРАКА', labels.lane,
        scheme.primary);

    // Коловозна трака — половина коловоза, по одной на направление.
    _bracket(canvas, _kolovozLeft, _axis, _halfRow, scheme.tertiary);
    _bracket(canvas, _axis, _kolovozRight, _halfRow, scheme.tertiary);
    _rowCaption(canvas, _halfRow, 'КОЛОВОЗНА ТРАКА', labels.laneHalf,
        scheme.tertiary);

    _bracket(canvas, _kolovozLeft, _kolovozRight, _kolovozRow, scheme.secondary);
    _rowCaption(canvas, _kolovozRow, 'КОЛОВОЗ', labels.roadway,
        scheme.secondary);

    _bracket(canvas, _roadLeft, _roadRight, _roadRow, scheme.onSurfaceVariant);
    _rowCaption(canvas, _roadRow, 'ПУТ', labels.road, scheme.onSurfaceVariant);
  }

  /// Вид сверху: трава — банкина — тротоар — коловоз — тротоар — банкина.
  void _paintTopView(Canvas canvas) {
    // Трава за краями пута: видно, что «пут» — это от края до края,
    // а дальше уже не дорога.
    for (final rect in const [
      Rect.fromLTRB(4, _sceneTop, _roadLeft, _sceneBottom),
      Rect.fromLTRB(_roadRight, _sceneTop, 396, _sceneBottom),
    ]) {
      canvas.drawRect(rect, Paint()..color = _grass);
    }

    // Грунт по всей ширине пута: по краям он остаётся виден как банкина.
    canvas.drawRect(
      const Rect.fromLTRB(_roadLeft, _sceneTop, _roadRight, _sceneBottom),
      Paint()..color = _shoulder,
    );
    // Щебень на банкинах — фактура отличает грунт от бетона тротоара и на
    // чёрно-белой печати, и при плохом контрасте экрана.
    final gravel = Paint()..color = const Color(0xFF6E6757);
    for (final left in const [_roadLeft, _sidewalkRight]) {
      for (var y = _sceneTop + 7; y < _sceneBottom - 4; y += 9) {
        final x = left + 6 + (y * 13) % 18;
        canvas.drawCircle(Offset(x, y), 1.3, gravel);
      }
    }

    // Тротоары — бетонные плиты со швами поперёк хода пешехода.
    for (final rect in const [
      Rect.fromLTRB(_sidewalkLeft, _sceneTop, _kolovozLeft, _sceneBottom),
      Rect.fromLTRB(_kolovozRight, _sceneTop, _sidewalkRight, _sceneBottom),
    ]) {
      canvas.drawRect(rect, Paint()..color = _sidewalk);
      final seam = _stroke(const Color(0xFF8F8F8F), 1);
      for (var y = rect.top + 14; y < rect.bottom - 2; y += 14) {
        canvas.drawLine(
            Offset(rect.left + 2, y), Offset(rect.right - 2, y), seam);
      }
      canvas.drawRect(rect, _stroke(const Color(0xFF6E6E6E), 1.2));
    }

    canvas.drawRect(
      const Rect.fromLTRB(_kolovozLeft, _sceneTop, _kolovozRight, _sceneBottom),
      Paint()..color = _asphalt,
    );

    // Разметка: сплошные краевые (утоплены внутрь асфальта, чтобы не слиться
    // со светлым фоном), сплошная осевая и прерывистые между полосами
    // одного направления.
    final edge = _stroke(_marking, 2.5);
    for (final x in const [_kolovozLeft + 2.5, _kolovozRight - 2.5]) {
      canvas.drawLine(Offset(x, _sceneTop), Offset(x, _sceneBottom), edge);
    }
    canvas.drawLine(const Offset(_axis, _sceneTop),
        const Offset(_axis, _sceneBottom), _stroke(_marking, 3));
    final dashed = _stroke(_marking, 2.5);
    for (final x in const [140.0, 260.0]) {
      for (var y = _sceneTop + 6; y < _sceneBottom - 4; y += 21) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 12), dashed);
      }
    }

    // Стрелки направления на асфальте: левая коловозна трака едет вниз,
    // правая — вверх. Так «половина коловоза — для одного направления»
    // видно и без машин.
    for (final x in const [110.0, 170.0]) {
      _roadArrow(canvas, x, down: true);
    }
    for (final x in const [230.0, 290.0]) {
      _roadArrow(canvas, x, down: false);
    }

    // По машине в полосе: одна саобраћајна трака — это место ровно для
    // одного ряда ТС, и на схеме это должно быть видно.
    _paintCarVertical(canvas, const Offset(110, 112), _carGreen,
        facingUp: false);
    _paintCarVertical(canvas, const Offset(230, 146), _carBlue, facingUp: true);
    _paintCarVertical(canvas, const Offset(290, 156), _carRed, facingUp: true);

    canvas.drawRect(
      const Rect.fromLTRB(_roadLeft, _sceneTop, _roadRight, _sceneBottom),
      _stroke(scheme.outline, 1.4),
    );

    _sideCaption(canvas, 62, 'ТРОТОАР', labels.sidewalk, const Offset(62, 80));
    _sideCaption(canvas, 344, 'БАНКИНА', labels.shoulder,
        const Offset(371, 80));
  }

  /// Каноничная легковушка ([paintAutoTopView]) в вертикальной полосе:
  /// поворачиваем холст, потому что «родная» машинка едет горизонтально.
  void _paintCarVertical(
    Canvas canvas,
    Offset center,
    Color color, {
    required bool facingUp,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(facingUp ? -math.pi / 2 : math.pi / 2);
    paintAutoTopView(
      canvas,
      Rect.fromCenter(center: Offset.zero, width: _carLength, height: _carWidth),
      color: color,
    );
    canvas.restore();
  }

  /// Стрелка-разметка направления движения в полосе [x]. Стрелки «вниз»
  /// нарисованы в нижней части сцены, «вверх» — в верхней, чтобы не
  /// пересекаться с машинами.
  void _roadArrow(Canvas canvas, double x, {required bool down}) {
    final paint = Paint()..color = _marking.withValues(alpha: 0.9);
    final tail = down ? _sceneBottom - 42 : _sceneTop + 42;
    final tip = down ? _sceneBottom - 16 : _sceneTop + 16;
    final headBase = down ? tip - 9 : tip + 9;
    canvas.drawRect(
      Rect.fromLTRB(x - 1.5, math.min(tail, headBase), x + 1.5,
          math.max(tail, headBase)),
      paint,
    );
    final head = Path()
      ..moveTo(x, tip)
      ..lineTo(x - 5, headBase)
      ..lineTo(x + 5, headBase)
      ..close();
    canvas.drawPath(head, paint);
  }

  /// Подпись сбоку от сцены со стрелкой к нужной части.
  void _sideCaption(
    Canvas canvas,
    double centerX,
    String term,
    String hint,
    Offset target,
  ) {
    drawCanvasText(canvas, term, Offset(centerX, 24), scheme.onSurface,
        maxWidth: 130, fontSize: 12.5, fontWeight: FontWeight.bold);
    drawCanvasText(canvas, hint, Offset(centerX, 44), scheme.onSurfaceVariant,
        maxWidth: 130, fontSize: 11);
    _arrow(canvas, Offset(centerX, 56), target, scheme.outline);
  }

  /// Скобка, охватывающая участок [x1]…[x2]: горизонталь с усиками вверх.
  ///
  /// Края поджаты внутрь: у соседних скобок одного уровня границы общие, и без
  /// зазора четыре скобки сливаются в одну длинную с перегородками — ровно то
  /// различие длин, ради которого схема и рисуется, пропадает.
  void _bracket(Canvas canvas, double x1, double x2, double y, Color color) {
    const gap = 3.0;
    final paint = _stroke(color, 2);
    final left = x1 + gap;
    final right = x2 - gap;
    canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    canvas.drawLine(Offset(left, y), Offset(left, y - 8), paint);
    canvas.drawLine(Offset(right, y), Offset(right, y - 8), paint);
  }

  /// Сербский термин и русское пояснение под скобкой уровня.
  void _rowCaption(
    Canvas canvas,
    double rowY,
    String term,
    String hint,
    Color color,
  ) {
    drawCanvasText(canvas, term, Offset(_axis, rowY + 16), color,
        maxWidth: 370, fontSize: 13, fontWeight: FontWeight.bold);
    drawCanvasText(
        canvas, hint, Offset(_axis, rowY + 36), scheme.onSurfaceVariant,
        maxWidth: 370, fontSize: 11);
  }

  /// Пунктирные направляющие от краёв участков вниз к их скобкам: без них
  /// непонятно, какая скобка какому куску асфальта соответствует.
  void _paintGuides(Canvas canvas) {
    // (x на сцене, скобка, до которой тянется направляющая)
    const guides = [
      (_roadLeft, _roadRow),
      (_roadRight, _roadRow),
      (_kolovozLeft, _kolovozRow),
      (_kolovozRight, _kolovozRow),
      (_axis, _halfRow),
      (140.0, _laneRow),
      (260.0, _laneRow),
    ];
    final paint = _stroke(scheme.outlineVariant, 1);
    for (final (x, bottom) in guides) {
      for (var y = _sceneBottom + 2; y < bottom - 8; y += 7) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 4), paint);
      }
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = _stroke(color, 1.4);
    canvas.drawLine(from, to, paint);
    final direction = (to - from);
    final unit = direction / direction.distance;
    final normal = Offset(-unit.dy, unit.dx);
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - unit.dx * 8 + normal.dx * 4,
          to.dy - unit.dy * 8 + normal.dy * 4)
      ..lineTo(to.dx - unit.dx * 8 - normal.dx * 4,
          to.dy - unit.dy * 8 - normal.dy * 4)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  @override
  bool shouldRepaint(covariant _PresekPainter oldDelegate) =>
      oldDelegate.scheme != scheme || oldDelegate.labels != labels;
}
