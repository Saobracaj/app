import '../app_environment.dart';

sealed class EnvironmentEvent {}

/// В диалоге отмечено окружение [environment].
class EnvironmentSelected extends EnvironmentEvent {
  EnvironmentSelected(this.environment);

  final AppEnvironment environment;
}

/// Нажата кнопка «Переключить»: сохранить выбор, разлогинить и перезапустить.
class EnvironmentSwitchConfirmed extends EnvironmentEvent {}
