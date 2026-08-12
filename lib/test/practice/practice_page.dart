import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_time_ago/get_time_ago.dart';
import 'package:routemaster/routemaster.dart';

import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/presentation/wide_layout.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/practice/finalize_practice.dart';
import 'package:saobracaj/test/practice/practice.dart' show formatDuration;
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/test/practice/exam_strings.dart';
import 'package:saobracaj/test/practice/widgets/quest_button.dart';
import 'package:saobracaj/theme/exam_theme.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

class PracticePage extends StatelessWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<PracticePageBloc>(),
      child: BlocBuilder<PracticePageBloc, PracticeParams>(
        builder: (context, state) {
          // Широкий экран: настройки и таблица прошлых попыток слева,
          // карточка запуска — справа (макет веб-версии).
          if (context.isExpandedScreen) {
            final withSidebar = context.isLargeScreen;
            return Scaffold(
              appBar: withSidebar
                  ? null
                  : AppBar(
                      title: Text(LocaleKeys.simulation_title.tr()),
                      actions: const [AuthButton()],
                    ),
              backgroundColor: widePageBackground(context),
              body: ListView(
                children: [
                  WideContent(
                    maxWidth: 1140,
                    padding: const EdgeInsets.fromLTRB(40, 34, 40, 64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (withSidebar)
                          PageHeading(
                            title: LocaleKeys.simulation_title.tr(),
                            subtitle: LocaleKeys.simulation_subtitle.tr(),
                          ),
                        MainWithSide(
                          sideWidth: 320,
                          main: _WideOptions(state: state),
                          side: _StartCard(state: state, onStart: onPressed),
                          sideFirstWhenStacked: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(LocaleKeys.simulation_title.tr()),
              actions: const [AuthButton()],
            ),
            body: ReadableWidth(
              child: ListView(
                children: [
                  CheckboxListTile(
                    title: Text(
                      LocaleKeys.simulation_options_showErrorsImmediately.tr(),
                    ),
                    value: state.showRightAnswers,
                    onChanged: (value) => context.read<PracticePageBloc>().add(
                      ToggleRightAnswers(),
                    ),
                  ),
                  CheckboxListTile(
                    title: Text(
                      LocaleKeys.simulation_options_showStatistics.tr(),
                    ),
                    value: state.showStats,
                    onChanged: (value) =>
                        context.read<PracticePageBloc>().add(ToggleShowStats()),
                  ),
                  CheckboxListTile(
                    title: Text(
                      LocaleKeys.simulation_options_buttonsLikeInExam.tr(),
                    ),
                    // subtitle: Text('Менее удобно, но ближе к реальности'),
                    value: state.buttonsLikeInExam,
                    onChanged: (value) => context.read<PracticePageBloc>().add(
                      ToggleButtonsLikeInExam(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: state.buttonsLikeInExam
                        ? CustomIconButton(
                            onPressed: () => onPressed(context, state),
                            icon: Icons.arrow_forward,
                            label: ExamStrings.confirmStart,
                            color: ExamPalette.header,
                          )
                        : FilledButton(
                            onPressed: () => onPressed(context, state),
                            child: Text(LocaleKeys.simulation_start.tr()),
                          ),
                  ),
                  if (state.records.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        LocaleKeys.simulation_previousTries.tr(
                          args: [state.records.length.toString()],
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (var record in state.records)
                      ListTile(
                        title: Text(
                          LocaleKeys.simulation_previousTriesItem.tr(
                            args: [
                              record.points.toString(),
                              record.mistakes.toString(),
                              formatDuration(
                                Duration(seconds: record.durationSeconds),
                              ),
                            ],
                          ),
                        ),
                        subtitle: Text(GetTimeAgo.parse(record.time)),
                        leading: record.points < kMinPoints
                            ? Icon(
                                Icons.close,
                                color: Theme.of(context).quiz.wrong,
                              )
                            : Icon(
                                Icons.check,
                                color: Theme.of(context).quiz.correct,
                              ),
                        onTap: record.wrongAnswers.isEmpty
                            ? null
                            : () {
                                Routemaster.of(context).push(
                                  '/start?q=${record.wrongAnswers.join(',')}',
                                );
                              },
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void onPressed(BuildContext context, PracticeParams state) async {
    await Routemaster.of(context)
        .push(
          '/questPractice?'
          'showRightAnswers=${state.showRightAnswers}'
          '&showStats=${state.showStats}'
          '&buttonsLikeInExam=${state.buttonsLikeInExam}',
        )
        .result;
    if (context.mounted) {
      context.read<PracticePageBloc>().add(LoadPrevTries());
    }
  }
}

/// Настройки симуляции и таблица прошлых попыток — левая колонка широкого
/// экрана.
class _WideOptions extends StatelessWidget {
  const _WideOptions({required this.state});

  final PracticeParams state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PracticePageBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                title: Text(
                  LocaleKeys.simulation_options_showErrorsImmediately.tr(),
                ),
                value: state.showRightAnswers,
                onChanged: (_) => bloc.add(ToggleRightAnswers()),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(LocaleKeys.simulation_options_showStatistics.tr()),
                value: state.showStats,
                onChanged: (_) => bloc.add(ToggleShowStats()),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(
                  LocaleKeys.simulation_options_buttonsLikeInExam.tr(),
                ),
                value: state.buttonsLikeInExam,
                onChanged: (_) => bloc.add(ToggleButtonsLikeInExam()),
              ),
            ],
          ),
        ),
        if (state.records.isNotEmpty) ...[
          const SizedBox(height: 32),
          SectionHeading(
            title: LocaleKeys.quest_previousTries.tr(),
            hint: '${state.records.length}',
          ),
          _AttemptsTable(records: state.records),
        ],
      ],
    );
  }
}

/// Прошлые попытки таблицей: статус, баллы, ошибки, время и когда это было.
/// Строка ведёт к разбору ошибок этой попытки.
class _AttemptsTable extends StatelessWidget {
  const _AttemptsTable({required this.records});

  final List<PracticeResult> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );
    final numeric = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AttemptRow(
          status: Text(
            LocaleKeys.simulation_table_result.tr(),
            style: headerStyle,
          ),
          points: Text(
            LocaleKeys.simulation_table_points.tr(),
            style: headerStyle,
          ),
          errors: Text(
            LocaleKeys.simulation_table_errors.tr(),
            style: headerStyle,
          ),
          time: Text(LocaleKeys.simulation_table_time.tr(), style: headerStyle),
          when: Text(LocaleKeys.simulation_table_when.tr(), style: headerStyle),
        ),
        for (final record in records)
          _AttemptRow(
            divided: true,
            // Разбор ошибок — там же, куда ведёт строка в мобильном списке.
            onTap: record.wrongAnswers.isEmpty
                ? null
                : () => Routemaster.of(
                    context,
                  ).push('/start?q=${record.wrongAnswers.join(',')}'),
            status: _StatusBadge(passed: record.points >= kMinPoints),
            points: Text('${record.points}', style: numeric),
            errors: Text('${record.mistakes}', style: numeric),
            time: Text(
              formatDuration(Duration(seconds: record.durationSeconds)),
              style: numeric,
            ),
            when: Text(
              GetTimeAgo.parse(record.time),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Одна строка таблицы попыток (она же — строка заголовков).
class _AttemptRow extends StatelessWidget {
  const _AttemptRow({
    required this.status,
    required this.points,
    required this.errors,
    required this.time,
    required this.when,
    this.onTap,
    this.divided = false,
  });

  final Widget status;
  final Widget points;
  final Widget errors;
  final Widget time;
  final Widget when;
  final VoidCallback? onTap;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Align(alignment: Alignment.centerLeft, child: status),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerRight, child: points),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerRight, child: errors),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerRight, child: time),
          ),
          Expanded(
            flex: 3,
            child: Align(alignment: Alignment.centerRight, child: when),
          ),
        ],
      ),
    );
    final content = onTap == null
        ? row
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: row,
          );
    if (!divided) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: content,
    );
  }
}

/// Плашка «Сдано / Не сдано» в таблице попыток.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.passed});

  final bool passed;

  @override
  Widget build(BuildContext context) {
    final quiz = Theme.of(context).quiz;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: passed ? quiz.correctContainer : quiz.wrongContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        passed
            ? LocaleKeys.simulation_passed.tr()
            : LocaleKeys.simulation_failed.tr(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: passed ? quiz.onCorrectContainer : quiz.onWrongContainer,
        ),
      ),
    );
  }
}

/// Правая карточка широкого экрана: порог сдачи, лучший результат и кнопка
/// запуска симуляции.
class _StartCard extends StatelessWidget {
  const _StartCard({required this.state, required this.onStart});

  final PracticeParams state;
  final void Function(BuildContext context, PracticeParams state) onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = state.records.isEmpty
        ? null
        : state.records.map((e) => e.points).reduce((a, b) => a > b ? a : b);
    return SurfaceCard(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            [
              LocaleKeys.simulation_threshold.tr(args: ['$kMinPoints']),
              if (best != null)
                LocaleKeys.simulation_bestResult.tr(args: ['$best']),
            ].join(' '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          state.buttonsLikeInExam
              ? CustomIconButton(
                  onPressed: () => onStart(context, state),
                  icon: Icons.arrow_forward,
                  label: ExamStrings.confirmStart,
                  color: ExamPalette.header,
                )
              : FilledButton(
                  onPressed: () => onStart(context, state),
                  child: Text(LocaleKeys.simulation_start.tr()),
                ),
        ],
      ),
    );
  }
}
