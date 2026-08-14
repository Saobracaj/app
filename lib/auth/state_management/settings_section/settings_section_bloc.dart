import 'package:flutter_bloc/flutter_bloc.dart';

import 'settings_section_events.dart';
import 'settings_section_state.dart';

/// Держит выбранный раздел настроек широкой раскладки. Зависимостей нет,
/// поэтому блок создаётся прямо в `BlocProvider(create:)` без DI.
class SettingsSectionBloc
    extends Bloc<SettingsSectionEvent, SettingsSectionState> {
  SettingsSectionBloc() : super(const SettingsSectionState()) {
    on<SettingsSectionSelected>(
      (event, emit) => emit(state.copyWith(selected: event.section)),
    );
  }
}
