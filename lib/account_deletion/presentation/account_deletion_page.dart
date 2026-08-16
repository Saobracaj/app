import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_state.dart';
import '../../core/di.dart';
import '../../core/responsive.dart';
import '../../generated/locale_keys.g.dart';
import '../../subscription/presentation/tariff_formatting.dart';
import '../state_management/account_deletion_bloc.dart';
import '../state_management/account_deletion_events.dart';
import '../state_management/account_deletion_state.dart';

/// «Удаление аккаунта» — opened from the profile section of the settings.
///
/// Two steps: the checklist of what goes (account, e-mail and display name are
/// fixed; comments, support photos, support conversation, group history and
/// the device-side history are the user's choice) with the consents, then the
/// e-mailed confirmation code. On success the session ends and a farewell is
/// shown; the guest can close the screen.
class AccountDeletionPage extends StatelessWidget {
  const AccountDeletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.accountDeletion_title.tr())),
      body: SafeArea(
        child: ReadableWidth(
          child: BlocBuilder<AuthBloc, AuthState>(
            buildWhen: (prev, curr) => prev.status != curr.status,
            builder: (context, auth) {
              // The bloc is created once the session is known to be live; the
              // farewell state must survive the sign-out that follows the
              // deletion, so the guest branch is only shown when no flow ran.
              if (auth.status == AuthStatus.unknown) {
                return const Center(child: CircularProgressIndicator());
              }
              return _FlowHost(
                signedIn: auth.status == AuthStatus.authenticated,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Keeps one [AccountDeletionBloc] for the life of the screen — created only
/// when signed in, kept alive across the sign-out that ends the flow.
class _FlowHost extends StatefulWidget {
  const _FlowHost({required this.signedIn});

  final bool signedIn;

  @override
  State<_FlowHost> createState() => _FlowHostState();
}

class _FlowHostState extends State<_FlowHost> {
  AccountDeletionBloc? _bloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureBloc();
  }

  @override
  void didUpdateWidget(covariant _FlowHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureBloc();
  }

  void _ensureBloc() {
    if (widget.signedIn && _bloc == null) {
      _bloc = getIt<AccountDeletionBloc>()..add(AccountDeletionStarted());
    }
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = _bloc;
    if (bloc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            LocaleKeys.accountDeletion_signInRequired.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return BlocProvider.value(value: bloc, child: const _AccountDeletionView());
  }
}

class _AccountDeletionView extends StatelessWidget {
  const _AccountDeletionView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountDeletionBloc, AccountDeletionState>(
      listenWhen: (prev, curr) => prev.codeSentTick != curr.codeSentTick,
      listener: (context, state) {
        if (state.codeSentTick > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LocaleKeys.accountDeletion_resent.tr())),
          );
        }
      },
      builder: (context, state) {
        if (state.deleted) return const _DoneView();
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.loadError != null) {
          return _LoadError(message: state.loadError!);
        }
        return switch (state.step) {
          AccountDeletionStep.options => _OptionsStep(state: state),
          AccountDeletionStep.code => _CodeStep(state: state),
        };
      },
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              LocaleKeys.accountDeletion_loadError.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => context.read<AccountDeletionBloc>().add(
                AccountDeletionStarted(),
              ),
              child: Text(LocaleKeys.accountDeletion_retry.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 1: the checklist and the consents.
class _OptionsStep extends StatelessWidget {
  const _OptionsStep({required this.state});

  final AccountDeletionState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccountDeletionBloc>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = state.preview;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(LocaleKeys.accountDeletion_intro.tr()),
        const SizedBox(height: 16),
        Text(
          LocaleKeys.accountDeletion_whatToDelete.tr(),
          style: theme.textTheme.titleSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Fixed items: checked, cannot be turned off.
        _Item(
          title: LocaleKeys.accountDeletion_itemAccount.tr(),
          hint: LocaleKeys.accountDeletion_itemAccountHint.tr(),
          value: true,
          onChanged: null,
        ),
        _Item(
          title: LocaleKeys.accountDeletion_itemDisplayName.tr(),
          hint: LocaleKeys.accountDeletion_itemDisplayNameHint.tr(),
          value: true,
          onChanged: null,
        ),
        _Item(
          title: LocaleKeys.accountDeletion_itemComments.tr(
            args: ['${preview.publicCommentCount}'],
          ),
          hint: LocaleKeys.accountDeletion_itemCommentsHint.tr(),
          value: state.deletePublicComments,
          onChanged: (v) => bloc.add(DeletePublicCommentsToggled(v)),
        ),
        _Item(
          title: LocaleKeys.accountDeletion_itemAttachments.tr(
            args: ['${preview.supportAttachmentCount}'],
          ),
          hint: LocaleKeys.accountDeletion_itemAttachmentsHint.tr(),
          value: state.deleteSupportAttachments || state.deleteSupportChat,
          // Deleting the whole conversation implies the attachments.
          onChanged: state.deleteSupportChat
              ? null
              : (v) => bloc.add(DeleteSupportAttachmentsToggled(v)),
        ),
        _Item(
          title: LocaleKeys.accountDeletion_itemSupportChat.tr(
            args: ['${preview.supportMessageCount}'],
          ),
          hint: LocaleKeys.accountDeletion_itemSupportChatHint.tr(),
          value: state.deleteSupportChat,
          onChanged: (v) => bloc.add(DeleteSupportChatToggled(v)),
        ),
        _Item(
          title: LocaleKeys.accountDeletion_itemGroupHistory.tr(
            args: ['${preview.groupActivityCount}'],
          ),
          hint: LocaleKeys.accountDeletion_itemGroupHistoryHint.tr(
            args: ['${preview.ownedGroupCount}'],
          ),
          value: state.deleteGroupHistory,
          onChanged: (v) => bloc.add(DeleteGroupHistoryToggled(v)),
        ),
        _Item(
          title: LocaleKeys.accountDeletion_itemLocal.tr(),
          hint: LocaleKeys.accountDeletion_itemLocalHint.tr(),
          value: state.clearLocalData,
          onChanged: (v) => bloc.add(ClearLocalDataToggled(v)),
        ),
        const SizedBox(height: 8),
        Text(
          LocaleKeys.accountDeletion_alwaysDeleted.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: state.acceptIrreversible,
          onChanged: (v) => bloc.add(AcceptIrreversibleToggled(v ?? false)),
          title: Text(LocaleKeys.accountDeletion_acceptIrreversible.tr()),
        ),
        if (preview.hasActiveSubscription)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: state.acceptSubscriptionLoss,
            onChanged: (v) =>
                bloc.add(AcceptSubscriptionLossToggled(v ?? false)),
            title: Text(
              LocaleKeys.accountDeletion_acceptSubscription.tr(
                args: [
                  preview.subscriptionUntil == null
                      ? '—'
                      : formatDate(preview.subscriptionUntil!),
                ],
              ),
            ),
          ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            state.errorMessage!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: state.canRequestCode
              ? () => bloc.add(RequestCodePressed())
              : null,
          icon: state.inProgress
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mail_outline),
          label: Text(LocaleKeys.accountDeletion_sendCode.tr()),
        ),
      ],
    );
  }
}

/// One row of the checklist: a checkbox (disabled = fixed choice) with a
/// title and an explanatory hint.
class _Item extends StatelessWidget {
  const _Item({
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
      title: Text(title),
      subtitle: Text(
        hint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Step 2: the e-mailed code.
class _CodeStep extends StatelessWidget {
  const _CodeStep({required this.state});

  final AccountDeletionState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccountDeletionBloc>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          LocaleKeys.accountDeletion_codeSentTo.tr(args: [state.preview.email]),
        ),
        const SizedBox(height: 16),
        _CodeField(state: state),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: state.inProgress
                ? null
                : () => bloc.add(ResendCodePressed()),
            child: Text(LocaleKeys.accountDeletion_resend.tr()),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: state.canConfirm
              ? () => bloc.add(ConfirmDeletePressed())
              : null,
          icon: state.inProgress
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_forever_outlined),
          label: Text(LocaleKeys.accountDeletion_confirmDelete.tr()),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: state.inProgress
              ? null
              : () => bloc.add(BackToOptionsPressed()),
          child: Text(LocaleKeys.accountDeletion_back.tr()),
        ),
      ],
    );
  }
}

/// The six-digit field. Stateful only for its controller (the value lives in
/// the bloc); the error comes from the server's message.
class _CodeField extends StatefulWidget {
  const _CodeField({required this.state});

  final AccountDeletionState state;

  @override
  State<_CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<_CodeField> {
  late final _controller = TextEditingController(text: widget.state.code);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: LocaleKeys.accountDeletion_codeLabel.tr(),
        border: const OutlineInputBorder(),
        errorText: widget.state.errorMessage,
      ),
      onChanged: (v) => context.read<AccountDeletionBloc>().add(CodeChanged(v)),
      onSubmitted: (_) =>
          context.read<AccountDeletionBloc>().add(ConfirmDeletePressed()),
    );
  }
}

/// The farewell, shown after the session ended.
class _DoneView extends StatelessWidget {
  const _DoneView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              LocaleKeys.accountDeletion_doneTitle.tr(),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.accountDeletion_doneBody.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Routemaster.of(context).replace('/settings'),
              child: Text(LocaleKeys.accountDeletion_close.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
