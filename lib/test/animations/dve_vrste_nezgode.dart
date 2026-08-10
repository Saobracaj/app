// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Два вида ДТП рядом: *тешка незгода* сверху, *мања материјална штета* снизу.
///
/// Панели намеренно устроены одинаково (шапка → сцена вид сверху → два
/// вывода), и различие видно по одному месту: где стоят машины. Наверху они
/// остались на *коловозу* там, где столкнулись, внизу — уже на обочине, а
/// проезжая часть свободна. Почти каждый вопрос категории проверяет ровно
/// это различие, поэтому оно и вынесено в геометрию, а не только в подписи.
///
/// Панели идут одна под другой, а не слева направо: на телефоне половинка
/// шириной 200 не вмещает ни машину с подписью, ни таблицу выводов.
///
/// Слаг в `animations_map.dart`: `dve-vrste-nezgode`.
class DveVrsteNezgode extends StatelessWidget {
  const DveVrsteNezgode({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 560,
          child: CustomPaint(
            painter: _DveVrstePainter(
              Theme.of(context).colorScheme,
              _Labels.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские пояснения. Сербские термины из правил (*тешка незгода*, *коловоз*,
/// *увиђај*, *Европски извештај*) остаются как есть — их и спрашивают.
class _Labels {
  const _Labels({
    required this.severeWhat,
    required this.minorWhat,
    required this.doNotMove,
    required this.callServices,
    required this.clearRoad,
    required this.noPolice,
  });

  factory _Labels.of(BuildContext context) => _Labels(
        severeWhat: context.tr(LocaleKeys.dveVrsteNezgode_severeWhat),
        minorWhat: context.tr(LocaleKeys.dveVrsteNezgode_minorWhat),
        doNotMove: context.tr(LocaleKeys.dveVrsteNezgode_doNotMove),
        callServices: context.tr(LocaleKeys.dveVrsteNezgode_callServices),
        clearRoad: context.tr(LocaleKeys.dveVrsteNezgode_clearRoad),
        noPolice: context.tr(LocaleKeys.dveVrsteNezgode_noPolice),
      );

  final String severeWhat;
  final String minorWhat;
  final String doNotMove;
  final String callServices;
  final String clearRoad;
  final String noPolice;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Labels &&
          other.severeWhat == severeWhat &&
          other.minorWhat == minorWhat &&
          other.doNotMove == doNotMove &&
          other.callServices == callServices &&
          other.clearRoad == clearRoad &&
          other.noPolice == noPolice;

  @override
  int get hashCode => Object.hash(
        severeWhat,
        minorWhat,
        doNotMove,
        callServices,
        clearRoad,
        noPolice,
      );
}

/// Асфальт и разметка — цвета-содержание: они одинаковы во всех сценах и в
/// обеих темах, иначе «дорога» перестаёт читаться как дорога.
const Color kAsphalt = Color(0xFF5A6068);
const Color kShoulder = Color(0xFF8B8377);
const Color kMarking = Color(0xFFF2F2F2);
const Color kCarBlue = Color(0xFF3B6FD4);
const Color kCarGreen = Color(0xFF3E8E52);
const Color kSignalRed = Color(0xFFD32F2F);

class _DveVrstePainter extends IllustrationPainter {
  _DveVrstePainter(super.colorScheme, this.labels);

  final _Labels labels;

  @override
  void paint(Canvas canvas, Size size) {
    _severePanel(canvas, const Rect.fromLTRB(6, 4, 394, 272));
    _minorPanel(canvas, const Rect.fromLTRB(6, 284, 394, 556));
  }

  @override
  bool shouldRepaint(covariant _DveVrstePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.labels != labels;

  // ================= ВЕРХ: ТЕШКА НЕЗГОДА =================

  void _severePanel(Canvas canvas, Rect panel) {
    panelFrame(canvas, panel, border: colorScheme.error);
    _header(
      canvas,
      panel,
      'тешка незгода',
      labels.severeWhat,
      colorScheme.errorContainer,
      colorScheme.onErrorContainer,
    );

    // Дорога: две полосы, обе заняты — уезжать нельзя.
    const road = Rect.fromLTRB(6, 52, 394, 170);
    _asphalt(canvas, road);
    _dashedCenterLine(canvas, road);

    // Полиция подъезжает слева, скорая — справа: обе службы вызваны.
    drawCarTopView(
      canvas,
      this,
      const Rect.fromLTWH(8, 60, 84, 36),
      body: colorScheme.surfaceContainerHighest,
      beacon: true,
    );
    drawCarTopView(
      canvas,
      this,
      const Rect.fromLTWH(302, 116, 86, 36),
      body: const Color(0xFFF1F1F1),
      noseRight: false,
      ambulanceCross: true,
    );

    // Участники стоят ровно там, где столкнулись: носы смяты, машины
    // перегородили обе полосы.
    drawCarTopView(
      canvas,
      this,
      const Rect.fromLTWH(112, 60, 94, 38),
      body: kCarBlue,
      damagedFront: true,
      hazardOn: true,
    );
    drawCarTopView(
      canvas,
      this,
      const Rect.fromLTWH(196, 114, 94, 38),
      body: kCarGreen,
      noseRight: false,
      damagedFront: true,
      hazardOn: true,
    );
    _impact(canvas, const Offset(202, 108));

    // Пострадавший лежит на коловозу — из-за него ничего не двигают.
    drawPersonTopView(canvas, const Offset(150, 138), 22, const Color(0xFF23272B),
        lying: true);
    _triangleSign(canvas, const Offset(52, 140), 15);

    // Кто есть кто на сцене: без подписей белая машина с маячком читается как
    // ещё один участник.
    roadLabel(canvas, 'полиција', const Offset(50, 106));
    roadLabel(canvas, 'хитна помоћ', const Offset(340, 162));

    _noMoveBadge(canvas, const Offset(330, 72), 20);

    _verdict(
      canvas,
      const Rect.fromLTRB(16, 180, 384, 218),
      labels.doNotMove,
      allowed: false,
    );
    _verdict(
      canvas,
      const Rect.fromLTRB(16, 224, 384, 262),
      labels.callServices,
      allowed: true,
    );
  }

  // ============= НИЗ: МАЊА МАТЕРИЈАЛНА ШТЕТА =============

  void _minorPanel(Canvas canvas, Rect panel) {
    panelFrame(canvas, panel, border: colorScheme.tertiary);
    _header(
      canvas,
      panel,
      'мања материјална штета',
      labels.minorWhat,
      colorScheme.tertiaryContainer,
      colorScheme.onTertiaryContainer,
    );

    const road = Rect.fromLTRB(6, 332, 394, 400);
    const shoulder = Rect.fromLTRB(6, 400, 394, 458);
    _asphalt(canvas, road);
    canvas.drawRect(shoulder, Paint()..color = kShoulder);
    // Сплошная линия — граница коловоза: видно, что машины уже за ней.
    canvas.drawLine(
      Offset(road.left, road.bottom - 2),
      Offset(road.right, road.bottom - 2),
      Paint()
        ..color = kMarking
        ..strokeWidth = 3,
    );
    _dashes(canvas, 356, road.left + 10, road.right - 10);

    roadLabel(canvas, 'коловоз слободан', const Offset(150, 372),
        fontSize: 13);
    _triangleSign(canvas, const Offset(322, 372), 15);

    // Машины уже на обочине: та же геометрия, что наверху, но сдвинута за
    // край коловоза — в этом и весь ответ.
    drawCarTopView(
      canvas,
      this,
      const Rect.fromLTWH(16, 404, 88, 36),
      body: kCarBlue,
      scratched: true,
      hazardOn: true,
    );
    drawCarTopView(
      canvas,
      this,
      const Rect.fromLTWH(112, 404, 88, 36),
      body: kCarGreen,
      scratched: true,
      hazardOn: true,
    );

    // Водители заполняют бланк — вместо полиции и протокола.
    drawPersonTopView(canvas, const Offset(222, 424), 22, const Color(0xFF2B2B2B));
    drawPersonTopView(canvas, const Offset(248, 424), 22, const Color(0xFF2B2B2B));
    _europeanForm(canvas, const Rect.fromLTRB(266, 404, 386, 448));

    _verdict(
      canvas,
      const Rect.fromLTRB(16, 464, 384, 502),
      labels.clearRoad,
      allowed: true,
    );
    _verdict(
      canvas,
      const Rect.fromLTRB(16, 508, 384, 546),
      labels.noPolice,
      allowed: true,
    );
  }

  // ==================== ОБЩИЕ КУСКИ ====================

  void _header(
    Canvas canvas,
    Rect panel,
    String serbian,
    String russian,
    Color chipColor,
    Color chipInk,
  ) {
    final chipWidth = measure(serbian, maxWidth: 220, fontSize: 13, isBold: true)
            .width +
        24;
    final chip = Rect.fromLTWH(panel.left + 12, panel.top + 10, chipWidth, 26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chip, const Radius.circular(13)),
      Paint()..color = chipColor,
    );
    text(
      canvas,
      serbian,
      chip.center,
      chipInk,
      maxWidth: chipWidth,
      fontSize: 13,
      isBold: true,
    );
    text(
      canvas,
      russian,
      Offset((chip.right + panel.right - 12) / 2, chip.center.dy),
      colorScheme.onSurface,
      maxWidth: panel.right - 24 - chip.right,
      fontSize: 11,
    );
  }

  void _asphalt(Canvas canvas, Rect road) {
    canvas.drawRect(road, Paint()..color = kAsphalt);
  }

  void _dashedCenterLine(Canvas canvas, Rect road) {
    _dashes(canvas, road.center.dy, road.left + 10, road.right - 10);
  }

  void _dashes(Canvas canvas, double y, double from, double to) {
    final paint = Paint()
      ..color = kMarking
      ..strokeWidth = 3;
    for (var x = from; x < to; x += 34) {
      canvas.drawLine(Offset(x, y), Offset(x + 18, y), paint);
    }
  }

  /// Место удара: звёздочка из лучей. Без неё две машины рядом читаются как
  /// «стоят в пробке», а не как столкнувшиеся.
  void _impact(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = i * 3.14159 / 4;
      final dir = Offset.fromDirection(angle);
      canvas.drawLine(center + dir * 5, center + dir * 15, paint);
    }
  }

  /// Знак аварийной остановки: красный треугольник вид сверху лежит на дороге
  /// узкой стороной к потоку, поэтому рисуем его слегка сплюснутым.
  void _triangleSign(Canvas canvas, Offset center, double size) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * 0.9, center.dy + size * 0.7)
      ..lineTo(center.dx - size * 0.9, center.dy + size * 0.7)
      ..close();
    canvas.drawPath(path, Paint()..color = kSignalRed);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - size * 0.45)
        ..lineTo(center.dx + size * 0.42, center.dy + size * 0.42)
        ..lineTo(center.dx - size * 0.42, center.dy + size * 0.42)
        ..close(),
      Paint()..color = const Color(0xFFF6F1E7),
    );
  }

  /// Иконка «не померај возило»: машина под красной перечёркивающей чертой.
  void _noMoveBadge(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = colorScheme.surface);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = kSignalRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    drawCarTopView(
      canvas,
      this,
      Rect.fromCenter(center: center, width: radius * 1.5, height: radius * 0.8),
      body: colorScheme.onSurface.withValues(alpha: 0.35),
    );
    canvas.drawLine(
      center + Offset.fromDirection(2.36, radius),
      center + Offset.fromDirection(-0.78, radius),
      Paint()
        ..color = kSignalRed
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    roadLabel(canvas, 'не померај', Offset(center.dx, center.dy + radius + 14));
  }

  /// Бланк «Европски извештај»: белый лист со строчками — по нему видно, что
  /// вместо протокола участники пишут бумагу сами.
  void _europeanForm(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = const Color(0xFFF7F5EF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    text(
      canvas,
      'Европски\nизвештај',
      Offset(rect.center.dx, rect.top + 16),
      const Color(0xFF23272B),
      maxWidth: rect.width - 8,
      fontSize: 11,
      isBold: true,
    );
    final line = Paint()
      ..color = const Color(0xFF9AA0A6)
      ..strokeWidth = 1.4;
    for (var i = 0; i < 3; i++) {
      final y = rect.top + 30 + i * 5.0;
      canvas.drawLine(Offset(rect.left + 8, y), Offset(rect.right - 8, y), line);
    }
  }

  /// Вывод панели: галочка — обязанность, крест — запрет. Смысл держится не
  /// только на цвете: рядом с плашкой всегда стоит знак.
  void _verdict(Canvas canvas, Rect rect, String value, {required bool allowed}) {
    calloutBox(
      canvas,
      value,
      rect,
      fill: allowed ? colorScheme.tertiaryContainer : colorScheme.errorContainer,
      textColor: allowed
          ? colorScheme.onTertiaryContainer
          : colorScheme.onErrorContainer,
      check: allowed,
      cross: !allowed,
      fontSize: 12,
    );
  }
}
