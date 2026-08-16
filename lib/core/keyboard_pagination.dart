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
/// Устройство — два узла, и это принципиально. Клавиши доходят до
/// обработчика, только пока основной фокус стоит на нём или на его потомке.
/// Потомки же регулярно «отпускают» фокус через `unfocus()`: текстовое поле
/// — при клике мимо себя, `SelectionArea` (в неё обёрнуты текст вопроса и
/// варианты) на вебе — при любом клике вне неё, композер комментария — при
/// отправке. `unfocus()` отдаёт фокус ближайшему объемлющему [FocusScope];
/// пока обработчик был простым `Focus`, это был scope маршрута — выше
/// обработчика, — и клавиши «в какой-то момент» переставали работать до
/// конца жизни экрана. Поэтому:
///
/// * внешний узел — [FocusScope] с обработчиком клавиш: `unfocus()` любого
///   потомка приземляется на нём и не уходит из-под обработчика;
/// * внутренний — служебный `Focus`, который и держит фокус по умолчанию
///   (вне Tab-обхода и семантики). Как только фокус оказывается припаркован
///   «ни на ком» — на самом scope или на объемлющем scope маршрута (так
///   заканчивается `FocusScope.of(context).unfocus()` из глубины экрана), —
///   его возвращают этому узлу. Так стрелки в «пустом» состоянии не
///   уводят фокус к первому попавшемуся элементу внутри (это делает
///   `DirectionalFocusAction`, когда у scope нет сфокусированного ребёнка),
///   а автофокус нового вопроса не зависит от истории фокуса маршрута.
///
/// Возвращать фокус с корневого scope и scope окна нельзя: туда он уходит,
/// когда окно/вкладка браузера теряют фокус, и забирать его — значит
/// перетягивать фокус у адресной строки.
///
/// Диалоги и bottom sheet живут в собственных маршрутах со своим scope —
/// события клавиш из них сюда не всплывают, так что нажатия внутри диалога
/// подтверждения не листают вопросы под ним.
///
/// `null` в колбэке (первый/последний вопрос, ответ уже раскрыт) означает
/// «нечего делать» — событие тогда не съедается и уходит дальше по дереву.
class KeyboardPagination extends StatefulWidget {
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

  /// Стоит ли основной фокус в текстовом поле (внутри [EditableText]).
  @visibleForTesting
  static bool isEditingText() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.findAncestorStateOfType<EditableTextState>() != null;
  }

  @override
  State<KeyboardPagination> createState() => _KeyboardPaginationState();
}

// Stateful ради двух узлов фокуса: их надо держать в руках, чтобы вернуть
// припаркованный фокус держателю (см. `_reclaimParkedFocus`).
class _KeyboardPaginationState extends State<KeyboardPagination> {
  late final FocusScopeNode _scope = FocusScopeNode(
    debugLabel: 'KeyboardPagination',
    onKeyEvent: _handleKey,
    // Прозрачен для Tab-обхода, как scope самого маршрута: у краёв фокус
    // уходит к соседям в объемлющем scope, а не крутится внутри.
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );

  /// Держатель фокуса по умолчанию: служебный узел, в Tab-обход не попадает.
  final FocusNode _holder = FocusNode(
    debugLabel: 'KeyboardPagination holder',
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _scope.addListener(_reclaimParkedFocus);
  }

  @override
  void dispose() {
    _scope.removeListener(_reclaimParkedFocus);
    _holder.dispose();
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope.withExternalFocusNode(
      focusScopeNode: _scope,
      includeSemantics: false,
      child: Focus.withExternalFocusNode(
        focusNode: _holder,
        autofocus: true,
        includeSemantics: false,
        child: widget.child,
      ),
    );
  }

  /// Фокус припаркован «ни на ком» — на нашем scope (`unfocus()` потомка)
  /// или на объемлющем scope маршрута (`unfocus()` нашего scope) — значит,
  /// в маршруте ничего не сфокусировано и забирать его нам не у кого:
  /// возвращаем держателю.
  void _reclaimParkedFocus() {
    if (!mounted) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return;
    if (identical(primary, _scope) ||
        identical(primary, _scope.enclosingScope)) {
      _holder.requestFocus();
    }
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
    if (KeyboardPagination.isEditingText()) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final VoidCallback? action;
    if (key == LogicalKeyboardKey.arrowLeft) {
      action = widget.onPrevious;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      action = widget.onNext;
    } else if (key == LogicalKeyboardKey.space) {
      action = widget.onShowAnswer;
    } else {
      action = null;
    }
    if (action == null) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  }
}
