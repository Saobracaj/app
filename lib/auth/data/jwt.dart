import 'dart:convert';

/// Local (unverified) inspection of the JWTs issued by `saobracaj_backend`.
///
/// The signature is never checked here. Two claims are read: `exp`, so the
/// client can tell an expired access token from a live one *before* spending a
/// request on it (the back-end silently treats an expired token as anonymous
/// instead of returning an error, so a request is not a reliable probe), and
/// `sub`, so it can tell *whose* session the data on the device belongs to
/// without asking the server.
DateTime? jwtExpiry(String token) {
  final exp = _claims(token)?['exp'];
  if (exp is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
}

/// The user id [token] was issued for (`sub`), or `null` when there is no
/// token or it cannot be read.
String? jwtSubject(String? token) {
  if (token == null || token.isEmpty) return null;
  final sub = _claims(token)?['sub'];
  return sub is String && sub.isNotEmpty ? sub : null;
}

Map<String, dynamic>? _claims(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = json.decode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map ? payload.cast<String, dynamic>() : null;
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
