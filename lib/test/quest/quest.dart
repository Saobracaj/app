import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/dictionary/dictionary.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_bloc.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_events.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/quest/state_management/quest_bloc.dart';
import 'package:saobracaj/test/quest/state_management/quest_content_bloc.dart';
import 'package:saobracaj/test/quest/state_management/translations_bloc.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

import 'finalize_test.dart';
import 'presentation/answer_option_card.dart';
import 'presentation/quest_app_bar.dart';
import 'presentation/quest_bottom_bar.dart';
import 'presentation/quest_markdown.dart';
import 'presentation/question_image_card.dart';
import 'presentation/question_progress_strip.dart';
import 'question_features/presentation/question_features_tabs.dart';

class Quest extends StatelessWidget {
  const Quest({
    super.key,
    required this.questions,
    required this.options,
    this.subcategory,
    this.openComments = false,
    this.commentThreadId,
  });

  final List<int> questions;
  final StartTestState options;
  final String? subcategory;

  /// Deep-link support: open straight into the discussion tab (revealing the
  /// feature tabs) and, optionally, expand/scroll to a specific thread.
  final bool openComments;
  final String? commentThreadId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
      builder: (context, state) {
        final qqs = [...state.questionsData!.questions];
        final qs = <Question>[];
        for (var q in qqs) {
          if (options.randomOptionsOrder) {
            qs.add(q.copyWith(choices: [...q.choices]..shuffle()));
          } else {
            qs.add(q.copyWith());
          }
        }
        return BlocProvider(
          create: (context) => QuestBloc(
            state.questionsData!.copyWith(questions: qs),
            options.random ? ([...questions]..shuffle()) : [...questions],
            subcategory,
          ),
          child: BlocBuilder<QuestBloc, QuestState>(
            builder: (context, state) {
              final questBloc = context.read<QuestBloc>();
              // One description of the run, shared by the progress strip and
              // whoever else needs it, so they cannot drift apart.
              final entries = [
                for (var i = 0; i < state.questions.length; i++)
                  _entryFor(state, qs, i),
              ];
              if (state.finalizeTest) {
                context.read<AllQuestionsBloc>().add(LoadStatistics());
                // The answers just recorded change the automatic
                // "recent mistakes" list on the home screen.
                context.read<QuestionListsBloc>().add(QuestionListsRefreshed());
                return FinalizeTestWidget();
              }
              final currentId = state.questions[state.currentQuestionIndex];
              final question = qs.firstWhere(
                (element) => element.id == currentId,
              );
              return MultiBlocProvider(
                // Deliberately NOT keyed by question: the blocs live for the
                // whole run and are reset through QuestionChanged /
                // ResetTranslation below. Recreating the subtree per question
                // (the old approach) also recreated the progress strip, which
                // killed its collapse animation on every jump.
                providers: [
                  BlocProvider(create: (context) => TranslationsBloc()),
                  // Hoisted above the Scaffold so the app bar and the pinned
                  // bottom bar see the selection / reveal state too.
                  BlocProvider(
                    create: (context) => QuestContentBloc(
                      {...question.choices},
                      state.answers[currentId] ?? {},
                      currentId,
                      revealAnswers: openComments,
                    ),
                  ),
                ],
                child: BlocListener<QuestBloc, QuestState>(
                  listenWhen: (prev, curr) =>
                      prev.currentQuestionIndex != curr.currentQuestionIndex,
                  listener: (context, state) {
                    // Selection state must not leak between questions (and the
                    // RU toggle deliberately resets).
                    final id = state.questions[state.currentQuestionIndex];
                    final q = qs.firstWhere((element) => element.id == id);
                    context.read<QuestContentBloc>().add(
                      QuestionChanged({...q.choices}, state.answers[id] ?? {}, id),
                    );
                    context.read<TranslationsBloc>().add(ResetTranslation());
                  },
                  child: Scaffold(
                    appBar: QuestAppBar(
                      questionNumber: state.currentQuestionIndex + 1,
                      questionCount: state.questions.length,
                      points: question.points,
                      questionId: currentId,
                    ),
                    // Полоса закреплена под шапкой, а её раскрытием управляют
                    // жесты тела: потяг вниз у самого верха раскрывает
                    // навигатор, прокрутка вверх — сворачивает.
                    body: QuestionProgressHeader(
                      entries: entries,
                      currentQuestionId: currentId,
                      onQuestionSelected: (picked) =>
                          questBloc.add(MoveToQuestion(picked)),
                      child: ListView(
                        // Короткий вопрос тоже должен отзываться на потяг —
                        // иначе полосу не раскрыть жестом.
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          QuestionContent(
                            key: ValueKey(currentId),
                            question: question,
                            openComments: openComments,
                            commentThreadId: commentThreadId,
                          ),
                        ],
                      ),
                    ),
                    bottomNavigationBar: QuestBottomBar(
                      question: question,
                      first: state.currentQuestionIndex == 0,
                      last:
                          state.currentQuestionIndex ==
                          state.questions.length - 1,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Describes the question at [index] of the run: its number, its worth and
/// whether it has been answered correctly yet.
QuestionNavigatorEntry _entryFor(
  QuestState state,
  List<Question> qs,
  int index,
) {
  final id = state.questions[index];
  final question = qs.firstWhere((element) => element.id == id);
  final given = state.answers[id];
  final correct = question.choices
      .where((element) => element.isCorrect)
      .toSet();
  return QuestionNavigatorEntry(
    questionId: id,
    number: index + 1,
    points: question.points,
    status: given == null
        ? QuestionStatus.unanswered
        : (setEquals(given, correct)
              ? QuestionStatus.correct
              : QuestionStatus.wrong),
  );
}

/// The scrolling body of one question: image, text (with the optional RU
/// interlinear line), the required-answers chip, the answer cards and — once
/// the answers are revealed — the feature tabs. The actions live in the
/// pinned bottom bar, not here.
class QuestionContent extends StatelessWidget {
  const QuestionContent({
    super.key,
    required this.question,
    this.openComments = false,
    this.commentThreadId,
  });

  final Question question;

  /// Deep-link into the discussion for this question (reveal tabs + open the
  /// comments tab and scroll to it).
  final bool openComments;
  final String? commentThreadId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rightAnswers = question.choices
        .where((element) => element.isCorrect)
        .length;

    return BlocBuilder<TranslationsBloc, TranslationsState>(
      builder: (context, translationState) {
        final showTranslation = translationState.showTranslation;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The header (image + statement) deliberately sits outside the
            // QuestContentBloc builder: markdown parsing is not free, and the
            // statement does not change when a choice is tapped.
            if (question.hasImage) ...[
              QuestionImageCard(imageId: question.imageId),
              SizedBox(height: 14),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuestMarkdown(
                    text: question.text.trim().dict,
                    pStyle: theme.textTheme.titleMedium,
                  ),
                  if (showTranslation && question.translation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        question.translation!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 10),
            if (rightAnswers > 1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RequiredAnswersChip(count: rightAnswers),
              ),
              SizedBox(height: 12),
            ],
            BlocBuilder<QuestContentBloc, QuesContentState>(
              builder: (context, state) {
                final bloc = context.read<QuestContentBloc>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c in question.choices)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: AnswerOptionCard(
                          choice: c,
                          selected: state.selectedChoices.contains(c),
                          revealed: state.showCorrectAnswers,
                          showTranslation: showTranslation,
                          onTap: state.showCorrectAnswers
                              ? null
                              : () => bloc.add(AddChoice(c)),
                        ),
                      ),
                    if (state.showCorrectAnswers)
                      QuestionFeaturesTabs(
                        questionId: question.id,
                        categoryId: question.categoryId,
                        initialFeature: openComments
                            ? AppFeature.publicQuestionComments
                            : null,
                        commentThreadId: openComments ? commentThreadId : null,
                        autoScroll: openComments,
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

/// The "Потребна N одговора" chip shown on multi-answer questions.
class _RequiredAnswersChip extends StatelessWidget {
  const _RequiredAnswersChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final quiz = Theme.of(context).quiz;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: quiz.infoContainer,
        borderRadius: BorderRadius.circular(13),
      ),
      // widthFactor keeps the chip hugging its label instead of stretching.
      child: Center(
        widthFactor: 1,
        child: Text(
          LocaleKeys.quest_requiredAnswers.plural(count),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: quiz.onInfoContainer,
          ),
        ),
      ),
    );
  }
}
