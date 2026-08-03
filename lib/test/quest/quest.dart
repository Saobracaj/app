import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/dictionary/dictionary.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/presentation/feature_gate.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/question_lists/presentation/add_to_lists_button.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_bloc.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_events.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/quest/state_management/quest_bloc.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:saobracaj/test/animations/animations_map.dart';
import 'package:saobracaj/test/practice/widgets/question_tries.dart';
import 'package:saobracaj/test/quest/state_management/quest_content_bloc.dart';
import 'package:saobracaj/test/quest/state_management/translations_bloc.dart';
import 'package:saobracaj/util/nav_to_url.dart';
import 'package:collection/collection.dart';

import 'finalize_test.dart';
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
        debugPrint(questions.toString());
        // final qs = [...state.questionsData!.questions];
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
              if (state.finalizeTest) {
                context.read<AllQuestionsBloc>().add(LoadStatistics());
                // The answers just recorded change the automatic
                // "recent mistakes" list on the home screen.
                context.read<QuestionListsBloc>().add(QuestionListsRefreshed());
                return FinalizeTestWidget();
              }
              return BlocProvider(
                key: ValueKey(
                  'translations_${state.questions[state.currentQuestionIndex]}',
                ),
                create: (context) => TranslationsBloc(),
                child: Scaffold(
                  appBar: AppBar(
                    title: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Питање: ${state.currentQuestionIndex + 1} / ${questions.length}',
                      ),
                      subtitle: Text(
                        'Број поена: ${qs.firstWhere((element) => element.id == state.questions[state.currentQuestionIndex]).points}',
                        style: TextStyle(
                          color: Color(0xff2c6aa0),
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FeatureGate(
                            feature: AppFeature.russianContent,
                            child: Builder(
                              builder: (context) => IconButton(
                                onPressed: () => context
                                    .read<TranslationsBloc>()
                                    .add(ToggleShowTranslation()),
                                icon: Icon(Icons.translate_outlined),
                              ),
                            ),
                          ),
                          // Ticking lists here keeps the menu open — see
                          // AddToListsButton.
                          AddToListsButton(
                            questionId:
                                state.questions[state.currentQuestionIndex],
                          ),
                        ],
                      ),
                    ),
                  ),
                  body: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children: state.questions.map((e) {
                            final isAnswered = state.answers[e] != null;
                            final isCorrect = (setEquals(
                              state.answers[e],
                              qs
                                  .firstWhere((element) => element.id == e)
                                  .choices
                                  .where((element) => element.isCorrect)
                                  .toSet(),
                            ));
                            return InkWell(
                              onTap: () => questBloc.add(MoveToQuestion(e)),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 100),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: !isAnswered
                                      ? Colors.grey
                                      : (isCorrect ? Colors.green : Colors.red),
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      state.questions[state
                                              .currentQuestionIndex] ==
                                          e
                                      ? Border.all(
                                          color: Colors.black,
                                          width: 2,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      /*Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Баллов: ${state.score} / ${state.possibleScore}', style: Theme.of(context).textTheme.labelSmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Правильных ответов: ${state.rightAnswers}', style: Theme.of(context).textTheme.labelSmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Неправильных ответов: ${state.wrongAnswers}', style: Theme.of(context).textTheme.labelSmall),
                    ),*/
                      SizedBox(height: 16),
                      QuestionContent(
                        key: ValueKey(
                          state.questions[state.currentQuestionIndex],
                        ),
                        randomOptions: options.randomOptionsOrder,
                        question: qs.firstWhere(
                          (element) =>
                              state.questions[state.currentQuestionIndex] ==
                              element.id,
                        ),
                        answers:
                            state.answers[state.questions[state
                                .currentQuestionIndex]],
                        last:
                            state.currentQuestionIndex ==
                            state.questions.length - 1,
                        openComments: openComments,
                        commentThreadId: commentThreadId,
                      ),
                    ],
                  ),
                  bottomNavigationBar: SafeArea(
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
                        ],
                      ),
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

class QuestionContent extends StatelessWidget {
  const QuestionContent({
    super.key,
    required this.randomOptions,
    required this.question,
    required this.answers,
    required this.last,
    this.openComments = false,
    this.commentThreadId,
  });

  final bool randomOptions;
  final Question question;
  final Set<Choice>? answers;
  final bool last;

  /// Deep-link into the discussion for this question (reveal tabs + open the
  /// comments tab and scroll to it).
  final bool openComments;
  final String? commentThreadId;

  @override
  Widget build(BuildContext context) {
    final rightAnswers = question.choices
        .where((element) => element.isCorrect)
        .length;
    final questBloc = context.read<QuestBloc>();
    var choices = [...question.choices];
    /* if (randomOptions) {
      choices.shuffle();
    }*/

    return MultiBlocProvider(
      key: ValueKey(question.id),
      providers: [
        BlocProvider(
          create: (context) => QuestContentBloc(
            choices.toSet(),
            answers ?? {},
            question.id,
            revealAnswers: openComments,
          ),
        ),
      ],
      child: BlocBuilder<QuestContentBloc, QuesContentState>(
        builder: (context, state) {
          final bloc = context.read<QuestContentBloc>();

          return BlocBuilder<TranslationsBloc, TranslationsState>(
            builder: (context, translationState) {
              return RadioGroup<Choice>(
                groupValue: state.selectedChoices.firstOrNull,
                onChanged: (value) {
                  if (value != null) bloc.add(AddChoice(value));
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    QuestionTries(question.id),
                    SizedBox(height: 16),
                    SelectableText(question.id.toString()),
                    ListTile(
                      title: QuestMarkdown(text: question.text.trim().dict),
                      subtitle:
                          (!translationState.showTranslation ||
                              question.translation == null)
                          ? null
                          : Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(question.translation!),
                            ),
                    ),
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
                        child: Text(
                          'Број потребних одговора: $rightAnswers',
                          style: TextStyle(
                            color: Color(0xff2c6aa0),
                            fontStyle: FontStyle.italic,
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
                                    ? Color(0x2200ff00)
                                    : Color(0x10ff0000)),
                          child: CheckboxListTile(
                            title: QuestMarkdown(text: c.text.trim().dict),
                            value: state.selectedChoices.contains(c),
                            onChanged: (value) => context
                                .read<QuestContentBloc>()
                                .add(AddChoice(c)),
                            controlAffinity: ListTileControlAffinity.leading,
                            subtitle:
                                (c.translationRu == null ||
                                    !translationState.showTranslation)
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(c.translationRu!),
                                  ),
                          ),
                        )
                      else
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          color: !state.showCorrectAnswers
                              ? Colors.transparent
                              : (c.isCorrect
                                    ? Color(0x22008E00)
                                    : Color(0x10ff0000)),
                          child: RadioListTile<Choice>(
                            title: QuestMarkdown(text: c.text.trim().dict),
                            value: c,
                            subtitle:
                                (c.translationRu == null ||
                                    !translationState.showTranslation)
                                ? null
                                : Text(c.translationRu!),
                          ),
                        ),

                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(8),
                      child: OutlinedButton(
                        onPressed: last
                            ? null
                            : () => _closeTest(context, state),
                        child: Text('Следеће питање'),
                      ),
                    ),
                    if (last)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: OutlinedButton(
                          onPressed: () async {
                            await _closeTest(context, state);
                            if (questBloc.state.answers.length !=
                                questBloc.state.questions.length) {
                              if (!context.mounted) return;
                              final res = await _showMyDialog(context);
                              if (res != true) {
                                return;
                              }
                            }
                            questBloc.add(FinalizeTest());
                          },
                          child: Text('Завершить тест'),
                        ),
                      ),
                    SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: state.showCorrectAnswers
                            ? null
                            : () {
                                bloc.add(ShowCorrectAnswers());
                              },
                        child: Text('Прикажи одговор'),
                      ),
                    ),

                    // SizedBox(height: 400, width: 300, child: PropushanjeAnimation()),

                    // AnimatedAutoWidget(color: Colors.green, leftIndicatorOn: true, rightIndicatorOn: true),
                    // SizedBox(height: 200, child: RoadView(moving: true,)),
                    // Mimoilazenje(),
                    // ObgonAnimacija(),
                    // Obgon(),
                    // ObyezdAnimacija(),
                    // ObyezdAnimacija2(),
                    // BlockedRoadScene(),
                    if (state.showCorrectAnswers)
                      QuestionFeaturesTabs(
                        questionId: question.id,
                        initialFeature: openComments
                            ? AppFeature.publicQuestionComments
                            : null,
                        commentThreadId: openComments ? commentThreadId : null,
                        autoScroll: openComments,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _closeTest(BuildContext context, QuesContentState state) async {
    final questBloc = context.read<QuestBloc>();
    final bloc = context.read<QuestContentBloc>();
    if (state.selectedChoices.isNotEmpty) {
      var correctAnswer = question.choices
          .where((element) => element.isCorrect)
          .toSet();
      if (correctAnswer.length != state.selectedChoices.length) {
        const snackBar = SnackBar(
          content: Text('Нисте означили потребан број одговора'),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        return;
      }
      if (!state.showCorrectAnswers) {
        questBloc.add(AddAnswer(question.id, state.selectedChoices));
      } else {
        questBloc.add(AddAnswer(question.id, {}));
      }

      if (!setEquals(state.selectedChoices, correctAnswer)) {
        if (state.showCorrectAnswers) {
          questBloc.add(NextQuestion());
          return;
        }

        bloc.add(ShowCorrectAnswers());
        return;
        //await Future.delayed(Duration(seconds: 1));
      }
    }
    questBloc.add(NextQuestion());
  }
}

Future<bool?> _showMyDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Завершить тест'),
        content: const SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(
                'Вы не дали ответ на некоторые вопросы. Вы точно хотите завершить тест?',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Отмена'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Завершить'),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  );
}

class QuestMarkdown extends StatelessWidget {
  const QuestMarkdown({
    super.key,
    required this.text,
    this.padding,
    this.useLargeText = true,
  });

  final String text;
  final EdgeInsets? padding;
  final bool useLargeText;

  @override
  Widget build(BuildContext context) {
    return Markdown(
      shrinkWrap: true,
      selectable: false,
      physics: NeverScrollableScrollPhysics(),
      data: text,
      onTapLink: (text, href, title) => openDictionary(context, href),
      padding: padding ?? EdgeInsets.zero,
      styleSheet: MarkdownStyleSheet(
        p: useLargeText ? Theme.of(context).textTheme.bodyLarge : null,
        a: TextStyle(color: Theme.of(context).colorScheme.primary),
        blockquoteDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withAlpha(40),
          borderRadius: BorderRadius.circular(2.0),
        ),
      ),
      sizedImageBuilder: (config) {
        final uri = config.uri.toString();

        final Widget imageWidget;
        if (uri.toString().startsWith('anim/')) {
          final animationName = uri.split('anim/')[1];
          imageWidget = getAnimation(animationName);
        } else if (uri.startsWith('http')) {
          imageWidget = Image.network(uri);
        } else {
          imageWidget = Image.asset('assets/md_img/$uri');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            if (config.title != null)
              Text(
                config.title!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            SizedBox(height: 8),
            imageWidget,
            SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void openDictionary(BuildContext context, String? href) async {
    if (href == null) return;
    if (href.startsWith('dict/')) {
      final link = href.split('/')[1];

      // final markdownText = await dictianoryDataSource.loadDictianory(Uri.decodeFull(link));
      showMarkdown(context, Uri.decodeFull(link));
    } else if (href.startsWith('/zakon')) {
      final link = href.split('/')[1];
      Routemaster.of(context).push(link);
    } else if (href.startsWith('zakon')) {
      Routemaster.of(context).push(href);
    } else if (href.startsWith('https://saobracaj.app/')) {
      final link = href.split('https://saobracaj.app/')[1];
      Routemaster.of(context).push(link);
    } else {
      navigateToUri(context, Uri.parse(href));
    }
  }
}

Future showMarkdown(BuildContext context, String link) async {
  final o = getDictByTitle(link);
  if (o == null) return;
  final String text = o['sr'];

  final paragraph = o['paragraph'];
  final chlan = o['chlan'];
  final chapter = o['chapter'];

  final _ = {
    'paragraph': o['paragraph'],
    'chlan': o['chlan'],
    'chapter': o['chapter'],
  };

  final uriPath = 'zakon?paragraph=$paragraph&chlan=$chlan&chapter=$chapter';
  // final uri = Uri.https('saobracaj.app', '/zakon', queryParameters).path;

  final res = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        // Для того чтобы bottom sheet не обрезался под клавиатурой
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  ((o['title'] as String?)?.capitalize() ?? '').fixMd,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              SizedBox(height: 16),
              /* TextButton(
                onPressed: () {
                  Routemaster.of(context).push(uriPath);
                },
                child: Text('Закон о безбедности саобраћаја на путевима, члан $chlan'),
              ),*/
              ListTile(
                onTap: () {
                  Routemaster.of(context).push(uriPath);
                },
                subtitle: Text(
                  'Закон о безбедности саобраћаја на путевима, члан $chlan',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              SizedBox(height: 16),
              QuestMarkdown(
                text: text.fixMd,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              if (o['ru'] != null) ...[
                SizedBox(height: 16),
                QuestMarkdown(
                  text: (o['ru'] as String).fixMd,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ],

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Back'),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
  return res;
}

extension _FixChlan on String {
  String get fixMd => replaceAll('<sup>', '').replaceAll('</sup>', '').trim();
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
