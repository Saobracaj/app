import 'package:freezed_annotation/freezed_annotation.dart';

import '../app_environment.dart';

part 'environment_state.freezed.dart';

@freezed
abstract class EnvironmentState with _$EnvironmentState {
  const factory EnvironmentState({
    /// Окружение, отмеченное в диалоге (не обязательно активное).
    required AppEnvironment selected,

    /// Идёт переключение: сохранение выбора, разлогин и перезапуск.
    @Default(false) bool switching,
  }) = _EnvironmentState;
}
