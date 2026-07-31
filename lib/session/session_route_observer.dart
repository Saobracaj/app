import 'package:flutter/widgets.dart';
import 'package:routemaster/routemaster.dart';

import '../db/dependencies.dart';

/// Observes route changes and mirrors the current location to the back-end so
/// the user's other devices can follow along. The heavy lifting (auth check,
/// debounce, filtering out non-resumable routes) lives in [sessionSync]; this
/// just forwards every navigation's full path (including query params).
class SessionRouteObserver extends RoutemasterObserver {
  @override
  void didChangeRoute(RouteData routeData, Page page) {
    sessionSync.pushLocation(routeData.fullPath);
  }
}
