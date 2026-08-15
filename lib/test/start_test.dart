import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/presentation/wide_layout.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';

/// Адрес экрана настроек прогона по этому набору вопросов.
String startTestPath(List<int> questionIds, {String? subcategory}) =>
    '/start?q=${questionIds.join(',')}'
    '${subcategory == null ? '' : '&subcategory=$subcategory'}';

/// Спрашивает настройки прогона и запускает его.
///
/// На web это диалог поверх текущего экрана: пара переключателей не стоит
/// целой страницы, а уход со списка вопросов ради них ломает ход мысли. На
/// телефоне (и в приложении вообще) остаётся отдельный экран `/start` — он же
/// открывается по прямой ссылке.
void openStartTest(
  BuildContext context,
  List<int> questionIds, {
  String? subcategory,
}) {
  if (questionIds.isEmpty) return;
  if (kIsWeb) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          StartTestDialog(questionIds: questionIds, subcategory: subcategory),
    );
    return;
  }
  Routemaster.of(
    context,
  ).push(startTestPath(questionIds, subcategory: subcategory));
}

/// Адрес самого прогона с выбранными настройками.
String _runPath(
  List<int> questionIds,
  String? subcategory,
  StartTestState state,
) =>
    '/quest?q=${questionIds.join(',')}'
    '&randomOptionsOrder=${state.randomOptionsOrder}'
    '&random=${state.random}&subcategory=$subcategory';

/// Настройки прогона диалогом (web): те же переключатели, что и на экране
/// [StartTest], число вопросов и кнопка «Начать».
class StartTestDialog extends StatelessWidget {
  const StartTestDialog({
    super.key,
    required this.questionIds,
    this.subcategory,
  });

  final List<int> questionIds;
  final String? subcategory;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<StartTestBloc>(),
      child: BlocBuilder<StartTestBloc, StartTestState>(
        builder: (context, state) {
          final bloc = context.read<StartTestBloc>();
          return AlertDialog(
            title: Text(LocaleKeys.quest_runSettings.tr()),
            contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    title: Text(LocaleKeys.quest_options_shuffleQuestions.tr()),
                    value: state.random,
                    onChanged: (_) => bloc.add(ToggleRandom()),
                  ),
                  SwitchListTile(
                    title: Text(LocaleKeys.quest_options_shuffleOptions.tr()),
                    value: state.randomOptionsOrder,
                    onChanged: (_) => bloc.add(ToggleRandomOptionsOrder()),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Text(
                      LocaleKeys.quest_questions.tr(
                        args: ['${questionIds.length}'],
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(LocaleKeys.quest_finalDialog_cancelButton.tr()),
              ),
              FilledButton(
                onPressed: () {
                  final path = _runPath(questionIds, subcategory, state);
                  Navigator.of(context).pop();
                  Routemaster.of(context).push(path);
                },
                child: Text(LocaleKeys.quest_start.tr()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class StartTest extends StatelessWidget {
  const StartTest({super.key, required this.questionIds, this.subcategory});

  final List<int> questionIds;
  final String? subcategory;

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
                                onPressed: () => Routemaster.of(context).push(
                                  _runPath(questionIds, subcategory, state),
                                ),
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
                      onPressed: () => Routemaster.of(
                        context,
                      ).push(_runPath(questionIds, subcategory, state)),
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
