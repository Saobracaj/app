import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../auth/presentation/auth_flow.dart';
import '../../auth/state_management/auth/auth_bloc.dart';
import '../../core/di.dart';
import '../../core/responsive.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/subscription_bloc.dart';
import '../state_management/subscription_events.dart';
import '../state_management/subscription_state.dart';

/// Страница, на которую lava.top возвращает человека после оплаты:
/// `/tariffs/lava?invoiceId=…&status=…`.
///
/// `status` из адреса не источник истины — только повод показать ошибку
/// быстрее: страница в любом случае спрашивает бэкенд, оплачен ли счёт,
/// пока тот не ответит «да» или «нет» (или не выйдет время), и после
/// активации уходит на экран подписки тем же путём, что и покупка в сторе.
class LavaReturnPage extends StatelessWidget {
  const LavaReturnPage({super.key, required this.invoiceId, this.status});

  final String invoiceId;

  /// `status`, который lava.top дописал к адресу возврата (например
  /// `failed` или `cancelled`); может отсутствовать.
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.subscription_lavaReturnTitle.tr())),
      body: BlocProvider(
        create: (_) =>
            getIt<SubscriptionBloc>()..add(LavaReturnRequested(invoiceId)),
        child: _LavaReturnBody(invoiceId: invoiceId),
      ),
    );
  }
}

class _LavaReturnBody extends StatelessWidget {
  const _LavaReturnBody({required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authenticated = context.select(
      (AuthBloc bloc) => bloc.state.isAuthenticated,
    );
    return BlocConsumer<SubscriptionBloc, SubscriptionState>(
      listenWhen: (prev, curr) =>
          curr.activatedSku != null && curr.activatedSku != prev.activatedSku,
      listener: (context, state) {
        final message = state.infoMessage;
        if (message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
        // Оплачено и активировано: «назад» не должно возвращать сюда.
        Routemaster.of(context).replace('/subscription');
      },
      builder: (context, state) {
        final bloc = context.read<SubscriptionBloc>();
        // Пока опрос не закончился отказом, страница ждёт: и первый кадр до
        // старта опроса, и сам опрос — одно и то же «обрабатываем платёж».
        final failed =
            !state.lavaAwaitingPayment &&
            (state.lavaPaymentFailed || state.errorMessage != null);
        final children = <Widget>[];
        if (!authenticated && state.errorMessage != null) {
          // Вкладка вернулась без сессии (например, другой браузер): войти
          // и переспросить.
          children.addAll([
            Text(LocaleKeys.subscription_signInToBuy.tr()),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => openLogin(context),
              child: Text(LocaleKeys.subscription_signInToBuy.tr()),
            ),
          ]);
        } else if (!failed) {
          children.addAll([
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
            Text(
              LocaleKeys.subscription_lavaAwaiting.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ]);
        } else {
          children.addAll([
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              state.errorMessage ?? LocaleKeys.subscription_lavaFailed.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                if (!state.lavaPaymentFailed ||
                    state.errorMessage ==
                        LocaleKeys.subscription_lavaTimeout.tr())
                  OutlinedButton(
                    onPressed: () => bloc.add(LavaReturnRequested(invoiceId)),
                    child: Text(LocaleKeys.subscription_lavaCheckAgain.tr()),
                  ),
                FilledButton(
                  onPressed: () => Routemaster.of(context).replace('/tariffs'),
                  child: Text(LocaleKeys.subscription_lavaToTariffs.tr()),
                ),
              ],
            ),
          ]);
        }
        return ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              ),
            ],
          ),
        );
      },
    );
  }
}
