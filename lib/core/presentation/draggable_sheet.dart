/// Bottom sheet, который тянется сам, — тот же, что у превью вопроса.
///
/// Внутри такого листа нет второго скроллинга: тянется сам лист, а его
/// содержимое прокручивается контроллером, который лист же и выдаёт. Поэтому
/// палец в списке двигает лист, пока тому есть куда расти, и только потом
/// прокручивает содержимое, — а не упирается в «прокрутку внутри прокрутки»,
/// из-за которой лист со списком вопросов невозможно было закрыть тем же
/// движением, каким закрывается лист с вопросом.
///
/// Правила листа собраны здесь один раз: маршрут (а не `showModalBottomSheet`),
/// закруглённая подложка, ручка сверху, закрытие по сжатию до минимума и ряд
/// кнопок «Закрыть» / «Развернуть» внизу — ровно тот, что стоит у превью
/// вопроса.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';

/// Показать лист с [builder]-содержимым.
///
/// [builder] получает контроллер прокрутки листа и обязан отдать его своему
/// единственному скролл-виджету — иначе лист перестанет тянуться за палец.
Future<T?> showDraggableSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context, ScrollController controller)
  builder,
  double initialSize = 0.65,
  double minSize = 0.3,
  double maxSize = 0.9,
}) {
  // Root navigator — по той же причине, что и у превью вопроса: лист, открытый
  // в навигаторе вкладки, оказался бы под нижней панелью.
  return Navigator.of(context, rootNavigator: true).push<T>(
    _DraggableSheetRoute<T>(
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      initialSize: initialSize,
      minSize: minSize,
      maxSize: maxSize,
      builder: builder,
    ),
  );
}

/// Маршрут листа. Именно [PageRoute], как и у превью вопроса: hero летает
/// только между двумя page-маршрутами, и «развернуть» из листа открывает
/// полноценный экран.
class _DraggableSheetRoute<T> extends PageRouteBuilder<T> {
  _DraggableSheetRoute({
    required String barrierLabel,
    required double initialSize,
    required double minSize,
    required double maxSize,
    required Widget Function(BuildContext, ScrollController) builder,
  }) : super(
         opaque: false,
         barrierColor: Colors.black54,
         barrierDismissible: true,
         barrierLabel: barrierLabel,
         transitionDuration: const Duration(milliseconds: 280),
         reverseTransitionDuration: const Duration(milliseconds: 220),
         pageBuilder: (context, animation, secondaryAnimation) => _SheetBody(
           initialSize: initialSize,
           minSize: minSize,
           maxSize: maxSize,
           builder: builder,
         ),
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             SlideTransition(
               position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                   .animate(
                     CurvedAnimation(
                       parent: animation,
                       curve: Curves.easeOutCubic,
                       reverseCurve: Curves.easeInCubic,
                     ),
                   ),
               child: child,
             ),
       );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.initialSize,
    required this.minSize,
    required this.maxSize,
    required this.builder,
  });

  final double initialSize;
  final double minSize;
  final double maxSize;
  final Widget Function(BuildContext, ScrollController) builder;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      // Лист, а не экран: на широком окне он не растягивается на всю ширину.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: _DismissOnCollapse(
          child: DraggableScrollableSheet(
            expand: false,
            snap: true,
            initialChildSize: initialSize,
            minChildSize: minSize,
            maxChildSize: maxSize,
            builder: (context, controller) => Material(
              color: Theme.of(context).colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(top: false, child: builder(context, controller)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Закрывает маршрут, когда лист стянули до минимума, — так закрывается
/// [DraggableScrollableSheet], живущий на собственном маршруте.
class _DismissOnCollapse extends StatefulWidget {
  const _DismissOnCollapse({required this.child});

  final Widget child;

  @override
  State<_DismissOnCollapse> createState() => _DismissOnCollapseState();
}

class _DismissOnCollapseState extends State<_DismissOnCollapse> {
  bool _dismissing = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (!_dismissing &&
            notification.extent <= notification.minExtent + 0.005) {
          _dismissing = true;
          Navigator.of(context).pop();
        }
        return false;
      },
      child: widget.child,
    );
  }
}

/// Ручка сверху — первый элемент прокручиваемого содержимого листа.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Нижний ряд листа: «Закрыть» слева, «Развернуть» справа — теми же кнопками и
/// в том же порядке, что у превью вопроса.
class SheetActions extends StatelessWidget {
  const SheetActions({super.key, this.onExpand, this.trailing});

  /// «Развернуть»; `null` — разворачивать некуда, кнопки не будет.
  final VoidCallback? onExpand;

  /// Всё, что стоит правее «Развернуть» (например, «Сохранить себе»).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocaleKeys.quest_preview_close.tr()),
          ),
          const Spacer(),
          if (onExpand != null)
            TextButton.icon(
              onPressed: onExpand,
              icon: const Icon(Icons.open_in_full, size: 18),
              label: Text(LocaleKeys.quest_preview_expand.tr()),
            ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
