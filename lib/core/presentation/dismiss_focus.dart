import 'package:flutter/material.dart';

/// Снимает фокус с текстового поля, когда пользователь нажимает на свободное
/// место экрана (а на мобильных — заодно убирает клавиатуру).
///
/// Обёртка «полупрозрачна» для попаданий ([HitTestBehavior.translucent]): она
/// участвует в арене жестов наравне с потомками, но потомок всегда глубже и
/// потому выигрывает арену. Нажатие на строку списка, кнопку или само поле
/// достаётся им, а до [GestureDetector.onTap] дело доходит только там, где
/// своего обработчика нет, — то есть на пустом месте.
///
/// Фокус снимается только с обычного узла: если фокус уже «припаркован» на
/// [FocusScopeNode] (никто не сфокусирован, либо это scope маршрута), трогать
/// его нельзя — увести фокус выше по дереву значит сломать клавиатурные
/// обработчики (см. `lib/core/keyboard_pagination.dart`).
class DismissFocusOnTap extends StatelessWidget {
  const DismissFocusOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        final focus = FocusManager.instance.primaryFocus;
        if (focus != null && focus is! FocusScopeNode) focus.unfocus();
      },
      child: child,
    );
  }
}
