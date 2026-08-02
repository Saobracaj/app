import '../flavor.dart';

/// Configuration for the auth/back-end integration.
///
/// The Saobraćaj back-end (`saobracaj_backend`, Rust/Axum/async-graphql) exposes
/// a single GraphQL endpoint. The base URL is chosen by the active build
/// [FlavorConfig] (see `lib/flavor.dart`):
///
/// * `debug` → `http://localhost:8080`
/// * `prod`  → `https://api.saobracaj.gleb.at`
///
/// An explicit `--dart-define=SAOBRACAJ_API_URL=https://...` still takes
/// precedence over the flavor default when set.
class AuthConfig {
  const AuthConfig._();

  static const String _override = String.fromEnvironment('SAOBRACAJ_API_URL');

  /// Base URL of the back-end (without the trailing `/graphql`).
  static String get baseUrl =>
      _override.isNotEmpty ? _override : FlavorConfig.instance.apiBaseUrl;

  /// Full GraphQL endpoint.
  static String get graphqlUrl => '$baseUrl/graphql';
}
