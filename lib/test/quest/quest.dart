import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/keyboard_hints.dart';
import 'package:saobracaj/core/keyboard_pagination.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/core/selection_limit_feedback.dart';
import 'package:saobracaj/core/question_pager.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/dictionary/dict_links.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
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
import 'presentation/tabs_seen_reporter.dart';
import 'question_features/presentation/question_features_tabs.dart';
import 'question_features/state_management/question_cues_bloc.dart';
import 'question_features/state_management/question_cues_events.dart';
import 'question_features/state_management/question_cues_state.dart';

class Quest extends StatelessWidget {
  const Quest({
    super.key,
    required this.questions,
    required this.options,
    this.subcategory,
    this.openChat = false,
    this.chatMessageId,
    this.revealAnswers = false,
    this.answers,
  });

  final List<int> questions;
  final StartTestState options;
  final String? subcategory;

  /// Deep-link support: open straight into the discussion tab (revealing the
  /// feature tabs) and, optionally, expand/scroll to a specific thread.
  final bool openChat;
  final String? chatMessageId;

  /// Start with the answers already revealed, and with [answers] preselected —
  /// how the question preview sheet hands a question it has already been
  /// answered in over to the full screen.
  final bool revealAnswers;
  final Set<Choice>? answers;

  /// Принудительно собирать экран по-вебовски вне веба — для виджет-тестов,
  /// где `kIsWeb` всегда `false` (ср. [KeyboardHints.debugForceVisible]).
  @visibleForTesting
  static bool debugForceWeb = false;

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
            presentation: options.presentation,
          ),
          child: _QuestRun(
            questions: qs,
            options: options,
            openChat: openChat,
            chatMessageId: chatMessageId,
            revealAnswers: revealAnswers,
            answers: answers,
          ),
        );
      },
    );
  }
}

/// Прогон вопросов: страницы-вопросы под общей шапкой, полосой прогресса и
/// нижней панелью.
///
/// Stateful ради трёх вещей, которые обязаны пережить перестройку экрана:
/// листалки ([QuestionPager] со своим `PageController`), непрерывного
/// положения между вопросами (по нему полоса прогресса ведёт подсветку) и
/// блоков содержимого — по одному на вопрос.
///
/// Блок на вопрос, а не один на прогон: страницы живут рядом, сосед виден уже
/// во время свайпа, и его выбор нельзя держать в общем блоке. Заодно это
/// чинит и старую потерю состояния — вернувшись к вопросу свайпом назад,
/// пользователь застаёт его таким, каким оставил (выбор на месте, раскрытый
/// ответ раскрыт), а не сброшенным.
class _QuestRun extends StatefulWidget {
  const _QuestRun({
    required this.questions,
    required this.options,
    required this.openChat,
    required this.chatMessageId,
    required this.revealAnswers,
    required this.answers,
  });

  /// Весь банк вопросов (с уже перемешанными вариантами, если так просили) —
  /// прогон берёт из него свои по id.
  final List<Question> questions;
  final StartTestState options;

  /// Как открыли экран: см. одноимённые поля [Quest]. Всё это относится
  /// только к первому вопросу прогона — дальше пользователь листает сам.
  final bool openChat;
  final String? chatMessageId;
  final bool revealAnswers;
  final Set<Choice>? answers;

  @override
  State<_QuestRun> createState() => _QuestRunState();
}

class _QuestRunState extends State<_QuestRun> {
  final _contentBlocs = <int, QuestContentBloc>{};

  /// Положение прогона между вопросами (0 — первый, 1.5 — ровно между вторым
  /// и третьим): его ведёт листалка, а читает полоса прогресса.
  final _position = ValueNotifier<double>(0);

  @override
  void dispose() {
    for (final bloc in _contentBlocs.values) {
      bloc.close();
    }
    _position.dispose();
    super.dispose();
  }

  Question _question(int id) =>
      widget.questions.firstWhere((element) => element.id == id);

  /// Блок вопроса [id], один на весь прогон. Первый вопрос получает то, с чем
  /// экран открыли (глубокая ссылка в обсуждение, предпросмотр с уже
  /// раскрытым ответом), остальные — только записанный ранее ответ.
  QuestContentBloc _contentBloc(QuestState state, int id) {
    return _contentBlocs.putIfAbsent(id, () {
      final initial = state.questions.first == id;
      return QuestContentBloc(
        {..._question(id).choices},
        state.answers[id] ?? (initial ? widget.answers : null) ?? {},
        id,
        revealAnswers: initial && (widget.openChat || widget.revealAnswers),
        presentation: widget.options.presentation,
      );
    });
  }

  /// Прогон уехал с вопроса [index] свайпом: записываем выбор ровно так же,
  /// как это делает кнопка «Дальше» (неполный набор — подсказка и ничего не
  /// записываем, неверный — записываем и раскрываем верные ответы, только
  /// уже на оставленной позади странице).
  void _recordOnLeave(BuildContext context, QuestState state, int index) {
    if (index < 0 || index >= state.questions.length) return;
    final id = state.questions[index];
    final bloc = _contentBlocs[id];
    if (bloc == null) return;
    // Тот же выбор уже записан — второй попытки в статистике быть не должно
    // (вопрос можно листать туда-сюда сколько угодно).
    final recorded = state.answers[id];
    if (recorded != null && setEquals(recorded, bloc.state.selectedChoices)) {
      return;
    }
    QuestActions(context, _question(id), content: bloc).submit();
  }

  /// Страница одного вопроса — со своим блоком содержимого и своей
  /// прокруткой.
  Widget _page(BuildContext context, QuestState state, int index) {
    final id = state.questions[index];
    final question = _question(id);
    // Глубокая ссылка ведёт в обсуждение конкретного вопроса — открывать ту
    // же вкладку на всех следующих не за чем.
    final deepLink = widget.openChat && state.questions.first == id;
    return BlocProvider.value(
      value: _contentBloc(state, id),
      child: context.isExpandedScreen
          ? _WideQuestBody(
              question: question,
              first: index == 0,
              last: index == state.questions.length - 1,
              openChat: deepLink,
              chatMessageId: deepLink ? widget.chatMessageId : null,
            )
          : ListView(
              // Короткий вопрос тоже должен отзываться на потяг — иначе полосу
              // прогресса не раскрыть жестом.
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                QuestionContent(
                  question: question,
                  openChat: deepLink,
                  chatMessageId: deepLink ? widget.chatMessageId : null,
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuestBloc, QuestState>(
      builder: (context, state) {
        final questBloc = context.read<QuestBloc>();
        // One description of the run, shared by the progress strip and
        // whoever else needs it, so they cannot drift apart.
        final entries = [
          for (var i = 0; i < state.questions.length; i++)
            _entryFor(state, widget.questions, i),
        ];
        if (state.finalizeTest) {
          context.read<AllQuestionsBloc>().add(LoadStatistics());
          // The answers just recorded change the automatic
          // "recent mistakes" list on the home screen.
          context.read<QuestionListsBloc>().add(QuestionListsRefreshed());
          return FinalizeTestWidget();
        }
        final currentId = state.questions[state.currentQuestionIndex];
        final question = _question(currentId);
        return MultiBlocProvider(
          // Перевод — на весь прогон (и сбрасывается при переходе), а блок
          // содержимого текущего вопроса поднят над Scaffold, чтобы шапка и
          // прибитая к низу панель видели выбор и раскрытие. Сам блок при
          // этом принадлежит прогону, а не этому месту дерева, — той же
          // страницей он выдаётся и внутри листалки.
          providers: [
            BlocProvider(create: (context) => TranslationsBloc()),
            BlocProvider.value(value: _contentBloc(state, currentId)),
          ],
          child: BlocListener<QuestBloc, QuestState>(
            listenWhen: (prev, curr) =>
                prev.currentQuestionIndex != curr.currentQuestionIndex,
            // РУ-подстрочник новый вопрос встречает выключенным.
            listener: (context, state) =>
                context.read<TranslationsBloc>().add(ResetTranslation()),
            child: Builder(
              builder: (context) {
                final wide = context.isExpandedScreen;
                // Раскрытая пагинация и подсказка клавиш — обстановка веба
                // с мышью и клавиатурой, то есть просторного окна браузера.
                // Узкое окно — это телефонный браузер: там палец, и экран
                // собирается ровно как в мобильной версии (полоса прогресса
                // под шапкой, внизу одна панель действий) — трёхэтажный низ
                // съедал у вопроса половину высоты.
                final webChrome =
                    (kIsWeb || Quest.debugForceWeb) && context.isMediumScreen;
                final first = state.currentQuestionIndex == 0;
                final last =
                    state.currentQuestionIndex == state.questions.length - 1;
                // Один набор действий на все способы листать вопросы: кнопки
                // нижней панели и клавиши ← / → / пробел. Свайп идёт своим
                // путём — страница едет за пальцем, и остановить её на
                // полпути нельзя, — поэтому он только записывает выбор
                // (см. [_recordOnLeave]).
                final actions = QuestActions(context, question);
                final body = QuestionPager(
                  index: state.currentQuestionIndex,
                  itemCount: state.questions.length,
                  position: _position,
                  onIndexChanged: (index) =>
                      questBloc.add(MoveToQuestion(state.questions[index])),
                  onLeaving: (index) => _recordOnLeave(context, state, index),
                  itemBuilder: (context, index) => _page(context, state, index),
                );
                final bottomBar = wide
                    // На широком экране действия стоят прямо под вариантами
                    // ответа (см. _WideQuestBody) — мышью до прибитой к низу
                    // окна панели тянуться неудобно.
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
                // Низ экрана: панель действий (на узком экране),
                // в просторном вебе — пагинация и под ней мелкая подсказка,
                // что теми же путями ходят ← / → и пробел. Если
                // собирать нечего (широкий экран вне веба) —
                // панели нет вовсе.
                final bottomChildren = <Widget>[
                  ?bottomBar,
                  if (webChrome) pagination,
                  if (KeyboardHints.visible)
                    KeyboardHints(navigation: state.questions.length > 1),
                ];
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
                      categoryId: question.categoryId,
                    ),
                    // Полоса закреплена под шапкой, а её раскрытием
                    // управляют жесты тела: потяг вниз у самого верха
                    // раскрывает навигатор, прокрутка вверх — сворачивает.
                    // Прокрутка вопроса приходит к ней через листалку, то
                    // есть на уровень глубже (scrollDepth). В просторном
                    // вебе полосы нет: там мышь, и вместо жеста внизу
                    // страницы стоит раскрытая пагинация (см. ниже).
                    body: webChrome
                        ? body
                        : QuestionProgressHeader(
                            entries: entries,
                            currentQuestionId: currentId,
                            position: _position,
                            scrollDepth: 1,
                            onQuestionSelected: (picked) =>
                                questBloc.add(MoveToQuestion(picked)),
                            child: body,
                          ),
                    bottomNavigationBar: bottomChildren.isEmpty
                        ? null
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: bottomChildren,
                          ),
                  ),
                );
              },
            ),
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
    required this.question,
    required this.first,
    required this.last,
    required this.openChat,
    required this.chatMessageId,
  });

  final Question question;
  final bool first;
  final bool last;
  final bool openChat;
  final String? chatMessageId;

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
                          openChat: openChat,
                          chatMessageId: chatMessageId,
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
                        initialFeature: openChat
                            ? AppFeature.publicQuestionComments
                            : null,
                        chatMessageId: openChat ? chatMessageId : null,
                        autoScroll: openChat,
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
    this.openChat = false,
    this.chatMessageId,
    this.showFeatureTabs = true,
  });

  final Question question;

  /// Deep-link into the discussion for this question (reveal tabs + open the
  /// comments tab and scroll to it).
  final bool openChat;
  final String? chatMessageId;

  /// The wide layout hosts the tabs in its own right-hand pane and switches
  /// them off here.
  final bool showFeatureTabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rightAnswers = question.choices
        .where((element) => element.isCorrect)
        .length;

    return BlocProvider(
      // Lazy: built (and the asset read) only once a highlight is actually
      // asked for — i.e. after the reveal, and only for users who have the
      // analysis tab.
      create: (_) =>
          getIt<QuestionCuesBloc>(param1: question.id)
            ..add(QuestionCuesRequested()),
      child: BlocBuilder<TranslationsBloc, TranslationsState>(
        builder: (context, translationState) {
          final showTranslation = translationState.showTranslation;
          // SelectionArea makes the statement, the RU interlinear line and the
          // answer texts copyable (long press on touch, mouse drag on
          // desktop/web) without touching the tap-to-answer gesture: plain
          // Text/RichText register with it, so no SelectableText is needed
          // (SelectableText would swallow the taps on the answer cards).
          return SelectionArea(
            child: Column(
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
                      _WithCues(
                        builder: (context, cues) => QuestMarkdown(
                          text: dictLinks(context, question.text.trim()),
                          highlights: cues.questionHighlights,
                          pStyle: theme.textTheme.titleMedium,
                        ),
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
                        _WithCues(
                          builder: (context, cues) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var c in question.choices)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    8,
                                  ),
                                  child: AnswerOptionCard(
                                    choice: c,
                                    selected: state.selectedChoices.contains(c),
                                    revealed: state.showCorrectAnswers,
                                    showTranslation: showTranslation,
                                    highlights: cues.optionHighlights,
                                    onTap: state.showCorrectAnswers
                                        ? null
                                        : () => bloc.add(AddChoice(c)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (state.showCorrectAnswers && showFeatureTabs)
                          // The tabs host their own inputs and gestures (chat,
                          // comments); keep them out of the selection scope.
                          SelectionContainer.disabled(
                            child: TabsSeenReporter(
                              key: ValueKey('tabs-seen-${question.id}'),
                              questionId: question.id,
                              child: QuestionFeaturesTabs(
                                questionId: question.id,
                                categoryId: question.categoryId,
                                initialFeature: openChat
                                    ? AppFeature.publicQuestionComments
                                    : null,
                                chatMessageId: openChat ? chatMessageId : null,
                                autoScroll: openChat,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Resolves the key-phrase highlights for the question text and the answer
/// cards: the cues of the analysis tab, but only once the answers are revealed
/// (the tabs are on screen, so the tab explaining the highlights is a tap
/// away) and only for users who have that tab at all. Until then — and for
/// everybody else — the builder gets an empty state and nothing is marked.
class _WithCues extends StatelessWidget {
  const _WithCues({required this.builder});

  final Widget Function(BuildContext context, QuestionCuesState cues) builder;

  @override
  Widget build(BuildContext context) {
    final active =
        context.select(
          (FeatureFlagsBloc bloc) =>
              bloc.state.isEnabled(AppFeature.questionAnalysis),
        ) &&
        context.select(
          (QuestContentBloc bloc) => bloc.state.showCorrectAnswers,
        );
    if (!active) return builder(context, const QuestionCuesState());
    return BlocBuilder<QuestionCuesBloc, QuestionCuesState>(builder: builder);
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
