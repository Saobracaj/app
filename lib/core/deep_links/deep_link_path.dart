/// Turning an incoming link into a route this app knows.
///
/// Two shapes arrive at the app from outside:
///   * `https://saobracaj.gleb.at/…` — any address of the web version, an
///     Android App Link / iOS Universal Link verified against the files the
///     web server publishes under `/.well-known/`;
///   * `saobracaj://saobracaj.gleb.at/…` — the same address under the app's
///     own scheme, which works even where verification does not (a sideloaded
///     build, an in-app browser that swallows App Links).
///
/// The web version and the app share `routes.dart`, so every address of the
/// site is an address of the app: the path is handed to the router as is. A
/// path the app has no screen for lands on «страница не найдена» with a way
/// home — exactly what the browser shows for it — instead of being dropped on
/// the floor, which used to leave the user staring at whatever screen the app
/// happened to be on. Only the site's *files* (the Flutter bundle, the
/// platform verification files) are not screens and are left alone.
///
/// The mapping is a pure function so it can be tested without a device, and so
/// the routing rules live in one place instead of inside a platform callback.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

const _webHost = 'saobracaj.gleb.at';
const _customScheme = 'saobracaj';

/// Directories of the site that hold files, not screens (mirrors the list
/// `web_server/src/server.rs` serves from disk).
const _fileRoots = {'.well-known', 'assets', 'canvaskit', 'icons', 'packages'};

/// The in-app path for [uri], or `null` when the link is not ours to handle.
///
/// [isWeb] exists for tests only — in the app it is always [kIsWeb].
String? deepLinkPathFor(Uri uri, {bool isWeb = kIsWeb}) {
  // A trailing slash ('/question/10913/') is common in links pasted or built
  // by other apps; the empty segment it produces would miss every route and
  // land on "page not found", so it is dropped here.
  final segments = _routeSegments(uri)?.where((s) => s.isNotEmpty).toList();
  if (segments == null) return null;
  if (segments.isEmpty) return '/';
  if (_isFile(segments)) return null;

  final path = '/${segments.map(Uri.encodeComponent).join('/')}';
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

/// Whether [segments] address a file of the site rather than a screen:
/// something under a bundle directory, or a name with an extension at the top
/// level (`/robots.txt`, `/flutter_bootstrap.js`, `/sitemap.xml`).
bool _isFile(List<String> segments) =>
    _fileRoots.contains(segments.first) ||
    (segments.length == 1 && segments.first.contains('.'));

/// The path segments to route by, or `null` if the link belongs elsewhere.
List<String>? _routeSegments(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();

  if (scheme == 'https' || scheme == 'http') {
    // Only our own domain: a browser can hand over any link it likes.
    if (host != _webHost && host != 'www.$_webHost') return null;
    return uri.pathSegments;
  }
  if (scheme == _customScheme) {
    // `saobracaj://saobracaj.gleb.at/invite/CODE` mirrors the web address,
    // while the older `saobracaj://question/123` uses the host as the first
    // segment — both are in the wild, so both are accepted.
    if (host.isEmpty || host == _webHost) return uri.pathSegments;
    return [host, ...uri.pathSegments];
  }
  return null;
}
