import 'dart:async';

import 'package:dio/dio.dart';

import '../auth_config.dart';
import 'jwt.dart';
import 'token_storage.dart';

/// Thrown when a GraphQL request returns an `errors` envelope. [message] is a
/// human-readable, already-localized-by-the-server string when available;
/// [code] is the stable machine-readable `extensions.code` (e.g.
/// `authorization_required`), and [network] marks transport failures that never
/// reached the server.
class GraphqlException implements Exception {
  GraphqlException(this.message, {this.code, this.network = false});
  final String message;
  final String? code;
  final bool network;

  /// Codes the back-end returns when the *access* token was missing, expired or
  /// rejected — the requests worth retrying after a refresh.
  bool get isAuthError =>
      code == 'authorization_required' ||
      code == 'token_expired' ||
      code == 'wrong_token';

  @override
  String toString() => message;
}

/// Thrown when the session is gone for good: the refresh token itself is
/// expired or rejected, so nothing short of a new login will help. Listeners on
/// [GraphqlClient.sessionExpired] get the same signal.
class AuthExpiredException extends GraphqlException {
  AuthExpiredException([super.message = 'Session expired']);
}

/// Minimal GraphQL-over-HTTP client for `saobracaj_backend`.
///
/// Attaches the `Authorization`, `X-Device-Id` and `Accept-Language` headers and
/// keeps the access token alive on its own:
///
/// * **before** every authenticated request the stored access token's `exp` is
///   checked locally and the token is refreshed when it has (nearly) run out.
///   This is not an optimisation — the back-end treats an expired token as an
///   anonymous request rather than an error, so queries like `me` would quietly
///   answer `null` and look like a signed-out user;
/// * **after** an auth error it refreshes once and retries, covering tokens the
///   server rejects for reasons the client can't see;
/// * concurrent callers share a single in-flight refresh;
/// * only a rejected *refresh* token ends the session — it raises
///   [AuthExpiredException] and fires [sessionExpired] (network failures never
///   do, so going offline can't sign the user out).
///
/// Registered for DI via `RegisterModule` in `lib/core/di.dart` (the optional
/// `languageProvider` / `dio` params keep injectable from introspecting the
/// constructor directly).
class GraphqlClient {
  GraphqlClient(this._storage, {Dio? dio, this.languageProvider})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  final Dio _dio;
  final TokenStorage _storage;

  /// Returns the current UI language code (e.g. `ru`), used for `Accept-Language`.
  final String Function()? languageProvider;

  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();

  /// Fires when the refresh token is expired or rejected, i.e. the session
  /// cannot be renewed. `AuthRepository` listens and signs the user out.
  Stream<void> get sessionExpired => _sessionExpiredController.stream;

  Future<void>? _refreshInFlight;

  static const _refreshMutation = r'''
    mutation Refresh($refreshToken: String!) {
      refreshToken(refreshToken: $refreshToken) {
        accessToken refreshToken authenticated
      }
    }''';

  /// Runs [query] with [variables]. When [authenticated] is true the request
  /// carries the bearer token, which is refreshed beforehand if it has expired
  /// and once more if the server still rejects it.
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    if (!authenticated) return _send(query, variables, false);

    await _ensureFreshAccessToken();
    try {
      return await _send(query, variables, true);
    } on AuthExpiredException {
      rethrow;
    } on GraphqlException catch (e) {
      // Only an auth failure is worth a refresh + retry: retrying anything else
      // would replay the request (and any side effect) for nothing.
      if (e.network || !e.isAuthError) rethrow;
      if (!await _tryRefresh()) rethrow;
      return _send(query, variables, true);
    }
  }

  /// Refreshes and reports whether it worked, so a failed retry can surface the
  /// server's original error. An [AuthExpiredException] is *not* swallowed —
  /// "the session is over" outranks whatever the request itself failed on.
  Future<bool> _tryRefresh() async {
    try {
      await _refresh();
      return true;
    } on AuthExpiredException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  /// Refreshes the access token when it is missing or (nearly) expired.
  ///
  /// Does nothing for a guest (no tokens at all) — the request then goes out
  /// anonymously exactly as before, and the server decides. Throws
  /// [AuthExpiredException] when there *was* a session but it can no longer be
  /// renewed.
  Future<void> _ensureFreshAccessToken() async {
    final access = await _storage.accessToken;
    if (!isJwtExpired(access)) return;

    final refresh = await _storage.refreshToken;
    final hasRefresh = refresh != null && refresh.isNotEmpty;
    if (!hasRefresh) {
      // No session at all: let the request go out anonymously. A stored but
      // unusable access token, on the other hand, means the session is over.
      if (access == null || access.isEmpty) return;
      _expireSession();
      throw AuthExpiredException();
    }
    // A locally-expired refresh token can't be renewed — don't waste a request.
    if (isJwtExpired(refresh, skew: Duration.zero)) {
      _expireSession();
      throw AuthExpiredException();
    }
    await _refresh();
  }

  /// Single-flight token refresh: parallel callers await the same request.
  Future<void> _refresh() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> _performRefresh() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      _expireSession();
      throw AuthExpiredException();
    }

    final Map<String, dynamic> data;
    try {
      data = await _send(_refreshMutation, {'refreshToken': refresh}, false);
    } on GraphqlException catch (e) {
      // Only the server saying "this refresh token is no good" ends the
      // session. Transport failures and server-side hiccups (`internal_error`,
      // a 5xx body) are transient — a bad minute must not sign everyone out.
      if (!e.isAuthError) rethrow;
      _expireSession();
      throw AuthExpiredException(e.message);
    }

    final tokens = data['refreshToken'];
    final access = tokens is Map ? tokens['accessToken']?.toString() ?? '' : '';
    if (access.isEmpty) {
      // Succeeded but handed back nothing usable: not a rejected token, so the
      // session stays and the caller can try again later.
      throw GraphqlException('Empty refresh response');
    }
    final rotated = (tokens as Map)['refreshToken']?.toString();
    await _storage.saveTokens(
      access,
      rotated == null || rotated.isEmpty ? refresh : rotated,
    );
  }

  void _expireSession() {
    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
  }

  Future<Map<String, dynamic>> _send(
    String query,
    Map<String, dynamic> variables,
    bool authenticated,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Device-Id': await _storage.deviceId(),
    };
    final lang = languageProvider?.call();
    if (lang != null && lang.isNotEmpty) headers['Accept-Language'] = lang;
    if (authenticated) {
      final token = await _storage.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        AuthConfig.graphqlUrl,
        data: {'query': query, 'variables': variables},
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw GraphqlException(_networkMessage(e), network: true);
    }

    final data = response.data;
    if (data is! Map) {
      throw GraphqlException('Unexpected server response');
    }
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      String? message;
      String? code;
      if (first is Map) {
        message = first['message']?.toString();
        final extensions = first['extensions'];
        if (extensions is Map) code = extensions['code']?.toString();
      }
      throw GraphqlException(message ?? 'Request failed', code: code);
    }
    final payload = data['data'];
    if (payload is! Map<String, dynamic>) {
      throw GraphqlException('Empty server response');
    }
    return payload;
  }

  String _networkMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Network error. Check your connection and try again.';
    }
    return e.message ?? 'Network error';
  }
}
