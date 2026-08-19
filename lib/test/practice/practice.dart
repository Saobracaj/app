import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/core/keyboard_hints.dart';
import 'package:saobracaj/core/swipe_pagination.dart';
import 'package:saobracaj/core/keyboard_pagination.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/core/selection_limit_feedback.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_bloc.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_events.dart';
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
        // The bank may still be loading when the run screen is built — a cold
        // start straight on '/questPractice', or the first start before the
        // asset parse has finished. Dereferencing `questionsData` here killed
        // the whole screen into a grey error box; wait for it instead.
        final data = state.questionsData;
        if (data == null) return _LoadingRun(errorMessage: state.errorMessage);
        return BlocProvider(
          create: (context) => PracticeBloc(data, params)..add(Init()),
          child: BlocConsumer<PracticeBloc, PracticeState>(
            // The scroll view is recreated together with the question's
            // content (it sits under the per-question key), so the controller
            // may momentarily have no position to jump.
            listener: (context, state) {
              if (_scrollController.hasClients) _scrollController.jumpTo(0);
            },
            listenWhen: (previous, current) =>
                previous.currentQuestionIndex != current.currentQuestionIndex,
            builder: (context, state) {
              final questBloc = context.read<PracticeBloc>();
              if (state.finalizeTest) {
                context.read<AllQuestionsBloc>().add(LoadStatistics());
                // Экзамен записан в practice_records — пересчитываем автосписки,
                // чтобы «ошибки последнего экзамена» появились на главной сразу,
                // без перезапуска приложения. Ждём именно [attemptSaved]: экран
                // результата строится раньше, чем запись доходит до базы.
                if (state.attemptSaved) {
                  context.read<QuestionListsBloc>().add(
                    QuestionListsRefreshed(),
                  );
                }
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
                    questBloc.add(
                      ToggleMarkQuestion(state.currentQuestionIndex),
                    );
                  },
                  label: ExamStrings.markQuestion,
                  // Room for the whole caption once the header is not
                  // squeezed between the two chips on a phone.
                  width: context.isExpandedScreen ? 220 : 150,
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
          : _QuestionContent(
              key: ValueKey(state.currentQuestion),
              randomOptions: true,
              question: state.currentQuestion!,
              answers: state.currentAnswers,
              last: state.currentQuestionIndex == state.questions.length - 1,
              showPreviousTries: params.showStats,
              params: params,
              scrollController: _scrollController,
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
                    // Между стрелками и отчётом — мелкая подсказка про
                    // клавиши (только на вебе, см. KeyboardHints).
                    Expanded(
                      child: KeyboardHints(
                        showAnswer: params.showRightAnswers,
                        padding: EdgeInsets.zero,
                      ),
                    ),
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

/// Shown while the question bank is still loading (or failed to load): the
/// simulation cannot start without it, so there is nothing to draw yet.
class _LoadingRun extends StatelessWidget {
  const _LoadingRun({this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final message = errorMessage;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: message == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    // Без банка симуляция не стартует вообще, поэтому у сбоя
                    // загрузки должен быть выход, кроме перезапуска приложения.
                    FilledButton(
                      onPressed: () =>
                          context.read<AllQuestionsBloc>().add(Load()),
                      child: Text(LocaleKeys.simulation_retry.tr()),
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
    required this.scrollController,
  });

  final bool randomOptions;
  final Question question;
  final Set<Choice>? answers;
  final bool last;
  final bool showPreviousTries;
  final PracticeParams params;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final rightAnswers = question.choices
        .where((element) => element.isCorrect)
        .length;
    final quiz = Theme.of(context).quiz;
    final questBloc = context.read<PracticeBloc>();
    var choices = [...question.choices];

    return BlocProvider(
      key: ValueKey(question.id),
      create: (context) =>
          PracticeContentBloc(choices.toSet(), answers ?? {}, question.id),
      child: BlocBuilder<PracticeBloc, PracticeState>(
        builder: (context, practiceState) {
          return BlocConsumer<PracticeContentBloc, PracticeContentState>(
            // Лишний тап не выбирается — вместо молчаливого отказа даём
            // вибрацию и подсказку с нужным количеством ответов.
            listenWhen: (previous, current) =>
                previous.limitHits != current.limitHits,
            listener: (context, state) => showSelectionLimitFeedback(
              context,
              ExamStrings.answerLimitReached(rightAnswers),
            ),
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
              // The actions of the exam replica; which of them exist depends
              // on the position in the run and on the training options.
              final examActions = _ExamActions(
                previous: first
                    ? null
                    : () => _saveAndLoadNext(false, context, state, params),
                next: last
                    ? null
                    : () => _saveAndLoadNext(true, context, state, params),
                endExam: () async =>
                    await _finalizeTest(context, state, params),
                report: () async {
                  final res = await _showTable(context, questBloc.state);
                  if (res != null) {
                    questBloc.add(NavigateToQuestion(res));
                  }
                },
                showAnswer: params.showRightAnswers
                    ? () => bloc.add(ShowCorrectAnswers())
                    : null,
              );
              // On a wide screen the replica follows the real software's
              // layout: the question fills the page from the left and the
              // buttons sit in a bar pinned to the bottom of the window —
              // navigation on the left, "show the answer" in the middle,
              // the report and the end of the exam on the right. On phones
              // the buttons stay stacked under the answers, where a thumb
              // reaches them.
              final wideExam =
                  params.buttonsLikeInExam && context.isExpandedScreen;

              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showPreviousTries) ...[
                    QuestionTries(question.id),
                    SizedBox(height: 16),
                  ],
                  // Текст вопроса и вариантов можно выделить и скопировать
                  // (долгий тап / протяжка мышью); тап по варианту по-прежнему
                  // выбирает его — SelectionArea не перехватывает обычные тапы.
                  SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(title: Text(question.text.trim())),
                        if (question.hasImage)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: 200,
                                maxHeight: 600,
                                maxWidth: 600,
                              ),
                              child: Image.asset(
                                'assets/img/${question.imageId}.jpeg',
                              ),
                            ),
                          ),
                        if (rightAnswers > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ShakeOnTrigger(
                              trigger: state.limitHits,
                              child: Text(
                                ExamStrings.requiredAnswers(rightAnswers),
                                style: TextStyle(
                                  color: quiz.info,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        for (var c in choices)
                          if (rightAnswers > 1)
                            AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              color: !state.showCorrectAnswers
                                  ? Colors.transparent
                                  : (c.isCorrect
                                        ? quiz.correctContainer
                                        : quiz.wrongContainer),
                              child: CheckboxListTile(
                                title: Text(c.text),
                                value: state.selectedChoices.contains(c),
                                onChanged: (value) => context
                                    .read<PracticeContentBloc>()
                                    .add(AddChoice(c)),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            )
                          else
                            AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              color: !state.showCorrectAnswers
                                  ? Colors.transparent
                                  : (c.isCorrect
                                        ? quiz.correctContainer
                                        : quiz.wrongContainer),
                              child: RadioListTile<Choice>(
                                title: Text(c.text),
                                value: c,
                              ),
                            ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),
                  if (params.buttonsLikeInExam && !wideExam) ...[
                    _ExamButtonsColumn(actions: examActions),
                    KeyboardHints(
                      showAnswer: examActions.showAnswer != null,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    ),
                  ],
                  if (!params.buttonsLikeInExam)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: last
                            ? null
                            : () => _saveAndLoadNext(
                                true,
                                context,
                                state,
                                params,
                              ),
                        child: Text(ExamStrings.nextQuestion),
                      ),
                    ),
                  if (last && !params.buttonsLikeInExam)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FilledButton(
                        onPressed: () async =>
                            await _finalizeTest(context, state, params),
                        child: Text(ExamStrings.endExam),
                      ),
                    ),
                  SizedBox(height: 16),
                  if (!params.buttonsLikeInExam && params.showRightAnswers)
                    TextButton(
                      onPressed: state.showCorrectAnswers
                          ? null
                          : () {
                              bloc.add(ShowCorrectAnswers());
                            },
                      child: Text(ExamStrings.showAnswer),
                    ),
                ],
              );

              // Свайп по телу вопроса листает его так же, как «претходно /
              // следеће питање» и стрелки; кнопки прибитой к низу панели
              // (широкий экран) остаются вне жеста.
              final scrollable = SwipePagination(
                onPrevious: examActions.previous,
                onNext: examActions.next,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: content,
                ),
              );

              return KeyboardPagination(
                onPrevious: examActions.previous,
                onNext: examActions.next,
                onShowAnswer: state.showCorrectAnswers
                    ? null
                    : examActions.showAnswer,
                child: RadioGroup<Choice>(
                  groupValue: state.selectedChoices.firstOrNull,
                  onChanged: (value) {
                    if (value != null) bloc.add(AddChoice(value));
                  },
                  child: wideExam
                      ? Column(
                          children: [
                            Expanded(child: scrollable),
                            _ExamActionBar(actions: examActions),
                          ],
                        )
                      : scrollable,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<SavedAnswer> _saveAnswer(
    BuildContext context,
    PracticeContentState state,
    PracticeParams params,
  ) async {
    final questBloc = context.read<PracticeBloc>();

    if (state.selectedChoices.isNotEmpty) {
      var correctAnswer = question.choices
          .where((element) => element.isCorrect)
          .toSet();
      if (correctAnswer.length != state.selectedChoices.length) {
        const snackBar = SnackBar(content: Text(ExamStrings.wrongAnswerCount));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        return SavedAnswer.wrongNumber;
      }
      questBloc.add(AddAnswer(question.id, state.selectedChoices));
      return setEquals(state.selectedChoices, correctAnswer)
          ? SavedAnswer.correct
          : SavedAnswer.incorrect;
    } else {
      // no answer, can be next
      return SavedAnswer.empty;
    }
  }

  Future<void> _finalizeTest(
    BuildContext context,
    PracticeContentState state,
    PracticeParams params,
  ) async {
    final questBloc = context.read<PracticeBloc>();
    final bloc = context.read<PracticeContentBloc>();
    final saved = await _saveAnswer(context, state, params);
    // if (saved == null) return;
    if (saved == SavedAnswer.incorrect &&
        params.showRightAnswers &&
        !state.showCorrectAnswers) {
      // нужно показать правильный ответ перед завершением
      bloc.add(ShowCorrectAnswers());
      return;
    }
    if (params.buttonsLikeInExam ||
        questBloc.state.answers.length != questBloc.state.questions.length) {
      if (!context.mounted) return;
      final res = await _showMyDialog(context);
      if (res != true) {
        return;
      }
    }
    questBloc.add(FinalizeTest());
  }

  Future<void> _saveAndLoadNext(
    bool isNext,
    BuildContext context,
    PracticeContentState state,
    PracticeParams params,
  ) async {
    final practiceBloc = context.read<PracticeBloc>();
    final bloc = context.read<PracticeContentBloc>();
    final saved = await _saveAnswer(context, state, params);

    if (saved == SavedAnswer.incorrect &&
        params.showRightAnswers &&
        !state.showCorrectAnswers) {
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

/// The callbacks behind the buttons of the exam replica. A `null` callback
/// means the button does not exist at this point of the run (no "previous"
/// on the first question, no "next" on the last one, no "show the answer"
/// unless the training option is on).
class _ExamActions {
  const _ExamActions({
    required this.previous,
    required this.next,
    required this.endExam,
    required this.report,
    required this.showAnswer,
  });

  final VoidCallback? previous;
  final VoidCallback? next;
  final VoidCallback endExam;
  final VoidCallback report;
  final VoidCallback? showAnswer;
}

/// Phone layout of the replica's buttons: a stack of fixed-width buttons
/// under the answers, in the order the real software lists them.
class _ExamButtonsColumn extends StatelessWidget {
  const _ExamButtonsColumn({required this.actions});

  final _ExamActions actions;

  @override
  Widget build(BuildContext context) {
    Widget item(Widget button, {double top = 4}) => Container(
      width: 240,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: top),
      child: button,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (actions.previous != null)
          item(_ExamButton.previous(actions.previous), top: 8),
        if (actions.next != null) item(_ExamButton.next(actions.next)),
        item(_ExamButton.endExam(actions.endExam)),
        item(_ExamButton.report(actions.report)),
        if (actions.showAnswer != null)
          item(_ExamButton.showAnswer(actions.showAnswer)),
      ],
    );
  }
}

/// Wide-screen layout of the replica's buttons — the bar the real
/// examination software pins to the bottom of the page: navigation on the
/// left, "show the answer" (training only) centred, the report and the end of
/// the exam on the right. Drawn on the software's light-grey strip; the
/// button groups shrink gracefully on medium widths instead of overflowing.
class _ExamActionBar extends StatelessWidget {
  const _ExamActionBar({required this.actions});

  final _ExamActions actions;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    Widget slot(Widget button) => Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, minHeight: 48),
        child: button,
      ),
    );
    // Three regions with symmetric flex factors: the middle one is always
    // centred in the window whatever the sides hold, and on medium widths
    // every group shrinks proportionally rather than one of them being
    // squeezed out.
    final buttons = Row(
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              if (actions.previous != null) ...[
                slot(_ExamButton.previous(actions.previous)),
                const SizedBox(width: _gap),
              ],
              if (actions.next != null) slot(_ExamButton.next(actions.next)),
            ],
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (actions.showAnswer != null)
                slot(_ExamButton.showAnswer(actions.showAnswer)),
            ],
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              slot(_ExamButton.report(actions.report)),
              const SizedBox(width: _gap),
              slot(_ExamButton.endExam(actions.endExam)),
            ],
          ),
        ),
      ],
    );
    return Material(
      color: ExamPalette.actionBar,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buttons,
              // A discreet reminder under the buttons that ← / → / space do
              // the same (web only, see KeyboardHints).
              KeyboardHints(
                showAnswer: actions.showAnswer != null,
                padding: const EdgeInsets.only(top: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The five buttons of the exam replica, each with its fixed colour, icon and
/// Serbian caption — shared by the phone stack and the wide bar so both
/// layouts show the very same buttons.
abstract final class _ExamButton {
  static Widget previous(VoidCallback? onPressed) => CustomIconButton(
    onPressed: onPressed,
    icon: Icons.arrow_back,
    iconPosition: IconPosition.left,
    label: ExamStrings.previousQuestion,
    color: ExamPalette.navigation,
  );

  static Widget next(VoidCallback? onPressed) => CustomIconButton(
    onPressed: onPressed,
    icon: Icons.arrow_forward,
    label: ExamStrings.nextQuestion,
    color: ExamPalette.navigation,
  );

  static Widget endExam(VoidCallback? onPressed) => CustomIconButton(
    onPressed: onPressed,
    icon: Icons.exit_to_app,
    label: ExamStrings.endExam,
    color: ExamPalette.danger,
  );

  static Widget report(VoidCallback? onPressed) => CustomIconButton(
    onPressed: onPressed,
    icon: Icons.format_list_numbered,
    label: ExamStrings.report,
    color: ExamPalette.report,
    textColor: ExamPalette.onReport,
  );

  static Widget showAnswer(VoidCallback? onPressed) => CustomIconButton(
    onPressed: onPressed,
    icon: Icons.check,
    label: ExamStrings.showAnswer,
    color: ExamPalette.success,
  );
}

Future<int?> _showTable(BuildContext context, PracticeState state) async {
  final res = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        final allQuestions =
            context.read<AllQuestionsBloc>().state.questionsData?.questions ??
            [];
        List<TableEntry> entries = [];
        for (var i = 0; i < state.questions.length; i++) {
          final q = state.questions[i];
          final question = allQuestions.firstWhere(
            (element) => element.id == q,
          );
          final t = TableEntry(
            question: ExamStrings.reportRow(i + 1),
            points: question.points,
            answered: state.answers.containsKey(q),
            marked: state.markedQuestions.contains(i),
          );
          entries.add(t);
        }
        return SingleChildScrollView(
          controller: controller,
          child: QuestionsTable(
            entries: entries,
            onAnswerToggle: (index, value) {},
          ),
        );
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
          child: ListBody(children: <Widget>[Text(ExamStrings.finishBody)]),
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
