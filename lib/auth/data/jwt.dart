import 'dart:convert';

/// Local (unverified) inspection of the JWTs issued by `saobracaj_backend`.
///
/// The signature is never checked here — only the `exp` claim is read, so the
/// client can tell an expired access token from a live one *before* spending a
/// request on it (the back-end silently treats an expired token as anonymous
/// instead of returning an error, so a request is not a reliable probe).
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = json.decode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return null;
    final exp = payload['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

/// Whether [token] is missing or its `exp` is already past (or within [skew],
/// which absorbs clock drift and the request's own round-trip time).
///
/// A token that cannot be parsed is treated as *not* expired: the server stays
/// the authority on anything this can't read.
bool isJwtExpired(
  String? token, {
  Duration skew = const Duration(seconds: 30),
}) {
  if (token == null || token.isEmpty) return true;
  final exp = jwtExpiry(token);
  if (exp == null) return false;
  return DateTime.now().toUtc().add(skew).isAfter(exp);
}
