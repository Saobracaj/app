import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:restart_app/restart_app.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../flavor.dart';
import '../data/environment_repository.dart';
import 'environment_events.dart';
import 'environment_state.dart';

/// Переключение окружения (prod/dev) из секретного диалога «О приложении».
///
/// Смена окружения — это смена бэкенда: сохранённая сессия и кэши относятся к
/// прежнему серверу, поэтому подтверждение выбора разлогинивает пользователя и
/// перезапускает приложение; новое окружение вступает в силу на старте
/// (`resolveAppEnvironment` в `lib/main_prod.dart`).
@injectable
class EnvironmentBloc extends Bloc<EnvironmentEvent, EnvironmentState> {
  EnvironmentBloc(this._repository, this._auth)
    : super(
        EnvironmentState(selected: FlavorConfig.instance.environment),
      ) {
    on<EnvironmentSelected>(
      (event, emit) => emit(state.copyWith(selected: event.environment)),
    );
    on<EnvironmentSwitchConfirmed>(_confirm);
  }

  final EnvironmentRepository _repository;
  final AuthRepository _auth;

  Future<void> _confirm(
    EnvironmentSwitchConfirmed event,
    Emitter<EnvironmentState> emit,
  ) async {
    if (state.switching) return;
    emit(state.copyWith(switching: true));
    await _repository.save(state.selected);
    await _auth.logout();
    // Дальше процесс живёт секунды: на Android приложение перезапускается,
    // на iOS — закрывается (полный перезапуск процесса там невозможен, выбор
    // применится при следующем открытии).
    await Restart.restartApp();
  }
}
