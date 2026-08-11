import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/vehicle_painting.dart';

/// Анимация «пропуштање возила са првенством пролаза»: что делает обычный
/// водитель, когда его догоняет или встречает ТС со спецсигналами.
///
/// Три фазы, каждая подписана сверху:
/// 1. поток прижимается к правому краю и, по потребности, останавливается;
/// 2. за ТС с приоритетом идёт колонна — её пропускают точно так же;
/// 3. пристраиваться к этой колонне нельзя.
class PropustanjeVozilaSPrvenstvom extends StatefulWidget {
  const PropustanjeVozilaSPrvenstvom({super.key});

  @override
  State<PropustanjeVozilaSPrvenstvom> createState() =>
      _PropustanjeVozilaSPrvenstvomState();
}

class _PropustanjeVozilaSPrvenstvomState
    extends State<PropustanjeVozilaSPrvenstvom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 8 секунд на три фазы с паузами: короче — не успеть прочитать подпись.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 320,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => CustomPaint(
              painter: _PropustanjePainter(scheme, _controller.value),
            ),
          ),
        ),
      ),
    );
  }
}

// Цвета сигналов и разметки — содержание картинки, поэтому литеральные.
const _blue = Color(0xFF1E62D0);
const _red = Color(0xFFD32F2F);
const _asphalt = Color(0xFF424242);
const _banking = Color(0xFF6D4C41);
const _yourCar = Color(0xFF2979FF);
const _otherCar = Color(0xFF43A047);

// Геометрия сцены (холст 400 × 320).
const _captionHeight = 50.0;
const _roadTop = 58.0;
const _roadBottom = 226.0;
const _laneSplit = 128.0; // осевая линия
const _rowDriving = 178.0; // обычное положение в своей полосе
const _rowPulledRight = 206.0; // прижались к правому краю
const _rowPriority = 156.0; // по чему проезжает спецтранспорт
const _rowOncoming = 100.0; // встречная полоса
const _rowOncomingPulled = 82.0; // встречный прижался к своему правому краю
const _carLength = 62.0;
const _carWidth = 26.0;

class _PropustanjePainter extends CustomPainter {
  _PropustanjePainter(this.scheme, this.t);

  final ColorScheme scheme;

  /// Положение внутри цикла, 0..1.
  final double t;

  /// Прогресс отрезка [a]..[b] с ограничением 0..1: после конца отрезка
  /// значение «залипает» на 1, поэтому фазу можно просто складывать со
  /// следующей и не хранить состояние.
  double _seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  double _ease(double v) => Curves.easeInOut.transform(v);

  @override
  void paint(Canvas canvas, Size size) {
    final pullOver = _ease(_seg(0.02, 0.26));
    final approach = _ease(_seg(0.02, 0.30));
    final pass = _ease(_seg(0.40, 0.68));
    final join = _ease(_seg(0.76, 0.92));

    // Спецмашина сначала догоняет поток, потом проезжает мимо.
    final escortX = -90 + 160 * approach + 280 * pass;
    final phase = t < 0.36 ? 1 : (t < 0.72 ? 2 : 3);

    _road(canvas);

    // Подпись фазы — сверху, чтобы стоп-кадр читался сам по себе.
    _caption(
      canvas,
      switch (phase) {
        1 => '1. Чујеш сирену и видиш светла → уз десну ивицу,\n'
            'по потреби заустави возило или сиђи са коловоза',
        2 => '2. Иза њега иде колона којој обезбеђује пролаз →\n'
            'и према њој поступаш као према возилу са првенством',
        _ => '3. Не смеш се прикључити тој колони',
      },
    );

    // Колонна, которой обеспечивают проезд: появляется только после того,
    // как спецмашина поравнялась с потоком.
    if (pass > 0) {
      _car(
        canvas,
        Offset(escortX - 88, _rowPriority),
        body: const Color(0xFFECEFF1),
      );
      _car(
        canvas,
        Offset(escortX - 168, _rowPriority),
        body: const Color(0xFF8D6E63),
      );
      _columnBracket(canvas, escortX);
    }

    _escortCar(canvas, Offset(escortX, _rowPriority));

    // Встречный тоже пропускает: «возач који сусретне ... возило са првенством».
    // Он прижимается к своему правому краю — то есть к верхней кромке дороги.
    _car(
      canvas,
      Offset(
        110 - 65 * pullOver,
        _rowOncoming + (_rowOncomingPulled - _rowOncoming) * pullOver,
      ),
      body: const Color(0xFFB0BEC5),
      facingLeft: true,
      brakeLights: pullOver > 0.15,
    );

    // Поток: две машины прижимаются вправо и встают.
    final yourY = _rowDriving + (_rowPulledRight - _rowDriving) * pullOver;

    _car(
      canvas,
      Offset(210, yourY),
      body: _otherCar,
      brakeLights: pullOver > 0.15,
      hazardOn: pullOver > 0.9,
      hazardIntensity: (t * 12) % 1 < 0.5 ? 1 : 0.1,
    );

    // Третья фаза: «ти» пробует вклиниться за колонну — так нельзя.
    final yourPos = Offset(84 + 26 * join, yourY - 30 * join);
    _car(
      canvas,
      yourPos,
      body: _yourCar,
      brakeLights: pullOver > 0.15 && join < 0.1,
      hazardOn: pullOver > 0.9 && join < 0.1,
      hazardIntensity: (t * 12) % 1 < 0.5 ? 1 : 0.1,
    );
    // Подпись «ти» — на банкине под машиной: на кузове её перекрывают
    // стоп-сигналы и аварийка.
    paintCanvasText(
      canvas,
      'ти',
      Offset(yourPos.dx, _roadBottom + 1),
      color: Colors.white,
      fontSize: 12,
      weight: FontWeight.bold,
      maxWidth: 40,
      align: TextAlign.center,
      alignment: Alignment.topCenter,
    );

    if (phase == 1) {
      // Стрелка «уз десну ивицу»: показывает направление манёвра, а не
      // движение вперёд.
      paintArrow(
        canvas,
        const Offset(36, 172),
        const Offset(36, 216),
        color: Colors.white,
        strokeWidth: 2.5,
      );
    }

    if (join > 0.05) {
      paintForbiddenMark(
        canvas,
        Offset(yourPos.dx + 4, yourPos.dy - 4),
        radius: 15 * join.clamp(0.4, 1.0),
      );
    }

    _footer(canvas);
  }

  void _road(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTRB(0, _roadTop, 400, _roadBottom),
      Paint()..color = _asphalt,
    );
    // Обочина: на неё съезжают, когда «по потреби» нужно освободить коловоз.
    canvas.drawRect(
      const Rect.fromLTRB(0, _roadBottom, 400, _roadBottom + 17),
      Paint()..color = _banking,
    );

    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    canvas.drawLine(
      const Offset(0, _roadTop + 3),
      const Offset(400, _roadTop + 3),
      line,
    );
    canvas.drawLine(
      const Offset(0, _roadBottom - 3),
      const Offset(400, _roadBottom - 3),
      line,
    );
    for (double x = 6; x < 400; x += 42) {
      canvas.drawLine(
        Offset(x, _laneSplit),
        Offset(x + 22, _laneSplit),
        line,
      );
    }
  }

  void _caption(Canvas canvas, String text) {
    final rect = const Rect.fromLTWH(0, 0, 400, _captionHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = scheme.primaryContainer,
    );
    paintCanvasText(
      canvas,
      text,
      rect.center,
      color: scheme.onPrimaryContainer,
      fontSize: 12,
      weight: FontWeight.w600,
      maxWidth: 384,
      align: TextAlign.center,
      alignment: Alignment.center,
    );
  }

  /// ТС под пратњом: красный и синий маячки мигают попеременно, плюс сирена.
  void _escortCar(Canvas canvas, Offset center) {
    final flash = (t * 16) % 1 < 0.5;
    paintTopViewCar(
      canvas,
      Rect.fromCenter(center: center, width: _carLength, height: _carWidth),
      body: const Color(0xFF1B2A3A),
      outline: Colors.white70,
      roofStripe: Colors.white,
      beacons: [
        Beacon(_red, intensity: flash ? 1 : 0.2),
        Beacon(_blue, intensity: flash ? 0.2 : 1),
      ],
    );
    paintSirenWaves(
      canvas,
      Offset(center.dx + _carLength / 2 + 5, center.dy),
      color: flash ? _red : _blue,
      size: 14,
    );
  }

  void _car(
    Canvas canvas,
    Offset center, {
    required Color body,
    bool brakeLights = false,
    bool hazardOn = false,
    double hazardIntensity = 1,
    bool facingLeft = false,
  }) {
    paintTopViewCar(
      canvas,
      Rect.fromCenter(center: center, width: _carLength, height: _carWidth),
      body: body,
      outline: Colors.white70,
      brakeLights: brakeLights,
      hazardOn: hazardOn,
      hazardIntensity: hazardIntensity,
      facingLeft: facingLeft,
    );
  }

  /// Подпись к колонне — в пустой встречной полосе, со скобкой вниз.
  void _columnBracket(Canvas canvas, double escortX) {
    final left = (escortX - 200).clamp(4.0, 396.0);
    final right = (escortX - 56).clamp(4.0, 396.0);
    if (right - left < 40) return;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const bracketY = 118.0;
    canvas.drawLine(Offset(left, bracketY), Offset(right, bracketY), paint);
    canvas.drawLine(
      Offset(left, bracketY),
      Offset(left, bracketY + 8),
      paint,
    );
    canvas.drawLine(
      Offset(right, bracketY),
      Offset(right, bracketY + 8),
      paint,
    );
    // Подпись всегда по центру холста: если вести её за скобкой, на краях
    // сцены она уезжает за границу картинки.
    paintCanvasText(
      canvas,
      'возила којима се обезбеђује пролаз',
      const Offset(200, bracketY - 10),
      color: Colors.white,
      fontSize: 11,
      weight: FontWeight.w600,
      maxWidth: 300,
      align: TextAlign.center,
      alignment: Alignment.bottomCenter,
    );
  }

  /// Постоянная сноска: частный случай со знаками полицейского из ТС.
  void _footer(Canvas canvas) {
    final rect = const Rect.fromLTWH(0, 254, 400, 66);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = scheme.secondaryContainer,
    );
    paintCanvasText(
      canvas,
      'Полицајац из возила даје знаке → прати возило до погодног\n'
      'места и заустави се иза њега.\n'
      'Заустављање и силазак са коловоза су „по потреби“, а не увек.',
      rect.center,
      color: scheme.onSecondaryContainer,
      fontSize: 11.5,
      maxWidth: 380,
      align: TextAlign.center,
      alignment: Alignment.center,
    );
  }

  @override
  bool shouldRepaint(covariant _PropustanjePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.scheme != scheme;
}
