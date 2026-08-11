// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Четыре зоны и разрешённая в каждой скорость.
///
/// Половина вопросов подкатегории — «дано определение, выбери зону» или
/// «выбери скорость», причём варианты во всех четырёх вопросах похожие.
/// Поэтому зоны стоят одним столбцом: знак — определение — скорость, и
/// строки сравниваются взглядом сверху вниз. В ТЗ карточки были в ряд, но на
/// телефоне четыре колонки дают нечитаемый кегль, поэтому ряд развёрнут в
/// столбец — сравнение при этом не теряется.
///
/// Сверху — приманка «20 km/h»: этой цифры нет ни в одном правильном ответе
/// категории, и её вычёркивание экономит время на самих вопросах.
class ZoneUporedno extends StatelessWidget {
  const ZoneUporedno({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 404,
          child: CustomPaint(
            painter: _ZonesPainter(
              Theme.of(context).colorScheme,
              context.tr(LocaleKeys.zoneUporedno_trap),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZonesPainter extends CustomPainter {
  _ZonesPainter(this.scheme, this.trap);

  final ColorScheme scheme;

  /// Русское пояснение к перечёркнутой «20 km/h». Названия зон и формулировки
  /// скоростей — сербские термины из вопросов, они не переводятся.
  final String trap;

  // Цвета знаков — их содержание, поэтому литеральные и одинаковые в обеих
  // темах.
  static const _signBlue = Color(0xFF0D5AA7);
  static const _signWhite = Color(0xFFFAFAFA);
  static const _signInk = Color(0xFF1B1B1B);
  static const _signRed = Color(0xFFD32F2F);
  static const _signYellow = Color(0xFFC6D935);

  static const _cardLeft = 10.0;
  static const _cardRight = 390.0;
  // Высота карточки рассчитана на самую длинную строку — «ЗОНА УСПОРЕНОГ
  // САОБРАЋАЈА» плюс двухстрочное определение под ней.
  static const _cardHeight = 78.0;
  static const _cardStep = 84.0;
  static const _firstCardTop = 62.0;

  static const _signCenterX = 48.0;
  static const _signSize = 52.0;
  static const _textLeft = 86.0;
  static const _speedCenterX = 326.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintTrapBanner(canvas);

    _paintCard(
      canvas,
      0,
      'ПЕШАЧКА ЗОНА',
      'првенствено намењена\nкретању пешака',
      _paintPedestrianZoneSign,
      _paintWalkingSpeed,
    );
    _paintCard(
      canvas,
      1,
      'ЗОНА УСПОРЕНОГ\nСАОБРАЋАЈА',
      'коловоз користе пешаци\nи возила заједно',
      _paintCalmZoneSign,
      (canvas, cy) => _speedText(
          canvas, cy, 'кретања пешака,\nнајвише 10 km/h', 12.5),
    );
    _paintCard(
      canvas,
      2,
      'ЗОНА „30”',
      'брзина возила ограничена\nдо 30 km/h',
      _paintZone30Sign,
      (canvas, cy) => _speedText(canvas, cy, '30 km/h', 21),
    );
    _paintCard(
      canvas,
      3,
      'ЗОНА ШКОЛЕ',
      'део пута у непосредној\nблизини школе',
      _paintSchoolZoneSign,
      _paintSchoolSpeed,
    );
  }

  /// Перечёркнутая «20 km/h» — универсальная приманка подкатегории.
  void _paintTrapBanner(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTRB(_cardLeft, 6, _cardRight, 50),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = scheme.errorContainer);

    const center = Offset(88, 28);
    drawCanvasText(canvas, '20 km/h', center, scheme.onErrorContainer,
        maxWidth: 140, fontSize: 22, fontWeight: FontWeight.bold);
    canvas.drawLine(
      const Offset(30, 28),
      const Offset(146, 28),
      Paint()
        ..color = scheme.error
        ..strokeWidth = 3.5,
    );
    drawCanvasText(canvas, trap, const Offset(272, 28), scheme.onErrorContainer,
        maxWidth: 220, fontSize: 11.5);
  }

  void _paintCard(
    Canvas canvas,
    int index,
    String term,
    String definition,
    void Function(Canvas canvas, Offset center) paintSign,
    void Function(Canvas canvas, double centerY) paintSpeed,
  ) {
    final top = _firstCardTop + index * _cardStep;
    final centerY = top + _cardHeight / 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(_cardLeft, top, _cardRight, top + _cardHeight),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = scheme.surfaceContainerHighest);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = scheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    paintSign(canvas, Offset(_signCenterX, centerY));

    drawCanvasText(canvas, term, Offset(_textLeft, top + 25), scheme.onSurface,
        maxWidth: 170,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.left,
        anchor: Alignment.centerLeft);
    drawCanvasText(canvas, definition, Offset(_textLeft, top + 55),
        scheme.onSurfaceVariant,
        maxWidth: 175,
        fontSize: 11,
        textAlign: TextAlign.left,
        anchor: Alignment.centerLeft);

    paintSpeed(canvas, centerY);
  }

  void _speedText(
      Canvas canvas, double centerY, String text, double fontSize) {
    drawCanvasText(canvas, text, Offset(_speedCenterX, centerY), scheme.primary,
        maxWidth: 124, fontSize: fontSize, fontWeight: FontWeight.bold);
  }

  /// В пешачкој зони скорость задана не цифрой, а шагом пешехода — вместо
  /// числа рисуем идущего человека.
  void _paintWalkingSpeed(Canvas canvas, double centerY) {
    _paintPerson(canvas, Offset(282, centerY), 38, scheme.primary,
        striding: true);
    drawCanvasText(canvas, 'кретања\nпешака', Offset(340, centerY),
        scheme.primary,
        maxWidth: 92, fontSize: 12.5, fontWeight: FontWeight.bold);
  }

  /// Единственная зона, где надо помнить цифры и время.
  void _paintSchoolSpeed(Canvas canvas, double centerY) {
    drawCanvasText(canvas, 'у насељу 30 km/h',
        Offset(_speedCenterX, centerY - 16), scheme.primary,
        maxWidth: 128, fontSize: 12.5, fontWeight: FontWeight.bold);
    drawCanvasText(canvas, 'ван насеља 50 km/h',
        Offset(_speedCenterX, centerY), scheme.primary,
        maxWidth: 128, fontSize: 12.5, fontWeight: FontWeight.bold);
    drawCanvasText(canvas, '07,00–21,00', Offset(_speedCenterX, centerY + 18),
        scheme.onSurfaceVariant,
        maxWidth: 128, fontSize: 11);
  }

  // === Знаки ===

  /// Синий квадрат с белым пешеходом: *пешачка зона*.
  void _paintPedestrianZoneSign(Canvas canvas, Offset center) {
    _paintSignPlate(canvas, center, _signBlue);
    _paintPerson(canvas, center.translate(-7, 1), 32, _signWhite);
    _paintPerson(canvas, center.translate(11, 5), 22, _signWhite);
  }

  /// Синий квадрат с домом, машиной и ребёнком: *зона успореног саобраћаја*.
  void _paintCalmZoneSign(Canvas canvas, Offset center) {
    _paintSignPlate(canvas, center, _signBlue);
    final origin = center.translate(-_signSize / 2, -_signSize / 2);
    final ink = Paint()..color = _signWhite;

    // Дом слева сверху.
    canvas.drawPath(
      Path()
        ..moveTo(origin.dx + 6, origin.dy + 20)
        ..lineTo(origin.dx + 18, origin.dy + 9)
        ..lineTo(origin.dx + 30, origin.dy + 20)
        ..close(),
      ink,
    );
    canvas.drawRect(
      Rect.fromLTRB(
          origin.dx + 10, origin.dy + 20, origin.dx + 26, origin.dy + 30),
      ink,
    );

    // Машина справа снизу, вид сбоку.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
            origin.dx + 26, origin.dy + 33, origin.dx + 47, origin.dy + 41),
        const Radius.circular(2),
      ),
      ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
            origin.dx + 31, origin.dy + 27, origin.dx + 42, origin.dy + 34),
        const Radius.circular(2),
      ),
      ink,
    );
    canvas.drawCircle(Offset(origin.dx + 31, origin.dy + 42), 3, ink);
    canvas.drawCircle(Offset(origin.dx + 42, origin.dy + 42), 3, ink);

    // Играющий ребёнок слева снизу.
    _paintPerson(
        canvas, Offset(origin.dx + 14, origin.dy + 41), 16, _signWhite,
        striding: true);
  }

  /// Белый квадрат с красным кругом «30»: *зона „30”*.
  void _paintZone30Sign(Canvas canvas, Offset center) {
    _paintSignPlate(canvas, center, _signWhite);
    drawCanvasText(canvas, 'ЗОНА', center.translate(0, -19), _signInk,
        maxWidth: 48, fontSize: 9, fontWeight: FontWeight.bold);
    final circleCenter = center.translate(0, 6);
    canvas.drawCircle(circleCenter, 14, Paint()..color = _signRed);
    canvas.drawCircle(circleCenter, 9.5, Paint()..color = _signWhite);
    drawCanvasText(canvas, '30', circleCenter, _signInk,
        maxWidth: 30, fontSize: 13, fontWeight: FontWeight.bold);
  }

  /// Жёлто-зелёный квадрат с детьми: *зона школе*.
  void _paintSchoolZoneSign(Canvas canvas, Offset center) {
    _paintSignPlate(canvas, center, _signYellow);
    _paintPerson(canvas, center.translate(-9, -4), 26, _signInk,
        striding: true);
    _paintPerson(canvas, center.translate(8, -1), 21, _signInk);
    drawCanvasText(canvas, 'ШКОЛА', center.translate(0, 20), _signInk,
        maxWidth: 50, fontSize: 9, fontWeight: FontWeight.bold);
  }

  void _paintSignPlate(Canvas canvas, Offset center, Color fill) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: _signSize, height: _signSize),
      const Radius.circular(5),
    );
    canvas.drawRRect(rect, Paint()..color = fill);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _signInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Пиктограмма человека: голова, корпус, руки и ноги. [striding] разводит
  /// ноги в шаге — так фигура читается как «идёт», а не «стоит».
  void _paintPerson(
    Canvas canvas,
    Offset center,
    double height,
    Color color, {
    bool striding = false,
  }) {
    final limb = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = height * 0.11
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
        center.translate(0, -height * 0.38), height * 0.15, Paint()..color = color);

    final shoulders = center.translate(0, -height * 0.2);
    final hips = center.translate(0, height * 0.08);
    canvas.drawLine(shoulders, hips, limb);
    canvas.drawLine(
      shoulders.translate(-height * 0.17, height * 0.12),
      shoulders.translate(height * 0.17, striding ? 0 : height * 0.12),
      limb,
    );
    final stride = striding ? height * 0.17 : height * 0.09;
    canvas.drawLine(hips, hips.translate(-stride, height * 0.34), limb);
    canvas.drawLine(hips, hips.translate(stride, height * 0.34), limb);
  }

  @override
  bool shouldRepaint(covariant _ZonesPainter oldDelegate) =>
      oldDelegate.scheme != scheme || oldDelegate.trap != trap;
}
