import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';
import 'package:saobracaj/test/animations/vozilo_bocno.dart';

/// Плакат «Категорија B: чиме сме да се управља» — конспект 34.
///
/// Четыре вопроса (№8499, №8500, №8503, №8504) — один и тот же список,
/// разложенный по разным наборам вариантов. Плакат показывает его целиком:
/// слева под галочкой всё, чем управлять можно, справа под крестом — три
/// постоянные ловушки (трактор, радна машина, мопед). Лента внизу — про
/// четвёртую ловушку, слово *носивост*: в вопросах оно подменяет собой
/// *највећа дозвољена маса*, и вариант с ним неправильный всегда.
class StaSmeKategorijaB extends StatelessWidget {
  const StaSmeKategorijaB({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 462,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

class _ScenePainter extends VoziloScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  @override
  void paint(Canvas canvas, Size size) {
    text(
      canvas,
      'Категорија B: чиме сме да се управља',
      const Offset(200, 14),
      colorScheme.onSurface,
      maxWidth: 396,
      fontSize: 13,
      isBold: true,
    );

    _allowedColumn(canvas);
    _forbiddenColumn(canvas);

    // Лента-предупреждение: не про конкретное ТС, а про подмену термина,
    // поэтому стоит под обеими колонками.
    _ribbon(canvas);
  }

  // --- Левая колонка: можно -------------------------------------------------

  void _allowedColumn(Canvas canvas) {
    const rect = Rect.fromLTRB(2, 30, 246, 410);
    panel(canvas, rect);
    _header(
      canvas,
      const Rect.fromLTRB(10, 38, 238, 62),
      'сме${gloss(' · можно')}',
      fill: colorScheme.tertiaryContainer,
      ink: colorScheme.onTertiaryContainer,
      check: true,
    );

    const rows = 6;
    for (var i = 0; i < rows; i++) {
      final top = 68.0 + i * 56;
      final ground = top + 44;
      // Земля только под пиктограммой: под текстом линия читается как
      // подчёркивание.
      canvas.drawLine(
        Offset(10, ground),
        Offset(88, ground),
        Paint()
          ..color = colorScheme.outline
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      switch (i) {
        case 0:
          // carSide ставит колёса ниже своего rect — компенсируем, чтобы они
          // стояли на земле, а не висели.
          carSide(canvas, Rect.fromLTRB(14, ground - 34, 84, ground - 4));
          _label(canvas, top, 'путничко возило',
              sub: 'највећа дозвољена маса ≤ 3.500 kg');
        case 1:
          _van(canvas, Rect.fromLTRB(16, ground - 32, 82, ground));
          _label(canvas, top, 'теретно возило',
              sub: 'највећа дозвољена маса ≤ 3.500 kg');
        case 2:
          _atv(canvas, Rect.fromLTRB(26, ground - 22, 72, ground));
          _label(canvas, top, 'лаки трицикл,\nлаки четвороцикл');
        case 3:
          _atv(canvas, Rect.fromLTRB(22, ground - 27, 78, ground));
          _label(canvas, top, 'тешки четвороцикл');
        case 4:
          _atv(canvas, Rect.fromLTRB(24, ground - 26, 76, ground));
          _label(canvas, top, 'тешки трицикл',
              sub: '≤ 15 kW — одмах\n> 15 kW — са 21 годином');
        case 5:
          _motocultivator(canvas, Rect.fromLTRB(16, ground - 36, 82, ground));
          _label(canvas, top, 'мотокултиватор');
      }
    }
  }

  void _label(Canvas canvas, double rowTop, String name, {String? sub}) {
    textLeft(
      canvas,
      name,
      Offset(94, rowTop + (sub == null ? 22 : 13)),
      colorScheme.onSurface,
      maxWidth: 146,
      fontSize: 11.5,
      isBold: true,
    );
    if (sub != null) {
      textLeft(
        canvas,
        sub,
        Offset(94, rowTop + 35),
        colorScheme.onSurfaceVariant,
        maxWidth: 146,
        fontSize: 10,
      );
    }
  }

  // --- Правая колонка: нельзя ----------------------------------------------

  void _forbiddenColumn(Canvas canvas) {
    const rect = Rect.fromLTRB(254, 30, 398, 410);
    panel(canvas, rect);
    _header(
      canvas,
      const Rect.fromLTRB(262, 38, 390, 62),
      'не сме${gloss(' · нельзя')}',
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      check: false,
    );

    const names = ['трактор', 'радна машина', 'мопед'];
    for (var i = 0; i < names.length; i++) {
      final top = 72.0 + i * 112;
      final ground = top + 62;
      canvas.drawLine(
        Offset(272, ground),
        Offset(380, ground),
        Paint()
          ..color = colorScheme.outline
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      switch (i) {
        case 0:
          _tractor(canvas, Rect.fromLTRB(286, ground - 48, 366, ground));
        case 1:
          _workMachine(canvas, Rect.fromLTRB(280, ground - 46, 372, ground));
        case 2:
          _moped(canvas, Rect.fromLTRB(296, ground - 38, 356, ground));
      }
      // Косая черта поверх: «нельзя» не должно держаться на одном заголовке.
      banSlash(canvas, Offset(326, ground - 26), 34, width: 5);
      text(
        canvas,
        names[i],
        Offset(326, ground + 16),
        colorScheme.onSurface,
        maxWidth: 132,
        fontSize: 11.5,
        isBold: true,
      );
    }
  }

  void _header(
    Canvas canvas,
    Rect rect,
    String value, {
    required Color fill,
    required Color ink,
    required bool check,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = fill,
    );
    if (check) {
      drawCheck(canvas, Offset(rect.left + 18, rect.center.dy), 7, ink);
    } else {
      drawCross(canvas, Offset(rect.left + 18, rect.center.dy), 6, ink,
          width: 3);
    }
    text(
      canvas,
      value,
      Offset(rect.center.dx + 12, rect.center.dy),
      ink,
      maxWidth: rect.width - 40,
      fontSize: 12.5,
      isBold: true,
    );
  }

  void _ribbon(Canvas canvas) {
    const rect = Rect.fromLTRB(2, 418, 398, 458);
    panel(canvas, rect, fill: colorScheme.errorContainer);
    drawCross(
      canvas,
      Offset(rect.left + 20, rect.center.dy),
      7,
      colorScheme.onErrorContainer,
      width: 3,
    );
    text(
      canvas,
      '„носивост” није „највећа дозвољена маса”'
      '${gloss('\nвариант со словом «носивост» — всегда неправильный')}',
      Offset(rect.center.dx + 12, rect.center.dy),
      colorScheme.onErrorContainer,
      maxWidth: rect.width - 56,
      fontSize: 11,
      isBold: true,
    );
  }

  // --- Пиктограммы ----------------------------------------------------------
  // Все — вид сбоку, носом вправо, колёса стоят на `rect.bottom`. Палитра
  // kVozilo* из vozilo_bocno.dart, чтобы техника на соседних листах конспектов
  // выглядела одинаково.

  Paint get _stroke => Paint()
    ..color = kVoziloStroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  /// Фургон: кузов-короб слева, кабина со скошенным лобовым справа.
  void _van(Canvas canvas, Rect r) {
    final w = r.width;
    final h = r.height;
    final wheelR = h * 0.18;
    final bodyBottom = r.bottom - wheelR;

    final box = Rect.fromLTRB(r.left, r.top, r.left + w * 0.62, bodyBottom);
    canvas.drawRect(box, Paint()..color = kVoziloBody);
    canvas.drawRect(box, _stroke);

    final cabTop = r.top + h * 0.32;
    final cab = Path()
      ..moveTo(box.right, cabTop)
      ..lineTo(r.right - w * 0.10, cabTop)
      ..lineTo(r.right, cabTop + h * 0.22)
      ..lineTo(r.right, bodyBottom)
      ..lineTo(box.right, bodyBottom)
      ..close();
    canvas.drawPath(cab, Paint()..color = kVoziloCab);
    canvas.drawPath(cab, _stroke);
    canvas.drawPath(
      Path()
        ..moveTo(box.right + w * 0.03, cabTop + h * 0.05)
        ..lineTo(r.right - w * 0.12, cabTop + h * 0.05)
        ..lineTo(r.right - w * 0.05, cabTop + h * 0.20)
        ..lineTo(box.right + w * 0.03, cabTop + h * 0.20)
        ..close(),
      Paint()..color = kVoziloGlass,
    );

    wheel(canvas, Offset(r.left + w * 0.18, bodyBottom), wheelR);
    wheel(canvas, Offset(r.right - w * 0.18, bodyBottom), wheelR);
  }

  /// Квадроцикл/трицикл: платформа, седло и руль. Число колёс сбоку всё равно
  /// не видно — различие «трицикл/четвороцикл» несёт подпись.
  void _atv(Canvas canvas, Rect r) {
    final w = r.width;
    final h = r.height;
    final wheelR = h * 0.30;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        r.left + w * 0.06,
        r.bottom - wheelR * 1.9,
        r.right - w * 0.06,
        r.bottom - wheelR * 0.9,
      ),
      Radius.circular(h * 0.14),
    );
    canvas.drawRRect(body, Paint()..color = kVoziloBody);
    canvas.drawRRect(body, _stroke);

    // Седло сзади.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          r.left + w * 0.14,
          body.top - h * 0.18,
          w * 0.30,
          h * 0.18,
        ),
        Radius.circular(h * 0.08),
      ),
      Paint()..color = kVoziloCab,
    );
    // Рулевая колонка и руль спереди.
    // Светлый штрих: тёмный на тёмной теме сливается с фоном (как дышло
    // в prikolica_common.dart).
    final bar = Paint()
      ..color = kVoziloRim
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(r.right - w * 0.24, body.top),
      Offset(r.right - w * 0.16, r.top),
      bar,
    );
    canvas.drawLine(
      Offset(r.right - w * 0.26, r.top + h * 0.04),
      Offset(r.right - w * 0.06, r.top),
      bar,
    );

    wheel(canvas, Offset(r.left + w * 0.22, r.bottom - wheelR), wheelR);
    wheel(canvas, Offset(r.right - w * 0.22, r.bottom - wheelR), wheelR);
  }

  /// Мотокультиватор: одно колесо, мотор над ним, длинные рукоятки назад.
  void _motocultivator(Canvas canvas, Rect r) {
    final w = r.width;
    final h = r.height;
    final wheelR = h * 0.26;
    final cx = r.left + w * 0.58;

    final engine = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, r.bottom - wheelR * 2 - h * 0.14),
        width: w * 0.32,
        height: h * 0.30,
      ),
      Radius.circular(h * 0.06),
    );
    canvas.drawRRect(engine, Paint()..color = kVoziloCab);
    canvas.drawRRect(engine, _stroke);

    // Рукоятки к оператору (он идёт сзади, слева).
    // Светлый штрих: тёмный на тёмной теме сливается с фоном (как дышло
    // в prikolica_common.dart).
    final bar = Paint()
      ..color = kVoziloRim
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - w * 0.10, engine.center.dy),
      Offset(r.left, r.top + h * 0.10),
      bar,
    );
    canvas.drawLine(
      Offset(r.left, r.top + h * 0.10),
      Offset(r.left, r.top),
      bar,
    );
    // Фреза сзади у земли.
    canvas.drawCircle(
      Offset(cx + w * 0.30, r.bottom - h * 0.10),
      h * 0.10,
      Paint()..color = kTeret,
    );

    wheel(canvas, Offset(cx, r.bottom - wheelR), wheelR);
  }

  /// Трактор: большое заднее колесо, маленькое переднее, капот и рама кабины.
  void _tractor(Canvas canvas, Rect r) {
    final w = r.width;
    final h = r.height;
    final rearR = h * 0.32;
    final frontR = h * 0.18;
    final rear = Offset(r.left + rearR + w * 0.02, r.bottom - rearR);
    final front = Offset(r.right - frontR - w * 0.06, r.bottom - frontR);

    // Капот от задней оси к носу.
    final hoodTop = r.bottom - frontR * 2 - h * 0.22;
    final hood = Rect.fromLTRB(
      rear.dx + rearR * 0.3,
      hoodTop,
      r.right - w * 0.02,
      hoodTop + h * 0.24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hood, Radius.circular(h * 0.05)),
      Paint()..color = kVoziloBody,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hood, Radius.circular(h * 0.05)),
      _stroke,
    );
    // Выхлопная труба.
    canvas.drawLine(
      Offset(hood.left + w * 0.10, hood.top),
      Offset(hood.left + w * 0.10, r.top + h * 0.10),
      Paint()
        ..color = kVoziloRim
        ..strokeWidth = 2.5,
    );

    // Рама кабины над задним колесом.
    final roof = Rect.fromLTRB(
      rear.dx - rearR * 0.9,
      r.top,
      rear.dx + rearR * 0.5,
      r.top + h * 0.10,
    );
    canvas.drawRect(roof, Paint()..color = kVoziloCab);
    final post = Paint()
      ..color = kVoziloCab
      ..strokeWidth = 2.5;
    canvas.drawLine(
        Offset(roof.left + 1, roof.bottom), Offset(roof.left + 1, hoodTop), post);
    canvas.drawLine(Offset(roof.right - 1, roof.bottom),
        Offset(roof.right - 1, hoodTop), post);

    wheel(canvas, rear, rearR);
    wheel(canvas, front, frontR);
  }

  /// Радна машина — экскаватор-погрузчик: корпус трактора и ковш спереди.
  void _workMachine(Canvas canvas, Rect r) {
    final w = r.width;
    final h = r.height;
    final wheelR = h * 0.24;
    final rear = Offset(r.left + w * 0.24, r.bottom - wheelR);
    final front = Offset(r.left + w * 0.56, r.bottom - wheelR);

    final body = Rect.fromLTRB(
      r.left + w * 0.06,
      r.bottom - wheelR * 2 - h * 0.20,
      r.left + w * 0.68,
      r.bottom - wheelR,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * 0.06)),
      Paint()..color = kTeret,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * 0.06)),
      _stroke,
    );
    // Кабина над корпусом.
    final cab = Rect.fromLTRB(
      r.left + w * 0.14,
      r.top,
      r.left + w * 0.42,
      body.top,
    );
    canvas.drawRect(cab, Paint()..color = kVoziloCab);
    canvas.drawRect(cab, _stroke);
    canvas.drawRect(
      cab.deflate(3),
      Paint()..color = kVoziloGlass,
    );

    // Стрела к ковшу.
    canvas.drawLine(
      Offset(body.right - w * 0.04, body.top + h * 0.06),
      Offset(r.right - w * 0.10, r.bottom - h * 0.24),
      Paint()
        ..color = kTeret
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    // Ковш: открытый совок у земли.
    canvas.drawPath(
      Path()
        ..moveTo(r.right - w * 0.16, r.bottom - h * 0.30)
        ..lineTo(r.right, r.bottom - h * 0.26)
        ..lineTo(r.right - w * 0.02, r.bottom)
        ..lineTo(r.right - w * 0.18, r.bottom)
        ..close(),
      Paint()..color = kVoziloCab,
    );

    wheel(canvas, rear, wheelR);
    wheel(canvas, front, wheelR);
  }

  /// Мопед: два маленьких колеса, низкая рама, руль на высокой колонке.
  void _moped(Canvas canvas, Rect r) {
    final w = r.width;
    final h = r.height;
    final wheelR = h * 0.24;
    final rear = Offset(r.left + wheelR, r.bottom - wheelR);
    final front = Offset(r.right - wheelR, r.bottom - wheelR);

    final bar = Paint()
      ..color = kVoziloRim
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    // Низкая рама-подножка от заднего колеса к рулевой колонке.
    final deckY = r.bottom - wheelR * 1.7;
    canvas.drawLine(rear, Offset(rear.dx + w * 0.14, deckY), bar);
    canvas.drawLine(
      Offset(rear.dx + w * 0.14, deckY),
      Offset(front.dx - w * 0.12, deckY),
      bar,
    );
    // Рулевая колонка и вилка.
    canvas.drawLine(
      Offset(front.dx - w * 0.12, deckY),
      Offset(front.dx - w * 0.02, r.top + h * 0.06),
      bar,
    );
    canvas.drawLine(Offset(front.dx - w * 0.02, r.top + h * 0.06), front, bar);
    // Руль: один штрих назад-вверх от верха колонки.
    canvas.drawLine(
      Offset(front.dx - w * 0.02, r.top + h * 0.06),
      Offset(front.dx - w * 0.18, r.top),
      bar,
    );
    // Седло на стойке над задним колесом.
    canvas.drawLine(
        Offset(rear.dx + w * 0.10, deckY), Offset(rear.dx + w * 0.10, r.top + h * 0.26), bar);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rear.dx + w * 0.12, r.top + h * 0.22),
          width: w * 0.26,
          height: h * 0.10,
        ),
        Radius.circular(h * 0.05),
      ),
      Paint()..color = kVoziloCab,
    );

    wheel(canvas, rear, wheelR);
    wheel(canvas, front, wheelR);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.colorScheme != colorScheme || old.gloss != gloss;
}
