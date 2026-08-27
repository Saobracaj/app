import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_environment.dart';

/// Хранит выбор окружения (prod/dev) на мобильных платформах.
///
/// Выбор читается один раз на старте — в `lib/main_prod.dart`, до DI (см.
/// [resolveAppEnvironment]); применяется он поэтому только после перезапуска
/// приложения, за который отвечает `EnvironmentBloc`.
@lazySingleton
class EnvironmentRepository {
  Future<void> save(AppEnvironment environment) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appEnvironmentPrefsKey, environment.storageKey);
  }
}
