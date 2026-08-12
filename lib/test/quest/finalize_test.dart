import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/presentation/wide_layout.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/questions/presentation/question_list_tile.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/quest/state_management/quest_bloc.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

class FinalizeTestWidget extends StatelessWidget {
  const FinalizeTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Результаты')),
      backgroundColor: context.isExpandedScreen
          ? widePageBackground(context)
          : null,
      body: BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
        builder: (context, state) {
          final qs = state.questionsData!.questions;

          return BlocBuilder<QuestBloc, QuestState>(
            builder: (context, state) {
              var wrongNumber = 0;
              final wrongAnswers = <int>[];
              for (var a in state.answers.entries) {
                if (!setEquals(
                  qs
                      .firstWhere((element) => element.id == a.key)
                      .choices
                      .where((element) => element.isCorrect)
                      .toSet(),
                  state.answers[a.key],
                )) {
                  wrongNumber++;
                  wrongAnswers.add(a.key);
                }
              }

              // Широкий экран: итог крупным заголовком, три плитки со счётом
              // и список ошибок под ними (макет веб-версии).
              if (context.isExpandedScreen) {
                final answered = state.answers.length;
                final quiz = Theme.of(context).quiz;
                return ListView(
                  children: [
                    WideContent(
                      maxWidth: 1000,
                      padding: const EdgeInsets.fromLTRB(40, 34, 40, 64),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PageHeading(
                            breadcrumbs: Text(
                              LocaleKeys.quest_result_finished.tr(),
                            ),
                            title: LocaleKeys.quest_result_title.tr(
                              args: [
                                '${state.rightAnswers}',
                                '${state.questions.length}',
                              ],
                            ),
                            bottomSpacing: 24,
                          ),
                          ResponsiveGrid(
                            minItemWidth: 220,
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              StatTile(
                                value: '${state.rightAnswers}',
                                label: LocaleKeys.quest_result_correct.tr(),
                                valueColor: quiz.correct,
                              ),
                              StatTile(
                                value: '$wrongNumber',
                                label: LocaleKeys.quest_result_wrong.tr(),
                                valueColor: quiz.wrong,
                              ),
                              StatTile(
                                value: '$answered',
                                label: LocaleKeys.quest_result_answered.tr(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          if (wrongNumber > 0) ...[
                            Text(
                              'Вопросы с неправильными ответами:',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            SurfaceCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  for (final id in wrongAnswers)
                                    QuestionListTile(
                                      question: qs.firstWhere(
                                        (element) => element.id == id,
                                      ),
                                      onTap: () => Routemaster.of(
                                        context,
                                      ).push('q?q=$id&randomOptionsOrder=true'),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          Row(
                            children: [
                              if (wrongNumber > 0) ...[
                                FilledButton(
                                  onPressed: () => Routemaster.of(
                                    context,
                                  ).push('/start?q=${wrongAnswers.join(',')}'),
                                  child: const Text('Работа над ошибками'),
                                ),
                                const SizedBox(width: 12),
                              ],
                              OutlinedButton(
                                onPressed: () => Routemaster.of(context).pop(),
                                child: const Text('Закрыть'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ReadableWidth(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Всего вопросов: ${state.questions.length}'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Правильных ответов: ${state.rightAnswers} из ${state.answers.length} отвеченных',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Неправильных ответов: ${state.wrongAnswers} из ${state.answers.length} отвеченных',
                      ),
                    ),
                    SizedBox(height: 16 + 8),
                    if (wrongNumber > 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Вопросы с неправильными ответами:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),

                      for (var a in state.answers.entries)
                        if (!setEquals(
                          qs
                              .firstWhere((element) => element.id == a.key)
                              .choices
                              .where((element) => element.isCorrect)
                              .toSet(),
                          state.answers[a.key],
                        ))
                          ListTile(
                            onTap: () {
                              Routemaster.of(
                                context,
                              ).push('q?q=${a.key}&randomOptionsOrder=true');
                            },
                            title: Text(
                              qs
                                  .firstWhere((element) => element.id == a.key)
                                  .text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: QuestionThumbnail(
                              question: qs.firstWhere(
                                (element) => element.id == a.key,
                              ),
                            ),
                          ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: OutlinedButton(
                          onPressed: () {
                            Routemaster.of(
                              context,
                            ).push('/start?q=${wrongAnswers.join(',')}');
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
