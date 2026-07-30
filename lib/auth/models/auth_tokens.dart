/// Pair of tokens returned by the back-end auth mutations.
///
/// Mirrors the `AuthTokens` GraphQL type from `saobracaj_backend`
/// (`accessToken`, `refreshToken`, `authenticated`). [authenticated] is `false`
/// when registration still requires email confirmation before the tokens work.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.authenticated,
  });

  final String accessToken;
  final String refreshToken;
  final bool authenticated;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String? ?? '',
    refreshToken: json['refreshToken'] as String? ?? '',
    authenticated: json['authenticated'] as bool? ?? true,
  );
}
