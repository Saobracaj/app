import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/auth/presentation/auth_button.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/questions/presentation/question_list_tile.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/statistics/state_management/history_bloc.dart';
import 'package:saobracaj/test/start_test.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
      builder: (context, allQuestionsState) {
        // A cold start on '/statistics' builds this before the question bank
        // has loaded; wait for it rather than dereference a null.
        final data = allQuestionsState.questionsData;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(LocaleKeys.home_history.tr())),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return BlocProvider(
          create: (context) => HistoryBloc(data.questions),
          child: BlocBuilder<HistoryBloc, HistoryState>(
            builder: (context, state) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(LocaleKeys.home_history.tr()),
                  actions: const [AuthButton()],
                ),
                body: ReadableWidth(
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: FilledButton(
                          onPressed: () {
                            openStartTest(
                              context,
                              state.questions
                                  .take(100)
                                  .map((e) => e.id)
                                  .toList(),
                            );
                          },
                          child: Text('Пройти последние ошибки'),
                        ),
                      ),
                      SizedBox(height: 16),
                      ListTile(
                        title: Text(
                          'Последние ошибки:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...state.questions.map(
                        (e) => QuestionListTile(
                          question: e,
                          onTap: () {
                            Routemaster.of(
                              context,
                            ).push('q?q=${e.id}&randomOptionsOrder=true');
                          },
                        ),
                      ),
                    ],
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
