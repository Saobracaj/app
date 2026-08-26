import 'package:flutter/widgets.dart';

import 'core/environment/app_environment.dart';
import 'flavor.dart';
import 'main.dart' as app;

/// Production flavor entry point — talks to the deployed back-end.
///
///   flutter run       -t lib/main_prod.dart
///   flutter build web -t lib/main_prod.dart
///
/// Одна и та же сборка обслуживает и прод, и dev-окружение: окружение
/// выбирается в рантайме (веб — по домену, mobile — по сохранённому выбору из
/// секретного диалога в «О приложении»), см. [resolveAppEnvironment].
Future<void> main() async {
  // Чтение shared preferences ходит в платформенный канал — биндинг нужен до
  // первого обращения. Повторный вызов в `app.main()` безвреден.
  WidgetsFlutterBinding.ensureInitialized();
  final environment = await resolveAppEnvironment();
  FlavorConfig.init(
    FlavorConfig(
      flavor: Flavor.prod,
      apiBaseUrl: environment.apiBaseUrl,
      environment: environment,
    ),
  );
  app.main();
}
