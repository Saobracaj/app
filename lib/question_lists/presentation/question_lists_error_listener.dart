import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/locale_keys.g.dart';
import '../state_management/question_lists_bloc.dart';
import '../state_management/question_lists_events.dart';
import '../state_management/question_lists_state.dart';

/// Surfaces a failed list write as a snackbar, wherever in the app it happened
/// (home screen, list screen, the menu on the question screen).
///
/// The optimistic change has already been rolled back by the repository at this
/// point, so the message only has to tell the user that nothing was saved.
class QuestionListsErrorListener extends StatelessWidget {
  const QuestionListsErrorListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<QuestionListsBloc, QuestionListsState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.questionLists_saveError.tr())),
        );
        context.read<QuestionListsBloc>().add(QuestionListsErrorShown());
      },
      child: child,
    );
  }
}
