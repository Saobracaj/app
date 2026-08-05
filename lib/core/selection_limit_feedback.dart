import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Обратная связь на попытку выбрать больше вариантов, чем требует вопрос.
///
/// Лишний тап нигде не «проглатывается молча»: карточка не выбирается, но
/// пользователь получает вибрацию, короткую подсказку внизу экрана и
/// подрагивание плашки с нужным количеством ответов (плашка может быть уже
/// прокручена за пределы экрана — поэтому подсказка дублируется снаккбаром).
void showSelectionLimitFeedback(BuildContext context, String message) {
  HapticFeedback.vibrate();
  final messenger = ScaffoldMessenger.of(context);
  // Частые тапы не должны копить очередь снаккбаров.
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 1600),
    ),
  );
}

/// Подрагивает содержимым каждый раз, когда меняется [trigger].
///
/// Состояние здесь чисто визуальное (контроллер анимации), поэтому виджет —
/// `StatefulWidget`, а не Bloc.
class ShakeOnTrigger extends StatefulWidget {
  const ShakeOnTrigger({
    super.key,
    required this.trigger,
    required this.child,
  });

  /// Любое значение, изменение которого запускает анимацию (например счётчик
  /// отклонённых тапов из состояния блока).
  final int trigger;
  final Widget child;

  @override
  State<ShakeOnTrigger> createState() => _ShakeOnTriggerState();
}

class _ShakeOnTriggerState extends State<ShakeOnTrigger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void didUpdateWidget(covariant ShakeOnTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      // Три затухающих колебания по ±8 логических пикселей.
      builder: (context, child) => Transform.translate(
        offset: Offset(
          math.sin(_controller.value * math.pi * 6) *
              8 *
              (1 - _controller.value),
          0,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
