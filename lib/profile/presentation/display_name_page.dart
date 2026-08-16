import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../../core/responsive.dart';
import '../domain/display_name_rules.dart';
import '../state_management/display_name_bloc.dart';
import '../state_management/display_name_events.dart';
import '../state_management/display_name_state.dart';

/// Profile settings screen opened by tapping the account (email) row in the
/// settings list. Lets the signed-in user set their public **display name**
/// (autosaved as they type, debounced via rxdart in [DisplayNameBloc]) and hosts
/// the "Delete account" entry point (`/deleteAccount`).
class DisplayNamePage extends StatelessWidget {
  const DisplayNamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: SafeArea(
        child: ReadableWidth(
          child: BlocProvider(
            create: (_) => getIt<DisplayNameBloc>()..add(DisplayNameStarted()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [DisplayNameContent()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Содержимое профиля (поле отображаемого имени с автосохранением и удаление
/// аккаунта) без собственного скролла — встраивается и в отдельную страницу,
/// и прямо в панель настроек на широком экране. Требует [DisplayNameBloc]
/// выше по дереву.
class DisplayNameContent extends StatefulWidget {
  const DisplayNameContent({super.key});

  @override
  State<DisplayNameContent> createState() => _DisplayNameContentState();
}

class _DisplayNameContentState extends State<DisplayNameContent> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DisplayNameBloc, DisplayNameState>(
      // Sync the controller when the initial value loads (without clobbering the
      // user's in-progress edits).
      listenWhen: (prev, curr) =>
          prev.loading != curr.loading && _controller.text.isEmpty,
      listener: (context, state) {
        if (_controller.text != state.value) {
          _controller.text = state.value;
        }
      },
      builder: (context, state) {
        if (state.loading) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final scheme = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Отображаемое имя',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Это имя видят другие пользователи рядом с вашими комментариями.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLength: displayNameMaxLen,
              inputFormatters: [
                LengthLimitingTextInputFormatter(displayNameMaxLen),
                // Keep the name single-line: strip control characters.
                FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
              ],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Ваше имя',
                border: const OutlineInputBorder(),
                errorText: state.errorMessage,
                suffixIcon: _StatusIcon(state: state),
              ),
              onChanged: (v) =>
                  context.read<DisplayNameBloc>().add(DisplayNameChanged(v)),
            ),
            const SizedBox(height: 4),
            Text(
              'От $displayNameMinLen до $displayNameMaxLen символов, '
              'не более $displayNameMaxWords слов.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _confirmDeleteAccount(context),
                icon: Icon(Icons.delete_outline, color: scheme.error),
                label: Text(
                  LocaleKeys.settings_deleteAccount.tr(),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Opens the deletion flow (checklist → consents → e-mailed code); the
  /// screen itself ends the session on success.
  void _confirmDeleteAccount(BuildContext context) {
    Routemaster.of(context).push('/deleteAccount');
  }
}

/// Trailing indicator inside the field: a spinner while saving, a check once the
/// latest value is persisted.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.state});

  final DisplayNameState state;

  @override
  Widget build(BuildContext context) {
    if (state.saving) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.saved && state.errorMessage == null) {
      return Icon(Icons.check, color: Theme.of(context).colorScheme.primary);
    }
    return const SizedBox.shrink();
  }
}
