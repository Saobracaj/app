import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_time_ago/get_time_ago.dart';
import 'package:routemaster/routemaster.dart';

import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/core/di.dart';
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
          return Scaffold(
            appBar: AppBar(
              title: Text(LocaleKeys.simulation_title.tr()),
              actions: const [AuthButton()],
            ),
            body: ListView(
              children: [
                CheckboxListTile(
                  title: Text(LocaleKeys.simulation_options_showErrorsImmediately.tr()),
                  value: state.showRightAnswers,
                  onChanged: (value) => context.read<PracticePageBloc>().add(ToggleRightAnswers()),
                ),
                CheckboxListTile(
                  title: Text(LocaleKeys.simulation_options_showStatistics.tr()),
                  value: state.showStats,
                  onChanged: (value) => context.read<PracticePageBloc>().add(ToggleShowStats()),
                ),
                CheckboxListTile(
                  title: Text(LocaleKeys.simulation_options_buttonsLikeInExam.tr()),
                  // subtitle: Text('Менее удобно, но ближе к реальности'),
                  value: state.buttonsLikeInExam,
                  onChanged: (value) => context.read<PracticePageBloc>().add(ToggleButtonsLikeInExam()),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child:
                      state.buttonsLikeInExam
                          ? CustomIconButton(
                            onPressed: () => onPressed(context, state),
                            icon: Icons.arrow_forward,
                            label: ExamStrings.confirmStart,
                            color: ExamPalette.header,
                          )
                          : FilledButton(onPressed: () => onPressed(context, state), child: Text(LocaleKeys.simulation_start.tr())),
                ),
                if (state.records.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      LocaleKeys.simulation_previousTries.tr(args: [state.records.length.toString()]),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (var record in state.records)
                    ListTile(
                      title: Text(
                        LocaleKeys.simulation_previousTriesItem.tr(
                          args: [record.points.toString(), record.mistakes.toString(), formatDuration(Duration(seconds: record.durationSeconds))],
                        ),
                      ),
                      subtitle: Text(GetTimeAgo.parse(record.time)),
                      leading: record.points < kMinPoints
                          ? Icon(Icons.close, color: Theme.of(context).quiz.wrong)
                          : Icon(Icons.check, color: Theme.of(context).quiz.correct),
                      onTap:
                          record.wrongAnswers.isEmpty
                              ? null
                              : () {
                                Routemaster.of(context).push('/start?q=${record.wrongAnswers.join(',')}');
                              },
                    ),
                ],
              ],
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
