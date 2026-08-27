import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/road_sign.dart';
import 'package:saobracaj/test/animations/vehicle_painting.dart';

/// Статичная схема «посебни сигнали»: три вида проблесковых сигналов и что
/// каждый из них даёт водителю рядом.
///
/// Картинка снимает главную путаницу вопросов секции: синий и красно-синий
/// дают првенство пролаза (красно-синий — сильнее), жёлтый не даёт ничего,
/// а от светофора и разрешённого направления движения не освобождён никто.
class PosebniSignali extends StatelessWidget {
  const PosebniSignali({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RoadSignScope(
        signs: const ['III-2.1'],
        builder: (context, signs) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 400,
            height: 492,
            child: CustomPaint(painter: _PosebniSignaliPainter(scheme, signs)),
          ),
        ),
      ),
    );
  }
}

/// Синий, красный и жёлтый здесь — не оформление, а содержание: это цвета
/// самих сигналов, поэтому они литеральные, а не из темы.
const _blue = Color(0xFF1E62D0);
const _red = Color(0xFFD32F2F);
const _amber = Color(0xFFFFB300);

class _PosebniSignaliPainter extends CustomPainter {
  _PosebniSignaliPainter(this.scheme, this.signs);

  final ColorScheme scheme;
  final RoadSigns signs;

  @override
  void paint(Canvas canvas, Size size) {
    const cardHeight = 124.0;
    const gap = 10.0;

    _card(
      canvas,
      top: 0,
      height: cardHeight,
      accent: _blue,
      title: 'возило са првенством пролаза',
      body: 'најмање једно ПЛАВО ротационо или трепћуће светло\n'
          '+ сирена променљивог тона',
      note: 'хитна помоћ, ватрогасци, полиција у интервенцији',
      carBody: Colors.white,
      carStripe: _red,
      beacons: const [Beacon(_blue)],
      siren: true,
    );

    _card(
      canvas,
      top: cardHeight + gap,
      height: cardHeight,
      accent: _red,
      title: 'возило под пратњом',
      body: 'ЦРВЕНО и ПЛАВО наизменично\n+ сирена променљивог тона',
      note: 'јаче је од возила са првенством пролаза',
      carBody: const Color(0xFF2E3B4E),
      carStripe: Colors.white,
      beacons: const [Beacon(_red), Beacon(_blue, intensity: 0.25)],
      siren: true,
    );

    _card(
      canvas,
      top: (cardHeight + gap) * 2,
      height: cardHeight,
      accent: _amber,
      title: 'жуто ротационо или трепћуће светло',
      body: 'САМО УПОЗОРЕЊЕ — не даје првенство пролаза',
      note: 'повећај опрез и прилагоди брзину и начин вожње',
      carBody: _amber,
      carStripe: const Color(0xFF37474F),
      beacons: const [Beacon(_amber)],
      siren: false,
    );

    _exemptionStrip(canvas, top: (cardHeight + gap) * 3 + 2);
  }

  /// Одна строка схемы: цветная полоса-акцент, машина и подписи.
  void _card(
    Canvas canvas, {
    required double top,
    required double height,
    required Color accent,
    required String title,
    required String body,
    required String note,
    required Color carBody,
    required Color carStripe,
    required List<Beacon> beacons,
    required bool siren,
  }) {
    final rect = Rect.fromLTWH(0, top, 400, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()..color = scheme.surfaceContainerHighest,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..color = scheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Полоса слева цветом сигнала — по ней строка узнаётся с одного взгляда.
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, top, 6, height),
      Paint()..color = accent,
    );
    canvas.restore();

    final carRect = Rect.fromCenter(
      center: Offset(76, top + height / 2),
      width: 96,
      height: 44,
    );
    paintTopViewCar(
      canvas,
      carRect,
      body: carBody,
      outline: scheme.outline,
      roofStripe: carStripe,
      beacons: beacons,
    );
    if (siren) {
      paintSirenWaves(
        canvas,
        Offset(carRect.right + 6, carRect.center.dy),
        color: accent,
        size: 15,
      );
    }

    // Подписи ставятся стопкой по измеренной высоте предыдущей: заголовок
    // в сербской кириллице легко переносится на вторую строку, и фиксированные
    // отступы сразу дают наезд.
    const textLeft = 152.0;
    const textWidth = 234.0;
    var y = top + 14;
    y += paintCanvasText(
      canvas,
      title,
      Offset(textLeft, y),
      color: scheme.onSurface,
      fontSize: 13.5,
      weight: FontWeight.bold,
      maxWidth: textWidth,
    ).height + 7;
    y += paintCanvasText(
      canvas,
      body,
      Offset(textLeft, y),
      color: scheme.onSurface,
      fontSize: 12,
      maxWidth: textWidth,
    ).height + 6;
    paintCanvasText(
      canvas,
      note,
      Offset(textLeft, y),
      color: scheme.onSurfaceVariant,
      fontSize: 11.5,
      maxWidth: textWidth,
    );
  }

  /// Нижняя полоса-подсказка: от чего спецтранспорт НЕ освобождён.
  void _exemptionStrip(Canvas canvas, {required double top}) {
    const height = 86.0;
    final rect = Rect.fromLTWH(0, top, 400, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()..color = scheme.errorContainer,
    );

    paintCanvasText(
      canvas,
      'ни плаво, ни црвено-плаво НИСУ изузети од овога:',
      Offset(200, top + 14),
      color: scheme.onErrorContainer,
      fontSize: 12.5,
      weight: FontWeight.bold,
      maxWidth: 372,
      align: TextAlign.center,
      alignment: Alignment.topCenter,
    );

    _trafficLight(canvas, Offset(28, top + 56));
    paintCanvasText(
      canvas,
      'светлосни саобраћајни\nзнак (семафор)',
      Offset(46, top + 56),
      color: scheme.onErrorContainer,
      fontSize: 11,
      maxWidth: 148,
      alignment: Alignment.centerLeft,
    );

    _directionSign(canvas, Offset(220, top + 56));
    paintCanvasText(
      canvas,
      'дозвољени смер\nкретања',
      Offset(246, top + 56),
      color: scheme.onErrorContainer,
      fontSize: 11,
      maxWidth: 148,
      alignment: Alignment.centerLeft,
    );
  }

  void _trafficLight(Canvas canvas, Offset center) {
    final rect = Rect.fromCenter(center: center, width: 15, height: 34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF263238),
    );
    const lights = [_red, _amber, Color(0xFF2E7D32)];
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(center.dx, rect.top + 7 + i * 10),
        4,
        Paint()..color = lights[i],
      );
    }
  }

  /// Знак «једносмерни пут» (III-2.1): синий прямоугольник с белой стрелкой.
  void _directionSign(Canvas canvas, Offset center) {
    signs.paint(canvas, 'III-2.1',
        Rect.fromCenter(center: center, width: 46, height: 26));
  }

  @override
  bool shouldRepaint(covariant _PosebniSignaliPainter oldDelegate) =>
      oldDelegate.scheme != scheme || oldDelegate.signs != signs;
}
