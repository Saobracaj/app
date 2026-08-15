import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/presentation/wide_layout.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/statistics/phantom_subcategory.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';

class StartTest extends StatelessWidget {
  const StartTest({super.key, required this.questionIds, this.subcategory});

  final List<int> questionIds;
  final String? subcategory;

  /// Адрес прогона с выбранными настройками.
  String _runPath(StartTestState state) => quizRunPath(
    questionIds: questionIds,
    subcategory: subcategory,
    options: state,
  );

  @override
  Widget build(BuildContext context) {
    // Широкий экран: переключатели одной карточкой слева, а число вопросов и
    // кнопка «Начать» — карточкой-стартером справа (макет веб-версии).
    if (context.isExpandedScreen) {
      return Scaffold(
        appBar: AppBar(title: Text(LocaleKeys.quest_runSettings.tr())),
        backgroundColor: widePageBackground(context),
        body: BlocProvider(
          create: (context) => getIt<StartTestBloc>(),
          child: BlocBuilder<StartTestBloc, StartTestState>(
            builder: (context, state) {
              final bloc = context.read<StartTestBloc>();
              return ListView(
                children: [
                  WideContent(
                    // Блок настроек в макете прижат к левому краю колонки
                    // страницы, а не центрирован в окне.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 940),
                      child: MainWithSide(
                        main: SurfaceCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(
                                  LocaleKeys.quest_options_shuffleQuestions
                                      .tr(),
                                ),
                                value: state.random,
                                onChanged: (_) => bloc.add(ToggleRandom()),
                              ),
                              Divider(height: 1),
                              SwitchListTile(
                                title: Text(
                                  LocaleKeys.quest_options_shuffleOptions.tr(),
                                ),
                                value: state.randomOptionsOrder,
                                onChanged: (_) =>
                                    bloc.add(ToggleRandomOptionsOrder()),
                              ),
                            ],
                          ),
                        ),
                        side: SurfaceCard(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${questionIds.length}',
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                LocaleKeys.quest_questionsInRun.tr(),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => Routemaster.of(
                                  context,
                                ).push(_runPath(state)),
                                child: Text(LocaleKeys.quest_start.tr()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.quest_start.tr())),
      body: BlocProvider(
        create: (context) => getIt<StartTestBloc>(),
        child: BlocBuilder<StartTestBloc, StartTestState>(
          builder: (context, state) {
            final bloc = context.read<StartTestBloc>();
            return ReadableWidth(
              child: ListView(
                children: [
                  CheckboxListTile(
                    title: Text(LocaleKeys.quest_options_shuffleQuestions.tr()),
                    value: state.random,
                    onChanged: (value) => bloc.add(ToggleRandom()),
                  ),
                  CheckboxListTile(
                    title: Text(LocaleKeys.quest_options_shuffleOptions.tr()),
                    value: state.randomOptionsOrder,
                    onChanged: (value) => bloc.add(ToggleRandomOptionsOrder()),
                  ),
                  /* CheckboxListTile(
                  title: Text('Перемешивать варианты ответов'),
                  value: state.randomOptionsOrder,
                  onChanged: (value) => bloc.add(ToggleRandomOptionsOrder()),
                ),*/
                  ListTile(
                    title: Text(
                      LocaleKeys.quest_questions.tr(
                        args: ['${questionIds.length}'],
                      ),
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  // SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () =>
                          Routemaster.of(context).push(_runPath(state)),
                      child: Text(LocaleKeys.quest_start.tr()),
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

/// Адрес экрана вопросов (`/quest`) для прогона [questionIds] с настройками
/// [options].
///
/// `subcategory` попадает в адрес только когда он есть: прогон ошибок или
/// списка вопросов идёт без блока, и интерполяция `null` давала
/// `subcategory=null` — маршрут читал это как блок с именем «null», результат
/// уходил в статистику и в ленту группы как `block "null"`.
String quizRunPath({
  required List<int> questionIds,
  required StartTestState options,
  String? subcategory,
}) {
  final path = StringBuffer('/quest?q=${questionIds.join(',')}')
    ..write('&randomOptionsOrder=${options.randomOptionsOrder}')
    ..write('&random=${options.random}');
  if (!isPhantomSubcategory(subcategory)) {
    path.write('&subcategory=${Uri.encodeQueryComponent(subcategory!.trim())}');
  }
  return path.toString();
}
