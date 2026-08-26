import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../di.dart';
import '../../../flavor.dart';
import '../app_environment.dart';
import '../state_management/environment_bloc.dart';
import '../state_management/environment_events.dart';
import '../state_management/environment_state.dart';

/// Секретный диалог переключения окружения (prod/dev).
///
/// Открывается долгим нажатием на блок версии в «О приложении», и только не на
/// вебе — веб-клиент выбирает окружение автоматически по домену
/// (saobracaj-dev.gleb.at смотрит на dev). Строки сознательно не
/// локализованы: это инструмент разработчика, а не пользовательский экран.
Future<void> showEnvironmentDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => getIt<EnvironmentBloc>(),
      child: const _EnvironmentDialog(),
    ),
  );
}

class _EnvironmentDialog extends StatelessWidget {
  const _EnvironmentDialog();

  @override
  Widget build(BuildContext context) {
    final active = FlavorConfig.instance.environment;
    return BlocBuilder<EnvironmentBloc, EnvironmentState>(
      builder: (context, state) {
        final bloc = context.read<EnvironmentBloc>();
        return AlertDialog(
          title: const Text('Окружение'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioGroup<AppEnvironment>(
                groupValue: state.selected,
                onChanged: (value) {
                  // Пока идёт переключение, выбор заморожен.
                  if (state.switching || value == null) return;
                  bloc.add(EnvironmentSelected(value));
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final environment in AppEnvironment.values)
                      RadioListTile<AppEnvironment>(
                        value: environment,
                        title: Text(environment.name),
                        subtitle: Text(environment.apiBaseUrl),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Смена окружения разлогинит и перезапустит приложение.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: state.switching
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: state.switching
                  ? null
                  : () {
                      // Выбор не изменился — переключать нечего.
                      if (state.selected == active) {
                        Navigator.of(context).pop();
                        return;
                      }
                      bloc.add(EnvironmentSwitchConfirmed());
                    },
              child: state.switching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Переключить'),
            ),
          ],
        );
      },
    );
  }
}
