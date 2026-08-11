// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Где людей не везут вообще — и единственное место, где везут.
///
/// Три запрещённых сюжета (кузов грузовика, закрытый отсек без ручки изнутри,
/// жилой прицеп) идут подряд одинаковыми панелями с крестом, четвёртая панель
/// с галочкой показывает разрешённое: штатные места и число мест из
/// *саобраћајне дозволе*. Одинаковая рамка и одинаковое место подписи нужны
/// затем, чтобы четвёртая панель читалась как ответ на первые три.
///
/// Слаг в `animations_map.dart`: `zabranjena-mesta-za-lica`.
class ZabranjenaMestaZaLica extends StatelessWidget {
  const ZabranjenaMestaZaLica({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 700,
          child: CustomPaint(
            painter: _ZabranjenaMestaPainter(
              Theme.of(context).colorScheme,
              _Labels.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские пояснения. Сербские формулировки из правил (*простор за превоз
/// терета*, *камп приколица*, *саобраћајна дозвола*) не переводятся.
class _Labels {
  const _Labels({
    required this.cargoBed,
    required this.lockedSpace,
    required this.camper,
    required this.allowed,
  });

  factory _Labels.of(BuildContext context) => _Labels(
        cargoBed: context.tr(LocaleKeys.zabranjenaMesta_cargoBed),
        lockedSpace: context.tr(LocaleKeys.zabranjenaMesta_lockedSpace),
        camper: context.tr(LocaleKeys.zabranjenaMesta_camper),
        allowed: context.tr(LocaleKeys.zabranjenaMesta_allowed),
      );

  final String cargoBed;
  final String lockedSpace;
  final String camper;
  final String allowed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Labels &&
          other.cargoBed == cargoBed &&
          other.lockedSpace == lockedSpace &&
          other.camper == camper &&
          other.allowed == allowed;

  @override
  int get hashCode => Object.hash(cargoBed, lockedSpace, camper, allowed);
}

class _ZabranjenaMestaPainter extends IllustrationPainter {
  _ZabranjenaMestaPainter(super.colorScheme, this.labels);

  final _Labels labels;

  // Каждая панель рисуется в своих координатах (0,0 — её левый верхний угол),
  // поэтому сюжет можно двигать по вертикали, не пересчитывая всю геометрию.
  static const double _panelWidth = 384;
  static const double _panelHeight = 148;

  /// Сюжет всегда слева, вердикт всегда справа — глаз не ищет, где что.
  static const Rect _verdictSlot = Rect.fromLTRB(212, 12, 372, 136);

  @override
  void paint(Canvas canvas, Size size) {
    _panel(canvas, 8, _panelHeight, _cargoBedScene);
    _panel(canvas, 164, _panelHeight, _lockedSpaceScene);
    _panel(canvas, 320, _panelHeight, _camperScene);
    _panel(canvas, 476, 214, _allowedScene);
  }

  void _panel(
    Canvas canvas,
    double top,
    double height,
    void Function(Canvas canvas) scene,
  ) {
    panelFrame(canvas, Rect.fromLTWH(8, top, _panelWidth, height));
    canvas.save();
    canvas.translate(8, top);
    scene(canvas);
    canvas.restore();
  }

  // ============ 1. КУЗОВ ГРУЗОВИКА: «простор за превоз терета» ============

  void _cargoBedScene(Canvas canvas) {
    final truck = drawTruckProfile(
      canvas,
      this,
      const Rect.fromLTRB(12, 36, 188, 126),
    );

    // Люди сидят в кузове — ровно то, чего делать нельзя.
    for (final x in [38.0, 68.0, 98.0]) {
      person(
        canvas,
        Offset(x, truck.bed.bottom - 8),
        36,
        colorScheme.onSurfaceVariant,
        sitting: true,
      );
    }

    crossOutRect(
      canvas,
      const Rect.fromLTRB(14, 32, 190, 130),
      colorScheme.error,
    );
    _verdict(
      canvas,
      _verdictSlot,
      'простор за превоз терета',
      labels.cargoBed,
      allowed: false,
    );
  }

  // ====== 2. ЗАКРЫТЫЙ ОТСЕК: «не може се изнутра отворити» ======

  void _lockedSpaceScene(Canvas canvas) {
    final body = Paint()..color = colorScheme.surfaceContainerHighest;
    final outline = Paint()
      ..color = colorScheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Фургон: глухой ящик и скошенный передок. Окон в отсеке нет — это и есть
    // «затворени простор».
    const box = Rect.fromLTRB(18, 30, 124, 102);
    canvas.drawRect(box, body);
    canvas.drawRect(box, outline);
    final nose = Path()
      ..moveTo(124, 30)
      ..lineTo(152, 30)
      ..lineTo(176, 58)
      ..lineTo(176, 102)
      ..lineTo(124, 102)
      ..close();
    canvas.drawPath(nose, body);
    canvas.drawPath(nose, outline);
    canvas.drawRect(
      const Rect.fromLTRB(142, 38, 170, 60),
      Paint()..color = colorScheme.surface,
    );
    wheel(canvas, const Offset(50, 106), 13);
    wheel(canvas, const Offset(154, 106), 13);

    // Человек заперт внутри отсека.
    person(canvas, const Offset(78, 96), 54, colorScheme.onSurfaceVariant);

    // Задняя дверь и место, где нет внутренней ручки: перечёркнутый кружок.
    canvas.drawLine(const Offset(52, 30), const Offset(52, 102), outline);
    canvas.drawCircle(
      const Offset(40, 66),
      6,
      Paint()
        ..color = colorScheme.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    drawCross(canvas, const Offset(40, 66), 9, colorScheme.error, width: 2.5);

    crossOutRect(
      canvas,
      const Rect.fromLTRB(16, 24, 178, 112),
      colorScheme.error,
    );
    _verdict(
      canvas,
      _verdictSlot,
      'не може се изнутра отворити',
      labels.lockedSpace,
      allowed: false,
    );
  }

  // ============ 3. ЖИЛОЙ ПРИЦЕП: «камп приколица» ============

  void _camperScene(Canvas canvas) {
    final body = Paint()..color = colorScheme.surfaceContainerHighest;
    final outline = Paint()
      ..color = colorScheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Прицеп-дача слева, тягач справа: сцена читается «слева направо» как
    // «то, что тянут» и «то, что тянет».
    final caravan = RRect.fromRectAndCorners(
      const Rect.fromLTRB(10, 40, 96, 94),
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
    );
    canvas.drawRRect(caravan, body);
    canvas.drawRRect(caravan, outline);
    canvas.drawRect(
      const Rect.fromLTRB(20, 50, 50, 76),
      Paint()..color = colorScheme.surface,
    );
    canvas.drawRect(const Rect.fromLTRB(20, 50, 50, 76), outline);
    // Человек в окне прицепа — голова и плечи.
    canvas.drawCircle(
      const Offset(35, 60),
      7,
      Paint()..color = colorScheme.onSurfaceVariant,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(25, 70, 45, 76),
        const Radius.circular(3),
      ),
      Paint()..color = colorScheme.onSurfaceVariant,
    );
    wheel(canvas, const Offset(54, 94), 11);
    // Дышло к тягачу.
    canvas.drawLine(const Offset(96, 84), const Offset(112, 90), outline);

    drawCarProfile(canvas, this, const Rect.fromLTRB(110, 40, 200, 104));

    crossOutRect(
      canvas,
      const Rect.fromLTRB(12, 34, 198, 110),
      colorScheme.error,
    );
    _verdict(
      canvas,
      _verdictSlot,
      'камп приколица',
      labels.camper,
      allowed: false,
    );
  }

  // ====== 4. КАК МОЖНО: штатные места и число из документа ======

  void _allowedScene(Canvas canvas) {
    final car = drawCarProfile(
      canvas,
      this,
      const Rect.fromLTRB(14, 20, 154, 96),
    );

    // Пассажиры на штатных сиденьях: головы в салоне и лента ремня через
    // плечо у каждого.
    for (final x in [58.0, 94.0]) {
      canvas.drawCircle(
        Offset(x, car.cabin.top + 12),
        7,
        Paint()..color = colorScheme.onSurfaceVariant,
      );
      canvas.drawLine(
        Offset(x - 7, car.cabin.top + 20),
        Offset(x + 7, car.cabin.bottom + 4),
        Paint()
          ..color = colorScheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Раскрытая саобраћајна дозвола: число мест — подсвеченная строка.
    const doc = Rect.fromLTRB(216, 16, 320, 96);
    canvas.drawRRect(
      RRect.fromRectAndRadius(doc, const Radius.circular(6)),
      Paint()..color = colorScheme.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(doc, const Radius.circular(6)),
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Строки документа — просто линии: текст в них всё равно не прочитать.
    final ruled = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 2;
    for (final y in [28.0, 36.0]) {
      canvas.drawLine(Offset(doc.left + 8, y), Offset(doc.right - 8, y), ruled);
    }
    final highlight = Rect.fromLTRB(doc.left + 6, 44, doc.right - 6, 88);
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlight, const Radius.circular(4)),
      Paint()..color = colorScheme.tertiaryContainer,
    );
    text(
      canvas,
      'број места',
      Offset(highlight.center.dx, 56),
      colorScheme.onTertiaryContainer,
      maxWidth: highlight.width - 6,
      fontSize: 12,
    );
    text(
      canvas,
      '5',
      Offset(highlight.center.dx, 76),
      colorScheme.onTertiaryContainer,
      maxWidth: highlight.width - 6,
      fontSize: 20,
      isBold: true,
    );
    arrow(canvas, const Offset(212, 56), const Offset(170, 56));

    // Вердикт занимает всю ширину панели: подпись тут длиннее, чем у
    // запрещающих сюжетов, и в узкую колонку не влезает.
    _verdict(
      canvas,
      const Rect.fromLTRB(12, 104, 372, 202),
      'саобраћајна дозвола',
      labels.allowed,
      allowed: true,
    );
  }

  // ============================ ПРИМИТИВЫ ============================

  /// Вердикт панели: маркер (крест / галочка), сербский термин и русское
  /// пояснение. Строки раскладываются по измеренной высоте — при длинном
  /// переводе подписи не наедут друг на друга. Смысл держится не только на
  /// цвете: рядом с красным всегда стоит «није дозвољено».
  void _verdict(
    Canvas canvas,
    Rect rect,
    String term,
    String note, {
    required bool allowed,
  }) {
    final fill =
        allowed ? colorScheme.tertiaryContainer : colorScheme.errorContainer;
    final ink = allowed
        ? colorScheme.onTertiaryContainer
        : colorScheme.onErrorContainer;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final markerCenter = Offset(rect.left + 22, rect.top + 20);
    if (allowed) {
      drawCheck(canvas, markerCenter, 10, ink);
    } else {
      drawCross(canvas, markerCenter, 9, ink, width: 3.5);
    }
    text(
      canvas,
      allowed ? 'дозвољено' : 'није дозвољено',
      Offset((rect.left + 40 + rect.right) / 2, rect.top + 20),
      ink,
      maxWidth: rect.width - 48,
      fontSize: 12,
      isBold: true,
    );

    final width = rect.width - 20;
    var y = rect.top + 42;
    final termSize = measure(
      term,
      maxWidth: width,
      fontSize: 12,
      isBold: true,
      isItalic: true,
    );
    text(
      canvas,
      term,
      Offset(rect.center.dx, y + termSize.height / 2),
      ink,
      maxWidth: width,
      fontSize: 12,
      isBold: true,
      isItalic: true,
    );
    y += termSize.height + 8;
    final noteSize = measure(note, maxWidth: width, fontSize: 11);
    text(
      canvas,
      note,
      Offset(rect.center.dx, y + noteSize.height / 2),
      ink,
      maxWidth: width,
      fontSize: 11,
    );
  }

  @override
  bool shouldRepaint(covariant _ZabranjenaMestaPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.labels != labels;
}
