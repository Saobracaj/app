import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/state_management/start_test_bloc.dart';

class StartTest extends StatelessWidget {
  const StartTest({super.key, required this.questionIds, this.subcategory});

  final List<int> questionIds;
  final String? subcategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.quest_start.tr())),
      body: BlocProvider(
        create: (context) => StartTestBloc(),
        child: BlocBuilder<StartTestBloc, StartTestState>(
          builder: (context, state) {
            final bloc = context.read<StartTestBloc>();
            return ListView(
              children: [
                CheckboxListTile(title: Text(LocaleKeys.quest_options_shuffleQuestions.tr()), value: state.random, onChanged: (value) => bloc.add(ToggleRandom())),
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
                ListTile(title: Text(LocaleKeys.quest_questions.tr(args: ['${questionIds.length}']), style: TextStyle(fontStyle: FontStyle.italic))),
                // SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Routemaster.of(context).push(
                        '/quest?q=${questionIds.join(',')}&randomOptionsOrder=${state.randomOptionsOrder}&random=${state.random}&subcategory=$subcategory',
                      );
                    },
                    child: Text(LocaleKeys.quest_start.tr()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
