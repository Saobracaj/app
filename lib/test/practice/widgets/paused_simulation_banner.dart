import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/practice/domain/paused_simulation.dart';
import 'package:saobracaj/test/practice/practice.dart' show formatDuration;
import 'package:saobracaj/test/practice/state_management/paused_simulation_bloc.dart';
import 'package:saobracaj/test/practice/state_management/paused_simulation_state.dart';
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart'
    show kExamDuration;

/// Баннер «Симуляция экзамена на паузе» — на главной и на странице запуска
/// симуляции, пока на устройстве лежит незавершённая симуляция. Показывает,
/// когда она начата и на каком вопросе стоит; «Продолжить» открывает
/// симуляцию с того же места, и таймер идёт дальше.
///
/// Без снимка не рисует ничего (и не занимает места — [padding] применяется
/// только к видимому баннеру).
class PausedSimulationBanner extends StatelessWidget {
  const PausedSimulationBanner({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PausedSimulationBloc, PausedSimulationState>(
      builder: (context, state) {
        final snapshot = state.snapshot;
        if (snapshot == null) return const SizedBox.shrink();
        return Padding(
          padding: padding,
          child: _Banner(snapshot: snapshot),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.snapshot});

  final PausedSimulation snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = context.locale.toString();
    final started = DateFormat.yMd(locale).add_Hm().format(snapshot.startedAt);
    final timeLeft = kExamDuration - Duration(seconds: snapshot.elapsedSeconds);
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    LocaleKeys.simulation_pause_bannerTitle.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.simulation_pause_bannerStarted.tr(args: [started]),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            Text(
              LocaleKeys.simulation_pause_bannerProgress.tr(
                args: [
                  '${snapshot.currentQuestionIndex + 1}',
                  '${snapshot.questions.length}',
                  formatDuration(timeLeft),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(LocaleKeys.simulation_pause_continue.tr()),
                onPressed: () => resumePausedSimulation(context, snapshot),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Открывает экран симуляции поверх всего с немедленным возобновлением
/// таймера. Настройки запуска дублируются в адресе, чтобы перезагрузка вкладки
/// на вебе после завершения этой симуляции стартовала новую с теми же опциями.
void resumePausedSimulation(BuildContext context, PausedSimulation snapshot) {
  Routemaster.of(context).push(
    '/questPractice',
    queryParameters: {
      'resume': 'true',
      'showRightAnswers': '${snapshot.showRightAnswers}',
      'showStats': '${snapshot.showStats}',
      'buttonsLikeInExam': '${snapshot.buttonsLikeInExam}',
    },
  );
}
