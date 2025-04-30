import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/state_management/all_questions_bloc.dart';
import 'package:saobracaj/state_management/quest_bloc.dart';

class FinalizeTestWidget extends StatelessWidget {
  const FinalizeTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Результаты')),
      body: BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
        builder: (context, state) {
          final qs = state.questionsData!.questions;

          return BlocBuilder<QuestBloc, QuestState>(
            builder: (context, state) {
              var wrongNumber = 0;
              final wrongAnswers = <int>[];
              for (var a in state.answers.entries) {
                if (!setEquals(
                  qs.firstWhere((element) => element.id == a.key).choices.where((element) => element.isCorrect).toSet(),
                  state.answers[a.key],
                )) {
                  wrongNumber++;
                  wrongAnswers.add(a.key);
                }
              }

              return ListView(
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text('Всего вопросов: ${state.questions.length}')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Правильных ответов: ${state.rightAnswers} из ${state.answers.length} отвеченных'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Неправильных ответов: ${state.wrongAnswers} из ${state.answers.length} отвеченных'),
                  ),
                  SizedBox(height: 16 + 8),
                  if (wrongNumber > 0) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Вопросы с неправильными ответами:', style: Theme.of(context).textTheme.titleMedium),
                    ),

                    for (var a in state.answers.entries)
                      if (!setEquals(
                        qs.firstWhere((element) => element.id == a.key).choices.where((element) => element.isCorrect).toSet(),
                        state.answers[a.key],
                      ))
                        ListTile(
                          onTap: () {
                            Routemaster.of(context).push('q?q=${a.key}&randomOptionsOrder=true');
                          },
                          title: Text(qs.firstWhere((element) => element.id == a.key).text, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: SizedBox(
                            width: 60,
                            height: 48,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/img/${qs.firstWhere((element) => element.id == a.key).id}.jpeg',
                                // fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.car_crash, size: 48, color: Theme.of(context).colorScheme.secondary.withAlpha(50));
                                },
                              ),
                            ),
                          ),
                        ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: OutlinedButton(
                        onPressed: () {
                          Routemaster.of(context).push('/start?q=${wrongAnswers.join(',')}');
                        },
                        child: Text('Пройти вопросы с ошибками заново'),
                      ),
                    ),
                  ],

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Routemaster.of(context).pop();
                      },
                      child: Text('Закрыть'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
