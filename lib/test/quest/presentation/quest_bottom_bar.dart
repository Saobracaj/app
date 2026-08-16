import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/models/models.dart';

import '../state_management/quest_content_bloc.dart';
import 'quest_actions.dart';

/// The pinned action bar of the question screen: "show answer" on the left,
/// and on the right the back step-button next to the confirm-then-advance
/// primary button (morphing into "finish" on the last question).
///
/// Going back is pure navigation — nothing is submitted or recorded — so it
/// stays enabled even with a selection in progress. In a single-question run
/// there is nowhere to step back to and the button disappears entirely.
///
/// The buttons only dispatch to [QuestActions] — the same object the keyboard
/// shortcuts (← / → / space) call, so both inputs behave identically.
///
/// В режиме презентации ([QuestBloc.presentation]) «показать ответ» не нужна —
/// ответы и так раскрыты, — а на последнем вопросе вместо «завершить» стоит
/// «закрыть»: без итогов и без вопроса «точно завершить?».
class QuestBottomBar extends StatelessWidget {
  const QuestBottomBar({
    super.key,
    required this.question,
    required this.first,
    required this.last,
    this.inline = false,
  });

  final Question question;
  final bool first;
  final bool last;

  /// The wide layout places this bar in the scroll flow right under the
  /// answers instead of pinning it to the bottom of the window — inline it
  /// drops the bar surface and the bottom SafeArea inset.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<QuestContentBloc, QuesContentState>(
      builder: (context, state) {
        final actions = QuestActions(context, question);
        final presentation = actions.presentation;
        return ColoredBox(
          color: inline ? Colors.transparent : scheme.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            bottom: !inline,
            child: Padding(
              padding: inline
                  ? const EdgeInsets.fromLTRB(16, 14, 16, 0)
                  : const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  if (!presentation)
                    TextButton(
                      onPressed: state.showCorrectAnswers
                          ? null
                          : actions.showAnswer,
                      child: Text(LocaleKeys.quest_showAnswer.tr()),
                    ),
                  const Spacer(),
                  if (!(first && last)) ...[
                    IconButton.filledTonal(
                      tooltip: LocaleKeys.quest_previous.tr(),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(46, 46),
                      ),
                      onPressed: first ? null : actions.previous,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 10),
                  ],
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 46),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: last ? actions.finish : actions.next,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          last
                              ? (presentation
                                    ? LocaleKeys.quest_close.tr()
                                    : LocaleKeys.quest_finish.tr())
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
}
