// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';

/// Насколько груз может выступать за габарит: 1 m спереди, 1/6 длины (но не
/// больше 1,5 m) сзади, остальное лежит на кузове.
///
/// Схема держится на двух размерных линиях у одного и того же грузовика:
/// разница «перед / зад» — единственное, что путают в вопросах 8633–8635.
/// Внизу бледным — те самые приманки (1,5 m спереди, 1/4 длины сзади),
/// перечёркнутые, чтобы неверное число не запоминалось наравне с верным.
///
/// Слаг в `animations_map.dart`: `istureni-teret`.
class IstureniTeret extends StatelessWidget {
  const IstureniTeret({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 340,
          child: CustomPaint(
            painter: _IstureniTeretPainter(
              Theme.of(context).colorScheme,
              _Labels.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русские подписи читаются в `build()` через [BuildContext]: painter их
/// кэширует, и без этого при смене языка картинка осталась бы на старом.
/// Сербские формулировки из правил (*највише 1 m*, *1/6 дужине терета*)
/// не переводятся и живут прямо в painter'е.
class _Labels {
  const _Labels({
    required this.front,
    required this.rear,
    required this.supported,
    required this.wrongTitle,
  });

  factory _Labels.of(BuildContext context) => _Labels(
        front: context.tr(LocaleKeys.istureniTeret_front),
        rear: context.tr(LocaleKeys.istureniTeret_rear),
        supported: context.tr(LocaleKeys.istureniTeret_supported),
        wrongTitle: context.tr(LocaleKeys.istureniTeret_wrongTitle),
      );

  final String front;
  final String rear;
  final String supported;
  final String wrongTitle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Labels &&
          other.front == front &&
          other.rear == rear &&
          other.supported == supported &&
          other.wrongTitle == wrongTitle;

  @override
  int get hashCode => Object.hash(front, rear, supported, wrongTitle);
}

class _IstureniTeretPainter extends IllustrationPainter {
  _IstureniTeretPainter(super.colorScheme, this.labels);

  final _Labels labels;

  // Грузовик стоит носом вправо; груз — длинные трубы, лежащие на кузове и
  // выходящие за оба габарита.
  static const Rect _truck = Rect.fromLTRB(96, 92, 300, 196);
  static const double _loadFront = 344; // конец груза спереди
  static const double _loadRear = 26; // конец груза сзади
  static const double _loadTop = 110;
  static const double _loadBottom = 132;
  static const double _dimY = 226; // высота размерных линий

  @override
  void paint(Canvas canvas, Size size) {
    // Земля: без неё машина висит в воздухе и размерные линии не к чему
    // привязать.
    canvas.drawLine(
      const Offset(20, 196),
      const Offset(380, 196),
      Paint()
        ..color = colorScheme.outlineVariant
        ..strokeWidth = 2,
    );

    drawTruckProfile(
      canvas,
      this,
      _truck,
      // Кабина ниже обычного: трубы лежат поверх неё и поверх бортов кузова,
      // иначе груз «протыкал» бы кабину.
      cabTop: 0.34,
    );

    _drawPipes(canvas);

    // Опора груза на кузов: выноска ровно на тот участок труб, который лежит
    // в кузове. Это третья часть правила, её в вопросе 8635 и проверяют.
    calloutBox(
      canvas,
      '${labels.supported}\nпреостали део мора бити ослоњен\nна товарни простор',
      const Rect.fromLTRB(12, 12, 388, 60),
      fill: colorScheme.secondaryContainer,
    );
    arrow(canvas, const Offset(150, 60), const Offset(170, 106));

    _drawFrontDimension(canvas);
    _drawRearDimension(canvas);
    _drawWrongValues(canvas);
  }

  /// Пучок труб: несколько параллельных линий читается как груз, а один
  /// прямоугольник — как ящик.
  void _drawPipes(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTRB(_loadRear, _loadTop, _loadFront, _loadBottom),
      const Radius.circular(6),
    );
    canvas.drawRRect(rrect, Paint()..color = colorScheme.tertiaryContainer);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final line = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1;
    for (final y in [109.0, 117.0]) {
      canvas.drawLine(
        Offset(_loadRear + 4, y),
        Offset(_loadFront - 4, y),
        line,
      );
    }
  }

  void _drawFrontDimension(Canvas canvas) {
    // Пунктиры сносят габарит машины и конец груза на общую линию замера.
    dashedLine(canvas, const Offset(300, 150), const Offset(300, _dimY + 10));
    dashedLine(
      canvas,
      const Offset(_loadFront, _loadBottom),
      const Offset(_loadFront, _dimY + 10),
    );
    dimensionLine(
      canvas,
      const Offset(300, _dimY),
      const Offset(_loadFront, _dimY),
      color: colorScheme.primary,
    );
    text(
      canvas,
      labels.front,
      const Offset(322, _dimY - 14),
      colorScheme.onSurface,
      maxWidth: 90,
      fontSize: 11,
    );
    calloutBox(
      canvas,
      'највише 1 m',
      const Rect.fromLTRB(268, _dimY + 14, 388, _dimY + 44),
      fill: colorScheme.primaryContainer,
      textColor: colorScheme.onPrimaryContainer,
      fontSize: 12,
      isBold: true,
    );
  }

  void _drawRearDimension(Canvas canvas) {
    dashedLine(canvas, const Offset(96, 150), const Offset(96, _dimY + 10));
    dashedLine(
      canvas,
      const Offset(_loadRear, _loadBottom),
      const Offset(_loadRear, _dimY + 10),
    );
    dimensionLine(
      canvas,
      const Offset(_loadRear, _dimY),
      const Offset(96, _dimY),
      color: colorScheme.primary,
    );
    text(
      canvas,
      labels.rear,
      const Offset(70, _dimY - 14),
      colorScheme.onSurface,
      maxWidth: 90,
      fontSize: 11,
    );
    calloutBox(
      canvas,
      '1/6 дужине терета\nи највише 1,5 m',
      const Rect.fromLTRB(12, _dimY + 14, 246, _dimY + 58),
      fill: colorScheme.primaryContainer,
      textColor: colorScheme.onPrimaryContainer,
      fontSize: 12,
      isBold: true,
    );
  }

  /// Приманки из вопросов. Бледные и перечёркнутые: их надо узнавать, но не
  /// запоминать как правило.
  void _drawWrongValues(Canvas canvas) {
    const row = 306.0;
    text(
      canvas,
      labels.wrongTitle,
      const Offset(66, row),
      colorScheme.onSurfaceVariant,
      maxWidth: 108,
      fontSize: 11,
    );
    _strikethrough(canvas, '1,5 m напред', const Offset(196, row), 96);
    _strikethrough(canvas, '1/4 дужине позади', const Offset(316, row), 120);
  }

  void _strikethrough(
    Canvas canvas,
    String value,
    Offset center,
    double width,
  ) {
    final size = text(
      canvas,
      value,
      center,
      colorScheme.onSurfaceVariant,
      maxWidth: width,
      fontSize: 11,
    );
    canvas.drawLine(
      Offset(center.dx - size.width / 2, center.dy),
      Offset(center.dx + size.width / 2, center.dy),
      Paint()
        ..color = colorScheme.error
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _IstureniTeretPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.labels != labels;
}
