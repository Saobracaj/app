/// The host every shareable link to the app points at.
///
/// One constant so the share sheet, the in-content markdown links and the URLs
/// the app resolves back into routes can never drift apart. The paths are the
/// ones declared in `lib/routes.dart` — e.g. `/question/1234?comments=1`.
const String kDeepLinkHost = 'saobracaj.gleb.at';

/// An absolute link to [path] (with or without a leading slash) on the app's
/// public host.
///
/// [query] takes the same shape as [Uri.https] — values may be `String`,
/// `Iterable<String>` or `null`.
Uri appLink(String path, [Map<String, dynamic>? query]) => Uri.https(
  kDeepLinkHost,
  path.startsWith('/') ? path : '/$path',
  query == null || query.isEmpty ? null : query,
);
