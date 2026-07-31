/// Configuration for the auth/back-end integration.
///
/// The Saobraćaj back-end (`saobracaj_backend`, Rust/Axum/async-graphql) exposes
/// a single GraphQL endpoint. There is no deployed URL yet, so this defaults to a
/// local server; override it at build time with
/// `--dart-define=SAOBRACAJ_API_URL=https://...`.
class AuthConfig {
  const AuthConfig._();

  /// Base URL of the back-end (without the trailing `/graphql`).
  static const String baseUrl = String.fromEnvironment(
    'SAOBRACAJ_API_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Full GraphQL endpoint.
  static String get graphqlUrl => '$baseUrl/graphql';
}
