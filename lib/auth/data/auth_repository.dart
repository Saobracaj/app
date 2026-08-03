import 'dart:async';

import 'package:injectable/injectable.dart';

import '../models/auth_tokens.dart';
import '../models/viewer.dart';
import 'auth_status.dart';
import 'graphql_client.dart';
import 'jwt.dart';
import 'token_storage.dart';

/// Data-access layer over the `saobracaj_backend` auth/notifications GraphQL API.
///
/// Wraps the raw [GraphqlClient] calls in typed methods and keeps the persisted
/// tokens in sync with the returned [AuthTokens].
///
/// It is also the source of truth for the session: every auth flow that ends up
/// signed in emits [AuthStatus.authenticated] on [sessionStatus], and [logout]
/// emits [AuthStatus.unauthenticated]. The app-wide `AuthBloc` subscribes to
/// this stream (mirroring owncup's `UserAuthRepository`/`AuthBloc` split), so no
/// caller has to hand the session to a holder manually.
@lazySingleton
class AuthRepository {
  AuthRepository(this._client, this._storage) {
    // The client renews the access token on its own; it only reports back when
    // the *refresh* token is gone too, which is the one case that must end the
    // session.
    _expirySub = _client.sessionExpired.listen((_) => logout());
  }

  final GraphqlClient _client;
  final TokenStorage _storage;
  late final StreamSubscription<void> _expirySub;

  static const _tokenFields = 'accessToken refreshToken authenticated';

  final StreamController<AuthStatus> _sessionController =
      StreamController<AuthStatus>.broadcast();
  AuthStatus _sessionStatus = AuthStatus.unknown;

  /// The current session status, replayed to each new listener followed by any
  /// subsequent transitions. Consumed by the app-wide `AuthBloc`.
  Stream<AuthStatus> get sessionStatus async* {
    yield _sessionStatus;
    yield* _sessionController.stream;
  }

  void _emitSession(AuthStatus status) {
    _sessionStatus = status;
    _sessionController.add(status);
  }

  Future<AuthTokens> _persist(Map<String, dynamic> tokensJson) async {
    final tokens = AuthTokens.fromJson(tokensJson);
    if (tokens.authenticated && tokens.accessToken.isNotEmpty) {
      await _storage.saveTokens(tokens.accessToken, tokens.refreshToken);
      _emitSession(AuthStatus.authenticated);
    }
    return tokens;
  }

  Future<AuthTokens> register(
    String email,
    String password, {
    String? language,
  }) async {
    final data = await _client.run(
      '''mutation Register(\$email: String!, \$password: String!, \$language: String) {
        register(email: \$email, password: \$password, language: \$language) { $_tokenFields }
      }''',
      variables: {'email': email, 'password': password, 'language': language},
    );
    return _persist(data['register'] as Map<String, dynamic>);
  }

  Future<AuthTokens> confirmEmail(String email, String code) async {
    final data = await _client.run(
      '''mutation ConfirmEmail(\$email: String!, \$code: String!) {
        confirmEmail(email: \$email, code: \$code) { $_tokenFields }
      }''',
      variables: {'email': email, 'code': code},
    );
    return _persist(data['confirmEmail'] as Map<String, dynamic>);
  }

  Future<bool> resendConfirmationCode(String email) async {
    final data = await _client.run(
      '''mutation Resend(\$email: String!) {
        resendConfirmationCode(email: \$email)
      }''',
      variables: {'email': email},
    );
    return data['resendConfirmationCode'] as bool? ?? false;
  }

  Future<AuthTokens> login(String email, String password) async {
    final data = await _client.run(
      '''mutation Login(\$email: String!, \$password: String!) {
        login(email: \$email, password: \$password) { $_tokenFields }
      }''',
      variables: {'email': email, 'password': password},
    );
    return _persist(data['login'] as Map<String, dynamic>);
  }

  Future<bool> requestPasswordReset(String email) async {
    final data = await _client.run(
      '''mutation RequestReset(\$email: String!) {
        requestPasswordReset(email: \$email)
      }''',
      variables: {'email': email},
    );
    return data['requestPasswordReset'] as bool? ?? false;
  }

  Future<AuthTokens> confirmPasswordReset(
    String email,
    String code,
    String newPassword,
  ) async {
    final data = await _client.run(
      '''mutation ConfirmReset(\$email: String!, \$code: String!, \$newPassword: String!) {
        confirmPasswordReset(email: \$email, code: \$code, newPassword: \$newPassword) { $_tokenFields }
      }''',
      variables: {'email': email, 'code': code, 'newPassword': newPassword},
    );
    return _persist(data['confirmPasswordReset'] as Map<String, dynamic>);
  }

  /// Log in or register via a Firebase ID token (Google / Apple sign-in).
  Future<AuthTokens> firebaseAuth(String idToken) async {
    final data = await _client.run(
      '''mutation FirebaseAuth(\$idToken: String!) {
        firebaseAuth(idToken: \$idToken) { $_tokenFields }
      }''',
      variables: {'idToken': idToken},
    );
    return _persist(data['firebaseAuth'] as Map<String, dynamic>);
  }

  Future<Viewer?> me() async {
    final data = await _client.run(
      'query Me { me { id email permissions } }',
      authenticated: true,
    );
    final me = data['me'];
    if (me is Map<String, dynamic>) return Viewer.fromJson(me);
    return null;
  }

  Future<bool> setEmailNotifications(bool enabled) async {
    final data = await _client.run(
      '''mutation SetEmailNotifications(\$enabled: Boolean!) {
        setEmailNotifications(enabled: \$enabled)
      }''',
      variables: {'enabled': enabled},
      authenticated: true,
    );
    return data['setEmailNotifications'] as bool? ?? enabled;
  }

  /// Register (or refresh) the current device, optionally with its FCM token.
  Future<void> registerDevice({String? pushToken, String? platform}) async {
    await _client.run(
      '''mutation RegisterDevice(\$pushToken: String, \$platform: String) {
        registerDevice(pushToken: \$pushToken, platform: \$platform) { deviceId }
      }''',
      variables: {'pushToken': pushToken, 'platform': platform},
      authenticated: true,
    );
  }

  Future<bool> setDevicePushEnabled(bool enabled) async {
    final data = await _client.run(
      '''mutation SetDevicePushEnabled(\$enabled: Boolean!) {
        setDevicePushEnabled(enabled: \$enabled)
      }''',
      variables: {'enabled': enabled},
      authenticated: true,
    );
    return data['setDevicePushEnabled'] as bool? ?? enabled;
  }

  Future<void> logout() async {
    await _storage.clear();
    _emitSession(AuthStatus.unauthenticated);
  }

  /// Publish the persisted session on startup: [AuthStatus.authenticated] if a
  /// renewable session is stored (the `AuthBloc` then validates it via [me],
  /// and the client refreshes the access token on the way), otherwise
  /// [AuthStatus.unauthenticated].
  Future<void> bootstrap() async {
    _emitSession(
      await hasStoredSession()
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  /// Whether a session can still be used. An expired *access* token is fine —
  /// it gets refreshed on the first request; what matters is that either it or
  /// the refresh token is still alive.
  Future<bool> hasStoredSession() async {
    final access = await _storage.accessToken;
    if (access == null || access.isEmpty) return false;
    if (!isJwtExpired(access)) return true;
    return !isJwtExpired(await _storage.refreshToken, skew: Duration.zero);
  }

  @disposeMethod
  Future<void> dispose() async {
    await _expirySub.cancel();
    await _sessionController.close();
  }
}
