
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/state_management/all_questions_bloc.dart';

part 'statistics_page.freezed.dart';

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
                      ...state.questions.map((e) => ListTile(onTap: () {
                        Routemaster.of(
                          context,
                        ).push('/quest?q=${e.id}&randomOptionsOrder=true');
                      }, title: Text(e.text, maxLines: 2, overflow: TextOverflow.ellipsis))),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }
}

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final List<Question> allQuestions;

  HistoryBloc(this.allQuestions) : super(HistoryState()) {
    on<Init>(_init);
    add(Init());
  }

  void _init(Init event, Emitter<dynamic> emit) async {
    final res = await repository.getQuestionsWhereLastAnswerWasWrong();
    final arr = <Question>[];
    for (int qid in res) {
      arr.add(allQuestions.firstWhere((element) => element.id == qid));
    }

    emit(state.copyWith(questions: arr));
  }
}

sealed class HistoryEvent {}

class Init extends HistoryEvent {}

@freezed
sealed class HistoryState with _$HistoryState {
  const factory HistoryState({@Default([]) List<Question> questions}) = _HistoryState;
}
