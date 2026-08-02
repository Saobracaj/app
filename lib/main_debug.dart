import 'flavor.dart';
import 'main.dart' as app;

/// Debug flavor entry point — talks to the local dev back-end, same as before.
///
///   flutter run -t lib/main_debug.dart
void main() {
  FlavorConfig.init(
    const FlavorConfig(
      flavor: Flavor.debug,
      apiBaseUrl: 'http://localhost:8080',
    ),
  );
  app.main();
}
