import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/routes.dart';

/// Opens a screen on top of the one at [context].
///
/// Routemaster derives the whole page stack from the URL, so a screen can only
/// be pushed through the router when the resulting path exists in the route
/// table: pushing an unregistered path lands on "page not found", and pushing
/// an *absolute* path throws away everything that was below it (which is how
/// "back" from a konspekt opened inside a question used to end up on the home
/// screen). Mirroring every "X opened on top of Y" combination into the route
/// table is not possible in general — the chain question → konspekt → question
/// → … has no fixed depth.
///
/// So this helper pushes through the router whenever the URL can express the
/// result (the common case, which keeps the address bar, deep links and the
/// browser history honest) and falls back to an ordinary imperative route
/// otherwise. Both end up on top of the current screen and both come back with
/// a plain "back", which is all the caller cares about.
///
///   * [path] — path relative to the current screen, e.g. `konspekt`;
///   * [screen] — the same screen as a widget, for the imperative fallback.
Future<void> pushScreen(
  BuildContext context, {
  required String path,
  Map<String, String>? queryParameters,
  required Widget Function() screen,
}) {
  if (isRoutable(context, path)) {
    Routemaster.of(context).push(path, queryParameters: queryParameters);
    return Future.value();
  }
  // Root navigator, for the same reason [showQuestionPreview] uses it: a screen
  // pushed into a home-screen tab's own navigator opens under the bottom bar.
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<void>(MaterialPageRoute(builder: (_) => screen()));
}

/// Whether pushing [path] relative to the screen at [context] resolves to a
/// registered route.
///
/// A screen that was itself pushed imperatively has no [RouteData] (and no path
/// of its own): Routemaster would resolve the relative path against the page
/// *underneath* it, which is not what the user is looking at, so those always
/// take the imperative branch.
bool isRoutable(BuildContext context, String path) {
  final base = RouteData.maybeOf(context)?.path;
  if (base == null) return false;
  final target = base == '/' ? '/$path' : '$base/$path';
  return routes.get(target) != null;
}

/// Роуты корневого навигатора, как они лежат сейчас, — чтобы знать, что
/// наверху: страница routemaster'а или роут, открытый императивно (запасная
/// ветка [pushScreen], поток входа, диалог).
///
/// Routemaster не подключает переданные ему наблюдатели к навигатору напрямую
/// (у них нет `navigator`), поэтому навигатор берётся у самого роута.
class RootRoutesObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];

  /// Верхний роут корневого навигатора, если он открыт не routemaster'ом.
  Route<dynamic>? get topPagelessRoute {
    final top = _routes.lastOrNull;
    return top != null && top.settings is! Page ? top : null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final at = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (at >= 0) {
      if (newRoute == null) {
        _routes.removeAt(at);
      } else {
        _routes[at] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
  }
}

/// Системная кнопка «назад» (Android), которая сначала закрывает то, что
/// открыто императивно.
///
/// Routemaster отвечает на неё шагом назад по истории адресов — и не видит
/// роутов, которых в адресе нет: экран входа, открытый поверх вопроса, при
/// нажатии «назад» оставался на месте, а под ним менялся экран (или вместе с
/// экраном под ним исчезал и он сам). Пока наверху такой роут, «назад»
/// закрывает его, как и стрелка в шапке; дальше — routemaster, как раньше.
class AppBackButtonDispatcher extends RootBackButtonDispatcher {
  AppBackButtonDispatcher(this._rootRoutes);

  final RootRoutesObserver _rootRoutes;

  @override
  Future<bool> didPopRoute() async {
    final pageless = _rootRoutes.topPagelessRoute;
    final navigator = pageless?.navigator;
    if (navigator == null) return super.didPopRoute();
    // Роут мог запретить закрытие (PopScope) — кнопка всё равно обработана,
    // выходить из приложения нельзя.
    await navigator.maybePop();
    return true;
  }
}
