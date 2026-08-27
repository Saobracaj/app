import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/environment/app_environment.dart';
import 'package:saobracaj/core/environment/data/environment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('environmentForHost — выбор окружения по домену веб-клиента', () {
    test('dev-домен смотрит на dev-окружение', () {
      expect(
        environmentForHost('saobracaj-dev.gleb.at'),
        AppEnvironment.dev,
      );
    });

    test('прод-домен смотрит на прод', () {
      expect(
        environmentForHost('saobracaj.gleb.at'),
        AppEnvironment.production,
      );
    });

    test('незнакомый хост (localhost и т.п.) — это прод', () {
      expect(environmentForHost('localhost'), AppEnvironment.production);
      expect(environmentForHost(''), AppEnvironment.production);
    });
  });

  group('resolveAppEnvironment — выбор окружения на мобильных', () {
    test('без сохранённого выбора — прод', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await resolveAppEnvironment(), AppEnvironment.production);
    });

    test('сохранённый выбор dev применяется', () async {
      SharedPreferences.setMockInitialValues({appEnvironmentPrefsKey: 'dev'});
      expect(await resolveAppEnvironment(), AppEnvironment.dev);
    });

    test('испорченное значение не роняет запуск — прод', () async {
      SharedPreferences.setMockInitialValues({
        appEnvironmentPrefsKey: 'что-то неизвестное',
      });
      expect(await resolveAppEnvironment(), AppEnvironment.production);
    });
  });

  group('EnvironmentRepository', () {
    test('сохраняет выбор так, что resolveAppEnvironment его видит', () async {
      SharedPreferences.setMockInitialValues({});
      await EnvironmentRepository().save(AppEnvironment.dev);
      expect(await resolveAppEnvironment(), AppEnvironment.dev);

      await EnvironmentRepository().save(AppEnvironment.production);
      expect(await resolveAppEnvironment(), AppEnvironment.production);
    });
  });

  group('AppEnvironment — адреса бэкендов', () {
    test('у каждого окружения свой базовый URL без завершающего /graphql', () {
      expect(
        AppEnvironment.production.apiBaseUrl,
        'https://api.saobracaj.gleb.at',
      );
      expect(
        AppEnvironment.dev.apiBaseUrl,
        'https://api.saobracaj-dev.gleb.at',
      );
    });
  });
}
