import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/models/models.dart';

import '../state_management/quest_bloc.dart';
import '../state_management/quest_content_bloc.dart';

/// The pinned action bar of the question screen: "show answer" on the left,
/// and on the right the back step-button next to the confirm-then-advance
/// primary button (morphing into "finish" on the last question).
///
/// Going back is pure navigation — nothing is submitted or recorded — so it
/// stays enabled even with a selection in progress. In a single-question run
/// there is nowhere to step back to and the button disappears entirely.
class QuestBottomBar extends StatelessWidget {
  const QuestBottomBar({
    super.key,
    required this.question,
    required this.first,
    required this.last,
  });

  final Question question;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<QuestContentBloc, QuesContentState>(
      builder: (context, state) {
        return ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: state.showCorrectAnswers
                        ? null
                        : () => context.read<QuestContentBloc>().add(
                            ShowCorrectAnswers(),
                          ),
                    child: Text(LocaleKeys.quest_showAnswer.tr()),
                  ),
                  const Spacer(),
                  if (!(first && last)) ...[
                    IconButton.filledTonal(
                      tooltip: LocaleKeys.quest_previous.tr(),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(46, 46),
                      ),
                      onPressed: first
                          ? null
                          : () =>
                              context.read<QuestBloc>().add(PrevQuestion()),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 10),
                  ],
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 46),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => last
                        ? _finish(context, state)
                        : _next(context, state),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          last
                              ? LocaleKeys.quest_finish.tr()
                              : LocaleKeys.quest_next.tr(),
                        ),
                        if (!last) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _next(BuildContext context, QuesContentState state) {
    if (_submit(context, state)) {
      context.read<QuestBloc>().add(NextQuestion());
    }
  }

  Future<void> _finish(BuildContext context, QuesContentState state) async {
    final questBloc = context.read<QuestBloc>();
    if (!_submit(context, state)) return;
    if (questBloc.state.answers.length != questBloc.state.questions.length) {
      final confirmed = await _showFinishDialog(context);
      if (confirmed != true) return;
    }
    questBloc.add(FinalizeTest());
  }

  /// Records the current selection and reports whether the flow may advance.
  ///
  /// Not revealed yet: an empty selection skips the question without recording
  /// (deliberate — the only way back is the navigator sheet); a wrong-sized
  /// selection blocks with a snackbar; otherwise the answer is recorded, and a
  /// wrong one reveals the correct answers and stays on the question.
  ///
  /// Already revealed: advancing is always allowed, but if the user peeked
  /// before any attempt was recorded, a selection made after the peek counts
  /// as a wrong answer — and only once, so a normal wrong answer that was
  /// recorded on the first press is not recorded again.
  bool _submit(BuildContext context, QuesContentState state) {
    final questBloc = context.read<QuestBloc>();
    final correct = question.choices.where((c) => c.isCorrect).toSet();

    if (!state.showCorrectAnswers) {
      if (state.selectedChoices.isEmpty) return true;
      if (correct.length != state.selectedChoices.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.quest_wrongAnswerCount.tr())),
        );
        return false;
      }
      questBloc.add(AddAnswer(question.id, state.selectedChoices));
      if (!setEquals(state.selectedChoices, correct)) {
        context.read<QuestContentBloc>().add(ShowCorrectAnswers());
        return false;
      }
      return true;
    }

    if (state.selectedChoices.isNotEmpty &&
        questBloc.state.answers[question.id] == null) {
      questBloc.add(AddAnswer(question.id, {}));
    }
    return true;
  }

  Future<bool?> _showFinishDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.quest_finalDialog_title.tr()),
        content: Text(LocaleKeys.quest_finalDialog_content.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocaleKeys.quest_finalDialog_cancelButton.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(LocaleKeys.quest_finalDialog_okButton.tr()),
          ),
        ],
      ),
    );
  }
}
