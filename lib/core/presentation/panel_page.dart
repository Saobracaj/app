import 'package:flutter/material.dart';

import '../responsive.dart';

/// Страница раздела двухпанельного экрана: на широком экране открывается без
/// анимации перехода, на телефоне — обычная [MaterialPage].
///
/// Routemaster строит стек страниц из адреса, поэтому у раздела с собственным
/// адресом (`/settings/appearance`) нет другого способа существовать, кроме
/// как отдельной страницей поверх экрана-хозяина. На телефоне так и выглядит:
/// раздел — новый экран, и переход между экранами уместен. На широком экране
/// та же страница рисует тот же макет и лишь подменяет содержимое правой
/// панели, а анимация «ушли на другой экран» там врёт: панель должна
/// переключаться мгновенно, как вкладка.
class PanelPage<T> extends Page<T> {
  const PanelPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// Содержимое страницы.
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) =>
      _PanelPageRoute<T>(page: this, instant: context.isExpandedScreen);
}

/// Маршрут [PanelPage]: [MaterialRouteTransitionMixin] с нулевой длительностью
/// перехода в обе стороны, когда страница подменяет панель ([instant]).
class _PanelPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _PanelPageRoute({required PanelPage<T> page, required this.instant})
    : super(settings: page);

  /// Ширина экрана в момент открытия: панель, а не новый экран.
  final bool instant;

  PanelPage<T> get _page => settings as PanelPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  @override
  Duration get transitionDuration =>
      instant ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      instant ? Duration.zero : super.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      instant ? null : super.delegatedTransition;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => instant
      ? child
      : super.buildTransitions(context, animation, secondaryAnimation, child);

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}
