import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/core/keyboard_pagination.dart';
import 'package:saobracaj/core/selection_limit_feedback.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/test/practice/state_management/practice_content_bloc.dart';
import 'package:saobracaj/test/practice/widgets/custom_checkbox.dart';
import 'package:saobracaj/test/practice/widgets/quest_button.dart';
import 'package:saobracaj/test/practice/widgets/question_tries.dart';
import 'package:saobracaj/theme/exam_theme.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

import 'exam_strings.dart';
import 'finalize_practice.dart';
import 'izvestai.dart';

class Practice extends StatelessWidget {
  Practice({super.key, required this.params});

  final PracticeParams params;

  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
      builder: (context, state) {
        return BlocProvider(
          create: (context) => PracticeBloc(state.questionsData!, params)..add(Init()),
          child: BlocConsumer<PracticeBloc, PracticeState>(
            listener: (context, state) => _scrollController.jumpTo(0),
            listenWhen: (previous, current) => previous.currentQuestionIndex != current.currentQuestionIndex,
            builder: (context, state) {
              final questBloc = context.read<PracticeBloc>();
              if (state.finalizeTest) {
                context.read<AllQuestionsBloc>().add(LoadStatistics());
                // The results screen is ordinary app UI (it links back into the
                // trainer), so it keeps the user's own theme even after an
                // exam-styled run.
                return FinalizePracticeWidget();
              }
              // With "buttons like in the exam" on, the whole run is rendered in
              // the frozen replica palette — the Builder puts every descendant
              // context (including the ones handed to the report sheet and the
              // confirmation dialog) below that theme.
              final run = Builder(
                builder: (context) => _buildRun(context, state, questBloc),
              );
              return params.buttonsLikeInExam
                  ? Theme(data: examTheme, child: run)
                  : run;
            },
          ),
        );
      },
    );
  }

  Widget _buildRun(
    BuildContext context,
    PracticeState state,
    PracticeBloc questBloc,
  ) {
    final quiz = Theme.of(context).quiz;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HeaderChip(
                  color: quiz.info,
                  onColor: quiz.onInfo,
                  minWidth: 120,
                  label: ExamStrings.questionCounter(
                    state.currentQuestionIndex + 1,
                    state.questions.length,
                  ),
                ),
                CustomCheckbox(
                  value: state.markedQuestions.contains(
                    state.currentQuestionIndex,
                  ),
                  onChanged: (value) {
                    questBloc.add(ToggleMarkQuestion(state.currentQuestionIndex));
                  },
                  label: ExamStrings.markQuestion,
                ),
                _HeaderChip(
                  // The countdown is the one element the real software renders
                  // on solid black; outside the exam replica it follows the
                  // theme's own high-contrast surface instead.
                  color: params.buttonsLikeInExam
                      ? ExamPalette.timer
                      : Theme.of(context).colorScheme.inverseSurface,
                  onColor: params.buttonsLikeInExam
                      ? Colors.white
                      : Theme.of(context).colorScheme.onInverseSurface,
                  minWidth: 50,
                  label: formatDuration(state.timeLeft),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              ExamStrings.points(state.currentQuestion?.points ?? 0),
              style: TextStyle(
                fontSize: 14,
                color: quiz.info,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      body: state.currentQuestion == null
          ? SizedBox()
          : SingleChildScrollView(
              controller: _scrollController,
              child: _QuestionContent(
                key: ValueKey(state.currentQuestion),
                randomOptions: true,
                question: state.currentQuestion!,
                answers: state.currentAnswers,
                last:
                    state.currentQuestionIndex == state.questions.length - 1,
                showPreviousTries: params.showStats,
                params: params,
              ),
            ),
      bottomNavigationBar: params.buttonsLikeInExam
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: state.currentQuestionIndex == 0
                          ? null
                          : () {
                              questBloc.add(PrevQuestion());
                            },
                      icon: Icon(Icons.arrow_back_ios_new_outlined),
                    ),
                    SizedBox(width: 16),
                    IconButton(
                      onPressed:
                          state.currentQuestionIndex ==
                              state.questions.length - 1
                          ? null
                          : () {
                              questBloc.add(NextQuestion());
                            },
                      icon: Icon(Icons.arrow_forward_ios_outlined),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () async {
                        final res = await _showTable(context, questBloc.state);
                        if (res != null) {
                          questBloc.add(NavigateToQuestion(res));
                        }
                      },
                      icon: Icon(Icons.format_list_numbered),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The exam header's boxed readouts — the question counter and the countdown —
/// drawn as a filled chip inside a same-coloured hairline frame, the way the
/// examination software does it.
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.color,
    required this.onColor,
    required this.label,
    required this.minWidth,
  });

  final Color color;
  final Color onColor;
  final String label;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints: BoxConstraints(minWidth: minWidth),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(color: onColor),
        ),
      ),
    );
  }
}

class _QuestionContent extends StatelessWidget {
  const _QuestionContent({
    super.key,
    required this.randomOptions,
    required this.question,
    required this.answers,
    required this.last,
    required this.showPreviousTries,
    required this.params,
  });

  final bool randomOptions;
  final Question question;
  final Set<Choice>? answers;
  final bool last;
  final bool showPreviousTries;
  final PracticeParams params;

  @override
  Widget build(BuildContext context) {
    final rightAnswers = question.choices.where((element) => element.isCorrect).length;
    final quiz = Theme.of(context).quiz;
    final questBloc = context.read<PracticeBloc>();
    var choices = [...question.choices];

    return BlocProvider(
      key: ValueKey(question.id),
      create: (context) => PracticeContentBloc(choices.toSet(), answers ?? {}, question.id),
      child: BlocBuilder<PracticeBloc, PracticeState>(
        builder: (context, practiceState) {
          return BlocConsumer<PracticeContentBloc, PracticeContentState>(
            // Лишний тап не выбирается — вместо молчаливого отказа даём
            // вибрацию и подсказку с нужным количеством ответов.
            listenWhen: (previous, current) => previous.limitHits != current.limitHits,
            listener: (context, state) => showSelectionLimitFeedback(context, ExamStrings.answerLimitReached(rightAnswers)),
            builder: (context, state) {
              final bloc = context.read<PracticeContentBloc>();
              final first = practiceState.currentQuestionIndex == 0;

              // Клавиатура: ← / → работают как кнопки «претходно/следеће
              // питање» экзаменационной оболочки — сохраняют выбор и
              // переходят (при неверном числе ответов остаёмся с подсказкой,
              // при неверном ответе с включённым показом — раскрываем
              // верный); пробел = «прикажи одговор», если она вообще есть.
              // Стрелки на самой радиокнопке (фокус с Tab) остаются за
              // RadioGroup — он стоит ниже и перехватывает их первым.
              return KeyboardPagination(
                onPrevious: first
                    ? null
                    : () => _saveAndLoadNext(false, context, state, params),
                onNext: last
                    ? null
                    : () => _saveAndLoadNext(true, context, state, params),
                onShowAnswer:
                    params.showRightAnswers && !state.showCorrectAnswers
                    ? () => bloc.add(ShowCorrectAnswers())
                    : null,
                child: RadioGroup<Choice>(
                groupValue: state.selectedChoices.firstOrNull,
                onChanged: (value) {
                  if (value != null) bloc.add(AddChoice(value));
                },
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showPreviousTries) ...[QuestionTries(question.id), SizedBox(height: 16)],
                  ListTile(title: Text(question.text.trim())),
                  if (question.hasImage)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: 200, maxHeight: 600, maxWidth: 600),
                        child: Image.asset('assets/img/${question.imageId}.jpeg'),
                      ),
                    ),
                  if (rightAnswers > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ShakeOnTrigger(
                        trigger: state.limitHits,
                        child: Text(ExamStrings.requiredAnswers(rightAnswers), style: TextStyle(color: quiz.info, fontStyle: FontStyle.italic)),
                      ),
                    ),
                  for (var c in choices)
                    if (rightAnswers > 1)
                      AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        color: !state.showCorrectAnswers ? Colors.transparent : (c.isCorrect ? quiz.correctContainer : quiz.wrongContainer),
                        child: CheckboxListTile(
                          title: Text(c.text),
                          value: state.selectedChoices.contains(c),
                          onChanged: (value) => context.read<PracticeContentBloc>().add(AddChoice(c)),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      )
                    else
                      AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        color: !state.showCorrectAnswers ? Colors.transparent : (c.isCorrect ? quiz.correctContainer : quiz.wrongContainer),
                        child: RadioListTile<Choice>(
                          title: Text(c.text),
                          value: c,
                        ),
                      ),

                  SizedBox(height: 16),
                  if (params.buttonsLikeInExam) ...[
                    if (!first)
                      Container(
                        width: 240,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: CustomIconButton(
                          onPressed: () => _saveAndLoadNext(false, context, state, params),
                          icon: Icons.arrow_back,
                          iconPosition: IconPosition.left,
                          label: ExamStrings.previousQuestion,
                          color: ExamPalette.navigation,
                        ),
                      ),
                    if (practiceState.currentQuestionIndex != practiceState.questions.length - 1)
                      Container(
                        width: 240,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: CustomIconButton(
                          onPressed: () => _saveAndLoadNext(true, context, state, params),
                          icon: Icons.arrow_forward,
                          label: ExamStrings.nextQuestion,
                          color: ExamPalette.navigation,
                        ),
                      ),
                    Container(
                      width: 240,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: CustomIconButton(
                        onPressed: () async => await _finalizeTest(context, state, params),
                        icon: Icons.exit_to_app,
                        label: ExamStrings.endExam,
                        color: ExamPalette.danger,
                      ),
                    ),
                    Container(
                      width: 240,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: CustomIconButton(
                        onPressed: () async {
                          final res = await _showTable(context, questBloc.state);
                          if (res != null) {
                            questBloc.add(NavigateToQuestion(res));
                          }
                        },
                        icon: Icons.format_list_numbered,
                        label: ExamStrings.report,
                        color: ExamPalette.report,
                        textColor: ExamPalette.onReport,
                      ),
                    ),
                    if (params.showRightAnswers)
                      Container(
                        width: 240,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: CustomIconButton(
                          onPressed: () => bloc.add(ShowCorrectAnswers()),
                          icon: Icons.check,
                          label: ExamStrings.showAnswer,
                          color: ExamPalette.success,
                        ),
                      ),
                  ],
                  if (!params.buttonsLikeInExam)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: last ? null : () => _saveAndLoadNext(true, context, state, params),
                        child: Text(ExamStrings.nextQuestion),
                      ),
                    ),
                  if (last && !params.buttonsLikeInExam)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FilledButton(onPressed: () async => await _finalizeTest(context, state, params), child: Text(ExamStrings.endExam)),
                    ),
                  SizedBox(height: 16),
                  if (!params.buttonsLikeInExam && params.showRightAnswers)
                    TextButton(
                      onPressed:
                          state.showCorrectAnswers
                              ? null
                              : () {
                                bloc.add(ShowCorrectAnswers());
                              },
                      child: Text(ExamStrings.showAnswer),
                    ),
                ],
                ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<SavedAnswer> _saveAnswer(BuildContext context, PracticeContentState state, PracticeParams params) async {
    final questBloc = context.read<PracticeBloc>();

    if (state.selectedChoices.isNotEmpty) {
      var correctAnswer = question.choices.where((element) => element.isCorrect).toSet();
      if (correctAnswer.length != state.selectedChoices.length) {
        const snackBar = SnackBar(content: Text(ExamStrings.wrongAnswerCount));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        return SavedAnswer.wrongNumber;
      }
      questBloc.add(AddAnswer(question.id, state.selectedChoices));
      return setEquals(state.selectedChoices, correctAnswer) ? SavedAnswer.correct : SavedAnswer.incorrect;
    } else {
      // no answer, can be next
      return SavedAnswer.empty;
    }
  }

  Future<void> _finalizeTest(BuildContext context, PracticeContentState state, PracticeParams params) async {
    final questBloc = context.read<PracticeBloc>();
    final bloc = context.read<PracticeContentBloc>();
    final saved = await _saveAnswer(context, state, params);
    // if (saved == null) return;
    if (saved == SavedAnswer.incorrect && params.showRightAnswers && !state.showCorrectAnswers) {
      // нужно показать правильный ответ перед завершением
      bloc.add(ShowCorrectAnswers());
      return;
    }
    if (params.buttonsLikeInExam || questBloc.state.answers.length != questBloc.state.questions.length) {
      if (!context.mounted) return;
      final res = await _showMyDialog(context);
      if (res != true) {
        return;
      }
    }
    questBloc.add(FinalizeTest());
  }

  Future<void> _saveAndLoadNext(bool isNext, BuildContext context, PracticeContentState state, PracticeParams params) async {
    final practiceBloc = context.read<PracticeBloc>();
    final bloc = context.read<PracticeContentBloc>();
    final saved = await _saveAnswer(context, state, params);

    if (saved == SavedAnswer.incorrect && params.showRightAnswers && !state.showCorrectAnswers) {
      //  ответ неверный, показываем верный
      bloc.add(ShowCorrectAnswers());
      return;
    }

    if (saved != SavedAnswer.wrongNumber && isNext) {
      practiceBloc.add(NextQuestion());
    } else if (saved != SavedAnswer.wrongNumber) {
      practiceBloc.add(PrevQuestion());
    }
  }
}

Future<int?> _showTable(BuildContext context, PracticeState state) async {
  final res = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder:
        (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            final allQuestions = context.read<AllQuestionsBloc>().state.questionsData?.questions ?? [];
            List<TableEntry> entries = [];
            for (var i = 0; i < state.questions.length; i++) {
              final q = state.questions[i];
              final question = allQuestions.firstWhere((element) => element.id == q);
              final t = TableEntry(
                question: ExamStrings.reportRow(i + 1),
                points: question.points,
                answered: state.answers.containsKey(q),
                marked: state.markedQuestions.contains(i),
              );
              entries.add(t);
            }
            return SingleChildScrollView(controller: controller, child: QuestionsTable(entries: entries, onAnswerToggle: (index, value) {}));
          },
        ),
  );
  return res;
}

Future<bool?> _showMyDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(ExamStrings.finishTitle),
        content: const SingleChildScrollView(
          child: ListBody(
            children: <Widget>[Text(ExamStrings.finishBody)],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text(ExamStrings.finishCancel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text(ExamStrings.finishConfirm),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  );
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

enum SavedAnswer { correct, incorrect, empty, wrongNumber }
