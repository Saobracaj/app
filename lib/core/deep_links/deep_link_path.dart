/// Turning an incoming link into a route this app knows.
///
/// Two shapes arrive at the app from outside:
///   * `https://saobracaj.gleb.at/invite/ABC-DEF-GHI` — the invite link (and
///     `/shared/ABCDEFGH`, a shared question list), an Android App Link / iOS
///     Universal Link, verified against the files the web server publishes
///     under `/.well-known/`;
///   * `saobracaj://saobracaj.gleb.at/invite/ABC-DEF-GHI` — the same address
///     under the app's own scheme, which works even where verification does
///     not (a sideloaded build, an in-app browser that swallows App Links).
///
/// The mapping is a pure function so it can be tested without a device, and so
/// the routing rules live in one place instead of inside a platform callback.
library;

const _webHost = 'saobracaj.gleb.at';
const _customScheme = 'saobracaj';

/// Top-level routes a link may open.
///
/// A link is not allowed to address just any screen: `routes.dart` has entries
/// that only make sense as children of another page, and an unknown path would
/// land the user on an empty "page not found". Anything outside this list is
/// ignored, and the app opens where it was.
const _linkableRoots = {
  'invite',
  // A shared question list: https://saobracaj.gleb.at/shared/ABCDEFGH
  'shared',
  'question',
  'groups',
  'konspekt',
  'zakon',
  'lists',
  'questions',
  'statistics',
  'practice',
  'about',
  'home',
  // The support chat: `saobracaj://support` for one's own conversation and
  // `saobracaj://support/threads/<id>` for the moderator's view of one — both
  // are what the backend puts in a support notification.
  'support',
  // Любой чат и тред по ссылке из пуша: `saobracaj://chat/<id>`.
  'chat',
  'thread',
  // Top-level screens a notification may point at: the settings hub (the
  // test-push screen suggests `/settings`), the subscription and its tariffs,
  // and the moderator's screens.
  'settings',
  'notifications',
  'subscription',
  'tariffs',
  'moderation',
  'billing',
};

/// The in-app path for [uri], or `null` when the link is not ours to handle.
String? deepLinkPathFor(Uri uri) {
  // A trailing slash ('/question/10913/') is common in links pasted or built
  // by other apps; the empty segment it produces would miss every route and
  // land on "page not found", so it is dropped here.
  final segments = _routeSegments(uri)?.where((s) => s.isNotEmpty).toList();
  if (segments == null) return null;
  if (segments.isEmpty) return '/';
  if (!_linkableRoots.contains(segments.first)) return null;

  final path = '/${segments.map(Uri.encodeComponent).join('/')}';
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

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
