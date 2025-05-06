import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/state_management/all_questions_bloc.dart';
import 'package:saobracaj/state_management/practice_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/test/practice/practice_page.dart';
import 'package:saobracaj/test/practice/widgets/custom_checkbox.dart';
import 'package:saobracaj/test/practice/widgets/quest_button.dart';
import 'package:saobracaj/test/practice/widgets/question_tries.dart' hide Init;

import 'finalize_practice.dart';
import 'izvestai.dart';

part 'practice.freezed.dart';

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
                return FinalizePracticeWidget();
              }
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Color(0xFF2C6AA0),
                                width: 1,
                                style: BorderStyle.solid, // В Flutter нет 'double', можно имитировать
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              constraints: const BoxConstraints(minWidth: 120),
                              decoration: BoxDecoration(color: Color(0xFF2C6AA0), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                'Питање: ${state.currentQuestionIndex + 1} / ${state.questions.length}', // Твой текст
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
                              ),
                            ),
                          ),

                          CustomCheckbox(
                            value: state.markedQuestions.contains(state.currentQuestionIndex),
                            onChanged: (value) {
                              questBloc.add(ToggleMarkQuestion(state.currentQuestionIndex));
                            },
                            label: 'Обележите питање',
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 1, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              constraints: const BoxConstraints(minWidth: 50),
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                formatDuration(state.timeLeft),
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Број поена: ${state.currentQuestion?.points}',
                        style: TextStyle(fontSize: 14, color: Color(0xff2c6aa0), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                body:
                    state.currentQuestion == null
                        ? SizedBox()
                        : SingleChildScrollView(
                          controller: _scrollController,
                          child: _QuestionContent(
                            key: ValueKey(state.currentQuestion),
                            randomOptions: true,
                            question: state.currentQuestion!,
                            answers: state.currentAnswers,
                            last: state.currentQuestionIndex == state.questions.length - 1,
                            showPreviousTries: params.showStats,
                            params: params,
                          ),
                        ),
                bottomNavigationBar:
                    params.buttonsLikeInExam
                        ? null
                        : SafeArea(
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
            },
          ),
        );
      },
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
    final questBloc = context.read<PracticeBloc>();
    var choices = [...question.choices];

    return BlocProvider(
      key: ValueKey(question.id),
      create: (context) => QuestContentBloc(choices.toSet(), answers ?? {}, question.id),
      child: BlocBuilder<PracticeBloc, PracticeState>(
        builder: (context, practiceState) {
          return BlocBuilder<QuestContentBloc, QuesContentState>(
            builder: (context, state) {
              final bloc = context.read<QuestContentBloc>();

              return Column(
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
                  if (params.buttonsLikeInExam) ...[
                    if (practiceState.currentQuestionIndex != 0)
                      Container(
                        width: 240,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: CustomIconButton(
                          onPressed: () => _saveAndLoadNext(false, context, state, params),
                          icon: Icons.arrow_back,
                          iconPosition: IconPosition.left,
                          label: 'Претходно питање',
                          color: const Color(0xFF428bca),
                        ),
                      ),
                    if (practiceState.currentQuestionIndex != practiceState.questions.length - 1)
                      Container(
                        width: 240,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: CustomIconButton(
                          onPressed: () => _saveAndLoadNext(true, context, state, params),
                          icon: Icons.arrow_forward,
                          label: 'Следеће питање',
                          color: const Color(0xFF428bca),
                        ),
                      ),
                    Container(
                      width: 240,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: CustomIconButton(
                        onPressed: () async => await _finalizeTest(context, state, params),
                        icon: Icons.exit_to_app,
                        label: 'Крај испита',
                        color: const Color(0xffd9534f),
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
                        label: 'Извештај',
                        color: const Color(0xfffee188),
                        textColor: const Color(0xff946331),
                      ),
                    ),
                    if (params.showRightAnswers)
                      Container(
                        width: 240,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: CustomIconButton(
                          onPressed: () => bloc.add(ShowCorrectAnswers()),
                          icon: Icons.check,
                          label: 'Прикажи одговор',
                          color: const Color(0xff629b58),
                        ),
                      ),
                  ],
                  if (!params.buttonsLikeInExam)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: last ? null : () => _saveAndLoadNext(true, context, state, params),
                        child: Text('Следеће питање'),
                      ),
                    ),
                  if (last && !params.buttonsLikeInExam)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: OutlinedButton(onPressed: () async => await _finalizeTest(context, state, params), child: Text('Завершить тест')),
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
                      child: Text('Прикажи одговор'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<SavedAnswer> _saveAnswer(BuildContext context, QuesContentState state, PracticeParams params) async {
    final questBloc = context.read<PracticeBloc>();

    if (state.selectedChoices.isNotEmpty) {
      var correctAnswer = question.choices.where((element) => element.isCorrect).toSet();
      if (correctAnswer.length != state.selectedChoices.length) {
        const snackBar = SnackBar(content: Text('Нисте означили потребан број одговора'));
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

  Future<void> _finalizeTest(BuildContext context, QuesContentState state, PracticeParams params) async {
    final questBloc = context.read<PracticeBloc>();
    final bloc = context.read<QuestContentBloc>();
    final saved = await _saveAnswer(context, state, params);
    // if (saved == null) return;
    if (saved == SavedAnswer.incorrect && params.showRightAnswers && !state.showCorrectAnswers) {
      // нужно показать правильный ответ перед завершением
      bloc.add(ShowCorrectAnswers());
      return;
    }
    if (params.buttonsLikeInExam || questBloc.state.answers.length != questBloc.state.questions.length) {
      final res = await _showMyDialog(context);
      if (res != true) {
        return;
      }
    }
    questBloc.add(FinalizeTest());
  }

  Future<void> _saveAndLoadNext(bool isNext, BuildContext context, QuesContentState state, PracticeParams params) async {
    final practiceBloc = context.read<PracticeBloc>();
    final bloc = context.read<QuestContentBloc>();
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
                question: 'Питање ${i + 1}',
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

class QuestContentBloc extends Bloc<QuestContentEvent, QuesContentState> {
  final int questionId;

  QuestContentBloc(Set<Choice> choices, Set<Choice> currentAnswers, this.questionId)
    : super(QuesContentState(choices: choices, selectedChoices: currentAnswers)) {
    on<AddChoice>(_onAddChoise);
    on<ShowCorrectAnswers>(_onShowCorrectAnswers);
    // on<GetHistory>(_onGetHistory);
    // add(GetHistory());
  }

  void _onAddChoise(AddChoice event, Emitter<QuesContentState> emit) {
    var correctChoices = state.choices.where((element) => element.isCorrect);
    if (correctChoices.length > 1) {
      if (state.selectedChoices.contains(event.choice)) {
        emit(state.copyWith(selectedChoices: {...state.selectedChoices}..remove(event.choice)));
      } else if (correctChoices.length > state.selectedChoices.length) {
        emit(state.copyWith(selectedChoices: {...state.selectedChoices, event.choice}));
      }
    } else {
      emit(state.copyWith(selectedChoices: {event.choice}));
    }
  }

  void _onShowCorrectAnswers(ShowCorrectAnswers event, Emitter<QuesContentState> emit) {
    emit(state.copyWith(showCorrectAnswers: true));
  }
}

sealed class QuestContentEvent {}

class AddChoice extends QuestContentEvent {
  final Choice choice;

  AddChoice(this.choice);
}

class ShowCorrectAnswers extends QuestContentEvent {}

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
        title: Text('Да ли сигурно желите завршити теоријски испит?'),
        content: const SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              // Text('Да ли сигурно желите завршити теоријски испит?'),
              Text('Након потврде више нећете моћи унети било коју измену у дате одговоре.'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Одустаните'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Да'),
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
