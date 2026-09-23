import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/keyboard_hints.dart';
import 'package:saobracaj/core/keyboard_pagination.dart';
import 'package:saobracaj/core/question_pager.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/core/selection_limit_feedback.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_bloc.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_events.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/practice/data/paused_simulation_repository.dart';
import 'package:saobracaj/test/practice/state_management/practice_bloc.dart';
import 'package:saobracaj/test/practice/state_management/practice_content_bloc.dart';
import 'package:saobracaj/test/practice/state_management/practice_page_bloc.dart';
import 'package:saobracaj/test/practice/widgets/custom_checkbox.dart';
import 'package:saobracaj/test/practice/widgets/pause_screen.dart';
import 'package:saobracaj/test/practice/widgets/quest_button.dart';
import 'package:saobracaj/test/practice/widgets/question_tries.dart';
import 'package:saobracaj/theme/exam_theme.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

import 'exam_strings.dart';
import 'finalize_practice.dart';
import 'izvestai.dart';

/// Экран идущей симуляции. Если на устройстве лежит снимок незавершённой
/// симуляции, экран продолжает её (с её же настройками), а не начинает новую;
/// [resume] — сразу пустить таймер (кнопка «продолжить»), иначе она откроется
/// на экране паузы.
class Practice extends StatelessWidget {
  const Practice({super.key, required this.params, this.resume = false});

  final PracticeParams params;
  final bool resume;

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
          create: (context) {
            final snapshots = getIt<PausedSimulationRepository>();
            final snapshot = snapshots.current;
            return PracticeBloc(
              data,
              snapshot == null
                  ? params
                  : PracticeParams(
                      showRightAnswers: snapshot.showRightAnswers,
                      showStats: snapshot.showStats,
                      buttonsLikeInExam: snapshot.buttonsLikeInExam,
                    ),
              snapshots: snapshots,
              snapshot: snapshot,
              resume: resume,
            )..add(Init());
          },
          child: BlocConsumer<PracticeBloc, PracticeState>(
            // Симуляцию бросили на другом устройстве: здесь она тоже
            // закончилась, без результата — уходим на страницу запуска.
            listenWhen: (previous, current) =>
                !previous.endedRemotely && current.endedRemotely,
            listener: (context, state) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(
                    LocaleKeys.simulation_sync_abandonedElsewhere.tr(),
                  ),
                ),
              );
              Routemaster.of(context).push('/practice');
            },
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
              // Экран паузы — обычный экран приложения (в теме пользователя,
              // как и результат): паузы в настоящем экзамене нет.
              if (state.paused) return const PauseScreen();
              // Настройки берём у блока: у продолженной симуляции они из
              // снимка, а не из адреса.
              final params = questBloc.params;
              // With "buttons like in the exam" on, the whole run is rendered in
              // the frozen replica palette — every descendant context (including
              // the ones handed to the report sheet and the confirmation dialog)
              // sits below that theme.
              return params.buttonsLikeInExam
                  ? Theme(data: examTheme, child: const _PracticeRun())
                  : const _PracticeRun();
            },
          ),
        );
      },
    );
  }
}

/// Идущий прогон: шапка экзамена, листалка вопросов и кнопки.
///
/// Вопросы листаются настоящим [PageView] ([QuestionPager]): страница едет за
/// пальцем, сосед виден уже во время протяжки. Источник правды о номере
/// вопроса — [PracticeBloc]; кнопки, клавиши и отчёт двигают листалку через
/// него, а палец докладывает ему обратно ([QuestionPager.onIndexChanged]).
///
/// Stateful ради того, что обязано пережить перестройку экрана: блоков
/// содержимого — по одному на вопрос. Страницы живут рядом, и выбор соседа
/// нельзя держать в одном общем блоке; заодно вопрос, к которому вернулись,
/// застают таким, каким оставили (выбор на месте, раскрытый ответ раскрыт),
/// а не сброшенным до записанного ответа.
class _PracticeRun extends StatefulWidget {
  const _PracticeRun();

  @override
  State<_PracticeRun> createState() => _PracticeRunState();
}

class _PracticeRunState extends State<_PracticeRun> {
  final _contentBlocs = <int, PracticeContentBloc>{};

  /// Записанный ответ, из которого блок вопроса засеян в последний раз
  /// (см. [_syncRecorded]).
  final _seeded = <int, Set<Choice>>{};

  @override
  void dispose() {
    for (final bloc in _contentBlocs.values) {
      bloc.close();
    }
    super.dispose();
  }

  /// Вопрос [id] в том виде, в каком его показывает прогон (варианты уже
  /// перетасованы блоком, а у продолженной с другого устройства симуляции —
  /// переставлены так, как их видят там).
  Question _question(PracticeBloc bloc, int id) =>
      bloc.data.questions.firstWhere((element) => element.id == id);

  /// Блок вопроса [id], один на весь прогон; заводится с записанным ранее
  /// ответом (у продолженной симуляции — из снимка).
  PracticeContentBloc _contentBloc(PracticeBloc bloc, int id) {
    return _contentBlocs.putIfAbsent(id, () {
      final recorded = bloc.state.answers[id] ?? {};
      _seeded[id] = recorded;
      return PracticeContentBloc(
        {..._question(bloc, id).choices},
        recorded,
        id,
      );
    });
  }

  /// Ответы, пришедшие в блок прогона мимо этого экрана — снимок с другого
  /// устройства («зеркало» идущей там симуляции), — доводит до блоков
  /// вопросов: иначе на странице, которую здесь уже открывали, остался бы
  /// прежний выбор. Свой записанный ответ всегда равен выбору страницы (его
  /// с неё и записали), так что для него это пустой ход.
  void _syncRecorded(PracticeState state) {
    for (final entry in _contentBlocs.entries) {
      final recorded = state.answers[entry.key];
      if (recorded == null || setEquals(recorded, _seeded[entry.key])) continue;
      _seeded[entry.key] = recorded;
      entry.value.add(RestoreSelection(recorded));
    }
  }

  /// Прогон уехал с вопроса [index] свайпом: записываем выбор ровно так же,
  /// как это делает «следеће питање» (неполный набор — подсказка и ничего не
  /// записываем; неверный при включённом показе — записываем и раскрываем
  /// верные, только уже на оставленной позади странице: страницу за пальцем
  /// не остановить).
  void _recordOnLeave(BuildContext context, int index) {
    final questBloc = context.read<PracticeBloc>();
    final state = questBloc.state;
    if (index < 0 || index >= state.questions.length) return;
    final id = state.questions[index];
    final bloc = _contentBlocs[id];
    if (bloc == null) return;
    // Тот же выбор уже записан — второй записи в истории ответов быть не
    // должно (вопрос можно листать туда-сюда сколько угодно).
    final recorded = state.answers[id];
    if (recorded != null && setEquals(recorded, bloc.state.selectedChoices)) {
      return;
    }
    _QuestionActions(context, _question(questBloc, id), content: bloc).submit();
  }

  /// Страница одного вопроса — со своим блоком содержимого и своей
  /// прокруткой.
  Widget _page(BuildContext context, PracticeBloc questBloc, int index) {
    final state = questBloc.state;
    final id = state.questions[index];
    return BlocProvider.value(
      value: _contentBloc(questBloc, id),
      child: _QuestionContent(
        question: _question(questBloc, id),
        first: index == 0,
        last: index == state.questions.length - 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PracticeBloc, PracticeState>(
      listenWhen: (previous, current) => previous.answers != current.answers,
      listener: (context, state) => _syncRecorded(state),
      builder: (context, state) {
        final questBloc = context.read<PracticeBloc>();
        final params = questBloc.params;
        final current = state.currentQuestion;
        if (current == null) {
          return Scaffold(appBar: _appBar(context, state, questBloc));
        }
        final index = state.currentQuestionIndex;
        // Блок текущего вопроса поднят над Scaffold, чтобы клавиши и прибитая
        // к низу панель широкого экрана видели выбор и раскрытие. Сам блок
        // принадлежит прогону — той же страницей он выдаётся и в листалке.
        return BlocProvider.value(
          value: _contentBloc(questBloc, current.id),
          child: BlocBuilder<PracticeContentBloc, PracticeContentState>(
            builder: (context, content) {
              final actions = _QuestionActions(context, current).examActions(
                first: index == 0,
                last: index == state.questions.length - 1,
              );
              // On a wide screen the replica follows the real software's
              // layout: the question fills the page from the left and the
              // buttons sit in a bar pinned to the bottom of the window —
              // outside the pager, so they stay put while the question rides
              // the finger. On phones the buttons stay stacked under the
              // answers, where a thumb reaches them.
              final wideExam =
                  params.buttonsLikeInExam && context.isExpandedScreen;
              final pager = QuestionPager(
                index: index,
                itemCount: state.questions.length,
                onIndexChanged: (index) =>
                    questBloc.add(NavigateToQuestion(index)),
                onLeaving: (index) => _recordOnLeave(context, index),
                itemBuilder: (context, index) =>
                    _page(context, questBloc, index),
              );
              // Клавиатура: ← / → работают как кнопки «претходно/следеће
              // питање» экзаменационной оболочки — сохраняют выбор и
              // переходят (при неверном числе ответов остаёмся с подсказкой,
              // при неверном ответе с включённым показом — раскрываем
              // верный); пробел = «прикажи одговор», если она вообще есть.
              // Стрелки на самой радиокнопке (фокус с Tab) остаются за
              // RadioGroup — он стоит ниже, на странице, и перехватывает их
              // первым.
              return KeyboardPagination(
                onPrevious: actions.previous,
                onNext: actions.next,
                onShowAnswer: content.showCorrectAnswers
                    ? null
                    : actions.showAnswer,
                child: Scaffold(
                  appBar: _appBar(context, state, questBloc),
                  body: wideExam
                      ? Column(
                          children: [
                            Expanded(child: pager),
                            _ExamActionBar(actions: actions),
                          ],
                        )
                      : pager,
                  bottomNavigationBar: params.buttonsLikeInExam
                      ? null
                      : _bottomBar(context, state, questBloc, actions),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Шапка экзамена: номер вопроса, отметка «обележи питање», таймер и цена
  /// вопроса в баллах.
  PreferredSizeWidget _appBar(
    BuildContext context,
    PracticeState state,
    PracticeBloc questBloc,
  ) {
    final quiz = Theme.of(context).quiz;
    final params = questBloc.params;
    return AppBar(
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
                // Room for the whole caption once the header is not
                // squeezed between the two chips on a phone.
                width: context.isExpandedScreen ? 220 : 150,
              ),
              // Тап по таймеру ставит симуляцию на паузу.
              Tooltip(
                message: LocaleKeys.simulation_pause_title.tr(),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => questBloc.add(PauseRequested()),
                  child: _HeaderChip(
                    // The countdown is the one element the real software
                    // renders on solid black; outside the exam replica it
                    // follows the theme's own high-contrast surface instead.
                    color: params.buttonsLikeInExam
                        ? ExamPalette.timer
                        : Theme.of(context).colorScheme.inverseSurface,
                    onColor: params.buttonsLikeInExam
                        ? Colors.white
                        : Theme.of(context).colorScheme.onInverseSurface,
                    minWidth: 50,
                    label: formatDuration(state.timeLeft),
                  ),
                ),
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
    );
  }

  /// Нижняя панель обычного (не экзаменационного) вида: стрелки, подсказка
  /// про клавиши и отчёт. Стрелки только листают — выбор записывает кнопка
  /// «следеће питање» на странице (и свайп).
  Widget _bottomBar(
    BuildContext context,
    PracticeState state,
    PracticeBloc questBloc,
    _ExamActions actions,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            IconButton(
              onPressed: state.currentQuestionIndex == 0
                  ? null
                  : () => questBloc.add(PrevQuestion()),
              icon: Icon(Icons.arrow_back_ios_new_outlined),
            ),
            SizedBox(width: 16),
            IconButton(
              onPressed:
                  state.currentQuestionIndex == state.questions.length - 1
                  ? null
                  : () => questBloc.add(NextQuestion()),
              icon: Icon(Icons.arrow_forward_ios_outlined),
            ),
            // Между стрелками и отчётом — мелкая подсказка про
            // клавиши (только на вебе, см. KeyboardHints).
            Expanded(
              child: KeyboardHints(
                showAnswer: questBloc.params.showRightAnswers,
                padding: EdgeInsets.zero,
              ),
            ),
            IconButton(
              onPressed: actions.report,
              icon: Icon(Icons.format_list_numbered),
            ),
          ],
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

/// Страница одного вопроса: текст, картинка, варианты и — вне широкого
/// экзаменационного экрана — кнопки под ними. Блок содержимого приходит
/// сверху ([BlocProvider.value]): он принадлежит прогону и переживает уход
/// страницы с экрана.
class _QuestionContent extends StatelessWidget {
  const _QuestionContent({
    required this.question,
    required this.first,
    required this.last,
  });

  final Question question;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final rightAnswers = question.choices
        .where((element) => element.isCorrect)
        .length;
    final quiz = Theme.of(context).quiz;
    final params = context.read<PracticeBloc>().params;
    final choices = [...question.choices];

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
        // The actions of the exam replica; which of them exist depends
        // on the position in the run and on the training options.
        final examActions = _QuestionActions(
          context,
          question,
        ).examActions(first: first, last: last);
        // На широком экране кнопки экзамена стоят в панели у низа окна,
        // над листалкой (см. _PracticeRun) — на странице их тогда нет.
        final wideExam = params.buttonsLikeInExam && context.isExpandedScreen;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (params.showStats) ...[
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
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                        // Своя прозрачная Material под плиткой: ListTile
                        // рисует подсветку и всплеск на ближайшей Material,
                        // а окрашенная подложка между ними их бы скрыла (и
                        // Flutter в debug-сборке об этом предупреждает).
                        child: Material(
                          type: MaterialType.transparency,
                          child: CheckboxListTile(
                            title: Text(c.text),
                            value: state.selectedChoices.contains(c),
                            onChanged: (value) => bloc.add(AddChoice(c)),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
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
                        child: Material(
                          type: MaterialType.transparency,
                          child: RadioListTile<Choice>(
                            title: Text(c.text),
                            value: c,
                          ),
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
                  onPressed: examActions.next,
                  child: Text(ExamStrings.nextQuestion),
                ),
              ),
            if (last && !params.buttonsLikeInExam)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FilledButton(
                  onPressed: examActions.endExam,
                  child: Text(ExamStrings.endExam),
                ),
              ),
            SizedBox(height: 16),
            if (!params.buttonsLikeInExam && params.showRightAnswers)
              TextButton(
                onPressed: state.showCorrectAnswers
                    ? null
                    : () => bloc.add(ShowCorrectAnswers()),
                child: Text(ExamStrings.showAnswer),
              ),
          ],
        );

        return RadioGroup<Choice>(
          groupValue: state.selectedChoices.firstOrNull,
          onChanged: (value) {
            if (value != null) bloc.add(AddChoice(value));
          },
          child: SingleChildScrollView(child: content),
        );
      },
    );
  }
}

/// Действия над одним вопросом прогона — то, что делают кнопки «претходно /
/// следеће питање», «заврши тест», «извештај» и «прикажи одговор», клавиши
/// ← / → / пробел и свайп. Блок прогона и блок содержимого вопроса берёт из
/// [context] (либо блок содержимого передают явно — так делает свайп, у
/// которого под рукой контекст уже другого вопроса).
class _QuestionActions {
  _QuestionActions(this.context, this.question, {PracticeContentBloc? content})
    : practice = context.read<PracticeBloc>(),
      content = content ?? context.read<PracticeContentBloc>();

  final BuildContext context;
  final Question question;
  final PracticeBloc practice;
  final PracticeContentBloc content;

  PracticeParams get params => practice.params;

  /// Набор кнопок экзаменационной оболочки для этого вопроса: `null` — кнопки
  /// на этом месте прогона нет (см. [_ExamActions]).
  _ExamActions examActions({required bool first, required bool last}) {
    return _ExamActions(
      previous: first ? null : previous,
      next: last ? null : next,
      endExam: finish,
      report: report,
      showAnswer: params.showRightAnswers ? showAnswer : null,
    );
  }

  /// Записывает выбор в прогон. Пустой выбор — не ответ (вопрос можно
  /// пропустить), неполный набор — подсказка и ничего не записываем.
  Future<SavedAnswer> save() async {
    final selected = content.state.selectedChoices;
    if (selected.isEmpty) return SavedAnswer.empty;
    final correct = question.choices
        .where((element) => element.isCorrect)
        .toSet();
    if (correct.length != selected.length) {
      const snackBar = SnackBar(content: Text(ExamStrings.wrongAnswerCount));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return SavedAnswer.wrongNumber;
    }
    practice.add(AddAnswer(question.id, selected));
    return setEquals(selected, correct)
        ? SavedAnswer.correct
        : SavedAnswer.incorrect;
  }

  /// Записывает выбор; неверный ответ при включённом показе ещё и раскрывает
  /// верные варианты. `false` — на вопросе нужно остаться: раскрытый ответ
  /// надо увидеть, а неполный набор — исправить.
  Future<bool> submit() async {
    final saved = await save();
    if (saved == SavedAnswer.incorrect &&
        params.showRightAnswers &&
        !content.state.showCorrectAnswers) {
      content.add(ShowCorrectAnswers());
      return false;
    }
    return saved != SavedAnswer.wrongNumber;
  }

  Future<void> previous() async {
    if (await submit()) practice.add(PrevQuestion());
  }

  Future<void> next() async {
    if (await submit()) practice.add(NextQuestion());
  }

  void showAnswer() => content.add(ShowCorrectAnswers());

  Future<void> report() async {
    final res = await _showTable(context, practice.state);
    if (res != null) practice.add(NavigateToQuestion(res));
  }

  Future<void> finish() async {
    final saved = await save();
    if (saved == SavedAnswer.incorrect &&
        params.showRightAnswers &&
        !content.state.showCorrectAnswers) {
      // нужно показать правильный ответ перед завершением
      content.add(ShowCorrectAnswers());
      return;
    }
    if (params.buttonsLikeInExam ||
        practice.state.answers.length != practice.state.questions.length) {
      if (!context.mounted) return;
      final res = await _showMyDialog(context);
      if (res != true) return;
    }
    practice.add(FinalizeTest());
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
