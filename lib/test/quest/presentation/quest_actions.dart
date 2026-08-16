import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/models/models.dart';

import '../state_management/quest_bloc.dart';
import '../state_management/quest_content_bloc.dart';

/// Действия экрана вопроса — «показать ответ», «назад», «дальше», «завершить».
///
/// Одна реализация на кнопки нижней панели и на клавиатурные шорткаты
/// (← / → / пробел, см. `KeyboardPagination`): что бы ни нажал пользователь,
/// проверка выбранных вариантов, запись ответа и раскрытие верных проходят
/// по одним и тем же правилам. [context] должен видеть [QuestBloc] и
/// [QuestContentBloc] текущего вопроса.
class QuestActions {
  const QuestActions(this.context, this.question);

  final BuildContext context;
  final Question question;

  QuestBloc get _questBloc => context.read<QuestBloc>();
  QuestContentBloc get _contentBloc => context.read<QuestContentBloc>();

  /// «Режим презентации» текущего прогона (см. [QuestBloc.presentation]).
  bool get presentation => _questBloc.presentation;

  /// Раскрывает верные ответы. Повторный вызов после раскрытия — no-op, как и
  /// погашенная кнопка «показать ответ».
  void showAnswer() {
    final bloc = _contentBloc;
    if (bloc.state.showCorrectAnswers) return;
    bloc.add(ShowCorrectAnswers());
  }

  /// Шаг назад — чистая навигация: ничего не записывается.
  void previous() => _questBloc.add(PrevQuestion());

  /// Записывает текущий выбор и, если можно, переходит к следующему вопросу.
  void next() {
    if (submit()) _questBloc.add(NextQuestion());
  }

  /// Закрывает прогон без итогов и без подтверждения — «Закрыть» в режиме
  /// презентации: показывать нечего, записывать нечего.
  void close() => Routemaster.of(context).pop();

  /// Записывает текущий выбор и завершает прогон (с подтверждением, если
  /// отвечены не все вопросы). В режиме презентации — просто закрывает.
  Future<void> finish() async {
    if (presentation) {
      close();
      return;
    }
    final questBloc = _questBloc;
    if (!submit()) return;
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
  bool submit() {
    final questBloc = _questBloc;
    final contentBloc = _contentBloc;
    final state = contentBloc.state;
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
        contentBloc.add(ShowCorrectAnswers());
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
