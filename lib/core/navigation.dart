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
  if (_isRoutable(context, path)) {
    Routemaster.of(context).push(path, queryParameters: queryParameters);
    return Future.value();
  }
  // Root navigator, for the same reason [showQuestionPreview] uses it: a screen
  // pushed into a home-screen tab's own navigator opens under the bottom bar.
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (_) => screen()),
  );
}

/// Whether pushing [path] relative to the screen at [context] resolves to a
/// registered route.
///
/// A screen that was itself pushed imperatively has no [RouteData] (and no path
/// of its own): Routemaster would resolve the relative path against the page
/// *underneath* it, which is not what the user is looking at, so those always
/// take the imperative branch.
bool _isRoutable(BuildContext context, String path) {
  final base = RouteData.maybeOf(context)?.path;
  if (base == null) return false;
  final target = base == '/' ? '/$path' : '$base/$path';
  return routes.get(target) != null;
}
