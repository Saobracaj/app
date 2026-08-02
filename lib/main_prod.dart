import 'flavor.dart';
import 'main.dart' as app;

/// Production flavor entry point — talks to the deployed back-end.
///
///   flutter run       -t lib/main_prod.dart
///   flutter build web -t lib/main_prod.dart
void main() {
  FlavorConfig.init(
    const FlavorConfig(
      flavor: Flavor.prod,
      apiBaseUrl: 'https://api.saobracaj.gleb.at',
    ),
  );
  app.main();
}
