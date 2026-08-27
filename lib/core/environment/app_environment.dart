import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Окружения, на которые умеет смотреть prod-сборка приложения.
///
/// Прод и dev — один и тот же бинарь/бандл: окружение выбирается в рантайме
/// (см. [resolveAppEnvironment]), а не флейвором сборки. Флейвор `debug` с его
/// localhost-адресом сюда не входит — это отдельная точка входа
/// `lib/main_debug.dart`.
enum AppEnvironment {
  production('production', 'https://api.saobracaj.gleb.at'),
  dev('dev', 'https://api.saobracaj-dev.gleb.at');

  const AppEnvironment(this.storageKey, this.apiBaseUrl);

  /// Значение в shared preferences ([appEnvironmentPrefsKey]).
  final String storageKey;

  /// Базовый URL бэкенда этого окружения (без завершающего `/graphql`).
  final String apiBaseUrl;
}

/// Ключ выбранного окружения в shared preferences (только мобильные сборки —
/// веб выбирает окружение по домену и ничего не хранит).
const String appEnvironmentPrefsKey = 'app_environment';

/// Окружение по хосту, с которого открыт веб-клиент: dev-домен смотрит на
/// dev-бэкенд автоматически, всё остальное (прод-домен, localhost) — на прод.
AppEnvironment environmentForHost(String host) =>
    host == 'saobracaj-dev.gleb.at' ? AppEnvironment.dev : AppEnvironment.production;

/// Окружение этого запуска: на вебе — по домену из адресной строки, на
/// мобильных — сохранённый в shared preferences выбор из секретного диалога
/// (см. `showEnvironmentDialog`). Неизвестное/отсутствующее значение — прод.
///
/// Вызывается из `lib/main_prod.dart` до [FlavorConfig.init], поэтому не
/// пользуется getIt — DI к этому моменту ещё не сконфигурирован.
Future<AppEnvironment> resolveAppEnvironment() async {
  if (kIsWeb) return environmentForHost(Uri.base.host);
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(appEnvironmentPrefsKey);
  return AppEnvironment.values.firstWhere(
    (environment) => environment.storageKey == stored,
    orElse: () => AppEnvironment.production,
  );
}
