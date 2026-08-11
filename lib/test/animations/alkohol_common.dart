import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';

/// Общее для «алкогольных» схем: горизонтальная шкала промилле и перечёркнутая
/// рюмка.
///
/// Тема алкоголя проходит через два конспекта — «Возач» (порог 0,20 и нулевая
/// норма) и «Специјалне мере» (порог задержания 1,20). Числа разные, а язык
/// картинки должен быть один: одна и та же линейка, одни и те же деления и
/// одна и та же рюмка, иначе читатель решит, что это про разные вещи.

/// Зелёный и красный здесь — содержание, а не оформление: «трезв» и «под
/// дејством» различаются именно цветом отрезка шкалы. Фон светлый, чернила
/// тёмные — такая пара одинаково читается и на тёмной теме.
const kSoberFill = Color(0xFFC8E6C9);
const kSoberInk = Color(0xFF1B5E20);
const kDrunkFill = Color(0xFFFFCDD2);
const kDrunkInk = Color(0xFFB71C1C);

/// Геометрия шкалы: перевод значения mg/ml в координату холста.
@immutable
class PromileScale {
  const PromileScale({
    required this.left,
    required this.right,
    required this.axisY,
    required this.max,
    this.min = 0,
  });

  final double left;
  final double right;
  final double axisY;
  final double min;
  final double max;

  double x(double value) =>
      left + (value - min) / (max - min) * (right - left);
}

/// Подписи значений — только сербская запятая как разделитель («0,20»), потому
/// что ровно так они выглядят в вариантах ответа.
String promile(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

abstract class AlkoholScenePainter extends InfoScenePainter {
  AlkoholScenePainter(super.colorScheme);

  /// Высота цветного отрезка шкалы. Тоньше 18 подпись внутрь не влезает,
  /// толще — полоса начинает выглядеть кнопкой.
  static const barHeight = 20.0;

  /// Цветной отрезок [from]–[to] с подписью внутри.
  void scaleBar(
    Canvas canvas,
    PromileScale scale,
    double from,
    double to, {
    required Color fill,
    required Color ink,
    String? label,
    double fontSize = 11.5,
  }) {
    final rect = Rect.fromLTRB(
      scale.x(from),
      scale.axisY - barHeight / 2,
      scale.x(to),
      scale.axisY + barHeight / 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = fill,
    );
    if (label != null) {
      text(
        canvas,
        label,
        rect.center,
        ink,
        maxWidth: rect.width - 8,
        fontSize: fontSize,
        isBold: true,
      );
    }
  }

  /// Деление с подписью значения под шкалой.
  void scaleTick(
    Canvas canvas,
    PromileScale scale,
    double value, {
    Color? color,
    bool crossed = false,
    String? caption,
  }) {
    final ink = color ?? colorScheme.onSurfaceVariant;
    final x = scale.x(value);
    final top = scale.axisY + barHeight / 2;
    canvas.drawLine(
      Offset(x, top),
      Offset(x, top + 6),
      Paint()
        ..color = ink
        ..strokeWidth = 1.5,
    );
    text(
      canvas,
      promile(value),
      Offset(x, top + 17),
      ink,
      maxWidth: 56,
      fontSize: 11,
      isBold: crossed,
    );
    if (crossed) {
      // Перечёркнутое деление — это приманка из вариантов ответа: цифра есть,
      // но она неправильная. Черта поверх самой цифры, а не рядом.
      canvas.drawLine(
        Offset(x - 17, top + 17),
        Offset(x + 17, top + 17),
        Paint()
          ..color = kBanRed
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    if (caption != null) {
      // Подпись отодвинута от значения на полторы строки: вплотную она
      // сливается с самой цифрой и с подписями соседних делений.
      text(
        canvas,
        caption,
        Offset(x, top + 45),
        ink,
        maxWidth: 130,
        fontSize: 10.5,
      );
    }
  }

  /// Рюмка. [height] — от края чаши до подставки.
  void glassIcon(
    Canvas canvas,
    Offset center,
    double height,
    Color color, {
    bool crossed = true,
  }) {
    final w = height * 0.62;
    final top = center.dy - height / 2;
    final fill = Paint()..color = color;

    // Чаша — трапеция: узнаётся как рюмка даже в 20 пикселей высотой,
    // в отличие от бокала со скруглениями.
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - w / 2, top)
        ..lineTo(center.dx + w / 2, top)
        ..lineTo(center.dx + w * 0.13, top + height * 0.46)
        ..lineTo(center.dx - w * 0.13, top + height * 0.46)
        ..close(),
      fill,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx - w * 0.06,
        top + height * 0.46,
        center.dx + w * 0.06,
        top + height * 0.86,
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          center.dx - w * 0.42,
          top + height * 0.86,
          center.dx + w * 0.42,
          top + height,
        ),
        const Radius.circular(2),
      ),
      fill,
    );

    if (crossed) {
      banSlash(canvas, center, height * 0.62, width: height * 0.12);
    }
  }
}
