/// Веб: «установки» нет, есть только открытие страницы.
Future<DateTime?> readInstalledAt() async => null;

Future<String?> readPlayReferrer() async => null;

/// Редирект ссылки-источника отправляет браузер на сайт с `?lnk=<id клика>` —
/// веб-версия отдаёт его бэкенду, и визит привязывается к клику точно.
String? readWebClickId() {
  final id = Uri.base.queryParameters['lnk']?.trim();
  return id == null || id.isEmpty ? null : id;
}

String launchPlatform() => 'WEB';
