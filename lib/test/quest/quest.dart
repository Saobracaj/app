import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/keyboard_pagination.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/core/selection_limit_feedback.dart';
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
import 'presentation/quest_actions.dart';
import 'presentation/quest_app_bar.dart';
import 'presentation/quest_bottom_bar.dart';
import 'presentation/quest_markdown.dart';
import 'presentation/question_image_card.dart';
import 'presentation/question_pagination.dart';
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
    this.revealAnswers = false,
    this.answers,
  });

  final List<int> questions;
  final StartTestState options;
  final String? subcategory;

  /// Deep-link support: open straight into the discussion tab (revealing the
  /// feature tabs) and, optionally, expand/scroll to a specific thread.
  final bool openComments;
  final String? commentThreadId;

  /// Start with the answers already revealed, and with [answers] preselected —
  /// how the question preview sheet hands a question it has already been
  /// answered in over to the full screen.
  final bool revealAnswers;
  final Set<Choice>? answers;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
      builder: (context, state) {
        // A cold start straight on a deep link (`/question/8084` pasted into
        // the browser's address bar) builds this screen before the question
        // bank has loaded from the assets — `questionsData` is still null and
        // must not be dereferenced, or the first frame dies into a grey screen.
        final data = state.questionsData;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: state.errorMessage == null
                  ? const CircularProgressIndicator()
                  : Text(state.errorMessage!),
            ),
          );
        }
        final qqs = [...data.questions];
        final qs = <Question>[];
        for (var q in qqs) {
          if (options.randomOptionsOrder) {
            qs.add(q.copyWith(choices: [...q.choices]..shuffle()));
          } else {
            qs.add(q.copyWith());
          }
        }
        // A link can name a question that does not exist (a typo, a stale id):
        // running with it would crash the `firstWhere` below, so keep only the
        // ids the bank actually has and say so when nothing is left.
        final known = {for (final q in qs) q.id};
        final requested = questions.where(known.contains).toList();
        if (requested.isEmpty) return const _QuestionNotFound();
        return BlocProvider(
          create: (context) => QuestBloc(
            data.copyWith(questions: qs),
            options.random ? (requested..shuffle()) : requested,
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
                      state.answers[currentId] ?? answers ?? {},
                      currentId,
                      revealAnswers: openComments || revealAnswers,
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
                      QuestionChanged(
                        {...q.choices},
                        state.answers[id] ?? {},
                        id,
                      ),
                    );
                    context.read<TranslationsBloc>().add(ResetTranslation());
                  },
                  child: Builder(
                    builder: (context) {
                      final wide = context.isExpandedScreen;
                      final first = state.currentQuestionIndex == 0;
                      final last =
                          state.currentQuestionIndex ==
                          state.questions.length - 1;
                      final body = wide
                          ? _WideQuestBody(
                              key: ValueKey(currentId),
                              question: question,
                              first: first,
                              last: last,
                              openComments: openComments,
                              commentThreadId: commentThreadId,
                            )
                          : ListView(
                              // Короткий вопрос тоже должен отзываться на
                              // потяг — иначе полосу не раскрыть жестом.
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                QuestionContent(
                                  key: ValueKey(currentId),
                                  question: question,
                                  openComments: openComments,
                                  commentThreadId: commentThreadId,
                                ),
                              ],
                            );
                      final bottomBar = wide
                          // На широком экране действия стоят прямо под
                          // вариантами ответа (см. _WideQuestBody) — мышью до
                          // прибитой к низу окна панели тянуться неудобно.
                          ? null
                          : QuestBottomBar(
                              question: question,
                              first: first,
                              last: last,
                            );
                      final pagination = QuestionPagination(
                        entries: entries,
                        currentQuestionId: currentId,
                        onQuestionSelected: (picked) =>
                            questBloc.add(MoveToQuestion(picked)),
                      );
                      // Клавиатура: ← / → листают вопросы теми же путями,
                      // что кнопки нижней панели (→ записывает выбор, как
                      // «Дальше»; на последнем вопросе → ничего не делает —
                      // завершение прогона остаётся за явным нажатием
                      // кнопки), пробел = «показать ответ».
                      final actions = QuestActions(context, question);
                      return KeyboardPagination(
                        onPrevious: first ? null : actions.previous,
                        onNext: last ? null : actions.next,
                        onShowAnswer: actions.showAnswer,
                        child: Scaffold(
                          appBar: QuestAppBar(
                            questionNumber: state.currentQuestionIndex + 1,
                            questionCount: state.questions.length,
                            points: question.points,
                            questionId: currentId,
                          ),
                          // Полоса закреплена под шапкой, а её раскрытием
                          // управляют жесты тела: потяг вниз у самого верха
                          // раскрывает навигатор, прокрутка вверх — сворачивает.
                          // На вебе полосы нет: там мышь, и вместо жеста внизу
                          // страницы стоит раскрытая пагинация (см. ниже).
                          body: kIsWeb
                              ? body
                              : QuestionProgressHeader(
                                  entries: entries,
                                  currentQuestionId: currentId,
                                  onQuestionSelected: (picked) =>
                                      questBloc.add(MoveToQuestion(picked)),
                                  child: body,
                                ),
                          bottomNavigationBar: kIsWeb
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [?bottomBar, pagination],
                                )
                              : bottomBar,
                        ),
                      );
                    },
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

/// The wide-screen (tablet landscape / web) body of a question: the question
/// itself on the left with the actions right under the answers, and the
/// feature tabs (explanation, discussion, …) in their own scrollable pane on
/// the right — long texts are unreadable at full window width, and this way
/// they don't push the answers off screen either.
class _WideQuestBody extends StatelessWidget {
  const _WideQuestBody({
    super.key,
    required this.question,
    required this.first,
    required this.last,
    required this.openComments,
    required this.commentThreadId,
  });

  final Question question;
  final bool first;
  final bool last;
  final bool openComments;
  final String? commentThreadId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The tabs pane takes what a comfortable reading column needs and no
        // more; the question keeps the rest.
        final paneWidth = (constraints.maxWidth * 0.42)
            .clamp(360.0, 520.0)
            .toDouble();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // Прокручивается вся колонка, а колонка чтения ограничена уже
              // внутри списка: иначе scrollbar рисуется по краю этих 640
              // логических пикселей, то есть посреди экрана, а не у
              // разделителя, где его ищет рука.
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ReadableWidth(
                    maxWidth: 640,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QuestionContent(
                          question: question,
                          openComments: openComments,
                          commentThreadId: commentThreadId,
                          showFeatureTabs: false,
                        ),
                        QuestBottomBar(
                          question: question,
                          first: first,
                          last: last,
                          inline: true,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            SizedBox(
              width: paneWidth,
              child: BlocBuilder<QuestContentBloc, QuesContentState>(
                buildWhen: (prev, curr) =>
                    prev.showCorrectAnswers != curr.showCorrectAnswers,
                builder: (context, state) {
                  if (!state.showCorrectAnswers) {
                    // The pane fills with the feature tabs on reveal; until
                    // then an empty surface would read as something broken.
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          LocaleKeys.quest_wideTabsPlaceholder.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    children: [
                      QuestionFeaturesTabs(
                        questionId: question.id,
                        categoryId: question.categoryId,
                        initialFeature: openComments
                            ? AppFeature.publicQuestionComments
                            : null,
                        commentThreadId: openComments ? commentThreadId : null,
                        autoScroll: openComments,
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
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
    this.showFeatureTabs = true,
  });

  final Question question;

  /// Deep-link into the discussion for this question (reveal tabs + open the
  /// comments tab and scroll to it).
  final bool openComments;
  final String? commentThreadId;

  /// The wide layout hosts the tabs in its own right-hand pane and switches
  /// them off here.
  final bool showFeatureTabs;

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
            BlocConsumer<QuestContentBloc, QuesContentState>(
              // Тап сверх лимита ничего не выбирает — вместо этого подсказка
              // с вибрацией, чтобы отказ не выглядел «залипанием» интерфейса.
              listenWhen: (prev, curr) => prev.limitHits != curr.limitHits,
              listener: (context, state) => showSelectionLimitFeedback(
                context,
                LocaleKeys.quest_answerLimitReached.plural(rightAnswers),
              ),
              builder: (context, state) {
                final bloc = context.read<QuestContentBloc>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rightAnswers > 1) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ShakeOnTrigger(
                          trigger: state.limitHits,
                          child: _RequiredAnswersChip(count: rightAnswers),
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
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
                    if (state.showCorrectAnswers && showFeatureTabs)
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

/// What a deep link to a nonexistent question id lands on instead of a crash.
class _QuestionNotFound extends StatelessWidget {
  const _QuestionNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LocaleKeys.quest_questionNotFound.tr(),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Routemaster.of(context).replace('/home'),
                child: Text(LocaleKeys.quest_toHome.tr()),
              ),
            ],
          ),
        ),
      ),
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
