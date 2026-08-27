import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';
import 'package:saobracaj/test/animations/road_sign.dart';

/// Скоростные лимиты пробной возачке дозволе: 110 / 90 / 90 %.
///
/// В вопросах №10691, №10692 и №10693 три разных числа для трёх типов дорог, и
/// путаются они с обычными лимитами 130 и 100. Поэтому у каждой дороги здесь
/// стоят оба знака сразу: крупный — для пробной, бледный перечёркнутый —
/// обычный. Разница «на ступеньку ниже» так видна без счёта.
///
/// Нижняя полоса повторяет то, на чём построены все ловушки раздела: приписки
/// «само до 18 година» и «само од 23 до 06» к ограничению скорости не
/// относятся, оно действует всегда.
class ProbnaBrzine extends StatelessWidget {
  const ProbnaBrzine({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: RoadSignScope(
        signs: const ['II-30-blank'],
        builder: (context, signs) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 400,
            height: 336,
            child: CustomPaint(
                painter: _ScenePainter(scheme, Gloss.of(context), signs)),
          ),
        ),
      ),
    );
  }
}

class _ScenePainter extends InfoScenePainter {
  _ScenePainter(super.colorScheme, this.gloss, this.signs);

  final Gloss gloss;
  final RoadSigns signs;

  static const _left = Rect.fromLTRB(2, 38, 130, 272);
  static const _middle = Rect.fromLTRB(136, 38, 264, 272);
  static const _right = Rect.fromLTRB(270, 38, 398, 272);

  @override
  void paint(Canvas canvas, Size size) {
    chip(
      canvas,
      'ПРОБНА ВОЗАЧКА ДОЗВОЛА — брзине',
      const Rect.fromLTRB(2, 2, 398, 32),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 13.5,
    );

    _road(canvas, _left, road: 'аутопут', probna: '110', obicno: '130');
    _road(canvas, _middle, road: 'мотопут', probna: '90', obicno: '100');
    _percentRoad(canvas, _right);

    panel(
      canvas,
      const Rect.fromLTRB(2, 280, 398, 330),
      fill: colorScheme.secondaryContainer,
    );
    text(
      canvas,
      'Важи увек: нема изузетка ни по годинама ни по добу дана'
      '${gloss('\nвариант со словом «само …» — всегда неправильный')}',
      const Offset(200, 305),
      colorScheme.onSecondaryContainer,
      maxWidth: 380,
      fontSize: 12,
      isBold: true,
    );
  }

  /// Колонка «тип дороги → два знака»: крупный для пробной, бледный
  /// перечёркнутый — обычный лимит, который новичку не разрешён.
  void _road(
    Canvas canvas,
    Rect rect, {
    required String road,
    required String probna,
    required String obicno,
  }) {
    panel(canvas, rect);
    chip(
      canvas,
      road,
      Rect.fromLTRB(rect.left + 8, 46, rect.right - 8, 72),
      fill: colorScheme.tertiaryContainer,
      ink: colorScheme.onTertiaryContainer,
      fontSize: 13,
    );

    speedSign(canvas, signs, Offset(rect.center.dx, 116), 34, probna);
    chip(
      canvas,
      'пробна',
      Rect.fromCenter(
        center: Offset(rect.center.dx, 166),
        width: 82,
        height: 24,
      ),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 12.5,
    );

    speedSign(
      canvas,
      signs,
      Offset(rect.center.dx, 212),
      23,
      obicno,
      // Не совсем бледный: число обычного лимита нужно прочитать, чтобы
      // сравнить с числом для пробной — иначе сравнивать нечего.
      opacity: 0.72,
      crossedOut: true,
    );
    text(
      canvas,
      'обичан лимит${gloss('\nне для новичка')}',
      Offset(rect.center.dx, 251),
      colorScheme.onSurfaceVariant,
      maxWidth: rect.width - 12,
      fontSize: 11,
    );
  }

  /// Третья колонка устроена иначе: числа на знаке нет, есть проценты — и
  /// именно поэтому её путают с первыми двумя. Пример счёта нарисован рядом.
  void _percentRoad(Canvas canvas, Rect rect) {
    panel(canvas, rect);
    chip(
      canvas,
      'остали путеви',
      Rect.fromLTRB(rect.left + 8, 46, rect.right - 8, 72),
      fill: colorScheme.tertiaryContainer,
      ink: colorScheme.onTertiaryContainer,
      fontSize: 13,
    );

    speedSign(canvas, signs, Offset(rect.center.dx, 116), 34, '50');
    text(
      canvas,
      'колико пише на знаку',
      Offset(rect.center.dx, 162),
      colorScheme.onSurfaceVariant,
      maxWidth: rect.width - 12,
      fontSize: 11,
    );

    panel(
      canvas,
      Rect.fromLTRB(rect.left + 8, 178, rect.right - 8, 252),
      fill: colorScheme.primaryContainer,
    );
    text(
      canvas,
      'пробна:\n90 % од 50\n= 45 km/h',
      Offset(rect.center.dx, 215),
      colorScheme.onPrimaryContainer,
      maxWidth: rect.width - 24,
      fontSize: 13,
      isBold: true,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.gloss != gloss ||
      oldDelegate.signs != signs;
}
