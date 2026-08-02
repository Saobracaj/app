/// Build flavors for the client app.
///
/// Flavors are selected by launching a dedicated entry point
/// (`lib/main_debug.dart` or `lib/main_prod.dart`), each of which calls
/// [FlavorConfig.init] before running the shared `main` in `lib/main.dart`.
/// This approach works uniformly on mobile *and* web (Flutter's native
/// `--flavor` is not supported for web builds).
///
/// Run:
/// ```bash
/// flutter run    -t lib/main_debug.dart   # → local dev server
/// flutter run    -t lib/main_prod.dart    # → https://api.saobracaj.gleb.at
/// flutter build web -t lib/main_prod.dart
/// ```
/// Plain `flutter run` (target `lib/main.dart`) defaults to the debug flavor.
enum Flavor { debug, prod }

class FlavorConfig {
  const FlavorConfig({required this.flavor, required this.apiBaseUrl});

  /// Which flavor this build was launched as.
  final Flavor flavor;

  /// Back-end base URL, without the trailing `/graphql`.
  final String apiBaseUrl;

  bool get isProd => flavor == Flavor.prod;
  bool get isDebug => flavor == Flavor.debug;

  static const FlavorConfig _debug = FlavorConfig(
    flavor: Flavor.debug,
    apiBaseUrl: 'http://localhost:8080',
  );

  static FlavorConfig? _instance;

  /// The active flavor. Defaults to [Flavor.debug] when no entry point has
  /// called [init] (e.g. `flutter test` or a plain `lib/main.dart` launch).
  static FlavorConfig get instance => _instance ?? _debug;

  /// Selects the active flavor. Call once, before `runApp`.
  static void init(FlavorConfig config) => _instance = config;
}
