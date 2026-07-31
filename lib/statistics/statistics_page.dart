import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/statistics/state_management/history_bloc.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
      builder:
          (context, allQuestionsState) => BlocProvider(
            create: (context) => HistoryBloc(allQuestionsState.questionsData!.questions),
            child: BlocBuilder<HistoryBloc, HistoryState>(
              builder: (context, state) {
                final qs = allQuestionsState.questionsData!.questions;
                return Scaffold(
                  body: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: OutlinedButton(
                          onPressed: () {
                            Routemaster.of(context).push('/start?q=${state.questions.take(100).map((e) => e.id).join(',')}');
                          },
                          child: Text('Пройти последние ошибки'),
                        ),
                      ),
                      SizedBox(height: 16),
                      ListTile(title: Text('Последние ошибки:', style: Theme.of(context).textTheme.titleMedium)),
                      ...state.questions.map(
                        (e) => ListTile(
                          onTap: () {
                            Routemaster.of(context).push('q?q=${e.id}&randomOptionsOrder=true');
                          },
                          title: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withAlpha(220),
                              borderRadius: BorderRadius.circular(8), // Закруглённые углы
                            ),
                            child: Text(qs.firstWhere((element) => element.id == e.id).text, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          trailing: SizedBox(
                            width: 60,
                            height: 48,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/img/${qs.firstWhere((element) => element.id == e.id).id}.jpeg',
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
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }
}
