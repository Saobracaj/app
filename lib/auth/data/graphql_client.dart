import 'package:dio/dio.dart';

import '../auth_config.dart';
import 'token_storage.dart';

/// Thrown when a GraphQL request returns an `errors` envelope. [message] is a
/// human-readable, already-localized-by-the-server string when available.
class GraphqlException implements Exception {
  GraphqlException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Minimal GraphQL-over-HTTP client for `saobracaj_backend`.
///
/// Attaches the `Authorization`, `X-Device-Id` and `Accept-Language` headers and
/// transparently refreshes the access token once on an auth failure.
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

  /// Runs [query] with [variables]. When [authenticated] is true the request
  /// carries the bearer token and is retried once after a token refresh on an
  /// auth error.
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    try {
      return await _send(query, variables, authenticated);
    } on GraphqlException {
      if (!authenticated) rethrow;
      // Attempt a single token refresh, then retry; otherwise surface the
      // original error.
      final refreshed = await _tryRefresh();
      if (!refreshed) rethrow;
      return _send(query, variables, authenticated);
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
      throw GraphqlException(_networkMessage(e));
    }

    final data = response.data;
    if (data is! Map) {
      throw GraphqlException('Unexpected server response');
    }
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final message = first is Map ? first['message']?.toString() : null;
      throw GraphqlException(message ?? 'Request failed');
    }
    final payload = data['data'];
    if (payload is! Map<String, dynamic>) {
      throw GraphqlException('Empty server response');
    }
    return payload;
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final data = await _send(
        r'''mutation Refresh($refreshToken: String!) {
          refreshToken(refreshToken: $refreshToken) {
            accessToken refreshToken authenticated
          }
        }''',
        {'refreshToken': refresh},
        false,
      );
      final tokens = data['refreshToken'];
      if (tokens is Map) {
        await _storage.saveTokens(
          tokens['accessToken']?.toString() ?? '',
          tokens['refreshToken']?.toString() ?? refresh,
        );
        return true;
      }
    } catch (_) {
      // fall through
    }
    return false;
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
