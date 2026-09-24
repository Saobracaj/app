import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/practice/practice.dart' show formatDuration;
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart';

/// Экран паузы симуляции: таймер стоит, вместо вопроса — надпись «Пауза» и
/// три действия. «Возобновить» пускает таймер дальше с того же вопроса;
/// «Завершить» (после предупреждения) бросает симуляцию без результата и
/// уводит на страницу запуска; «На главную» оставляет симуляцию на паузе —
/// на главной её будет ждать баннер «продолжить».
class PauseScreen extends StatelessWidget {
  const PauseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<PracticeBloc>();
    final timeLeft = context.select<PracticeBloc, Duration>(
      (b) => b.state.timeLeft,
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ReadableWidth(
            maxWidth: 480,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    LocaleKeys.simulation_pause_title.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LocaleKeys.simulation_pause_subtitle.tr(
                      args: [formatDuration(timeLeft)],
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => bloc.add(ResumeRequested()),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(LocaleKeys.simulation_pause_resume.tr()),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _finish(context, bloc),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(LocaleKeys.simulation_pause_finish.tr()),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    // Симуляция остаётся на паузе (снимок лежит в хранилище);
                    // абсолютный путь снимает экран симуляции со стека.
                    onPressed: () => Routemaster.of(context).push('/home'),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(LocaleKeys.simulation_pause_home.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context, PracticeBloc bloc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.simulation_pause_finishTitle.tr()),
        content: Text(LocaleKeys.simulation_pause_finishBody.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LocaleKeys.simulation_pause_cancel.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(LocaleKeys.simulation_pause_finishConfirm.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    bloc.add(AbandonSimulation());
    Routemaster.of(context).push('/practice');
  }
}
