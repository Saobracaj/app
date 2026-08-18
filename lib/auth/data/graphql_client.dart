import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../../core/network/network_status.dart';
import '../auth_config.dart';
import 'graphql_batch.dart';
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
/// Every transport outcome is also reported to [NetworkStatus] (when one is
/// given): a connection failure flips the app to *offline*, a completed request
/// flips it back — that is what drives the "no network" copy and the automatic
/// reloads once the connection returns.
///
/// **Queries are batched, without waiting for each other.** Opening a screen
/// wakes several independent Blocs at once, and each of them used to spend its
/// own round trip (the home screen alone fired `me`, `featureFlags`,
/// `myQuestionLists` and `myGroups`). So a query that arrives while another
/// request is *already in flight* is held back and leaves with the ones next to
/// it as a single GraphQL document, split back apart on arrival — see
/// `graphql_batch.dart`. Identical queries collected this way are asked once.
///
/// Nothing is ever delayed to build a batch: with the line idle the query goes
/// out immediately, so a chain of dependent requests is exactly as fast as it
/// was, and a burst only ever fills time the app was going to spend waiting
/// anyway. Mutations are never batched (merging side effects is a different
/// problem) and are never held back; neither is anything the merger cannot
/// rewrite safely.
///
/// Registered for DI via `RegisterModule` in `lib/core/di.dart` (the optional
/// `languageProvider` / `dio` / `networkStatus` params keep injectable from
/// introspecting the constructor directly).
class GraphqlClient {
  GraphqlClient(
    this._storage, {
    Dio? dio,
    this.languageProvider,
    NetworkStatus? networkStatus,
    this.batchQueries = true,
    this.maxBatchSize = 16,
  }) : _network = networkStatus,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 20),
             ),
           );

  final Dio _dio;
  final TokenStorage _storage;
  final NetworkStatus? _network;

  /// Whether queries piling up behind an in-flight request travel together.
  /// Off in the tests that assert what a single operation puts on the wire.
  final bool batchQueries;

  /// Upper bound on the operations in one document, so a screen that fires a
  /// burst of queries cannot build an unbounded request.
  final int maxBatchSize;

  /// Queries waiting for the request ahead of them, per `authenticated` flag —
  /// the two carry different headers, so they cannot share a request.
  final Map<bool, _BatchQueue> _queues = {};

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
  ///
  /// A query issued while another request is in flight shares a request with
  /// the queries next to it (see [batchQueries]); nothing is ever delayed for
  /// the sake of a batch, and mutations never batch at all.
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    if (!authenticated) return _dispatch(query, variables, false);

    await _ensureFreshAccessToken();
    try {
      return await _dispatch(query, variables, true);
    } on AuthExpiredException {
      rethrow;
    } on GraphqlException catch (e) {
      // Only an auth failure is worth a refresh + retry: retrying anything else
      // would replay the request (and any side effect) for nothing.
      if (e.network || !e.isAuthError) rethrow;
      if (!await _tryRefresh()) rethrow;
      // On its own: the batch this query travelled in is long gone, and the
      // point of the retry is *this* operation with a fresh token.
      return _send(query, variables, true);
    }
  }

  /// Sends [query] now if the line is free, otherwise parks it for the batch
  /// that goes out when the request ahead of it comes back.
  Future<Map<String, dynamic>> _dispatch(
    String query,
    Map<String, dynamic> variables,
    bool authenticated,
  ) {
    final parsed = batchQueries ? parseBatchableQuery(query) : null;
    // A mutation (or anything the merger will not touch) never waits and never
    // holds the line: unchanged behaviour, down to the bytes on the wire.
    if (parsed == null) return _send(query, variables, authenticated);

    final queue = _queues.putIfAbsent(authenticated, _BatchQueue.new);
    if (!queue.busy) {
      queue.busy = true;
      return _watch(
        queue,
        authenticated,
        _send(query, variables, authenticated),
      );
    }

    final pending = _PendingQuery(query, parsed, variables);
    // The same query with the same variables, asked for twice while the line is
    // busy (the app refreshes feature flags from `main()` and from the session
    // holder), is one field on the wire and one answer for both callers.
    for (final queued in queue.pending) {
      if (queued.isSameRequestAs(pending)) return queued.completer.future;
    }
    queue.pending.add(pending);
    return pending.completer.future;
  }

  /// Frees the line once [request] settles, and sends whatever queued up behind
  /// it meanwhile. The caller's own outcome is untouched.
  Future<Map<String, dynamic>> _watch(
    _BatchQueue queue,
    bool authenticated,
    Future<Map<String, dynamic>> request,
  ) {
    unawaited(
      request
          .then<void>((_) {}, onError: (Object _) {})
          .whenComplete(() => _drain(queue, authenticated)),
    );
    return request;
  }

  /// Sends the queued queries, a batch per round trip, until nothing is left —
  /// then hands the line back. Every round is one request: the queries that
  /// arrive while it is out are the next round's batch.
  Future<void> _drain(_BatchQueue queue, bool authenticated) async {
    while (queue.pending.isNotEmpty) {
      // At most [maxBatchSize] operations per document; the rest go in the
      // round after this one.
      final size = queue.pending.length < maxBatchSize
          ? queue.pending.length
          : maxBatchSize;
      final pending = queue.pending.take(size).toList();
      queue.pending.removeRange(0, size);

      // A single queued query has nothing to merge — send it as it was written.
      if (pending.length == 1) {
        await _settleAlone(pending.single, authenticated);
        continue;
      }

      final merged = mergeBatchableQueries(
        [for (final p in pending) p.parsed],
        [for (final p in pending) p.variables],
      );
      if (kDebugMode) {
        // Visible proof during manual QA that a screen's requests travelled
        // together, and a cheap way to spot a screen that still does not.
        debugPrint('GraphQL: ${pending.length} queries in one request');
      }
      final dynamic body;
      try {
        body = await _post(merged.query, merged.variables, authenticated);
      } catch (e, stack) {
        // Transport failure or a non-GraphQL answer: every caller in the batch
        // gets the outcome it would have had on its own.
        for (final p in pending) {
          p.completer.completeError(e, stack);
        }
        continue;
      }
      _splitBatch(body, merged.prefixes, pending, authenticated);
    }
    queue.busy = false;
  }

  /// Hands each caller in [pending] its slice of the batched [body].
  ///
  /// An error carrying a `path` belongs to exactly one operation and only that
  /// caller sees it. Anything else — an error the server could not attribute
  /// (a parse or validation failure), or a payload that lost a caller's fields
  /// because a *neighbour's* non-null field errored and nulled the whole
  /// `data` — means the merge cannot be trusted for those callers, and they are
  /// asked again one by one. Wasteful, but it is the difference between a
  /// batching bug degrading performance and it breaking a screen.
  void _splitBatch(
    dynamic body,
    List<String> prefixes,
    List<_PendingQuery> pending,
    bool authenticated,
  ) {
    final envelope = body is Map ? body : const {};
    final errors = envelope['errors'];
    final ownErrors = <int, dynamic>{};
    var unattributed = body is! Map;
    if (errors is List) {
      for (final error in errors) {
        final owner = batchErrorOwner(error, prefixes);
        if (owner == null) {
          unattributed = true;
        } else {
          ownErrors.putIfAbsent(owner, () => error);
        }
      }
    }

    for (var i = 0; i < pending.length; i++) {
      final caller = pending[i];
      if (unattributed) {
        unawaited(_settleAlone(caller, authenticated));
        continue;
      }
      final error = ownErrors[i];
      if (error != null) {
        caller.completer.completeError(_graphqlError(error));
        continue;
      }
      final data = extractBatchData(envelope['data'], prefixes[i]);
      if (data == null) {
        unawaited(_settleAlone(caller, authenticated));
        continue;
      }
      caller.completer.complete(data);
    }
  }

  /// Runs one queued query on its own and settles its caller with the result.
  /// Never throws — the failure belongs to the caller's future, not to the
  /// batching machinery that is running it.
  Future<void> _settleAlone(_PendingQuery caller, bool authenticated) async {
    try {
      caller.completer.complete(
        await _send(caller.query, caller.variables, authenticated),
      );
    } catch (e, stack) {
      caller.completer.completeError(e, stack);
    }
  }

  /// Runs [query] with one file attached, using the GraphQL multipart request
  /// spec (an `operations` part, a `map` part and the file itself under `0`).
  ///
  /// Always authenticated — the only upload the app has is a support-chat
  /// attachment, which a guest cannot make. Auth handling mirrors [run]: the
  /// token is refreshed beforehand and once more if the server still rejects
  /// it, which is safe here because a rejected request never stored anything.
  Future<Map<String, dynamic>> upload(
    String query, {
    Map<String, dynamic> variables = const {},
    required List<int> bytes,
    required String fileName,
    String? contentType,
    String fileVariable = 'file',
    void Function(int sent, int total)? onProgress,
  }) async {
    await _ensureFreshAccessToken();
    try {
      return await _sendUpload(
        query,
        variables,
        bytes,
        fileName,
        contentType,
        fileVariable,
        onProgress,
      );
    } on AuthExpiredException {
      rethrow;
    } on GraphqlException catch (e) {
      if (e.network || !e.isAuthError) rethrow;
      if (!await _tryRefresh()) rethrow;
      return _sendUpload(
        query,
        variables,
        bytes,
        fileName,
        contentType,
        fileVariable,
        onProgress,
      );
    }
  }

  /// An access token good enough to open an authenticated connection with,
  /// refreshed first when it has (nearly) run out.
  ///
  /// Exists for the websocket transport, which authenticates once at
  /// `connection_init` and then holds the connection open — it cannot retry a
  /// request the way [run] does, so the token has to be fresh up front. Throws
  /// [AuthExpiredException] when the session can no longer be renewed; answers
  /// `null` for a guest.
  Future<String?> freshAccessToken() async {
    await _ensureFreshAccessToken();
    return _storage.accessToken;
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
  ) async => _unwrap(await _post(query, variables, authenticated));

  /// Posts one GraphQL document and answers with the raw response envelope
  /// (`data` *and* `errors`). [_send] reduces it to the payload; the batched
  /// path needs both halves to route each error to the caller that owns it.
  Future<dynamic> _post(
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
      throw _transportFailure(e);
    }
    _network?.reportSuccess();
    return response.data;
  }

  /// Turn a GraphQL response body into its `data` payload, raising the server's
  /// first error (with its stable `extensions.code`) when there is one. Shared
  /// by the JSON and multipart transports.
  Map<String, dynamic> _unwrap(dynamic body) {
    if (body is! Map) {
      throw GraphqlException('Unexpected server response');
    }
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw _graphqlError(errors.first);
    }
    final payload = body['data'];
    if (payload is! Map<String, dynamic>) {
      throw GraphqlException('Empty server response');
    }
    return payload;
  }

  /// One entry of a response's `errors` array as an exception, keeping the
  /// server's message and its stable `extensions.code`.
  GraphqlException _graphqlError(dynamic error) {
    String? message;
    String? code;
    if (error is Map) {
      message = error['message']?.toString();
      final extensions = error['extensions'];
      if (extensions is Map) code = extensions['code']?.toString();
    }
    return GraphqlException(message ?? 'Request failed', code: code);
  }

  /// The multipart half of [_send]: same headers, same error envelope, but the
  /// body is `multipart/form-data` and the file variable is sent as `null` in
  /// `operations` and pointed at by `map`, per the GraphQL multipart spec.
  Future<Map<String, dynamic>> _sendUpload(
    String query,
    Map<String, dynamic> variables,
    List<int> bytes,
    String fileName,
    String? contentType,
    String fileVariable,
    void Function(int sent, int total)? onProgress,
  ) async {
    final headers = <String, String>{'X-Device-Id': await _storage.deviceId()};
    final lang = languageProvider?.call();
    if (lang != null && lang.isNotEmpty) headers['Accept-Language'] = lang;
    final token = await _storage.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final formData = FormData.fromMap({
      'operations': jsonEncode({
        'query': query,
        'variables': {...variables, fileVariable: null},
      }),
      'map': jsonEncode({
        '0': ['variables.$fileVariable'],
      }),
      '0': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: contentType == null
            ? null
            : DioMediaType.parse(contentType),
      ),
    });

    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        AuthConfig.graphqlUrl,
        data: formData,
        options: Options(
          headers: headers,
          // A 20 MB attachment on a slow connection needs longer than the
          // client's default response window.
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
        ),
        onSendProgress: onProgress,
      );
    } on DioException catch (e) {
      throw _transportFailure(e);
    }
    _network?.reportSuccess();
    return _unwrap(response.data);
  }

  /// Wrap a Dio failure as a network [GraphqlException] and tell
  /// [NetworkStatus] about it — but only when the request really never reached
  /// the server. An HTTP error status is a *reachable* server misbehaving, and
  /// a cancelled request says nothing about the connection.
  GraphqlException _transportFailure(DioException e) {
    if (_isConnectionFailure(e)) _network?.reportFailure();
    return GraphqlException(_networkMessage(e), network: true);
  }

  static bool _isConnectionFailure(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError ||
    DioExceptionType.unknown => true,
    DioExceptionType.badResponse ||
    DioExceptionType.badCertificate ||
    DioExceptionType.transformTimeout ||
    DioExceptionType.cancel => false,
  };

  /// The message is a placeholder for logs and for the rare screen that shows
  /// the raw string; user-facing copy comes from `describeError`
  /// (`lib/core/network/error_messages.dart`), which maps a network failure to
  /// the localized "no connection" text.
  String _networkMessage(DioException e) {
    if (_isConnectionFailure(e)) {
      return 'Network error. Check your connection and try again.';
    }
    return e.message ?? 'Network error';
  }
}

/// One query waiting for its batch to go out.
class _PendingQuery {
  _PendingQuery(this.query, this.parsed, this.variables);

  final String query;
  final BatchableQuery parsed;
  final Map<String, dynamic> variables;
  final Completer<Map<String, dynamic>> completer =
      Completer<Map<String, dynamic>>();

  /// The variables as JSON, for comparing two queued requests; `null` when they
  /// cannot be encoded, which simply means "never equal to anything".
  late final String? _signature = _encodeVariables();

  String? _encodeVariables() {
    try {
      return jsonEncode(variables);
    } catch (_) {
      return null;
    }
  }

  /// Whether [other] asks the server exactly the same thing, so one field on
  /// the wire can answer both.
  bool isSameRequestAs(_PendingQuery other) =>
      query == other.query &&
      _signature != null &&
      _signature == other._signature;
}

/// The queries queued for one `authenticated` flag, behind the request that is
/// currently on the wire for it.
class _BatchQueue {
  final List<_PendingQuery> pending = [];

  /// Whether a request this queue is responsible for is in flight. While it is,
  /// arriving queries wait for it instead of opening a connection of their own.
  bool busy = false;
}
