import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/alkohol_common.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';

/// Список тех, кому нельзя ни грамма, одним плакатом.
///
/// Семь вопросов раздела (№8069, №8070, №8075, №8076, №8080, №8081, №10408)
/// спрашивают про семь разных ТС и водителей, но ответ у всех один — ноль.
/// Плакат показывает весь список сразу: пока он выглядит как семь отдельных
/// правил, каждое приходится вспоминать заново.
///
/// Внизу, за красной чертой, — два исключения (*мотокултиватор* и *пробна
/// вожња*): в №8070 это именно те варианты, которые отмечать не надо.
class NulaPromila extends StatelessWidget {
  const NulaPromila({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 590,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

/// Цвета, которые несут смысл сами по себе: оранжевая табличка опасного груза,
/// синий маячок, красный крест скорой, белые таблички «L» и «П».
///
/// Кузов и колёса тоже литеральные, и это не оплошность: если брать их из
/// темы, на тёмной теме светлый кузов и светлые колёса сливаются в пятно.
/// Серый кузов с тёмными шинами одинаково читается на обеих темах — так же,
/// как асфальт в дорожных сценах.
const _hazardPlate = Color(0xFFFF9800);
const _beaconBlue = Color(0xFF1E88E5);
const _crossRed = Color(0xFFD32F2F);
const _plateFace = Color(0xFFF7F7F7);
const _plateInk = Color(0xFF17191C);
const _vehicleBody = Color(0xFF7A828C);
const _vehicleTrim = Color(0xFF59616B);
const _vehicleGlass = Color(0xFFE8EDF2);
const _tire = Color(0xFF1B1E22);

typedef _Icon = void Function(Canvas, Rect);

class _ScenePainter extends AlkoholScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  /// Сетка 3×3: семь карточек списка (последняя — во всю ширину) плюс блок
  /// исключений. Ширина карточки 128 — минимум, при котором сербский термин
  /// вроде «пробна возачка дозвола» ложится в две строки, а не в четыре.
  static const _cellW = 128.0;
  static const _cellH = 122.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    _header(canvas);
    _grid(canvas);
    _exceptions(canvas);
  }

  void _header(Canvas canvas) {
    const rect = Rect.fromLTRB(2, 2, 398, 70);
    panel(canvas, rect, fill: colorScheme.primaryContainer);
    glassIcon(canvas, const Offset(36, 34), 32, colorScheme.onPrimaryContainer);
    glassIcon(canvas, const Offset(364, 34), 32, colorScheme.onPrimaryContainer);
    text(
      canvas,
      '0,00 mg/ml',
      const Offset(200, 24),
      colorScheme.onPrimaryContainer,
      maxWidth: 240,
      fontSize: 22,
      isBold: true,
    );
    text(
      canvas,
      'не сме да има алкохола у крви / у организму'
      '${gloss(' · ответ всегда «ноль»')}',
      const Offset(200, 54),
      colorScheme.onPrimaryContainer,
      maxWidth: 250,
      fontSize: 10.5,
    );
  }

  void _grid(Canvas canvas) {
    const top = 78.0;
    final cells = <List<Object>>[
      ['опасне материје', gloss('опасные грузы'), _tanker],
      ['ванредни превоз', gloss('негабарит'), _oversize],
      ['кандидат за возача', gloss('ученик на обучении'), _learnerCar],
      ['пробна возачка дозвола', gloss('новичок с «П»'), _probnaCar],
      ['право првенства пролаза', gloss('скорая, пожарные, полиция'), _emergency],
      ['јавни превоз ствари', gloss('грузы по найму'), _van],
    ];

    for (var i = 0; i < cells.length; i++) {
      final rect = Rect.fromLTWH(
        2 + (i % 3) * (_cellW + _gap),
        top + (i ~/ 3) * (_cellH + _gap),
        _cellW,
        _cellH,
      );
      _cell(
        canvas,
        rect,
        title: cells[i][0] as String,
        gloss: cells[i][1] as String,
        icon: cells[i][2] as _Icon,
      );
    }

    // Автобус — во всю ширину: рисовать его в узкой ячейке значит превратить
    // в тот же фургон, а в вопросе №10408 разница именно «ствари» / «лица».
    final wide = Rect.fromLTWH(2, top + 2 * (_cellH + _gap), 396, 92);
    panel(canvas, wide);
    _bus(canvas, Rect.fromLTWH(wide.left + 12, wide.top + 16, 176, 58));
    _banBadge(canvas, Offset(wide.right - 24, wide.top + 22));
    textLeft(
      canvas,
      'јавни превоз лица',
      Offset(wide.left + 204, wide.center.dy - 10),
      colorScheme.onSurface,
      maxWidth: 160,
      fontSize: 12.5,
      isBold: true,
    );
    if (gloss.isRussian) {
      textLeft(
        canvas,
        'пассажирские перевозки\nпо найму',
        Offset(wide.left + 204, wide.center.dy + 20),
        colorScheme.onSurfaceVariant,
        maxWidth: 160,
        fontSize: 10.5,
      );
    }
  }

  void _cell(
    Canvas canvas,
    Rect rect, {
    required String title,
    required String gloss,
    required _Icon icon,
  }) {
    panel(canvas, rect);
    icon(canvas, Rect.fromLTWH(rect.left + 8, rect.top + 12, rect.width - 16, 46));
    _banBadge(canvas, Offset(rect.right - 20, rect.top + 18));
    text(
      canvas,
      title,
      Offset(rect.center.dx, rect.top + 80),
      colorScheme.onSurface,
      maxWidth: rect.width - 12,
      fontSize: 11.5,
      isBold: true,
    );
    if (gloss.isNotEmpty) {
      text(
        canvas,
        gloss,
        Offset(rect.center.dx, rect.top + 108),
        colorScheme.onSurfaceVariant,
        maxWidth: rect.width - 12,
        fontSize: 10.5,
      );
    }
  }

  /// Перечёркнутая рюмка в углу карточки — «этому ноль».
  void _banBadge(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      15,
      Paint()..color = colorScheme.surface,
    );
    glassIcon(canvas, center, 20, colorScheme.onSurfaceVariant);
  }

  /// Исключения: те, кого в списке «нула» нет, хотя в вопросе они рядом.
  void _exceptions(Canvas canvas) {
    canvas.drawLine(
      const Offset(2, 454),
      const Offset(398, 454),
      Paint()
        ..color = kBanRed
        ..strokeWidth = 3,
    );
    chip(
      canvas,
      // Сербская строка самодостаточна: на сербской локали пояснения нет,
      // а одно «НЕ» без продолжения ничего не значит.
      'НЕ важи правило „нула“${gloss(' — на них не распространяется')}',
      const Rect.fromLTRB(2, 440, 310, 468),
      fill: kBanRed,
      ink: Colors.white,
      fontSize: 11.5,
    );

    _exception(
      canvas,
      const Rect.fromLTRB(2, 478, 197, 566),
      title: 'мотокултиватор',
      icon: _motocultivator,
    );
    _exception(
      canvas,
      const Rect.fromLTRB(203, 478, 398, 566),
      title: 'пробна вожња',
      icon: _testDriveCar,
    );
    text(
      canvas,
      'за њих важи општи праг 0,20 mg/ml'
      '${gloss(' · в №8070 это приманки')}',
      const Offset(200, 580),
      colorScheme.onSurfaceVariant,
      maxWidth: 392,
      fontSize: 11,
    );
  }

  void _exception(
    Canvas canvas,
    Rect rect, {
    required String title,
    required _Icon icon,
  }) {
    panel(canvas, rect, fill: colorScheme.surfaceContainerHighest);
    icon(canvas, Rect.fromLTWH(rect.left + 30, rect.top + 10, rect.width - 60, 44));
    text(
      canvas,
      title,
      Offset(rect.center.dx, rect.top + 70),
      colorScheme.onSurface,
      maxWidth: rect.width - 12,
      fontSize: 12.5,
      isBold: true,
    );
  }

  // --- Пиктограммы ТС, вид сбоку -------------------------------------------
  //
  // Все машины рисуются в отведённом прямоугольнике в долях его размера:
  // одна и та же функция годится и для ячейки 112×46, и для широкой полосы
  // автобуса, а силуэты остаются соразмерными друг другу.

  Paint get _bodyPaint => Paint()..color = _vehicleBody;

  void _wheels(Canvas canvas, Rect r, List<double> fractions) {
    final radius = r.height * 0.16;
    for (final f in fractions) {
      canvas.drawCircle(
        Offset(r.left + r.width * f, r.bottom - radius * 0.6),
        radius,
        Paint()..color = _tire,
      );
    }
  }

  void _box(Canvas canvas, Rect rect, {Color? color, double radius = 3}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      color == null ? _bodyPaint : (Paint()..color = color),
    );
  }

  /// Табличка с буквой — «L» у кандидата, «П» у новичка, «проба» на пробной.
  void _plate(Canvas canvas, Offset center, String value, {double width = 18}) {
    final rect = Rect.fromCenter(center: center, width: width, height: 16);
    _box(canvas, rect, color: _plateFace, radius: 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = _plateInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    text(
      canvas,
      value,
      center,
      _plateInk,
      maxWidth: width - 2,
      fontSize: value.length > 1 ? 8 : 11,
      isBold: true,
    );
  }

  /// Кабина + цилиндрическая цистерна + оранжевая табличка опасного груза.
  void _tanker(Canvas canvas, Rect r) {
    final bodyTop = r.top + r.height * 0.30;
    _box(canvas, Rect.fromLTRB(r.left, bodyTop, r.left + r.width * 0.26, r.bottom - r.height * 0.18));
    _box(
      canvas,
      Rect.fromLTRB(r.left + r.width * 0.28, r.top + r.height * 0.22,
          r.right, r.bottom - r.height * 0.22),
      radius: r.height * 0.28,
    );
    _wheels(canvas, r, [0.14, 0.55, 0.72, 0.88]);
    _box(
      canvas,
      Rect.fromLTWH(r.left + r.width * 0.30, r.bottom - r.height * 0.30,
          r.width * 0.16, r.height * 0.20),
      color: _hazardPlate,
      radius: 1,
    );
  }

  /// Тягач с грузом, свисающим за платформу, — «ванредни превоз».
  ///
  /// Негабарит виден только по свесу: груз нарочно длиннее платформы и торчит
  /// за задний борт, а на торце висит красная табличка обозначения.
  void _oversize(Canvas canvas, Rect r) {
    _box(canvas, Rect.fromLTRB(r.left, r.top + r.height * 0.40,
        r.left + r.width * 0.22, r.bottom - r.height * 0.18));
    // Платформа — заметно короче груза.
    _box(canvas, Rect.fromLTRB(r.left + r.width * 0.22, r.bottom - r.height * 0.38,
        r.left + r.width * 0.66, r.bottom - r.height * 0.20));
    _wheels(canvas, r, [0.11, 0.40, 0.54, 0.62]);
    // Груз: выше кабины и со свесом вправо.
    // Правый край груза не доводится до угла ячейки: там стоит значок рюмки.
    final load = Rect.fromLTRB(r.left + r.width * 0.24, r.top + r.height * 0.20,
        r.right - 10, r.bottom - r.height * 0.38);
    _box(canvas, load, color: _vehicleTrim);
    // Торец свеса помечен красным — так обозначают выступающий груз.
    _box(
      canvas,
      Rect.fromLTRB(load.right - 6, load.top, load.right, load.bottom),
      color: _crossRed,
      radius: 1,
    );
  }

  /// Легковой автомобиль сбоку. [plate] — табличка на крыше, если нужна.
  void _carSide(Canvas canvas, Rect r, {String? plate, double plateWidth = 18}) {
    final bottom = r.bottom - r.height * 0.18;
    _box(
      canvas,
      Rect.fromLTRB(r.left + r.width * 0.06, r.top + r.height * 0.48, r.right - r.width * 0.06, bottom),
      radius: r.height * 0.16,
    );
    // Кабина — трапеция: без неё сбоку получается просто брусок.
    canvas.drawPath(
      Path()
        ..moveTo(r.left + r.width * 0.26, r.top + r.height * 0.50)
        ..lineTo(r.left + r.width * 0.36, r.top + r.height * 0.20)
        ..lineTo(r.left + r.width * 0.64, r.top + r.height * 0.20)
        ..lineTo(r.left + r.width * 0.74, r.top + r.height * 0.50)
        ..close(),
      _bodyPaint,
    );
    _wheels(canvas, r, [0.26, 0.74]);
    if (plate != null) {
      _plate(canvas, Offset(r.center.dx, r.top + r.height * 0.10), plate,
          width: plateWidth);
    }
  }

  void _learnerCar(Canvas canvas, Rect r) => _carSide(canvas, r, plate: 'L');

  void _probnaCar(Canvas canvas, Rect r) => _carSide(canvas, r, plate: 'П');

  void _testDriveCar(Canvas canvas, Rect r) =>
      _carSide(canvas, r, plate: 'проба', plateWidth: 34);

  /// Скорая: фургон с красным крестом и синим маячком.
  void _emergency(Canvas canvas, Rect r) {
    final bottom = r.bottom - r.height * 0.18;
    _box(canvas, Rect.fromLTRB(r.left + r.width * 0.30, r.top + r.height * 0.24, r.right - r.width * 0.06, bottom));
    _box(canvas, Rect.fromLTRB(r.left + r.width * 0.06, r.top + r.height * 0.48, r.left + r.width * 0.32, bottom));
    _wheels(canvas, r, [0.24, 0.74]);

    final cross = Offset(r.left + r.width * 0.62, r.center.dy + r.height * 0.06);
    final arm = r.height * 0.16;
    final red = Paint()
      ..color = _crossRed
      ..strokeWidth = arm * 0.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(cross - Offset(arm, 0), cross + Offset(arm, 0), red);
    canvas.drawLine(cross - Offset(0, arm), cross + Offset(0, arm), red);

    _box(
      canvas,
      Rect.fromLTWH(r.left + r.width * 0.46, r.top + r.height * 0.10, r.width * 0.16, r.height * 0.14),
      color: _beaconBlue,
      radius: 2,
    );
  }

  /// Фургон: тот же кузов, но глухой — «превоз ствари».
  void _van(Canvas canvas, Rect r) {
    final bottom = r.bottom - r.height * 0.18;
    _box(canvas, Rect.fromLTRB(r.left + r.width * 0.28, r.top + r.height * 0.20, r.right - r.width * 0.06, bottom));
    _box(canvas, Rect.fromLTRB(r.left + r.width * 0.06, r.top + r.height * 0.48, r.left + r.width * 0.30, bottom));
    _wheels(canvas, r, [0.22, 0.74]);
    // Створки задней двери — чтобы фургон не путался с автобусом.
    canvas.drawLine(
      Offset(r.right - r.width * 0.20, r.top + r.height * 0.24),
      Offset(r.right - r.width * 0.20, bottom - 2),
      Paint()
        ..color = _vehicleGlass
        ..strokeWidth = 2,
    );
  }

  /// Автобус: длинный кузов с рядом окон и дверью.
  void _bus(Canvas canvas, Rect r) {
    final bottom = r.bottom - r.height * 0.18;
    _box(canvas, Rect.fromLTRB(r.left, r.top + r.height * 0.12, r.right, bottom),
        radius: r.height * 0.12);
    _wheels(canvas, r, [0.16, 0.82]);

    final glass = Paint()..color = _vehicleGlass;
    for (var i = 0; i < 5; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            r.left + r.width * (0.08 + i * 0.17),
            r.top + r.height * 0.24,
            r.width * 0.12,
            r.height * 0.24,
          ),
          const Radius.circular(2),
        ),
        glass,
      );
    }
    // Дверь — вертикальная створка до низа кузова.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left + r.width * 0.60, r.top + r.height * 0.24,
            r.width * 0.10, r.height * 0.56),
        const Radius.circular(2),
      ),
      glass,
    );
  }

  /// Мотокультиватор: моторный блок на одном колесе и длинные ручки.
  void _motocultivator(Canvas canvas, Rect r) {
    final wheel = Offset(r.left + r.width * 0.34, r.bottom - r.height * 0.20);
    canvas.drawCircle(wheel, r.height * 0.24, Paint()..color = _tire);
    canvas.drawCircle(wheel, r.height * 0.10, Paint()..color = _vehicleGlass);
    _box(
      canvas,
      Rect.fromLTWH(r.left + r.width * 0.16, r.top + r.height * 0.28,
          r.width * 0.36, r.height * 0.32),
    );
    canvas.drawLine(
      Offset(r.left + r.width * 0.50, r.top + r.height * 0.44),
      Offset(r.right - r.width * 0.04, r.top + r.height * 0.06),
      Paint()
        ..color = colorScheme.onSurfaceVariant
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(r.right - r.width * 0.14, r.top + r.height * 0.16),
      Offset(r.right - r.width * 0.02, r.top + r.height * 0.22),
      Paint()
        ..color = colorScheme.onSurfaceVariant
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.gloss != gloss;
}
