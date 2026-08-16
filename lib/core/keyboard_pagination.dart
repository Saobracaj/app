import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Клавиатурная навигация по списку вопросов: ← / → листают вопросы, а
/// пробел делает то же, что кнопка «показать ответ».
///
/// Оборачивает экран одного вопроса (тренажёр и симуляцию экзамена) и сам
/// забирает фокус при появлении, чтобы клавиши работали сразу, без клика по
/// странице. Обработчик стоит на узле фокуса, а не на app-level `Shortcuts`,
/// поэтому срабатывает раньше системных биндингов (прокрутка стрелками,
/// активация кнопки пробелом) — и ровно поэтому сам уступает, когда фокус
/// стоит в текстовом поле: там стрелки двигают курсор, а пробел ставит
/// пробел, и перехватывать их нельзя (на вебе перехваченный пробел даже не
/// доходит до поля).
///
/// Диалоги и bottom sheet живут в собственных маршрутах со своим scope —
/// события клавиш из них сюда не всплывают, так что нажатия внутри диалога
/// подтверждения не листают вопросы под ним.
///
/// `null` в колбэке (первый/последний вопрос, ответ уже раскрыт) означает
/// «нечего делать» — событие тогда не съедается и уходит дальше по дереву.
class KeyboardPagination extends StatelessWidget {
  const KeyboardPagination({
    super.key,
    this.onPrevious,
    this.onNext,
    this.onShowAnswer,
    required this.child,
  });

  /// Стрелка влево.
  final VoidCallback? onPrevious;

  /// Стрелка вправо.
  final VoidCallback? onNext;

  /// Пробел.
  final VoidCallback? onShowAnswer;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      // Служебный узел: в Tab-обход и в дерево семантики не попадает.
      skipTraversal: true,
      includeSemantics: false,
      debugLabel: 'KeyboardPagination',
      onKeyEvent: _handleKey,
      child: child,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    // Только первое нажатие: автоповтор зажатой стрелки не должен пролистывать
    // десяток вопросов, а зажатый пробел — что-то «раскрывать» повторно.
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (isEditingText()) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final VoidCallback? action;
    if (key == LogicalKeyboardKey.arrowLeft) {
      action = onPrevious;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      action = onNext;
    } else if (key == LogicalKeyboardKey.space) {
      action = onShowAnswer;
    } else {
      action = null;
    }
    if (action == null) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  }

  /// Стоит ли основной фокус в текстовом поле (внутри [EditableText]).
  @visibleForTesting
  static bool isEditingText() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.findAncestorStateOfType<EditableTextState>() != null;
  }
}
