import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/practice/state_management/question_tries_bloc.dart';

class QuestionTries extends StatelessWidget {
  const QuestionTries(this.qid, {super.key});

  final int qid;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => QuestionTriesBloc(qid),
      child: BlocBuilder<QuestionTriesBloc, List<bool>>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  state.isEmpty ? LocaleKeys.quest_noPreviousTries.tr():  LocaleKeys.quest_previousTries.tr(),
                  style: Theme
                      .of(context)
                      .textTheme
                      .labelSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  children: [
                    if (state.isNotEmpty)
                      for (var s in state)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: s ? Colors.red : Colors.green, borderRadius: BorderRadius.circular(20)),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
