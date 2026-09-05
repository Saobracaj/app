import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/extension_request_bloc.dart';
import '../state_management/extension_request_events.dart';
import '../state_management/extension_request_state.dart';

/// Диалог «Не сдал экзамен»: дата экзамена и комментарий, отправка в чат с
/// разработчиком. После отправки — снэкбар и переход в сам чат, где придёт
/// ответ.
///
/// Messenger и переходы берутся от контекста экрана, а не диалога: к моменту,
/// когда они понадобятся, диалог уже закрыт.
Future<void> showExtensionRequestDialog(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) =>
          getIt<ExtensionRequestBloc>()..add(ExtensionRequestOpened()),
      child: _ExtensionRequestDialog(
        messenger: messenger,
        onSent: () {
          if (!context.mounted) return;
          Routemaster.of(context).push('/support');
        },
        onSignIn: () {
          if (!context.mounted) return;
          Routemaster.of(context).push('/login');
        },
      ),
    ),
  );
}

class _ExtensionRequestDialog extends StatelessWidget {
  const _ExtensionRequestDialog({
    required this.messenger,
    required this.onSent,
    required this.onSignIn,
  });

  final ScaffoldMessengerState messenger;
  final VoidCallback onSent;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExtensionRequestBloc, ExtensionRequestState>(
      listenWhen: (prev, curr) => curr.sent && !prev.sent,
      listener: (context, state) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(LocaleKeys.subscription_extensionSent.tr())),
        );
        onSent();
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final bloc = context.read<ExtensionRequestBloc>();
        final enabled = state.signedIn && !state.sending;
        return AlertDialog(
          title: Text(LocaleKeys.subscription_extensionDialogTitle.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.subscription_extensionPromiseBody.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  enabled: enabled,
                  keyboardType: TextInputType.datetime,
                  onChanged: (value) =>
                      bloc.add(ExtensionExamDateChanged(value)),
                  decoration: InputDecoration(
                    labelText: LocaleKeys.subscription_extensionExamDate.tr(),
                    hintText: LocaleKeys.subscription_extensionExamDateHint
                        .tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: enabled,
                  minLines: 2,
                  maxLines: 5,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      ExtensionRequestState.maxNoteLength,
                    ),
                  ],
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) => bloc.add(ExtensionNoteChanged(value)),
                  decoration: InputDecoration(
                    labelText: LocaleKeys.subscription_extensionNote.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (!state.signedIn) ...[
                  const SizedBox(height: 12),
                  Text(
                    LocaleKeys.subscription_extensionSignIn.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onSignIn();
                      },
                      child: Text(LocaleKeys.questionFeedback_signIn.tr()),
                    ),
                  ),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
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
                  ? () => bloc.add(ExtensionRequestSubmitted())
                  : null,
              child: state.sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(LocaleKeys.subscription_extensionSend.tr()),
            ),
          ],
        );
      },
    );
  }
}
