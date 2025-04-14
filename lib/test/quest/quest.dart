import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/state_management/all_questions_bloc.dart';
import 'package:saobracaj/state_management/quest_bloc.dart';
import 'package:saobracaj/state_management/start_test_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'finalize_test.dart';

part 'quest.freezed.dart';

class Quest extends StatelessWidget {
  const Quest({super.key, required this.questions, required this.options, this.subcategory});

  final List<int> questions;
  final StartTestState options;
  final String? subcategory;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
      builder: (context, state) {
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
          create: (context) => QuestBloc(state.questionsData!, options.random ? ([...questions]..shuffle()) : questions, subcategory),
          child: BlocBuilder<QuestBloc, QuestState>(
            builder: (context, state) {
              final questBloc = context.read<QuestBloc>();
              if (state.finalizeTest) {
                context.read<AllQuestionsBloc>().add(LoadStatistics());
                return FinalizeTestWidget();
              }
              return Scaffold(
                appBar: AppBar(
                  title: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Питање: ${state.currentQuestionIndex + 1} / ${questions.length}'),
                    subtitle: Text(
                      'Број поена: ${qs.firstWhere((element) => element.id == state.questions[state.currentQuestionIndex]).points}',
                      style: TextStyle(color: Color(0xff2c6aa0), fontStyle: FontStyle.italic),
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
                        children:
                            state.questions.map((e) {
                              final isAnswered = state.answers[e] != null;
                              final isCorrect = (setEquals(
                                state.answers[e],
                                qs.firstWhere((element) => element.id == e).choices.where((element) => element.isCorrect).toSet(),
                              ));
                              return InkWell(
                                onTap: () => questBloc.add(MoveToQuestion(e)),
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 100),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: !isAnswered ? Colors.grey : (isCorrect ? Colors.green : Colors.red),
                                    borderRadius: BorderRadius.circular(20),
                                    border: state.questions[state.currentQuestionIndex] == e ? Border.all(color: Colors.black, width: 2) : null,
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
                      key: ValueKey(state.questions[state.currentQuestionIndex]),
                      randomOptions: options.randomOptionsOrder,
                      question: qs.firstWhere((element) => state.questions[state.currentQuestionIndex] == element.id),
                      answers: state.answers[state.questions[state.currentQuestionIndex]],
                      last: state.currentQuestionIndex == state.questions.length - 1,
                    ),
                  ],
                ),
                bottomNavigationBar: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed:
                              state.currentQuestionIndex == 0
                                  ? null
                                  : () {
                                    questBloc.add(PrevQuestion());
                                  },
                          icon: Icon(Icons.arrow_back_ios_new_outlined),
                        ),
                        SizedBox(width: 16),
                        IconButton(
                          onPressed:
                              state.currentQuestionIndex == state.questions.length - 1
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
              );
            },
          ),
        );
      },
    );
  }
}

class QuestionContent extends StatelessWidget {
  const QuestionContent({super.key, required this.randomOptions, required this.question, required this.answers, required this.last});

  final bool randomOptions;
  final Question question;
  final Set<Choice>? answers;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final rightAnswers = question.choices.where((element) => element.isCorrect).length;
    final questBloc = context.read<QuestBloc>();
    var choices = [...question.choices];
    /* if (randomOptions) {
      choices.shuffle();
    }*/

    return BlocProvider(
      key: ValueKey(question.id),
      create: (context) => QuestContentBloc(choices.toSet(), answers ?? {}, question.id),
      child: BlocBuilder<QuestContentBloc, QuesContentState>(
        builder: (context, state) {
          final bloc = context.read<QuestContentBloc>();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  state.previousTries.isEmpty ? 'Вы ранее не отвечали на этот вопрос' : 'Предыдущие попытки',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  children: [
                    if (state.previousTries.isNotEmpty)
                      for (var s in state.previousTries)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: s ? Colors.red : Colors.green, borderRadius: BorderRadius.circular(20)),
                        ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Text('${question.id}, ${question.hasImage}, ${question.imageId}, '),
              ListTile(title: Text(question.text.trim())),
              if (question.hasImage)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 200, maxHeight: 600, maxWidth: 600),
                    child: Image.network('https://klgleb.github.io/saobracajData/img/${question.imageId}.jpeg'),
                  ),
                ),
              if (rightAnswers > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Број потребних одговора: $rightAnswers', style: TextStyle(color: Color(0xff2c6aa0), fontStyle: FontStyle.italic)),
                ),
              for (var c in choices)
                if (rightAnswers > 1)
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    color: !state.showCorrectAnswers ? Colors.transparent : (c.isCorrect ? Color(0x2200ff00) : Color(0x10ff0000)),
                    child: CheckboxListTile(
                      title: Text(c.text),
                      value: state.selectedChoices.contains(c),
                      onChanged: (value) => context.read<QuestContentBloc>().add(AddChoice(c)),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  )
                else
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    color: !state.showCorrectAnswers ? Colors.transparent : (c.isCorrect ? Color(0x22008E00) : Color(0x10ff0000)),
                    child: RadioListTile<Choice>(
                      title: Text(c.text),
                      value: c,
                      groupValue: state.selectedChoices.firstOrNull,
                      onChanged: (value) {
                        context.read<QuestContentBloc>().add(AddChoice(c));
                      },
                    ),
                  ),

              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                child: ElevatedButton(onPressed: last ? null : () => _closeTest(context, state), child: Text('Следеће питање')),
              ),
              if (last)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: OutlinedButton(
                    onPressed: () async {
                      await _closeTest(context, state);
                      if (questBloc.state.answers.length != questBloc.state.questions.length) {
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
              SizedBox(height: 16),
              TextButton(
                onPressed:
                    state.showCorrectAnswers
                        ? null
                        : () {
                          bloc.add(ShowCorrectAnswers());
                        },
                child: Text('Прикажи одговор'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _closeTest(BuildContext context, QuesContentState state) async {
    final questBloc = context.read<QuestBloc>();
    final bloc = context.read<QuestContentBloc>();
    if (state.selectedChoices.isNotEmpty) {
      var correctAnswer = question.choices.where((element) => element.isCorrect).toSet();
      if (correctAnswer.length != state.selectedChoices.length) {
        const snackBar = SnackBar(content: Text('Нисте означили потребан број одговора'));
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

class QuestContentBloc extends Bloc<QuestContentEvent, QuesContentState> {
  final int questionId;

  QuestContentBloc(Set<Choice> choices, Set<Choice> currentAnswers, this.questionId)
    : super(QuesContentState(choices: choices, selectedChoices: currentAnswers)) {
    on<AddChoice>(_onAddChoise);
    on<ShowCorrectAnswers>(_onShowCorrectAnswers);
    on<GetHistory>(_onGetHistory);
    add(GetHistory());
  }

  void _onAddChoise(AddChoice event, Emitter<QuesContentState> emit) {
    if (state.choices.where((element) => element.isCorrect).length > 1) {
      if (state.selectedChoices.contains(event.choice)) {
        emit(state.copyWith(selectedChoices: {...state.selectedChoices}..remove(event.choice)));
      } else {
        emit(state.copyWith(selectedChoices: {...state.selectedChoices, event.choice}));
      }
    } else {
      emit(state.copyWith(selectedChoices: {event.choice}));
    }
  }

  void _onShowCorrectAnswers(ShowCorrectAnswers event, Emitter<QuesContentState> emit) {
    emit(state.copyWith(showCorrectAnswers: true));
  }

  void _onGetHistory(GetHistory event, Emitter<QuesContentState> emit) async {
    final res = await repository.getAnswersByQuestionId(questionId);
    final arr = <bool>[];
    for (var r in res) {
      arr.add(r.isWrong);
    }
    emit(state.copyWith(previousTries: arr));
  }
}

sealed class QuestContentEvent {}

class AddChoice extends QuestContentEvent {
  final Choice choice;

  AddChoice(this.choice);
}

class ShowCorrectAnswers extends QuestContentEvent {}

class GetHistory extends QuestContentEvent {}

@freezed
sealed class QuesContentState with _$QuesContentState {
  const factory QuesContentState({
    @Default({}) Set<Choice> choices,
    @Default({}) Set<Choice> selectedChoices,
    @Default(false) bool showCorrectAnswers,
    @Default([]) List<bool> previousTries,
  }) = _QuesContentState;
}

Future<bool?> _showMyDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Завершить тест'),
        content: const SingleChildScrollView(
          child: ListBody(children: <Widget>[Text('Вы не дали ответ на некоторые вопросы. Вы точно хотите завершить тест?')]),
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
