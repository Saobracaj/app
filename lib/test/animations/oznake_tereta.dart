// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Чем обозначают груз, выступающий за габарит.
///
/// Схема повторяет таблицу правила: сверху обычные условия, где обозначение
/// зависит от вида возила (*теретно* — *прописана табла*, *путничко* —
/// *црвена тканина*), снизу *смањена видљивост*, где разницы между ними уже
/// нет — обоим нужен красный свет или красный светоотражатель. Отдельной
/// строкой перечёркнут *сигурносни троугао*: он приманка во всех четырёх
/// вопросах (8637, 8639, 8640, 8641).
///
/// Слаг в `animations_map.dart`: `oznake-tereta`.
class OznakeTereta extends StatelessWidget {
  const OznakeTereta({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 524,
          child: CustomPaint(
            painter: _OznakeTeretaPainter(
              Theme.of(context).colorScheme,
              _Labels.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские подписи. Сербские формулировки из правил (*прописана табла*,
/// *црвена тканина*, *сигурносни троугао*) не переводятся.
class _Labels {
  const _Labels({
    required this.day,
    required this.night,
    required this.never,
  });

  factory _Labels.of(BuildContext context) => _Labels(
        day: context.tr(LocaleKeys.oznakeTereta_day),
        night: context.tr(LocaleKeys.oznakeTereta_night),
        never: context.tr(LocaleKeys.oznakeTereta_never),
      );

  final String day;
  final String night;
  final String never;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Labels &&
          other.day == day &&
          other.night == night &&
          other.never == never;

  @override
  int get hashCode => Object.hash(day, night, never);
}

class _OznakeTeretaPainter extends IllustrationPainter {
  _OznakeTeretaPainter(super.colorScheme, this.labels);

  final _Labels labels;

  // Ночная панель рисуется своей палитрой, а не темой: затемнение здесь —
  // содержание («смањена видљивост»), а не оформление, и должно выглядеть
  // одинаково в светлой и тёмной теме.
  static const Color _nightBg = Color(0xFF232838);
  static const Color _nightInk = Color(0xFFE8EBF5);
  static const VehiclePalette _nightVehicle = VehiclePalette(
    body: Color(0xFF4A5169),
    outline: Color(0xFFB6BFD8),
    glass: Color(0xFF2C3348),
    tire: Color(0xFF12151F),
  );
  // Красный здесь — тоже содержание: и ткань, и огонь, и полосы на табличке
  // правило называет красными.
  static const Color _red = Color(0xFFE53935);

  @override
  void paint(Canvas canvas, Size size) {
    _dayPanel(canvas, const Rect.fromLTRB(8, 8, 392, 212));
    _nightPanel(canvas, const Rect.fromLTRB(8, 220, 392, 424));
    _triangleNever(canvas, const Rect.fromLTRB(8, 432, 392, 516));
  }

  // ==================== ОБЫЧНЫЕ УСЛОВИЯ ====================

  void _dayPanel(Canvas canvas, Rect panel) {
    panelFrame(canvas, panel);
    text(
      canvas,
      labels.day,
      Offset(panel.center.dx, panel.top + 18),
      colorScheme.onSurface,
      maxWidth: panel.width - 24,
      fontSize: 12,
      isBold: true,
    );

    // Слева грузовик с табличкой, справа легковой с тканью: разница между
    // строками правила видна в одном взгляде.
    final truck = drawTruckProfile(
      canvas,
      this,
      const Rect.fromLTRB(60, 46, 190, 134),
    );
    final loadRear = _load(canvas, truck, rearEnd: 30, thickness: 18);
    _plate(canvas, Offset(loadRear, (truck.bed.top + 6)));

    final car = drawCarProfile(
      canvas,
      this,
      const Rect.fromLTRB(252, 58, 382, 134),
    );
    final carLoadRear = _load(canvas, car, rearEnd: 224, thickness: 13);
    _cloth(canvas, Offset(carLoadRear, car.bed.top + 4));

    _dayCaption(
      canvas,
      const Rect.fromLTRB(14, 148, 194, 202),
      'теретно или прикључно возило',
      'прописана табла',
    );
    _dayCaption(
      canvas,
      const Rect.fromLTRB(206, 148, 386, 202),
      'путничко возило',
      'црвена тканина',
    );
  }

  /// Подпись дневной сцены: сверху вид возила, снизу — жирным то самое
  /// обозначение, которое и спрашивают. Разный кегль нужен, чтобы взгляд
  /// сразу цеплялся за ответ, а не за условие.
  void _dayCaption(Canvas canvas, Rect rect, String vehicle, String marking) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = colorScheme.secondaryContainer);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    text(
      canvas,
      vehicle,
      Offset(rect.center.dx, rect.top + 18),
      colorScheme.onSecondaryContainer,
      maxWidth: rect.width - 16,
      fontSize: 11,
    );
    text(
      canvas,
      marking,
      Offset(rect.center.dx, rect.bottom - 18),
      colorScheme.onSecondaryContainer,
      maxWidth: rect.width - 16,
      fontSize: 13,
      isBold: true,
    );
  }

  // ==================== СМАЊЕНА ВИДЉИВОСТ ====================

  void _nightPanel(Canvas canvas, Rect panel) {
    panelFrame(canvas, panel, fill: _nightBg, border: colorScheme.outline);
    text(
      canvas,
      '${labels.night}\nу условима смањене видљивости',
      Offset(panel.center.dx, panel.top + 24),
      _nightInk,
      maxWidth: panel.width - 24,
      fontSize: 12,
      isBold: true,
    );

    final truck = drawTruckProfile(
      canvas,
      this,
      const Rect.fromLTRB(60, 262, 190, 348),
      palette: _nightVehicle,
    );
    final truckLoad = _load(
      canvas,
      truck,
      rearEnd: 34,
      thickness: 18,
      palette: _nightVehicle,
    );
    _redLight(canvas, Offset(truckLoad + 2, truck.bed.top + 14));

    final car = drawCarProfile(
      canvas,
      this,
      const Rect.fromLTRB(252, 272, 382, 348),
      palette: _nightVehicle,
    );
    final carLoad = _load(
      canvas,
      car,
      rearEnd: 226,
      thickness: 13,
      palette: _nightVehicle,
    );
    _redLight(canvas, Offset(carLoad + 2, car.bed.top + 8));

    // Подпись общая на обе машины: в плохой видимости правило одно.
    const box = Rect.fromLTRB(20, 358, 380, 412);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(8)),
      Paint()..color = const Color(0xFF33394D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(8)),
      Paint()
        ..color = _red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    text(
      canvas,
      'црвено светло\nили светлоодбојна материја црвене боје',
      box.center,
      _nightInk,
      maxWidth: box.width - 16,
      fontSize: 12,
      isBold: true,
    );
  }

  // ==================== ТРЕУГОЛЬНИК — НИКОГДА ====================

  void _triangleNever(Canvas canvas, Rect panel) {
    panelFrame(canvas, panel);

    const center = Offset(62, 474);
    const half = 26.0;
    final outer = Path()
      ..moveTo(center.dx, center.dy - half)
      ..lineTo(center.dx + half, center.dy + half * 0.8)
      ..lineTo(center.dx - half, center.dy + half * 0.8)
      ..close();
    canvas.drawPath(outer, Paint()..color = _red);
    final inner = Path()
      ..moveTo(center.dx, center.dy - half * 0.55)
      ..lineTo(center.dx + half * 0.55, center.dy + half * 0.5)
      ..lineTo(center.dx - half * 0.55, center.dy + half * 0.5)
      ..close();
    canvas.drawPath(inner, Paint()..color = colorScheme.surface);
    // Ножки-подставка: без них треугольник не узнать как знак аварийной
    // остановки.
    canvas.drawLine(
      Offset(center.dx - half * 0.7, center.dy + half * 0.9),
      Offset(center.dx + half * 0.7, center.dy + half * 0.9),
      Paint()
        ..color = colorScheme.onSurfaceVariant
        ..strokeWidth = 3,
    );

    crossOutRect(
      canvas,
      Rect.fromCenter(center: center, width: 72, height: 72),
      colorScheme.error,
    );

    calloutBox(
      canvas,
      'сигурносни троугао — никада\n${labels.never}',
      const Rect.fromLTRB(114, 446, 380, 502),
      fill: colorScheme.errorContainer,
      textColor: colorScheme.onErrorContainer,
      cross: true,
      fontSize: 12,
    );
  }

  // ============================ ПРИМИТИВЫ ============================

  /// Груз, выступающий за задний габарит машины. Возвращает координату торца
  /// груза — к ней крепится обозначение.
  double _load(
    Canvas canvas,
    VehicleParts vehicle, {
    required double rearEnd,
    required double thickness,
    VehiclePalette? palette,
  }) {
    final colors = palette ?? VehiclePalette.of(colorScheme);
    final top = vehicle.bed.top;
    final rect = Rect.fromLTRB(
      rearEnd,
      top,
      vehicle.bed.right - 4,
      top + thickness,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color =
            palette == null ? colorScheme.tertiaryContainer : colors.body,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = colors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    return rearEnd;
  }

  /// *Прописана табла*: квадрат с красно-белыми косыми полосами — тот самый
  /// знак №1 из вопроса 8638.
  void _plate(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(center: center, width: 26, height: 26);
    canvas.drawRect(rect, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRect(rect);
    final stripe = Paint()
      ..color = _red
      ..strokeWidth = 6;
    for (var d = -26.0; d < 26; d += 12) {
      canvas.drawLine(
        Offset(rect.left + d, rect.bottom),
        Offset(rect.left + d + 26, rect.top),
        stripe,
      );
    }
    canvas.restore();
    canvas.drawRect(
      rect,
      Paint()
        ..color = _red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// *Црвена тканина*: лоскут ткани, поэтому край волнистый, а не прямой.
  void _cloth(Canvas canvas, Offset topLeft) {
    final path = Path()
      ..moveTo(topLeft.dx - 8, topLeft.dy)
      ..lineTo(topLeft.dx + 12, topLeft.dy)
      ..quadraticBezierTo(
        topLeft.dx + 16,
        topLeft.dy + 14,
        topLeft.dx + 8,
        topLeft.dy + 26,
      )
      ..quadraticBezierTo(
        topLeft.dx,
        topLeft.dy + 34,
        topLeft.dx - 10,
        topLeft.dy + 28,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = _red);
  }

  /// Красный огонь с ореолом: свет виден дальше самого груза, поэтому вокруг
  /// точки рисуются два полупрозрачных круга.
  void _redLight(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      22,
      Paint()..color = _red.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      center,
      13,
      Paint()..color = _red.withValues(alpha: 0.34),
    );
    canvas.drawCircle(center, 6, Paint()..color = _red);
  }

  @override
  bool shouldRepaint(covariant _OznakeTeretaPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.labels != labels;
}
