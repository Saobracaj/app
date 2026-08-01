import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/notifications_bloc.dart';
import '../state_management/notifications_events.dart';
import '../state_management/notifications_state.dart';

/// Standalone "Notifications" screen opened from the settings list (mirrors the
/// Appearance screen): email and push preferences. The push toggle follows the
/// OS permission — see [NotificationsBloc].
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.settings_notifications.tr())),
      body: SafeArea(
        child: BlocProvider(
          create: (_) => getIt<NotificationsBloc>()..add(NotificationsStarted()),
          child: const _NotificationsView(),
        ),
      ),
    );
  }
}

/// Thin stateful shell whose only job is to re-check the OS permission when the
/// app is resumed (e.g. after returning from the system settings).
class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<NotificationsBloc>().add(AppResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationsBloc, NotificationsState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && curr.errorMessage != prev.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!.tr())),
        );
      },
      builder: (context, state) {
        final bloc = context.read<NotificationsBloc>();
        return ListView(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.mail_outline),
              title: Text(LocaleKeys.settings_emailNotifications.tr()),
              value: state.emailNotifications,
              onChanged: state.loading
                  ? null
                  : (v) => bloc.add(EmailNotificationsToggled(v)),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: Text(LocaleKeys.settings_pushNotifications.tr()),
              subtitle: Text(
                kIsWeb
                    ? LocaleKeys.settings_pushOnThisBrowser.tr()
                    : LocaleKeys.settings_pushOnThisDevice.tr(),
              ),
              value: state.pushEnabled,
              onChanged: state.loading
                  ? null
                  : (v) => bloc.add(PushNotificationsToggled(v)),
            ),
            if (state.systemPermanentlyDenied && !state.pushEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  LocaleKeys.settings_pushBlockedHint.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
