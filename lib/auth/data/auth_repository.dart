import '../models/auth_tokens.dart';
import '../models/viewer.dart';
import 'graphql_client.dart';
import 'token_storage.dart';

/// Data-access layer over the `saobracaj_backend` auth/notifications GraphQL API.
///
/// Wraps the raw [GraphqlClient] calls in typed methods and keeps the persisted
/// tokens in sync with the returned [AuthTokens].
class AuthRepository {
  AuthRepository(this._client, this._storage);

  final GraphqlClient _client;
  final TokenStorage _storage;

  static const _tokenFields = 'accessToken refreshToken authenticated';

  Future<AuthTokens> _persist(Map<String, dynamic> tokensJson) async {
    final tokens = AuthTokens.fromJson(tokensJson);
    if (tokens.authenticated && tokens.accessToken.isNotEmpty) {
      await _storage.saveTokens(tokens.accessToken, tokens.refreshToken);
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

  Future<void> logout() => _storage.clear();

  Future<bool> hasStoredSession() async {
    final token = await _storage.accessToken;
    return token != null && token.isNotEmpty;
  }
}
