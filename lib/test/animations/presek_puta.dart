// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Поперечный разрез дороги с подписями-скобками.
///
/// Вопросы этой подкатегории — фото дороги с жёлтыми стрелками разной длины, и
/// отвечать на них надо именно по длине стрелки. Поэтому схема построена вокруг
/// вложенности: *пут* ⊃ *коловоз* ⊃ *коловозна трака* ⊃ *саобраћајна трака*.
/// Каждый уровень — своя скобка своего цвета под тем участком разреза, который
/// он покрывает; вертикальные направляющие связывают края скобок с краями
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
          height: 342,
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

  // === Горизонтальная разметка разреза (сетка 400 в ширину) ===
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
  static const _asphaltTop = 86.0;
  static const _asphaltBottom = 100.0;
  static const _sidewalkTop = 76.0; // тротоар приподнят над коловозом
  static const _groundBottom = 106.0;

  // Уровни скобок: чем шире понятие, тем ниже его скобка.
  static const _laneRow = 122.0;
  static const _halfRow = 178.0;
  static const _kolovozRow = 234.0;
  static const _roadRow = 290.0;

  // Покрытия — цвет и есть содержание, поэтому литеральные и одинаковые в
  // обеих темах (как в road.dart). Брать их из темы нельзя: в тёмной схеме
  // surfaceContainerHighest, outlineVariant и асфальт попадают в один
  // узкий диапазон серого, и разрез превращается в однородную полосу.
  static const _asphalt = Color(0xFF3C3C3C);
  static const _sidewalk = Color(0xFFBFBFBF); // бетонная плита тротоара
  static const _shoulder = Color(0xFF8C8474); // грунт/щебень банкине
  static const _marking = Color(0xFFF5F5F5);
  static const _carBlue = Color(0xFF1E88E5);
  static const _carGreen = Color(0xFF43A047);

  @override
  void paint(Canvas canvas, Size size) {
    _paintCrossSection(canvas);
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

  /// Сам разрез: банкина — тротоар — асфальт — тротоар — банкина.
  void _paintCrossSection(Canvas canvas) {
    // Грунт под всей конструкцией: он же банкина по краям.
    canvas.drawRect(
      const Rect.fromLTRB(_roadLeft, _asphaltTop, _roadRight, _groundBottom),
      Paint()..color = _shoulder,
    );

    // Тротоары — приподнятые площадки по краям коловоза. Швы между плитами
    // добавлены не для красоты: они отличают тротоар от банкине не только
    // тоном, а значит и на чёрно-белой печати, и при плохом контрасте экрана.
    for (final rect in const [
      Rect.fromLTRB(_sidewalkLeft, _sidewalkTop, _kolovozLeft, _groundBottom),
      Rect.fromLTRB(_kolovozRight, _sidewalkTop, _sidewalkRight, _groundBottom),
    ]) {
      canvas.drawRect(rect, Paint()..color = _sidewalk);
      final seam = _stroke(const Color(0xFF8F8F8F), 1);
      for (var x = rect.left + 9; x < rect.right - 2; x += 9) {
        canvas.drawLine(
            Offset(x, rect.top + 2), Offset(x, rect.bottom - 2), seam);
      }
      canvas.drawRect(rect, _stroke(const Color(0xFF6E6E6E), 1.2));
    }

    canvas.drawRect(
      const Rect.fromLTRB(
          _kolovozLeft, _asphaltTop, _kolovozRight, _asphaltBottom),
      Paint()..color = _asphalt,
    );

    // Разметка на поверхности асфальта: осевая шире продольных.
    final markingPaint = Paint()..color = _marking;
    canvas.drawRect(
      Rect.fromCenter(
          center: const Offset(_axis, _asphaltTop + 2), width: 9, height: 4),
      markingPaint,
    );
    for (final x in [140.0, 260.0]) {
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(x, _asphaltTop + 2), width: 5, height: 4),
        markingPaint,
      );
    }

    // По машине во второй и третьей полосе: одна саобраћајна трака — это
    // место ровно для одного ряда ТС, и на схеме это должно быть видно.
    _paintCar(canvas, 170, _carGreen);
    _paintCar(canvas, 230, _carBlue);

    canvas.drawRect(
      const Rect.fromLTRB(_roadLeft, _asphaltTop, _roadRight, _groundBottom),
      _stroke(scheme.outline, 1.4),
    );

    _sideCaption(canvas, 62, 'ТРОТОАР', labels.sidewalk, const Offset(62, 74));
    _sideCaption(canvas, 344, 'БАНКИНА', labels.shoulder, const Offset(371, 86));
  }

  /// Машина «в лоб»: кузов, крыша с окном и два колеса.
  void _paintCar(Canvas canvas, double centerX, Color color) {
    const bottom = _asphaltTop;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(centerX - 17, bottom - 15, centerX + 17, bottom),
      const Radius.circular(3),
    );
    final roof = RRect.fromRectAndRadius(
      Rect.fromLTRB(centerX - 11, bottom - 25, centerX + 11, bottom - 13),
      const Radius.circular(3),
    );
    canvas.drawRRect(roof, Paint()..color = color);
    canvas.drawRRect(body, Paint()..color = color);
    canvas.drawRect(
      Rect.fromLTRB(centerX - 8, bottom - 23, centerX + 8, bottom - 16),
      Paint()..color = _marking.withValues(alpha: 0.75),
    );
    for (final dx in [-13.0, 13.0]) {
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(centerX + dx, bottom - 2), width: 7, height: 5),
        Paint()..color = const Color(0xFF212121),
      );
    }
  }

  /// Подпись сбоку от разреза со стрелкой к нужной части.
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
    // (x на разрезе, скобка, до которой тянется направляющая)
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
      for (var y = _groundBottom + 2; y < bottom - 8; y += 7) {
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
