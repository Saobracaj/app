import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/presentation/feature_gate.dart';
import '../../generated/locale_keys.g.dart';
import '../domain/question_feedback_source.dart';
import '../state_management/question_feedback_bloc.dart';
import '../state_management/question_feedback_events.dart';
import '../state_management/question_feedback_state.dart';

/// Кнопка «Сообщить об ошибке» внизу вкладки вопроса — объяснения, конспекта
/// или обсуждения. Открывает диалог, который отправляет жалобу в чат
/// пользователя с разработчиком.
///
/// Видна, пока включена фича `question_feedback`.
class ReportProblemButton extends StatelessWidget {
  const ReportProblemButton({
    super.key,
    required this.questionId,
    required this.source,
  });

  final int questionId;
  final QuestionFeedbackSource source;

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      feature: AppFeature.questionFeedback,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 2),
          child: TextButton.icon(
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text(LocaleKeys.questionFeedback_report.tr()),
            onPressed: () => showQuestionFeedbackDialog(
              context,
              questionId: questionId,
              source: source,
            ),
          ),
        ),
      ),
    );
  }
}

/// Показывает диалог жалобы на вопрос.
///
/// Messenger берётся из контекста *до* открытия диалога: к моменту, когда он
/// понадобится, диалог уже закрывается и его собственный контекст использовать
/// нельзя. Переход на вход, наоборот, отложен в замыкание — оно выполняется от
/// контекста вкладки, которая всё это время остаётся на экране.
Future<void> showQuestionFeedbackDialog(
  BuildContext context, {
  required int questionId,
  required QuestionFeedbackSource source,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) =>
          getIt<QuestionFeedbackBloc>(param1: questionId, param2: source)
            ..add(QuestionFeedbackOpened()),
      child: _QuestionFeedbackDialog(
        messenger: messenger,
        onSignIn: () {
          if (!context.mounted) return;
          Routemaster.of(context).push('/login');
        },
      ),
    ),
  );
}

// Stateful ради одного FocusNode: `autofocus` на поле не срабатывает, потому
// что в момент первого кадра оно ещё disabled (signedIn приходит из блока
// асинхронно) — фокус ставится вручную, как только поле становится доступным.
class _QuestionFeedbackDialog extends StatefulWidget {
  const _QuestionFeedbackDialog({
    required this.messenger,
    required this.onSignIn,
  });

  final ScaffoldMessengerState messenger;
  final VoidCallback onSignIn;

  @override
  State<_QuestionFeedbackDialog> createState() =>
      _QuestionFeedbackDialogState();
}

class _QuestionFeedbackDialogState extends State<_QuestionFeedbackDialog> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<QuestionFeedbackBloc, QuestionFeedbackState>(
      listenWhen: (prev, curr) =>
          (curr.sent && !prev.sent) || (curr.signedIn && !prev.signedIn),
      listener: (context, state) {
        if (state.signedIn && !state.sent) {
          _focus.requestFocus();
          return;
        }
        Navigator.of(context).pop();
        widget.messenger.showSnackBar(
          SnackBar(content: Text(LocaleKeys.questionFeedback_sent.tr())),
        );
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final bloc = context.read<QuestionFeedbackBloc>();
        return AlertDialog(
          title: Text(LocaleKeys.questionFeedback_title.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  autofocus: true,
                  focusNode: _focus,
                  enabled: state.signedIn && !state.sending,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: QuestionFeedbackState.maxTextLength,
                  // Счётчик под полем нужен только у самого края лимита —
                  // «0/3800» под каждой жалобой ни о чём не говорит.
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        maxLength,
                        required isFocused,
                      }) => null,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      QuestionFeedbackState.maxTextLength,
                    ),
                  ],
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) =>
                      bloc.add(QuestionFeedbackTextChanged(value)),
                  decoration: InputDecoration(
                    labelText: LocaleKeys.questionFeedback_whatIsWrong.tr(),
                    hintText: LocaleKeys.questionFeedback_hint.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (state.signedIn) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.notify,
                    onChanged: state.sending
                        ? null
                        : (value) =>
                              bloc.add(QuestionFeedbackNotifyToggled(value)),
                    title: Text(
                      LocaleKeys.questionFeedback_notify.tr(),
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      LocaleKeys.questionFeedback_notifyHint.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (state.notificationsBlocked && !state.notify)
                    Text(
                      LocaleKeys.questionFeedback_notifyBlocked.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    LocaleKeys.questionFeedback_signInRequired.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onSignIn();
                      },
                      child: Text(LocaleKeys.questionFeedback_signIn.tr()),
                    ),
                  ),
                ],
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.sending
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(LocaleKeys.questionFeedback_cancel.tr()),
            ),
            FilledButton(
              onPressed: state.canSend
                  ? () => bloc.add(QuestionFeedbackSubmitted())
                  : null,
              child: state.sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(LocaleKeys.questionFeedback_send.tr()),
            ),
          ],
        );
      },
    );
  }
}
