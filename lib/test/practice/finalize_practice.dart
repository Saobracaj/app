import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/state_management/all_questions_bloc.dart';
import 'package:saobracaj/state_management/practice_bloc.dart';
import 'package:saobracaj/test/practice/widgets/confetti.dart';

const kMinPoints = 85;

class FinalizePracticeWidget extends StatelessWidget {
  const FinalizePracticeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text('Результаты')),
      body: BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
        builder: (context, state) {
          final qs = state.questionsData!.questions;

          return BlocBuilder<PracticeBloc, PracticeState>(
            builder: (context, state) {
              var pointsSummary = 0;
              final wrongAnswers = <int>[];
              for (var a in state.questions) {
                final q = qs.firstWhere((element) => element.id == a);
                final answers = state.answers[q.id] ?? {};
                if (!setEquals(q.choices.where((element) => element.isCorrect).toSet(), answers)) {
                  wrongAnswers.add(q.id);
                } else {
                  pointsSummary += q.points;
                }
              }
              final isSuccess = pointsSummary >= kMinPoints;

              return Scaffold(
                bottomNavigationBar: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Закрыть'),
                    ),
                  ),
                ),
                body: Stack(
                  children: [
                    if (isSuccess) ConfettiDemo(),
                    SafeArea(
                      child: ListView(
                        children: [
                          SizedBox(height: 16),
                          if (isSuccess)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withAlpha(220), // Полупрозрачный зелёный
                                  borderRadius: BorderRadius.circular(16), // Закруглённые углы
                                ),
                                child: Text(
                                  'Тест успешно пройден',
                                  style: Theme.of(context).textTheme.headlineLarge!.copyWith(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent, // Полупрозрачный зелёный
                                  borderRadius: BorderRadius.circular(16), // Закруглённые углы
                                ),
                                child: Text(
                                  'Симуляция провалена',
                                  style: Theme.of(context).textTheme.headlineLarge!.copyWith(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ListTile(title: Text('Набрано балов: $pointsSummary', style: Theme.of(context).textTheme.headlineMedium)),
                          ListTile(title: Text('Ошибок: ${wrongAnswers.length}', style: Theme.of(context).textTheme.headlineMedium)),
                          if (wrongAnswers.isNotEmpty) ...[
                            for (var q in wrongAnswers)
                              ListTile(
                                onTap: () {
                                  Routemaster.of(context).push('q?q=$q&randomOptionsOrder=true');
                                },
                                title: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface.withAlpha(220),
                                    borderRadius: BorderRadius.circular(8), // Закруглённые углы
                                  ),
                                  child: Text(qs.firstWhere((element) => element.id == q).text, maxLines: 2, overflow: TextOverflow.ellipsis),
                                ),
                                trailing: SizedBox(
                                  width: 60,
                                  height: 48,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      'assets/img/${qs.firstWhere((element) => element.id == q).id}.jpeg',
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
                                child: Text('Пройти вопросы с ошибками'),
                              ),
                            ),
                          ],
                        ],
                      ),
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
}
